#!/usr/bin/env bash
#
# ELTE Compilers dev environment - one entry point for everything.
#
#   ./dev.sh                 open a shell in the container
#   ./dev.sh build           (re)build the image
#   ./dev.sh test            build and test the bundled example
#   ./dev.sh verify          repeat the build on a real Debian 9 userland
#   ./dev.sh new <name>      start a new project from the example skeleton
#   ./dev.sh run <cmd...>    run a single command inside the container
#   ./dev.sh doctor          check that the local setup can work
#   ./dev.sh clean           remove the images this project created
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE_DEV="elte-compilers:dev"
IMAGE_PANDORA="elte-compilers:pandora"
CONTAINER_REPO="/workspaces/elte-compilers"
# The dev image is amd64 (Rosetta can accelerate it, and the JetBrains backend
# has no 32-bit build). The verification image is 32-bit, because that is what
# pandora is: `Target: i686-linux-gnu`.
PLATFORM="linux/amd64"
PLATFORM_PANDORA="linux/386"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

require_docker() {
    command -v docker >/dev/null 2>&1 \
        || die "docker is not installed. See the README for install instructions."
    docker info >/dev/null 2>&1 \
        || die "the Docker daemon is not reachable. Start Docker Desktop (or 'colima start') and try again."
}

image_exists() { docker image inspect "$1" >/dev/null 2>&1; }

build_image() {
    local image="$1" dockerfile="$2" platform="${3:-$PLATFORM}"
    info "building $image (first time takes a few minutes)"
    docker build --platform "$platform" -f "$REPO_ROOT/$dockerfile" -t "$image" "$REPO_ROOT"
}

ensure_image() {
    local image="$1" dockerfile="$2" platform="${3:-$PLATFORM}"
    image_exists "$image" || build_image "$image" "$dockerfile" "$platform"
}

# Where inside the container should we land? If the caller is somewhere under
# workspace/ on the host, put them at the matching place in the container -
# running `./dev.sh` from your assignment folder should drop you in it.
container_workdir() {
    local cwd; cwd="$(pwd -P)"
    local ws; ws="$(cd "$REPO_ROOT/workspace" && pwd -P)"
    if [[ "$cwd" == "$ws" || "$cwd" == "$ws"/* ]]; then
        printf '%s/workspace%s' "$CONTAINER_REPO" "${cwd#"$ws"}"
    else
        printf '%s/workspace' "$CONTAINER_REPO"
    fi
}

docker_run() {
    local image="$1" platform="$2"; shift 2

    local -a opts=(
        --rm
        --platform "$platform"
        -v "$REPO_ROOT:$CONTAINER_REPO"
        -w "$(container_workdir)"
        -e ELTE_EXPECT_MOUNT=1
    )

    # On Linux a bind mount keeps the host's numeric ownership, so the
    # container user has to become you. macOS and Windows translate ownership
    # in the file sharing layer and need nothing.
    if [[ "$(uname -s)" == "Linux" ]]; then
        opts+=(-e "HOST_UID=$(id -u)" -e "HOST_GID=$(id -g)")
    fi

    [[ -t 0 && -t 1 ]] && opts+=(-it)

    docker run "${opts[@]}" "$image" "$@"
}

cmd_build()  { require_docker; build_image "$IMAGE_DEV" docker/Dockerfile; }

cmd_shell() {
    require_docker; ensure_image "$IMAGE_DEV" docker/Dockerfile
    docker_run "$IMAGE_DEV" "$PLATFORM" bash
}

cmd_run() {
    [[ $# -gt 0 ]] || die "run needs a command, e.g. ./dev.sh run make"
    require_docker; ensure_image "$IMAGE_DEV" docker/Dockerfile
    docker_run "$IMAGE_DEV" "$PLATFORM" "$@"
}

cmd_test() {
    require_docker; ensure_image "$IMAGE_DEV" docker/Dockerfile
    info "building and testing the example with gcc 6.3.0"
    docker_run "$IMAGE_DEV" "$PLATFORM" bash -lc 'cd '"$CONTAINER_REPO"'/workspace/examples/calc && make clean >/dev/null && make && make test'
}

cmd_verify() {
    require_docker; ensure_image "$IMAGE_PANDORA" docker/Dockerfile.pandora "$PLATFORM_PANDORA"
    local target="${1:-examples/calc}"
    [[ -d "$REPO_ROOT/workspace/$target" ]] || die "workspace/$target does not exist"
    info "rebuilding '$target' on an untouched Debian 9 userland"
    docker_run "$IMAGE_PANDORA" "$PLATFORM_PANDORA" bash -lc "
        set -e
        cd '$CONTAINER_REPO/workspace/$target'
        make clean >/dev/null 2>&1 || true
        make
        if grep -qE '^test:' Makefile 2>/dev/null; then make test; fi
    "
    bold "verify: '$target' builds on Debian 9 exactly as pandora ships it."
}

cmd_new() {
    local name="${1:-}"
    [[ -n "$name" ]] || die "new needs a project name, e.g. ./dev.sh new hazi1"
    local dest="$REPO_ROOT/workspace/$name"
    [[ -e "$dest" ]] && die "workspace/$name already exists"
    mkdir -p "$dest"
    local f
    for f in grammar lexer scanner.h scanner.ih parser.h parser.ih main.cc Makefile; do
        cp "$REPO_ROOT/workspace/examples/calc/$f" "$dest/$f"
    done
    bold "created workspace/$name"
    info "open a shell with './dev.sh' and run 'make' inside it"
}

cmd_doctor() {
    bold "ELTE Compilers dev environment - setup check"
    command -v docker >/dev/null 2>&1 \
        && echo "  docker cli      : $(docker --version)" \
        || { echo "  docker cli      : MISSING"; return 1; }

    if docker info >/dev/null 2>&1; then
        echo "  docker daemon   : reachable"
    else
        echo "  docker daemon   : NOT reachable - start Docker Desktop or 'colima start'"
        return 1
    fi

    echo "  host arch       : $(uname -m)"
    if [[ "$(uname -m)" == "arm64" || "$(uname -m)" == "aarch64" ]]; then
        echo "                    (amd64 runs emulated here; if builds feel slow, turn on"
        echo "                     Rosetta - see 'Apple Silicon' in the README)"
    fi
    if docker run --rm --platform "$PLATFORM" debian:bookworm-slim true >/dev/null 2>&1; then
        echo "  linux/amd64     : runnable"
    else
        echo "  linux/amd64     : NOT runnable - this environment is amd64-only, see the README"
        return 1
    fi

    if docker run --rm --platform "$PLATFORM_PANDORA" i386/debian:stretch-slim true >/dev/null 2>&1; then
        echo "  linux/386       : runnable (needed only by './dev.sh verify')"
    else
        echo "  linux/386       : NOT runnable - './dev.sh verify' will not work, everything else will"
    fi

    image_exists "$IMAGE_DEV"     && echo "  image (dev)     : built" || echo "  image (dev)     : not built yet ('./dev.sh build')"
    image_exists "$IMAGE_PANDORA" && echo "  image (pandora) : built" || echo "  image (pandora) : not built yet (built on first './dev.sh verify')"

    if image_exists "$IMAGE_DEV"; then
        echo "  toolchain       :"
        docker run --rm --platform "$PLATFORM" "$IMAGE_DEV" \
            bash -lc 'printf "    %s\n" "$(g++ --version | head -1)" "$(bisonc++ -v)" "$(flexc++ -v)"'
    fi
}

cmd_clean() {
    require_docker
    docker image rm -f "$IMAGE_DEV" "$IMAGE_PANDORA" 2>/dev/null || true
    info "removed project images"
}

usage() { sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'; }

main() {
    local cmd="${1:-shell}"
    [[ $# -gt 0 ]] && shift || true
    case "$cmd" in
        build)          cmd_build "$@" ;;
        shell|sh|bash)  cmd_shell "$@" ;;
        run)            cmd_run "$@" ;;
        test)           cmd_test "$@" ;;
        verify)         cmd_verify "$@" ;;
        new)            cmd_new "$@" ;;
        doctor)         cmd_doctor "$@" ;;
        clean)          cmd_clean "$@" ;;
        -h|--help|help) usage ;;
        *)              die "unknown command '$cmd'. Try './dev.sh --help'." ;;
    esac
}

main "$@"
