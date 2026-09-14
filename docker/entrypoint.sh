#!/bin/sh
# Drops privileges to the `student` user, optionally remapping that user to the
# host's UID/GID first.
#
# This only matters on Linux, where a bind mount keeps the host's numeric
# ownership: if the container's student (1000) does not match your host account,
# every file the container writes ends up owned by the wrong user. Docker
# Desktop on macOS and Windows translates ownership for you, so HOST_UID is
# simply left unset there.
set -e

if [ "$(id -u)" = "0" ]; then
    if [ -n "${HOST_UID}" ] && [ "${HOST_UID}" != "$(id -u student)" ]; then
        usermod  -o -u "${HOST_UID}" student >/dev/null 2>&1 || true
        groupmod -o -g "${HOST_GID:-$HOST_UID}" student >/dev/null 2>&1 || true
        chown -R "${HOST_UID}:${HOST_GID:-$HOST_UID}" /home/student || true
    fi
    exec gosu student "$@"
fi

exec "$@"
