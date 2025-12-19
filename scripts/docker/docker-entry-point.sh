#!/bin/bash
#=============================================================================================================================================================================
#title: docker-entry-point.sh
#
#description: Entry point script for Qualcomm CI Docker container.
#             Sets up user permissions and ownership inside the container to match the host runner user. 
#
#usage: docker run ... <image_name> <host_uid> <host_gid>
#=============================================================================================================================================================================


USER_NAME=dev
PREV_ID=$(id -u $USER_NAME)
PREV_GID=$(id -g $USER_NAME)
HOST_UID=$1
HOST_GID=$2

#consume UID/GID arguments
if [[ "${1-}" == "$HOST_UID" && "${2-}" == "$HOST_GID" ]]; then
  shift 2 || true
fi

if [[ "$HOST_UID" != "$PREV_ID" || "$HOST_GID" != "$PREV_GID" ]]; then
    echo "[entrypoint] Inheriting UIDs/GIDs from the Host ($HOST_UID)"
    # Update the user ID and group ID for $USER_NAME
    groupmod -g "$HOST_GID" $USER_NAME
    usermod -u "$HOST_UID" $USER_NAME
    echo "[entrypoint] changing /home/dev ownership"

    #chown home directory to new IDs
    path="/home/$USER_NAME/"
    if [[ -e "$path" ]]; then
        echo "[entrypoint] Fixing ownership under: $path"

        #find all paths where UID/GID does not match and chown to new IDs
        find "$path" \( -not -uid "$HOST_UID" -o -not -gid "$HOST_GID" \) -print0 \
        | xargs -0 --no-run-if-empty chown -h "$HOST_UID:$HOST_GID"
    fi
    #create new group with same GID as original dev
    groupadd -g "${PREV_GID}" dev2
    usermod -a -G dev2 dev
fi

echo "[entrypoint] READY - dev user IDS: (uid=$(id -u dev), gid=$(id -g dev))"

#send signal file to continue with workflow
mkdir -p /tmp
echo "READY $(date -Is)" > /tmp/ready

#create new shell, preserve environment (-E), set $HOME (-H) and run as dev.
exec sudo -E -H -u dev -- sleep infinity
