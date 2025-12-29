#!/bin/bash
#=============================================================================================================================================================================
#title: get-changed-manifests.sh
#description:
#     For use exclusively within the trigger-build.yml workflow.
#     This script takes the previous commit SHA (BEFORE_SHA) and the latest commit SHA (CURRENT_SHA) as inputs.
#     This script must be accessed from a seperate checked-out repository (qualcomm-ci), 
#     the manifest repository path must be provided as an argument to ensure that the diff check is being perfomed in correct location.
#     The diff check identifies any manifest XML files that were added, modified, copied or renamed between the two commits.
#usage:
#     get-manifest-diff.sh -before_sha <previous_commit_sha> -current_sha <latest_commit_sha> -manifest_repo_path <path_to_manifest_repo>
#outputs:
#     A newline separated list of changed manifest files written to the self-hosted runner temp file: $RUNNER_TEMP/manifests.txt
#=============================================================================================================================================================================
set -e 

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
  #perform diff check and populate MANIFESTS array
  #in the case of a new branch or repo, BEFORE_SHA may be invalid. Set it to an empty tree for valid first diff-check.
  if [ -z "${BEFORE_SHA:-}" ] || [ "$BEFORE_SHA" = "0000000000000000000000000000000000000000" ]; then 
    BEFORE_SHA=$(git hash-object -t tree /dev/null) 
  fi

  echo "Checking for changed XML files between $BEFORE_SHA and $CURRENT_SHA in manifest repo at path: $MANIFEST_REPO_PATH."
  #change to manifest repo directory for diff check
  cd "$MANIFEST_REPO_PATH"
  
  #perform diff check to determine XML files that were added (A), modified (M), copied (C) or renamed (R) and output to array
  mapfile -t MANIFESTS < <(git diff --name-only --diff-filter=AMCR \
          "$BEFORE_SHA" "$CURRENT_SHA" \
          | grep -E '\.xml$')
}

function validate_diff_check() {
    #validate array and exit if no changed manifests found
    echo "Found ${#MANIFESTS[@]} changed XML files:"
    if [ ${#MANIFESTS[@]} -eq 0 ]; then
        echo "No manifests changed."
        {
          echo "## Triggered Builds"
          echo "_No manifests changed in this push._"
          echo "**Note:** Only added or modified XML files trigger builds."
        } >> "$GITHUB_STEP_SUMMARY"
    fi
    printf '%s\n' "${MANIFESTS[@]}"

}

parse_args "$@"
determine_changed_manifests
validate_diff_check
#pass each manifest to output as a new-line separated result for json-ification in next step
printf '%s\n' "${MANIFESTS[@]}" > "$RUNNER_TEMP/manifests.txt"
