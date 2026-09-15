# Quick start

*[Magyar változat](quick_start.hu.md) · [Full README](README.md)*

Install Docker, then run one command. Everything else — the compiler,
`bisonc++`, `flexc++` — lives in the container.

> **Docker needs the `buildx` component.** Docker Desktop ships it. If you
> install the plain Docker CLI yourself, install `docker-buildx` too: IDEs build
> dev containers with `docker buildx build`, and without it the build fails with
> `unknown shorthand flag: 'f' in -f`.

## macOS

**Docker Desktop** — simplest, includes buildx:

```bash
brew install --cask docker
```

**or Colima** — lighter, no GUI, but buildx is a separate package:

```bash
brew install colima docker docker-buildx
mkdir -p ~/.docker/cli-plugins
ln -sfn "$(brew --prefix)/lib/docker/cli-plugins/docker-buildx" ~/.docker/cli-plugins/docker-buildx
colima start --cpu 8 --memory 16 --vm-type vz --vz-rosetta
```

On Apple Silicon, `--vz-rosetta` is what keeps builds fast — the toolchain is
x86 and would otherwise be emulated by QEMU.

## Linux

**Debian / Ubuntu**

```bash
sudo apt update
sudo apt install -y docker.io docker-buildx
sudo usermod -aG docker "$USER"   # then log out and back in
```

**Fedora**

```bash
sudo dnf install -y docker docker-buildx
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"   # then log out and back in
```

**Arch**

```bash
sudo pacman -S --needed docker docker-buildx
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"   # then log out and back in
```

## Windows

```powershell
winget install Docker.DockerDesktop
```

Enable the WSL 2 backend when the installer offers it. Buildx is included.

## Check it works

```bash
git clone <this-repo> && cd CompilersDevEnv
./dev.sh doctor     # .\dev.ps1 doctor on Windows
./dev.sh test
```

`test` should end with `example: OK`. The first run builds the image and takes
a few minutes; after that everything starts in about a second.

## Using it from an IDE

The repository contains `.devcontainer/devcontainer.json`, so both IDEs pick it
up with no configuration. **Use VS Code if you don't already have a favorite**
— it's what this environment is built and tested against, and it starts up
faster.

### VS Code (recommended)

1. Install the **Dev Containers** extension (Extensions panel,
   <kbd>Ctrl/Cmd+Shift+X</kbd>, search "Dev Containers").
2. **File → Open Folder…** and pick the `CompilersDevEnv` folder.
3. A popup appears bottom-right: *"Folder contains a Dev Container
   configuration file. Reopen folder to develop in a container?"* — click
   **Reopen in Container**.
   - No popup? Press <kbd>F1</kbd> and run
     **Dev Containers: Reopen in Container** yourself.
4. First time only, this builds the image (a few minutes, with progress shown
   in a log panel). After that it's a few seconds.
5. Done when the window title says `[Dev Container: elte-compilers]` and the
   integrated terminal (<kbd>Ctrl/Cmd+`</kbd>) is inside the container.

### CLion (and other JetBrains IDEs)

1. Open the project folder.
2. Open `.devcontainer/devcontainer.json` — it is a hidden folder, so use the
   Project view rather than Finder or Explorer.
3. Click the container icon in the gutter next to the opening `{`.
4. Choose **Create Dev Container and Mount Sources**.
5. Pick **CLion** as the backend when prompted.

CLion opens on `workspace/`, and `workspace/examples/calc/` has a
`CMakeLists.txt`, so the example loads as a CMake project with working
completion and debugging.

### No IDE

Keep a shell open and use `make`:

```bash
./dev.sh          # shell in the container, in your workspace/ folder
make              # build whatever you are working on
```

## Day-to-day

```bash
./dev.sh new hazi1    # new assignment from the example skeleton
./dev.sh              # shell
./dev.sh verify       # rebuild on real 32-bit Debian 9 before submitting
```

Your code goes in `workspace/`, which is the same folder inside and outside the
container. Anything else you need is in the [full README](README.md).
