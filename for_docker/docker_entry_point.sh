#!/usr/bin/env bash
USER_NAME=dev
PREV_ID=$(id -u $USER_NAME)
PREV_GID=$(id -g $USER_NAME)
HOST_UID=$1
HOST_GID=$2

if [[ "${1-}" == "$HOST_UID" && "${2-}" == "$HOST_GID" ]]; then
  shift 2 || true
fi


if [[ "$HOST_UID" != "$PREV_ID" || "$HOST_GID" != "$PREV_GID" ]]; then
    echo "Inheriting UIDs/GIDs from the Host"
    # Update the user ID and group ID for $USER_NAME
    groupmod -g $HOST_GID $USER_NAME
    usermod -u $HOST_UID $USER_NAME
    echo "Changing /home/dev ownership"
    #chown home directory to new IDs
    path="/home/$USER_NAME/"
    if [[ -e "$path" ]]; then
        echo "[entrypoint] Fixing ownership under: $path"
        #chown if uid/gid does not match host
        find "$path" \( -not -uid "$HOST_UID" -o -not -gid "$HOST_GID" \) -print0 \
        | xargs -0 --no-run-if-empty chown -h "$HOST_UID:$HOST_GID"
        # find /home/dev -print0 | xargs -0 chown -h $HOST_UID:$HOST_GID

    fi
     # Create new group with same GID as original dev
    groupadd -g ${PREV_GID} dev2
    usermod -a -G dev2 dev
fi

echo "[entrypoint] READY - dev IDS: (uid=$(id -u dev), gid=$(id -g dev))"

#create new shell, preserve environment (-E), set $HOME (-H) and run as dev.
exec sudo -E -H -u dev -- sleep infinity
# sudo -u dev bash

