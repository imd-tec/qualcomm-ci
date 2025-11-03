#!/bin/bash
# Script to identify changed XML manifest files between current and previous commits

validate_diff () {
    #function to validate if any xml files were changed
    if [ -z "${1:-}" ]; then
    echo "No XML files changed. Exiting."
    echo "count=0" >> "$GITHUB_OUTPUT"
    {
    echo "## Triggered Builds"
    echo ""
    echo "_No XML manifests changed in this push._"
    } >> "$GITHUB_STEP_SUMMARY"
    exit 0
    fi
}

#get current and previous commit sha for comparison
#if one is missing, such as when manually dispatching, all XML's will be triggered to build
BEFORE="${{ github.event.before }}"
CURRENT="${{ github.sha }}"
echo "PREVIOUS COMMIT SHA: ${BEFORE:-'N/A - Likely manual dispatch.'}"
echo "CURRENT COMMIT SHA: ${CURRENT:-'N/A - Likely manual dispatch.'}"

#empty tree fallback if no previous commit https://stackoverflow.com/questions/9765453/is-gits-semi-secret-empty-tree-object-reliable-and-why-is-there-not-a-symbolic
if [ -z "${BEFORE:-}" ] ||  [ "$BEFORE" = "0000000000000000000000000000000000000000" ]; then
    BEFORE=$(git hash-object -t tree /dev/null)
fi

#grab xml diffs that have either been added (A) or modified (M) between previous and current sha and read to array
mapfile -t MANIFESTS < <(git diff --name-only --diff-filter=AM \
        "$BEFORE" "$CURRENT" \
        | grep -E '\.xml$')

#if no matches, terminate early
validate_diff "${MANIFESTS[*]}"

#save each new-line seperated result in a txt for use in next step
printf '%s\n' "${MANIFESTS[@]}" > "$RUNNER_TEMP/manifests.txt"