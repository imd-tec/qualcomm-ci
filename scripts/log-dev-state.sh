#!/bin/bash
#=============================================================================================================================================================================
#title: log-dev-state.sh
#description
#     Take development build job result status (success, failure, cancelled) and update the .last state file for the project.
#     Format is:
#       PROJECT | RESULT | DATE
#       META-LAYER | LAST_COMMIT
#       META-LAYER | LAST_COMMIT
#       ...
#
#     State files can be located at /mnt/nvme1/qcom_ci/dev_repo_poll/state/.
#usage: 
#     log-dev-state.sh <build_result> <state_log> <manifest_repository>
#=============================================================================================================================================================================

set -ex

BUILD_RESULT=$1
STATE_LOG=$2
MANIFEST_REPOSITORY=$3
project_name=$(basename "$MANIFEST_REPOSITORY") #e.g., imdt-qcom-manifest-dev
state_file="/mnt/nvme1/qcom_ci/dev_repo_poll/state/${project_name}.last"

case "$BUILD_RESULT" in
    success)   result="SUCCESS" ;;
    failure)   result="FAILURE" ;;
    cancelled) result="CANCELLED" ;;
    *)         result="UNKNOWN" ;;
esac

{
    # write build result line
    printf '%s | %s | %s\n' "$project_name" "$(date)" "$result"

    # write meta-layer name and hashes
    while IFS='|' read -r repo_name current_hash; do
        [ -z "$repo_name" ] && continue #ensures no empty lines are processed
        printf '%s | %s\n' "$repo_name" "$current_hash"
    done <<< "$STATE_LOG"

} > "$state_file"

echo -e "\nUpdated development state file at: $state_file"