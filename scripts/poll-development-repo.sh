#!/bin/bash
#=============================================================================================================================================================================
#title: poll-development-repo.sh
#description
#     For use exclusively within the trigger-build.yml workflow.
#     Triggered on scheduled cron job. See top of trigger-build.yml for details.
#     Script exists in qualcomm-ci repository so takes <path_to_manifest_repo> as an argument to access development manifests from calling repository.
#
#     As a development manifest can refer to a development meta layer branch, as opposed to a static revision commit hash, 
#     this script must clone the given meta layer repository and determine if relevant build files have been changed since the previous cron job.
#     The last checked commit hashes and build status are stored in a local state file for each project branch being monitored (see ${CI_DEV_DIR}/state/)
#     Detected changes trigger the build process and are passed to output for use in a later logging step (see update-dev-state.sh in /imd-tec/qualcomm-ci).
#
#     Additionally, A monitored repository labelled 'FAILED' or 'CANCELLED' will attempt to build irrespective of if there have been
#     any changes since the last attempt. Builds labelled as 'SUCCESS' will not build. 
#usage:
#     poll-development-repo.sh --manifest_repo_path <path_to_manifest_repo> --manifest_repo_name <manifest_repo_name>
#outputs:
#     A txt file containing the relevant metalayer repositories and their current commit hashes
#=============================================================================================================================================================================
set -eu

DEV_REPO_CACHE_PATH="${CI_DEV_DIR}/cache"
DEV_REPO_STATE_PATH="${CI_DEV_DIR}/state"
RELEVANT_FILES='^(conf/|recipes-|tools/|patches/|contents\.xml$)'
manifest_path=""
meta_dev_branches=""
trigger_build=false


function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--manifest_repo_path)  MANIFEST_REPO_PATH="$2"; shift 2 ;;
      -n|--manifest_repo_name)  MANIFEST_REPO_NAME="$2"; shift 2 ;;
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
        echo "ERROR: No development manifest found in the repository."
        exit 1
    fi
    echo "Found development manifest: $manifest_path"
}

function get_development_revisions() {
    #check all project revisions that do not match /^[0-9a-fA-F]{40}$/ (ie. commit hash)
    commit_hash_regex='^[0-9a-fA-F]{40}$'

    #get all revisions from project tags from manifest (i.e.,  "revision="kirkstone"")
    revision_keys=$(xmllint --xpath "//project/@revision" "$manifest_path" | grep -oE 'revision="[^"]+"') 
    
    #extract revision names (i.e., kirkstone)
    revision_names=$(cut -d'"' -f2 <<< "$revision_keys")
    
    #remove commit hash revisions and keep unique branch names only
    meta_dev_branches=$(grep -Ev "$commit_hash_regex"  <<< "$revision_names" | sort -u)

    if [ -z "$meta_dev_branches" ]; then
        echo "No non-commit hash revisions found in the manifest. Exiting."
        exit 0
    fi
    echo "Found non-commit hash revisions: $meta_dev_branches"
}

function check_for_differences() {
    #ensure state file has unique name per project development manifest to avoid overwrites 
    project_name=$(basename "$MANIFEST_REPO_NAME") #e.g., imdt-qcom-manifest-dev
    state_file="$DEV_REPO_STATE_PATH/$project_name.last" #e.g., /mnt/nvme1/qcom_ci/dev_repo_poll/state/imdt-qcom-manifest-dev.last
    #if state file does not exist; it's the first build => continue with build
    if [ ! -f "$state_file" ]; then
        echo -e "\nNo previous state file found for $project_name. Assuming first build. Continuing build process..." 
        trigger_build=true

    fi

    #read last recorded result and date from state file
    last_result=""
    last_date=""
    if [ -f "$state_file" ]; then
        #first line: PROJECT | DATE | RESULT
        IFS='|' read -r project last_date last_result < "$state_file"
        last_date=$(xargs <<< "$last_date")
        last_result=$(xargs <<< "$last_result")

        if [ -n "$last_result" ]; then
            echo -e "\nFOUND PROJECT: $project\nLast recorded run: $last_result on $last_date"
        fi
    fi       

    #even if first build, still iterate through all relevant repos and hashes for later state file update
    for branch in $meta_dev_branches; do
        cd "$MANIFEST_REPO_PATH"
        #get all repos with this branch name

        #name="meta-imdt-qcom-dev" name="clo/le/meta-qti-gst" ... => meta-imdt-qcom-dev clo/le/meta-qti-gst ... 
        repo_names=$(xmllint --xpath "//project[@revision='$branch']/@name" "$manifest_path" \
                    | grep -o 'name=\"[^\"]*\"' \
                    | cut -d'"' -f2)

        for repo_name in $repo_names; do
            cd "$MANIFEST_REPO_PATH"
            echo -e "\n[$project] Checking for changes in $repo_name($branch)\n"

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
            
            #if not labelled "SUCCESS" -> update output with candidate
            if [ "$last_result" != "SUCCESS" ]; then
                update_output "$repo_name" "$current_hash"
                continue
            fi
            
            #get last checked hash for this repo from state file
            last_hash=""
            if [ -f "$state_file" ]; then
                #after first line: META-LAYER | HASH
                last_hash=$(grep -m1 "^$repo_name *|" "$state_file" | cut -d'|' -f2 | xargs || true)
            fi

            #if there is no stored last_hash; it's the first build => continue with build
            if [ -z "$last_hash"  ]; then
                echo -e "\nNo previous state found for $repo_name. Assuming first build. Continuing build process..." 
                update_output "$repo_name" "$current_hash"
                continue
            fi

            #if there is no detected change (i.e., the current hash already exists in the state file) => continue to next candidate
            current_hash_exists=$(grep  -m1 -c "$current_hash" "$state_file" || true)
            if [  "$current_hash_exists" -gt 0 ] && [ "$last_result" == "SUCCESS" ]; then
                echo -e "\nState file contains most recent hash:\n $repo_url ($branch)\nCurrent hash: $current_hash\n\nUp to date. Skipping build trigger."    
                continue
            fi

            #if there is a detected change (i.e., the hash cannot be found), perform diff check to determine if meaningful build files have been affected
            if [ "$current_hash_exists" -eq 0 ]; then
                echo "Comparing files between $last_hash and $current_hash:"
                files=$(git diff --name-only "$last_hash" "$current_hash")
                
                #only continue with build if relevant files have been changed
                include=$(printf "%s\n" "$files" | grep -E "$RELEVANT_FILES" || true)
                if [ -z "$include" ]; then
                    echo "No relevant files were modified. Skipping build trigger."
                    continue
                else
                    echo -e "\nRelevant changes detected:\n$include\nContinuing build process..."
                    update_output "$repo_name" "$current_hash"
                    continue
                fi
            fi
        done

    done
    
    #if the build has been set to trigger, append manifest path to manifests.txt to signal build in later steps 
    if $trigger_build; then
        echo -e "\nBuild will be triggered. Appending manifest path to output file."
        echo "$manifest_path" >> "$RUNNER_TEMP/manifests.txt"
        else
        echo -e "\nNo changes detected. No build will be triggered."
    fi

    #send accumulated repository details to output for later state file updates in reusable build workflow
    if [ -f "$RUNNER_TEMP/dev_state_log.txt" ]; then
    {
        echo "dev_state_log<<EOF"
        cat "$RUNNER_TEMP/dev_state_log.txt"
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
    fi
}

function update_output() {
        local repo_name="$1"
        local current_hash="$2"
        trigger_build=true

        #append details of triggering repository and state file for later logging purposes
        echo "${repo_name}|${current_hash}" >> "$RUNNER_TEMP/dev_state_log.txt"
}

parse_args "$@"
get_manifest_path
get_development_revisions
check_for_differences
