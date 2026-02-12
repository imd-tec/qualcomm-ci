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
#     If multiple development manifests exist, lines are prefixed with the manifest path for filtering in later steps.
#
#     Additionally, a monitored repository labelled 'FAILED' or 'CANCELLED' will attempt to build irrespective of if there have been
#     any changes since the last attempt. Builds labelled as 'SUCCESS' will not build. 
#
#usage:
#     poll-development-repo.sh --manifest_repo_path <path_to_manifest_repo> --manifest_repo_name <manifest_repo_name>
#outputs:
#     A txt file containing the relevant metalayer repositories and their current commit hashes. 
#=============================================================================================================================================================================
set -eu

DEV_REPO_CACHE_PATH="${CI_DEV_DIR}/cache"
DEV_REPO_STATE_PATH="${CI_DEV_DIR}/state"
RELEVANT_FILES='^(conf/|recipes-|tools/|patches/|contents\.xml$)'

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

function poll_development_manifests() {
    # Find development manifest files in the repository and iterate through them, checking for changes.
    # If a manifest is not associated with a build config it will be skipped.
    # Trigger build and log build state as applicable.
    local dev_manifest_paths
    local dev_manifest_path
    local dev_manifest_filename
    local dev_manifest_dir
    local config_file

    cd "$MANIFEST_REPO_PATH"
    dev_manifest_paths=$(find . -type f -name 'development*.xml')
    if [ -z "$dev_manifest_paths" ]; then
        echo "ERROR: No development manifests found in the repository."
        exit 1
    fi
    echo "Found $(echo "$dev_manifest_paths" | wc -l) development manifest(s)."
    echo -e "Development manifest paths:\n $dev_manifest_paths"

    for dev_manifest_path in $dev_manifest_paths; do
        echo "================================================================="
        dev_manifest_dir=$(dirname "$dev_manifest_path")
        dev_manifest_filename=$(basename "$dev_manifest_path" .xml)
        config_file="$dev_manifest_dir/ci-build-config.yml"
        if [ -f "$config_file" ] && grep -q -E "^${dev_manifest_filename}:" "$config_file" 2>/dev/null; then
            process_manifest "$dev_manifest_path"
        else
            echo "No build config found for $dev_manifest_filename. Skipping..."
        fi
    done

    #export log file to output for use in later steps
    if [ -e "$RUNNER_TEMP/dev_state_log.txt" ]; then
        { 
            echo "dev_state_log<<EOF"
            cat "$RUNNER_TEMP/dev_state_log.txt"
            echo "EOF"
        } >> "$GITHUB_OUTPUT"
    fi
}

function process_manifest() {
    # Process a single development manifest file to check for changes in relevant meta-layer repositories.
    # If a relevant change is detected via diff-checking, or if the last build was not successful, signal to trigger a build.
    local dev_manifest_path="$1"
    local dev_manifest_filename=$(basename "$dev_manifest_path")
    local dev_manifest_name=${dev_manifest_filename%.*} #remove file extension
    local repository_name=$(basename "$MANIFEST_REPO_NAME") #e.g., imsu-glasses-manifest-dev
    local state_file="$DEV_REPO_STATE_PATH/${repository_name}-${dev_manifest_name}.last" #e.g., /${CI_DEV_DIR}/state/imsu-glasses-manifest-dev-development-glasses.last
    local trigger_manifest_build=false

    echo "Processing development manifest: $dev_manifest_path"

    # If state file does not exist; it's the first build => signal build and continue
    if [ ! -f "$state_file" ]; then
        echo -e "\nNo previous state file found for $state_file. Assuming first build. Continuing build process..." 
        trigger_manifest_build=true
    else
        #extract last recorded result from state file and check if previous build was not successful, if so => RETRY BUILD
        #first line: PROJECT | DATE | RESULT
        echo -e "\nReading state file: $state_file"
        IFS='|' read -r project last_date last_result < "$state_file"
        project=$(xargs <<< "$project")
        last_date=$(xargs <<< "$last_date")
        last_result=$(xargs <<< "$last_result")
        if [ -n "$last_result" ]; then
            echo -e "\nLast recorded run: $last_result on $last_date"
        fi
        if [ "$last_result" != "SUCCESS" ]; then
            echo "Last build was not SUCCESS. Retrying..."
            trigger_manifest_build=true
        fi
    fi

    #get meta-layer branches to be polled for given manifest
    local meta_dev_branches=""
    get_metalayer_branches "$dev_manifest_path"

    for branch in $meta_dev_branches; do
        #name="meta-imdt-qcom-dev" ; name="clo/le/meta-qti-gst" ... => meta-imdt-qcom-dev clo/le/meta-qti-gst ... 
        local meta_layers=$(xmllint --xpath "//project[@revision='$branch']/@name" "$dev_manifest_path" \
                    | grep -o 'name=\"[^\"]*\"' \
                    | cut -d'"' -f2)
        for meta_layer in $meta_layers; do
            if repo_has_changes "$meta_layer" "$branch" "$dev_manifest_path" "$state_file"; then
                trigger_manifest_build=true
            fi
        done
    done

    #if the build has been set to trigger, append current manifest path to manifests.txt to signal build process 
    if $trigger_manifest_build; then
        echo -e "\nSignalling to build. Appending '$dev_manifest_filename' to output file."
        echo "$dev_manifest_path" >> "$RUNNER_TEMP/manifests.txt"
    else
        echo -e "\nNo changes detected. '$dev_manifest_name' will not be built."
    fi
}

function get_metalayer_branches() {    
    # Get all meta-layer revisions that are not hashes
    local dev_manifest_path="$1"
    #extract revisions from project tags from manifest (i.e.,  "revision="kirkstone"")
    revision_keys=$(xmllint --xpath "//project/@revision" "$dev_manifest_path" | grep -oE 'revision="[^"]+"')     
    #extract revision names (i.e., kirkstone)
    revision_names=$(cut -d'"' -f2 <<< "$revision_keys")
    #remove commit hash revisions and keep unique branch names only
    commit_hash_regex='^[0-9a-fA-F]{40}$'
    meta_dev_branches=$(grep -Ev "$commit_hash_regex"  <<< "$revision_names" | sort -u)

    echo -e "\nFound non-commit hash revisions: $meta_dev_branches"
}

function repo_has_changes() {
    # Check if the given meta layer repository has changes in relevant files since the last recorded commit hash in the state file.
    # Signals to trigger build if changes are detected, or if the last recorded hash is undefined (e.g., first run or state file deleted).
    local meta_layer="$1"
    local branch="$2"
    local dev_manifest_path="$3"
    local dev_manifest_name=$(basename "$dev_manifest_path" .xml)
    local state_file="$4"

    #construct repo url for cloning and  clone repo into local cache if not already cached
    local remote=$(xmllint --xpath "string(//project[@name='$meta_layer']/@remote)" "$dev_manifest_path") #imdt
    local base_url=$(xmllint --xpath "string(//remote[@name='$remote']/@fetch)" "$dev_manifest_path") #https://github.com/imd-tec"
    local repo_url="${base_url}/${meta_layer}.git"
    echo -e "Checking for changes in '$meta_layer'('$branch')\n"

    mkdir -p "${DEV_REPO_CACHE_PATH}" "${DEV_REPO_STATE_PATH}"
    if [ ! -d "$DEV_REPO_CACHE_PATH/$meta_layer" ]; then
        echo "Cloning repository '$meta_layer' from '$repo_url' into local cache..."
        git clone "$repo_url" "$DEV_REPO_CACHE_PATH/$meta_layer"
    fi

    #fetch and get current hash 
    local current_hash=""
    current_hash=$(
        cd "$DEV_REPO_CACHE_PATH/$meta_layer"
        git fetch origin "$branch"
        git rev-parse origin/"$branch"
    )

    #append to GH output
    #NOTE: always log the current hash for every repository, regardless of whether
    #      relevant changes are later detected. This is used for state tracking when
    #      updating the dev state file (see log-dev-state.sh).
    echo "${dev_manifest_name}|${meta_layer}|${current_hash}" >> "$RUNNER_TEMP/dev_state_log.txt"

    #if applicable, get last checked hash for this repository from state file
    local last_hash=""
    if [ -f "$state_file" ]; then 
        last_hash=$(grep -m1 "^$meta_layer *|" "$state_file" | cut -d'|' -f2 | xargs || true)
    fi

    #if last_hash is undefined => signal build
    if [ -z "$last_hash"  ]; then
        echo -e "\nNo previous state found for $meta_layer. Assuming first build." 
        return 0 
    fi
    
    #if hashes differ with relevant files modified => signal build
    if [ "$last_hash" != "$current_hash" ]; then
        echo "Comparing files between $last_hash and $current_hash:"
        #check if relevant files have been modified
        local changed_files=$(
            cd "$DEV_REPO_CACHE_PATH/$meta_layer"
            git diff --name-only "$last_hash" "$current_hash"
        )
        include=$(printf "%s\n" "$changed_files" | grep -E "$RELEVANT_FILES" || true)
        if [ -n "$include" ]; then
            echo -e "\nRelevant changes detected:\n$include\n"
            return 0 
        else
            #no relevant files changed => no changes; skip build
            echo "No relevant files were modified. Skipping build for $meta_layer."
            return 1
        fi
    else
        #hashes are the same => no changes; skip build
        return 1
    fi
}

parse_args "$@"
poll_development_manifests
if [ -s "$RUNNER_TEMP/manifests.txt" ]; then
    echo -e "\nSignalling builds for: \n"
    cat "$RUNNER_TEMP/manifests.txt"
else
    echo -e "\nNo builds were signalled; '$RUNNER_TEMP/manifests.txt' is empty."
fi
