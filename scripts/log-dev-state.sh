#!/bin/bash
#=============================================================================================================================================================================
#title: log-dev-state.sh
#description
#     Take development build job result status (success, failure, cancelled) and update the .last state file for the project.
#     As some manifest repositories may contain multiple development manifests, lines not designated for the given manifest are filtered out.
#
#     Output format is:
#       REPOSITORY | DATE | RESULT
#       META-LAYER | LAST_HASH
#       META-LAYER | LAST_HASH
#       ...
#
#     State files can be located at ${CI_DEV_DIR}/state/.
#usage: 
#     log-dev-state.sh <build_result> <dev_state_log> <manifest_repository> <manifest_xml>
#=============================================================================================================================================================================
set -e

BUILD_RESULT=$1
DEV_STATE_LOG=$2
MANIFEST_REPOSITORY=$3
MANIFEST_XML=$4

repository_base=$(basename "$MANIFEST_REPOSITORY") #e.g., imdt-qcom-manifest-dev
manifest_base=$(basename "$MANIFEST_XML" .xml) #e.g., development-glasses

DEV_REPO_STATE_PATH="${CI_DEV_DIR}/state"
state_file="${DEV_REPO_STATE_PATH}/${repository_base}-${manifest_base}.last"

case "$BUILD_RESULT" in
    success)   result="SUCCESS" ;;
    failure)   result="FAILURE" ;;
    cancelled) result="CANCELLED" ;;
    *)         result="UNKNOWN" ;;
esac

{
    #write header line: REPOSITORY | DATE | RESULT
    printf '%s | %s | %s\n' "$repository_base" "$(date)" "$result"

    #write meta-layer name and hashes: META-LAYER | LAST_HASH
    while IFS='|' read -r log_manifest log_repo log_hash; do
        [ -z "$log_manifest" ] && continue #ensures no empty lines are processed
        #trim whitespace
        log_manifest=$(echo "$log_manifest" | xargs) #for filtering when handling multiple development manifests
        log_repo=$(echo "$log_repo" | xargs)
        log_hash=$(echo "$log_hash" | xargs)
        if [ "$log_manifest" == "$manifest_base" ]; then
            printf '%s | %s\n' "$log_repo" "$log_hash"       
        fi
    done <<< "$DEV_STATE_LOG"

} > "$state_file"

echo -e "\nUpdated development state file at: $state_file"
