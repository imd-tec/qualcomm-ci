#!/bin/bash
#=============================================================================================================================================================================
#title: poll_development_repo.sh
#description
#     For use exclusively within the trigger-build.yml workflow.
#     Triggered on scheduled cron job. See top of trigger-build.yml for details.
#     Script is accessed from the qualcomm-ci repository so takes <path_to_manifest_repo> as an argument to access development manifests. 
#     As a development manifest can refer to a development meta layer branch, as opposed to a revision commit hash, 
#     this script must clone the given  meta layer repository and determine if relevant build files have been changed since the previous cron job.
#     The last checked commit hash is stored in a local file for each project branch being monitored (see /mnt/nvme1/qcom_ci/dev_repo_poll/state/)
#     If changes are detected, the script outputs the path to the development manifest to $GITHUB_OUTPUT and continues the build process.
#usage:
#     poll_development_repo.sh --manifest_repo_path <path_to_manifest_repo>
#outputs:
#     A txt file containing the path to the development manifest
#=============================================================================================================================================================================
set -eu

function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--manifest_repo_path)
        MANIFEST_REPO_PATH="$2"; shift 2 ;;
      *)
        echo "Unknown option: $1"; exit 1 ;;
    esac
  done
}


DEV_REPO_CACHE_PATH="/mnt/nvme1/qcom_ci/dev_repo_poll/cache"
DEV_REPO_STATE_PATH="/mnt/nvme1/qcom_ci/dev_repo_poll/state"
RELEVANT_FILES='^(conf/|recipes-|tools/|patches/|contents\.xml$)'
manifest_path=""
development_branches=""

function get_manifest_path() {
    #find the development manifest file in the repository
    cd "$MANIFEST_REPO_PATH"
    manifest_path=$(find . -type f -name 'development.xml' | head -n 1)
    if [ -z "$manifest_path" ]; then
        echo "No development manifest found in the repository."
        exit 1
    fi
    echo "Found development manifest: $manifest_path"

    echo "$manifest_path"
}

function get_development_revisions() {
    #check all project revisions that do not match /^[0-9a-fA-F]{40}$/ (ie. commit hash)
    commit_hash_regex='^[0-9a-fA-F]{40}$'
    #get all revisions from project tags from manifest (i.e.,  "revision="kirkstone"")
    revision_keys=$(xmllint --xpath "//project/@revision" "$manifest_path" | grep -oE 'revision="[^"]+"') 
    #extract revision names (i,.e., kirkstone)
    revision_names=$(echo "$revision_keys" | cut -d'"' -f2)
    #remove commit hash revisions and keep unique branch names only
    development_branches=$(echo "$revision_names" | grep -Ev "$commit_hash_regex" | sort -u)

    if [ -z "$development_branches" ]; then
        echo "No non-commit hash revisions found in the manifest. Exiting."
        exit 0
    fi
    echo "Found non-commit hash revisions: $development_branches"
}

function check_for_differences() {
    for branch in $development_branches; do
        echo -e "Checking for changes in branch: $branch\n"

        #get meta layer project name for this branch
        repo_name=$(xmllint --xpath "string(//project[@revision='$branch']/@name)" "$manifest_path" ) #meta-imdt-qcom-dev
        #TODO - Handling multiple projects with the same branch name (unlikely but possible)
        #get remote from first project with this branch
        remote=$(xmllint --xpath "string(//project[@name='$repo_name']/@remote)" "$manifest_path") #imdt
        #get fetch org url from remote
        base_url=$(xmllint --xpath "string(//remote[@name='$remote']/@fetch)" "$manifest_path") #https://github.com/imd-tec"

        #construct repo url
        repo_url="${base_url}/${repo_name}.git"

        #ensure cache and state directories exist
        mkdir -p "${DEV_REPO_CACHE_PATH}" "${DEV_REPO_STATE_PATH}" 
        
        #clone repo into local cache if not already cached
        if [ ! -d "$DEV_REPO_CACHE_PATH/$repo_name" ]; then
            git clone "$repo_url" "$DEV_REPO_CACHE_PATH/$repo_name"
        fi

        #get current hash for the branch
        cd "$DEV_REPO_CACHE_PATH/$repo_name"
        git fetch origin "$branch"
        current_hash=$(git rev-parse origin/"$branch")

        #attempt to load previous hash from state file
        state_file="$DEV_REPO_STATE_PATH/$repo_name.last"
        previous_hash=""

        #if state file exists, read previous hash
        if [ -f "$state_file" ]; then
            #read line from state file (i.e., "Wed 26 Nov 18:32:24 GMT 2025 8aa69f5....")
            line=$(cat "$state_file") 
            #extract hash from line 
            previous_hash=${line##* } 
            #extract date from state file for logging purposes
            last_date="${line% "$previous_hash"}" 
            echo -e "\nLast checked on $last_date."
        fi

        if [ "$previous_hash" == "$current_hash" ]; then
            echo -e "\nNo changes detected in branch: $branch\nPrevious hash  $previous_hash\nCurrent hash   $current_hash\n\nUp to date. Skipping build trigger."    
        fi
        
        #if previous_hash exists, perform diff check to determine if relevant files have changed
        if [ -n "$previous_hash" ] && [ "$previous_hash" != "$current_hash" ]; then
            echo "Comparing files between $previous_hash and $current_hash:"
            files=$(git diff --name-only "$previous_hash" "$current_hash")
            
            #only continue with build if relevant files, as previously outlined, have been changed
            include=$(printf "%s\n" "$files" | grep -E "$RELEVANT_FILES" || true)
            if [ -z "$include" ]; then
                echo "No relevant files were modified. Skipping build trigger."
            else
                echo "Relevant changes detected:"
                echo "$include"
                echo "Continuing build process..."
                echo "$manifest_path" >> "$RUNNER_TEMP/manifests.txt"
            fi
        fi

        #if previous_hash does not exist; it's the first build => continue with build
        if [ -z "$previous_hash" ]; then
            echo -e "\nNo previous state found for $repo_name. Assuming first build. Continuing build process..." 
            echo "$manifest_path" >> "$RUNNER_TEMP/manifests.txt"
        fi

        #echo current_hash hash to state file for scheduled comparison
        echo "$(date) $current_hash" > "$state_file"
    done
}

parse_args "$@"
get_manifest_path
get_development_revisions
check_for_differences