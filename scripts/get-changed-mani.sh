#!/bin/bash
# For use exclusively when callee manifest repository build workflow is triggered by push events
# This script is used identify changed XML manifest files between current and previous commits for extraction of build details

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

#get current and previous commit sha for comparison in determining changed files
#if one is missing, such as when manually dispatching, all XML's will be triggered for build
BEFORE="${{ github.event.before }}"
CURRENT="${{ github.sha }}"
echo "PREVIOUS COMMIT SHA: ${BEFORE:-'N/A - Likely manual dispatch.'}"
echo "CURRENT COMMIT SHA: ${CURRENT:-'N/A - Likely manual dispatch.'}"

#empty tree fallback if no previous commit https://stackoverflow.com/questions/9765453/is-gits-semi-secret-empty-tree-object-reliable-and-why-is-there-not-a-symbolic
if [ -z "${BEFORE:-}" ] ||  [ "$BEFORE" = "0000000000000000000000000000000000000000" ]; then
    BEFORE=$(git hash-object -t tree /dev/null)
fi

#get XML files that were added (A), modified (M), copied (C) or renamed (R)
echo "Checking for changed XML files..."
mapfile -t MANIFESTS < <(git diff --name-only --diff-filter=AMCR \
        "$BEFORE" "$CURRENT" \
        | grep -E '\.xml$' \
        | grep -v '^qualcomm-ci/' || true)


#validate changes and exit if no changed manifests found
validate_diff_check "${MANIFESTS[@]}"

#pass to output list as new-line separated result for json-ification in next step
printf '%s\n' "${MANIFESTS[@]}" > "$RUNNER_TEMP/manifests.txt"