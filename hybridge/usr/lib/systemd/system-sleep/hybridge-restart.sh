#!/bin/bash

[ "$1" != "post" ] && exit 0

sleep 1

loginctl list-users --no-legend | awk '{print $1}' | while read -r uid; do
    user_name=$(id -nu "$uid")

    if [ -d "/run/user/$uid" ]; then
        runuser -u "$user_name" -- \
            env XDG_RUNTIME_DIR="/run/user/$uid" \
            systemctl --user is-enabled --quiet hybridge.service && \
        runuser -u "$user_name" -- \
            env XDG_RUNTIME_DIR="/run/user/$uid" \
            systemctl --user restart hybridge.service
    fi
done
