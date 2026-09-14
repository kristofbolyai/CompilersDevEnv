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

# When the launcher scripts start us they expect the repository to be
# bind-mounted. Docker only shares folders it has been allowed to share, and a
# path outside that set is not an error: it is mounted as an empty directory,
# which otherwise surfaces much later as a confusing "no such file" from make.
if [ -n "${ELTE_EXPECT_MOUNT}" ] && [ ! -e /workspaces/elte-compilers/dev.sh ]; then
    cat >&2 <<'MSG'
error: the project folder is not visible inside the container.

  Docker mounted /workspaces/elte-compilers, but it is empty - which means
  Docker is not allowed to share the folder this repository lives in.

  Fix it by either:
    - moving the repository somewhere under your home directory, or
    - adding its location under
      Docker Desktop -> Settings -> Resources -> File sharing
      (Colima: restart with  colima start --mount $HOME:w )
MSG
    exit 1
fi

if [ "$(id -u)" = "0" ]; then
    if [ -n "${HOST_UID}" ] && [ "${HOST_UID}" != "$(id -u student)" ]; then
        usermod  -o -u "${HOST_UID}" student >/dev/null 2>&1 || true
        groupmod -o -g "${HOST_GID:-$HOST_UID}" student >/dev/null 2>&1 || true
        chown -R "${HOST_UID}:${HOST_GID:-$HOST_UID}" /home/student || true
    fi
    exec gosu student "$@"
fi

exec "$@"
