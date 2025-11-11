#!/bin/bash
# For use exclusively when callee manifest repository build workflow is triggered by push events
# This script takes BEFORE_SHA (previous sha) and CURRENT_SHA (latest sha) for the manifest repo commit hashes for the given trigger event as arguments
# It perfomes a diff check between the commits to determine which manifest files have been added, modified, copied or renamed
# Because this script is located in qualcomm-ci, the manifest repository path must be provided as an argument for correct diff checking
# Usage:
# get-manifest-diff.sh -before_sha <previous_commit_sha> -current_sha <latest_commit_sha> -manifest_repo_path <path_to_manifest_repo>
# Outputs:
# A newline separated list of changed manifest files written to $RUNNER_TEMP/manifests.txt
while [[ $# -gt 0 ]]; do
  case "$1" in
    --before_sha)
      BEFORE_SHA="$2"; shift 2 ;;
    --current_sha)
      CURRENT_SHA="$2"; shift 2 ;;
    --manifest_repo_path)
      MANIFEST_REPO_PATH="$2"; shift 2 ;;
    *)
      echo "Unknown option: $1"; exit 1 ;;
  esac
done

validate_diff_check () {
    local manifest_array=("$@")

    echo "Found ${#manifest_array[@]} changed XML files:"
    if [ ${#manifest_array[@]} -eq 0 ]; then
        echo "No manifests changed. Exiting."
        echo "count=0" >> "$GITHUB_OUTPUT"
        {
        echo "## Triggered Builds"
        echo "_No manifests changed in this push._"
        echo "**Note:** Only added, modified, copied or renamed XML files trigger builds."
        } >> "$GITHUB_STEP_SUMMARY"
        exit 0
    fi

    printf '  - %s\n' "${manifest_array[@]}"

}


#empty tree fallback if no previous commit https://stackoverflow.com/questions/9765453/is-gits-semi-secret-empty-tree-object-reliable-and-why-is-there-not-a-symbolic
if [ -z "${BEFORE_SHA:-}" ] ||  [ "$BEFORE_SHA" = "0000000000000000000000000000000000000000" ]; then
    BEFORE_SHA=$(git hash-object -t tree /dev/null)
fi  


#perform diff check to determine XML files that were added (A), modified (M), copied (C) or renamed (R) and output to array
echo "Checking for changed XML files between $BEFORE_SHA and $CURRENT_SHA..."
git config --get remote.origin.url
git log -2
#must specify manifest repo path with -C for diff check
mapfile -t MANIFESTS < <(git diff --name-only --diff-filter=AMCR \
        "$BEFORE_SHA" "$CURRENT_SHA" -C "$MANIFEST_REPO_PATH" \
        | grep -E '\.xml$' \
        | grep -v '^qualcomm-ci/' || true)

#validate array and exit if no changed manifests found
validate_diff_check "${MANIFESTS[@]}"

#pass to output list as new-line separated result for json-ification in next step
printf '%s\n' "${MANIFESTS[@]}" > "$RUNNER_TEMP/manifests.txt"