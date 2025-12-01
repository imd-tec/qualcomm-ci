#!/bin/bash
#=============================================================================================================================================================================
#title: poll_development_repo.sh
#description
#     For use exclusively within the trigger-build.yml workflow.
#     Triggered on scheduled cron job. See top of trigger-build.yml for details.
#     Script is accessed from the qualcomm-ci repository so takes <path_to_manifest_repo> as an argument to access development manifests. 
#     As a development manifest can refer to a development meta layer branch, as opposed to a revision commit hash, 
#     this script must clone the given  meta layer repository and determine if relevant build files have been changed since the previous cron job.
#     The last checked commit hash is stored in a local state file for each project branch being monitored (see /mnt/nvme1/qcom_ci/dev_repo_poll/state/)
#     If changes are detected, the script outputs the path to the development manifest to $GITHUB_OUTPUT and continues the build process.
#
#     Additionally, A monitored repository labelled 'FAILED' will attempt to build irrespective of if there have been
#     any changes since the last attempt. Inversely, builds labelled as 'SUCCESS' will not build. 
#usage:
#     poll_development_repo.sh --manifest_repo_path <path_to_manifest_repo>
#outputs:
#     A txt file containing the path to the development manifest
#=============================================================================================================================================================================
set -eu

DEV_REPO_CACHE_PATH="/mnt/nvme1/qcom_ci/dev_repo_poll/cache"
DEV_REPO_STATE_PATH="/mnt/nvme1/qcom_ci/dev_repo_poll/state"
RELEVANT_FILES='^(conf/|recipes-|tools/|patches/|contents\.xml$)'
manifest_path=""
development_branches=""
trigger_build=false

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

function get_manifest_path() {
    #find the development manifest file in the repository
    cd "$MANIFEST_REPO_PATH"
    manifest_path=$(find . -type f -name 'development.xml' | head -n 1)
    if [ -z "$manifest_path" ]; then
        echo "No development manifest found in the repository."
        exit 1
    fi
    echo "Found development manifest: $manifest_path"
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

        #must handle the fact that some meta layer repositories may have the same branch name
        #name="meta-imdt-qcom-dev" name="clo/le/meta-qti-gst" ... => meta-imdt-qcom-dev clo/le/meta-qti-gst ... 
        repo_names=$(xmllint --xpath "//project[@revision='$branch']/@name" "$manifest_path" \
                    | grep -o 'name=\"[^\"]*\"' \
                    | cut -d'"' -f2)

        for repo_name in $repo_names; do
            echo -e "Checking for changes in $repo_name($branch)\n"
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
            repo_file_name=${repo_name//\//_} # clo/le/meta-qti-gst => clo_le_meta-qti-gst
            state_file="$DEV_REPO_STATE_PATH/$repo_file_name.$branch.last"

            last_date=''
            last_hash=''
            last_result=''
            
            #if state file exists, read previous hash and success status
            if [ -f "$state_file" ]; then
                #date, hash and status from state .last file (i.e., "Wed 26 Nov 18:32:24 GMT 2025 | 8aa69f5.... | SUCCESS")
                IFS='|' read -r last_date last_hash last_result < "$state_file"
                echo -e "\nLast attempted build on $last_date."
            fi

            #if last_hash does not exist; it's the first build => continue with build
            if [ -z "$last_hash" ]; then
                echo -e "\nNo previous state found for $repo_name. Assuming first build. Continuing build process..." 
                update_output "$state_file" "$current_hash"
                continue
            fi

            #if there is no detected change (i.e., the current and last hashes are the same) and the previous result was a SUCCESS => continue to next candidate
            if [ "$last_hash" == "$current_hash" ]  && [ "$last_result" == "SUCCESS" ]; then
                echo -e "\nPrevious build was labelled $last_result and no changes detected in:\n $repo_url ($branch)\nPrevious hash  $last_hash\nCurrent hash    $current_hash\n\nUp to date. Skipping build trigger."    
                continue
            fi

            #if there is no detected change, BUT the previous run was a failure => continue with build
            if [ "$last_hash" == "$current_hash" ]  && [ "$last_result" == "FAILURE" ]; then
                echo -e "\nNo new changes since last build attempt, but previous build was labelled $last_result. Attempting to build again..."
                update_output "$state_file" "$current_hash"
                continue
            fi       
            
            #if there is a detected change, perform diff check to determine if meaningful build files have been affected
            if [ -n "$last_hash" ] && [ "$last_hash" != "$current_hash" ]; then
                echo "Comparing files between $last_hash and $current_hash:"
                files=$(git diff --name-only "$last_hash" "$current_hash")
                
                #only continue with build if relevant files have been changed
                include=$(printf "%s\n" "$files" | grep -E "$RELEVANT_FILES" || true)
                if [ -z "$include" ]; then
                    echo "No relevant files were modified. Skipping build trigger."
                    continue
                else
                    echo -e "\nRelevant changes detected:\n$include\nContinuing build process..."
                    update_output "$state_file" "$current_hash"
                    continue
                fi
            fi
        done

    done
    
    #if the build has been set to trigger, append manifest path to manifests.txt to signal build in later steps 
    if $trigger_build; then
        echo "$manifest_path" >> "$RUNNER_TEMP/manifests.txt"
    fi

    #send accumulated repository details to output for later logging job
    if [ -f "$RUNNER_TEMP/repo_states.txt" ]; then
    {
        echo "repo_states<<EOF"
        cat "$RUNNER_TEMP/repo_states.txt"
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
    fi
}


function update_output() {
        local state_file="$1"
        local current_hash="$2"
 
        trigger_build=true
        #append details of triggering repository and state file for later logging purposes
        echo "${state_file}|${current_hash}" >> "$RUNNER_TEMP/repo_states.txt"
}

parse_args "$@"
get_manifest_path
get_development_revisions
check_for_differences

