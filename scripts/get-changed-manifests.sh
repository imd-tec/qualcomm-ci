#!/bin/bash
#=============================================================================================================================================================================
#title: get-changed-manifests.sh
#description:
#     For use exclusively within the trigger-build.yml workflow.
#     This script takes the previous manifest repository commit SHA (BEFORE_SHA) and the latest commit SHA (CURRENT_SHA) as inputs.
#     As this script must be accessed from a separate checked-out repository (qualcomm-ci), the manifest repository path must be provided 
#     as an argument to ensure that the diff check is being performed in correct location.
#     The diff identifies any manifest XML files that were added, modified, copied or renamed between the two commits.
#
#     If any development manifests are detected, their state files are updated to QUEUED_FOR_BUILD to trigger a build in the next scheduled cron job.
#usage:
#     get-changed-manifests.sh -before_sha <previous_commit_sha> -current_sha <latest_commit_sha> -manifest_repo_path <path_to_manifest_repo>
#outputs:
#     A newline separated list of changed manifest files written to the self-hosted runner temp file: $RUNNER_TEMP/manifests.txt
#=============================================================================================================================================================================
set -e 

MANIFESTS=()
ALL_MANIFESTS=()

if [ -z "${CI_DEV_DIR:-}" ]; then
    echo "ERROR: CI_DEV_DIR is not set."
    exit 1
fi

function parse_args() {
while [[ $# -gt 0 ]]; do
  case "$1" in
    --before_sha)         BEFORE_SHA="$2"; shift 2 ;;
    --current_sha)        CURRENT_SHA="$2"; shift 2 ;;
    --manifest_repo_path) MANIFEST_REPO_PATH="$2"; shift 2 ;;
    *)
      echo "Unknown option: $1"; exit 1 ;;
  esac
done
}

function determine_changed_manifests() {
  # Perform git diff on manifest repository and populate ALL_MANIFESTS array
  
  #in the case of a new branch or repo, BEFORE_SHA may be invalid. Set it to an empty tree for valid first diff-check.
  if [ -z "${BEFORE_SHA:-}" ] || [ "$BEFORE_SHA" = "0000000000000000000000000000000000000000" ]; then 
    BEFORE_SHA=$(git hash-object -t tree /dev/null) 
  fi

  echo "Checking for changed XML files between $BEFORE_SHA and $CURRENT_SHA in manifest repo at path: $MANIFEST_REPO_PATH."

  #perform diff check to determine XML files that were added (A), modified (M), copied (C) or renamed (R) and output to array
  cd "$MANIFEST_REPO_PATH"
  mapfile -t ALL_MANIFESTS < <(git diff --name-only --diff-filter=AMCR \
          "$BEFORE_SHA" "$CURRENT_SHA" \
          | grep -E '\.xml$' || true)
}

function check_if_development() {
    # Iterate through ALL_MANIFESTS to check if any of the changed manifests are development manifests
    # If so, update their state files to QUEUED_FOR_BUILD to trigger build next scheduled trigger
    local repository_base=$(basename "$GITHUB_REPOSITORY")    

    for manifest in "${ALL_MANIFESTS[@]}"; do
        if [[ "$(basename "$manifest")" == development*.xml ]]; then
            echo -e "\nChanged development manifest detected: $manifest"

            #construct state file path
            DEV_REPO_STATE_PATH="${CI_DEV_DIR}/state"
            local manifest_base="$(basename "$manifest" .xml)"
            local state_file="${DEV_REPO_STATE_PATH}/${repository_base}-${manifest_base}.last"

            #ensure state directory exists and set state to QUEUED_FOR_BUILD for intended schedule build trigger
            mkdir -p "$DEV_REPO_STATE_PATH"
            printf '%s | %s | %s\n' "$repository_base" "$(date)" "QUEUED_FOR_BUILD" > "$state_file"
            echo "Updated state file: $state_file (Status: QUEUED_FOR_BUILD)"
        else
            #update the global MANIFESTS array with non-development manifests
            MANIFESTS+=("$manifest")
        fi
    done
}

function validate_diff_check() {
    # Validate MANIFESTS array and exit, echoing to GH STEP SUMMARY if no changed manifests found
    echo -e "\nFound ${#MANIFESTS[@]} changed non-development xml files:"
    if [ ${#MANIFESTS[@]} -eq 0 ]; then
        echo "No production manifests changed."
        {
          echo "## Triggered Builds"
          echo "_No production manifests changed in this push._"
          echo
          echo "**Note**: Only added or modified production manifests trigger immediate builds."
          echo "Modified development manifests are queued for next scheduled cron job."
        } >> "$GITHUB_STEP_SUMMARY"
    fi
    printf '%s\n' "${MANIFESTS[@]}"

}

parse_args "$@"
determine_changed_manifests
check_if_development
validate_diff_check

#pass each manifest to output as a new-line separated result for json-ification in next step
printf '%s\n' "${MANIFESTS[@]}" > "$RUNNER_TEMP/manifests.txt"
