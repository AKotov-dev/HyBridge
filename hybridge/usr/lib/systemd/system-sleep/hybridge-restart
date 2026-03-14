#!/bin/bash

# Этот hook вызывается дважды: pre и post
[ "$1" != "post" ] && exit 0

# Небольшая задержка, чтобы user dbus успел подняться
sleep 1

# Перебираем все активные user runtimes
for uid_dir in /run/user/*; do
    uid=${uid_dir##*/}

    # Пропускаем не числовые каталоги
    [[ "$uid" =~ ^[0-9]+$ ]] || continue

    user=$(id -nu "$uid")

    # Проверяем, что systemd user manager запущен
    if [ -d "/run/user/$uid" ]; then
        runuser -u "$user" -- env XDG_RUNTIME_DIR="/run/user/$uid" bash -c '
            systemctl --user is-enabled --quiet hybridge.service &&
            systemctl --user restart hybridge.service
        '
    fi
done

exit 0
