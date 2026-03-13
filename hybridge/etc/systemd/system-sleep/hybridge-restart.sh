#!/bin/bash

for uid in $(loginctl list-users --no-legend | awk '{print $1}'); do
    user_name=$(id -nu "$uid")
    # Проверяем, запущен ли пользовательский менеджер (папка рантайма существует)
    if [ -d "/run/user/$uid" ]; then
        # Выполняем команду ОТ ИМЕНИ пользователя с пробросом пути к шине
        runuser -u "$user_name" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
            systemctl --user is-enabled --quiet hybridge.service && \
        runuser -u "$user_name" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
            systemctl --user restart hybridge.service
#	touch /home/$user_name/1122334455
    fi
done
