# syntax=docker/dockerfile:1
# check=skip=FromPlatformFlagConstDisallowed
#
# The check above is skipped deliberately: BuildKit warns that a constant
# platform in FROM is usually a mistake, but here it is the point. The Debian 9
# packages this image is built from are published for x86 only, so the platform
# must not follow the host's.
#
# ELTE "Fordítóprogramok" (Compilers) development environment.
#
# Goal: reproduce the toolchain of the faculty server `pandora` exactly,
# while still being usable by modern IDEs.
#
#   pandora:  Debian 9 (stretch), gcc 6.3.0-18+deb9u1, bisonc++ 5.02.00,
#             flex 2.6.1 (flex/flex++) and flexc++ 2.05.00 side by side
#
# Debian 9 itself cannot host a JetBrains/VS Code remote backend: those need
# glibc >= 2.28 and stretch ships 2.24. So instead of running *on* stretch we
# graft stretch's toolchain packages onto a bookworm base (glibc 2.36).
# The compiler and generator binaries are the very same Debian builds that run
# on pandora - only the C library underneath them is newer.
#
# For a 100% faithful final check before submitting, use docker/Dockerfile.pandora
# (`./dev.sh verify`), which runs the untouched Debian 9 userland.

FROM --platform=linux/amd64 debian:bookworm-slim

LABEL org.opencontainers.image.title="ELTE Compilers Dev Environment"
LABEL org.opencontainers.image.description="gcc 6.3.0 + bisonc++ 5.02.00 + flex 2.6.1 + flexc++ 2.05.00, as on pandora"

# Exact versions as found on pandora. archive.debian.org is frozen, so these
# resolve identically forever.
ARG GCC6_VER=6.3.0-18+deb9u1
ARG BISONCPP_VER=5.02.00-1
ARG FLEX_VER=2.6.1-1.3
ARG FLEXCPP_VER=2.05.00-1+b1
ARG BOBCAT_VER=4.04.00-1
ARG ISL_VER=0.18-1
ARG MPFR_VER=3.1.5-1
ARG SSL_VER=1.1.1w-0+deb11u1

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# ---------------------------------------------------------------------------
# 1. Modern userland: build tooling, debugger, and the shared libraries the
#    JetBrains / VS Code remote backends require inside a dev container.
#    The lib32/i386 packages are what make `g++ -m32` work: pandora is a 32-bit
#    machine, so compiling with -m32 here reproduces its type sizes.
#    m4 is flex's own runtime dependency (it shells out to m4 to expand its
#    skeleton scanner), pulled from bookworm since m4 behavior is stable.
# ---------------------------------------------------------------------------
RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update -qq; \
    apt-get install -y -qq --no-install-recommends \
        binutils libc6-dev libgmp10 libmpc3 zlib1g libcc1-0 \
        libc6-dev-i386 libc6-i386 lib32stdc++6 lib32gcc-s1 linux-libc-dev:i386 \
        make cmake gdb valgrind m4 \
        git curl ca-certificates unzip procps less nano vim-tiny sudo gosu \
        libx11-6 libxext6 libxrender1 libxtst6 libxi6 libfreetype6 \
    ; \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Graft the Debian 9 toolchain on top.
#    The old suites are added only as a *download* source and pinned to a
#    negative priority, so apt will never pull anything from them on its own.
#    Packages are unpacked with dpkg-deb rather than installed, because their
#    dependency metadata refers to a Debian 9 world that no longer exists;
#    every library they actually need is either present above or unpacked here
#    under its own versioned soname, so nothing is overwritten.
#
#    Debian 9 predates the merged-/usr layout, so its debs carry real /lib and
#    /bin directories. Unpacking those straight onto bookworm would replace the
#    /lib -> usr/lib symlink with a directory and hide the dynamic loader,
#    breaking every binary in the image. Everything is therefore unpacked into a
#    staging tree, relocated under /usr, and only then merged into the image.
#    libreadline7/libtinfo5/libmilter1.0.1 are pulled in because libbobcat4 -
#    the library bisonc++ and flexc++ are linked against - needs them; the
#    archive is frozen, so leaving them unpinned is still deterministic.
# ---------------------------------------------------------------------------
RUN set -eux; \
    echo 'deb [arch=amd64 trusted=yes] http://archive.debian.org/debian stretch main'  >  /etc/apt/sources.list.d/legacy.list; \
    echo 'deb [arch=amd64 trusted=yes] http://archive.debian.org/debian bullseye main' >> /etc/apt/sources.list.d/legacy.list; \
    printf 'Package: *\nPin: release n=stretch\nPin-Priority: -10\n\nPackage: *\nPin: release n=bullseye\nPin-Priority: -10\n' \
        > /etc/apt/preferences.d/no-legacy; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid; \
    apt-get update -qq; \
    mkdir -p /tmp/debs /tmp/stage; cd /tmp/debs; \
    apt-get download -y \
        "gcc-6=${GCC6_VER}" "g++-6=${GCC6_VER}" "cpp-6=${GCC6_VER}" \
        "gcc-6-base=${GCC6_VER}" "libgcc-6-dev=${GCC6_VER}" "libstdc++-6-dev=${GCC6_VER}" \
        "gcc-6-multilib=${GCC6_VER}" "g++-6-multilib=${GCC6_VER}" \
        "lib32gcc-6-dev=${GCC6_VER}" "lib32stdc++-6-dev=${GCC6_VER}" \
        "libisl15=${ISL_VER}" "libmpfr4=${MPFR_VER}" \
        "libbobcat4=${BOBCAT_VER}" "libssl1.1=${SSL_VER}" \
        libreadline7/stretch libtinfo5/stretch libmilter1.0.1/stretch \
        "bisonc++=${BISONCPP_VER}" "flex=${FLEX_VER}" "flexc++=${FLEXCPP_VER}"; \
    for deb in *.deb; do dpkg-deb -x "$deb" /tmp/stage; done; \
    cd /tmp/stage; \
    for d in bin sbin lib lib64; do \
        if [ -d "$d" ] && [ ! -L "$d" ]; then \
            mkdir -p "usr/$d"; cp -a "$d/." "usr/$d/"; rm -rf "$d"; \
        fi; \
    done; \
    cp -a /tmp/stage/. /; \
    ldconfig; \
    cd /; rm -rf /tmp/debs /tmp/stage /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 3. Make the Debian 9 compiler the default `gcc` / `g++` / `cc` / `c++`.
#    Students type `g++` and get exactly what pandora's `g++` would do.
#    `flex` and `flex++` come straight from the unpacked Debian 9 package
#    above, so no alias is needed for them the way there is for gcc/g++.
# ---------------------------------------------------------------------------
RUN set -eux; \
    for pair in gcc:gcc-6 g++:g++-6 cc:gcc-6 c++:g++-6 cpp:cpp-6; do \
        ln -sf "/usr/bin/${pair#*:}" "/usr/local/bin/${pair%%:*}"; \
    done; \
    gcc --version | head -1; \
    g++ --version | head -1; \
    bisonc++ -v; \
    flexc++ -v; \
    flex --version; \
    printf 'int main(){ return 0; }\n' > /tmp/m.cc; \
    g++ -m32 -o /tmp/m32 /tmp/m.cc; /tmp/m32; \
    g++      -o /tmp/m64 /tmp/m.cc; /tmp/m64; \
    readelf -h /tmp/m32 | grep -q ELF32; \
    readelf -h /tmp/m64 | grep -q ELF64; \
    echo "-m32 builds and runs 32-bit binaries"; \
    rm -f /tmp/m.cc /tmp/m32 /tmp/m64

# ---------------------------------------------------------------------------
# 4. Unprivileged user. Dev containers expect to run as a non-root user so that
#    files created in the bind mount are owned by you and not by root.
# ---------------------------------------------------------------------------
ARG USERNAME=student
ARG USER_UID=1000
ARG USER_GID=1000
RUN set -eux; \
    groupadd --gid "$USER_GID" "$USERNAME"; \
    useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME"; \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"; \
    chmod 0440 "/etc/sudoers.d/$USERNAME"

# The repository is bind-mounted here; /workspace is a short alias for the
# folder you are meant to put your code in.
RUN set -eux; \
    mkdir -p /workspaces/elte-compilers/workspace; \
    ln -s /workspaces/elte-compilers/workspace /workspace; \
    chown -R "$USER_UID:$USER_GID" /workspaces

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspaces/elte-compilers/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
