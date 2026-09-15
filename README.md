# ELTE Compilers — Docker development environment

*[Magyar változat](README.hu.md) · [Quick start](quick_start.md)*

Everything the **Fordítóprogramok** (Compilers) course needs — `bisonc++`,
`flexc++` and the exact `g++` that runs on the faculty server — packed into a
container you can run on macOS, Windows or Linux. No system packages to hunt
down, no "works on pandora but not on my laptop", and nothing to uninstall
afterwards.

```console
$ git clone <this-repo> && cd CompilersDevEnv
$ ./dev.sh test
g++ (Debian 6.3.0-18+deb9u1) 6.3.0 20170516
bisonc++ V5.02.00
flexc++ V2.05.00
example: OK
```

## Versions

The whole point is that these match `pandora`. They are pinned, so they stay
matched:

| | pandora | this environment |
|---|---|---|
| `gcc` / `g++` | 6.3.0 (Debian 6.3.0-18+deb9u1) | identical |
| `bisonc++` | V5.02.00 | identical |
| `flexc++` | V2.05.00 | identical |
| Debian | 9 (stretch) | 9 toolchain on a Debian 12 base — see [How it works](#how-it-works) |
| Architecture | i686 (32-bit) | x86-64 by default, 32-bit via `-m32`, i686 in `./dev.sh verify` |

`flex` is aliased to `flexc++` in the dev image (`./dev.sh`, VS Code, CLion), so
if muscle memory from another course reaches for `flex` it still works. The
untouched `./dev.sh verify` image only has `flexc++`, matching pandora exactly.

## What you need

Docker, and nothing else.

| OS | Install |
|---|---|
| **macOS** | [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/) — on Apple Silicon also read [Apple Silicon](#apple-silicon-and-other-arm-machines) below |
| **Windows** | [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/) (enable the WSL 2 backend when asked) |
| **Linux** | [Docker Engine](https://docs.docker.com/engine/install/), then `sudo usermod -aG docker $USER` and log out and back in |

Copy-paste package manager commands for all three are in
[quick_start.md](quick_start.md). If you install the Docker CLI yourself rather
than Docker Desktop, install `docker-buildx` alongside it — IDEs build dev
containers with `docker buildx build`.

Check your setup at any time:

```console
$ ./dev.sh doctor
```

## Everyday use

Use `./dev.sh` on macOS and Linux, `.\dev.ps1` on Windows PowerShell. They take
the same commands and do the same things.

| Command | What it does |
|---|---|
| `./dev.sh` | Opens a shell inside the container, in your `workspace/` folder |
| `./dev.sh test` | Builds and tests the bundled example — a good first thing to run |
| `./dev.sh new hazi1` | Creates `workspace/hazi1/` from the example skeleton |
| `./dev.sh run make` | Runs one command in the container and exits |
| `./dev.sh verify` | Rebuilds on a real 32-bit Debian 9 — run this before submitting |
| `./dev.sh build` | Rebuilds the image (only needed if you change the Dockerfile) |
| `./dev.sh doctor` | Checks Docker, emulation and the toolchain |
| `./dev.sh clean` | Deletes the images this project created |

The first `./dev.sh` builds the image and takes a few minutes. Every run after
that starts in about a second.

A useful detail: `./dev.sh` remembers where you are. Run it from
`workspace/hazi1/` and you land in `/workspace/hazi1` inside the container.

## Where your code goes

The repository's `workspace/` folder is mounted into the container at
`/workspace`. It is the *same* folder, not a copy — edit files in your normal
editor on your own machine, compile them in the container, and both sides see
every change immediately.

```
CompilersDevEnv/
├── dev.sh, dev.ps1          ← the scripts you run
├── workspace/               ← mounted at /workspace; your code lives here
│   ├── examples/calc/       ← a working scanner + parser, start here
│   └── hazi1/               ← whatever you create
├── docker/                  ← image definitions
└── .devcontainer/           ← IDE integration
```

Nothing outside `workspace/` needs to be touched during the semester.

## Writing a scanner and a parser

Open `workspace/examples/calc/` — it is a complete four-function calculator,
about a hundred lines in total, and it is the shortest explanation of how these
tools fit together.

Two files describe the language, and you write both:

- **`lexer`** — the flexc++ specification: which character patterns form which
  tokens.
- **`grammar`** — the bisonc++ specification: how tokens combine into
  expressions, and what to do when they do.

Running the generators turns those into C++:

```console
$ bisonc++ grammar     # writes parserbase.h and parse.cc
$ flexc++ lexer        # writes scannerbase.h and lex.cc
```

**The order matters.** `bisonc++` defines the token constants
(`ParserBase::NUMBER` and friends) in `parserbase.h`, and the scanner's actions
use them, so the parser has to be generated first. The `Makefile` already
encodes this, so plain `make` always does the right thing.

Both generators also create four files *once* and then never touch them again:
`parser.h`, `parser.ih`, `scanner.h`, `scanner.ih`. Those are yours — they are
where you add members and helper functions, and they are the files kept in
version control. The four regenerated ones are in `.gitignore`, because
rebuilding overwrites them every time.

| File | Written by | Edit it? |
|---|---|---|
| `lexer`, `grammar` | you | yes — this is the actual work |
| `parserbase.h`, `parse.cc` | bisonc++, every run | no |
| `scannerbase.h`, `lex.cc` | flexc++, every run | no |
| `parser.h`, `parser.ih` | bisonc++, once | yes |
| `scanner.h`, `scanner.ih` | flexc++, once | yes |

The example shows the one piece that is genuinely fiddly: getting a token's
*value* (not just its type) from the scanner to the parser. Look at
`Parser::lex()` in `parser.ih` — every token passes through there, which makes
it the right place to set `d_val__`, the value bisonc++ pushes on its stack.

## Using an IDE

**VS Code is the recommended option** — it is what this environment is built
and tested against, it starts up faster than the JetBrains flow, and it does
not need the extra `.idea` workaround described in
[Troubleshooting](#troubleshooting). CLion works too, if you already know and
prefer it.

### VS Code (recommended)

1. Install the free **[VS Code](https://code.visualstudio.com/)** editor if
   you don't have it yet.
2. Install the **[Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)**
   extension (search for "Dev Containers" in the Extensions panel,
   <kbd>Ctrl/Cmd+Shift+X</kbd>).
3. Open the `CompilersDevEnv` folder in VS Code (**File → Open Folder…**).
4. VS Code notices the `.devcontainer/devcontainer.json` file on its own and
   shows a small popup in the bottom-right corner: *"Folder contains a Dev
   Container configuration file. Reopen folder to develop in a container?"*
   Click **Reopen in Container**.
   - Missed the popup, or it never appeared? Open the Command Palette
     (<kbd>F1</kbd>, or <kbd>Ctrl/Cmd+Shift+P</kbd>) and run
     **Dev Containers: Reopen in Container**.
5. The first time, VS Code builds the image and installs the C++ extensions
   listed in `devcontainer.json` automatically — this takes a few minutes and
   you'll see progress in a "Dev Containers" log panel. Every time after that
   it reopens in a few seconds.
6. Once it's done, the VS Code window title shows `[Dev Container: elte-
   compilers]`, the Explorer on the left shows the `workspace/` folder, and
   the integrated terminal (<kbd>Ctrl/Cmd+`</kbd>) already runs *inside* the
   container — `g++ --version` there should print the pandora-matching
   version from [Versions](#versions).

From here, open `workspace/examples/calc/` and you get real completion,
go-to-definition and a working debugger (set a breakpoint and press
<kbd>F5</kbd>) via the `ms-vscode.cpptools` extension.

### CLion and other JetBrains IDEs

CLion can use the same `.devcontainer/devcontainer.json`, but the workflow has
one more step and one known rough edge (see
[Troubleshooting](#troubleshooting) if it hangs on reopen):

1. Open the project folder in CLion.
2. Open `.devcontainer/devcontainer.json`.
3. Click the container icon in the gutter next to the opening `{`, and choose
   **Create Dev Container and Mount Sources**.
4. Wait for the first build, then pick **CLion** as the backend when prompted.

CLion opens directly on `workspace/`, and `workspace/examples/calc/` has a
`CMakeLists.txt` so the example is a CMake project it understands natively.

### Any other editor

There is nothing to integrate: edit files on your machine, and keep a
`./dev.sh` shell open in a terminal to run `make`. This works everywhere and is
what most people end up doing.

## Matching pandora's 32-bit build

pandora is a 32-bit machine, so `sizeof(long)` and `sizeof(void *)` are 4 there
and 8 in the dev image. Almost nothing in the course depends on that, but if
yours does, `-m32` makes the dev image produce 32-bit code too:

```console
$ g++ -m32 -std=c++14 -o calc main.cc parse.cc lex.cc
$ make CXXFLAGS="-std=c++14 -Wall -m32"
```

What `-m32` changes is the *target*, not the compiler: the same g++ 6.3.0 emits
x86 instead of x86-64, so pointers and `long` become 4 bytes and the binary
matches pandora's data model. `./dev.sh verify` covers the same ground by
running a genuinely 32-bit Debian 9, so reach for `-m32` only when you want the
faster feedback of the dev image.

## Before you submit

```console
$ ./dev.sh verify
```

This rebuilds your project on an untouched 32-bit Debian 9 — the same userland,
same architecture and same compiler as pandora. If it passes here, it will
compile when it is marked.

To check an assignment other than the example, name it:

```console
$ ./dev.sh verify hazi1
```

## How it works

Two images, because no single one can do both jobs.

**The dev image** (`docker/Dockerfile`) is what you use all day. Debian 9's
compiler and generators are unpacked onto a Debian 12 base: the `g++`,
`bisonc++` and `flexc++` binaries are the exact Debian builds that run on
pandora, but the C library underneath them is modern.

That sounds like a strange thing to do, and there is a specific reason for it.
Debian 9 ships glibc 2.24, while both the JetBrains and the VS Code remote
backends require **glibc 2.28 or newer**. An IDE simply cannot start inside a
Debian 9 container. Grafting the old toolchain onto a new base is what makes
"exact compiler" and "works with your IDE" possible at the same time.

Two details in that Dockerfile are worth knowing about if you ever edit it:

- Debian 9 predates the merged-`/usr` layout, so its packages contain real
  `/lib` and `/bin` directories. Unpacking them straight onto Debian 12 would
  replace the `/lib` → `usr/lib` symlink with a directory and hide the dynamic
  loader, which breaks every binary in the image. They are unpacked into a
  staging tree and relocated first.
- The old suites are pinned to a negative apt priority, so they are used as a
  download source and can never satisfy a normal `apt install`.

**The verification image** (`docker/Dockerfile.pandora`) is the opposite trade:
a plain, unmodified 32-bit Debian 9. No IDE can attach to it, and that is fine
— it exists so `./dev.sh verify` can answer one question honestly. It is built
the first time you run `verify`, not before.

Both images pin every package to an exact version from `archive.debian.org`,
which is frozen, so a build today and a build next year produce the same
toolchain.

## Apple Silicon and other ARM machines

The toolchain only exists as x86 binaries, so on an ARM Mac it runs emulated.
It works out of the box, but it is worth turning on **Rosetta**, which makes
builds several times faster and noticeably more reliable:

- **Docker Desktop** → Settings → General → *Use Rosetta for x86_64/amd64
  emulation on Apple Silicon*.
- **Colima** → start with `colima start --vm-type vz --vz-rosetta`, and give it
  some room: `--cpu 8 --memory 16`. To make that the default for every future
  Colima instance, put it in `colima template`.

Under plain QEMU emulation with little memory, `g++` occasionally dies with
`internal compiler error: Segmentation fault`. That is the emulator, not your
code — re-running `make` gets past it, and Rosetta plus more RAM stops it
happening.

`./dev.sh verify` uses 32-bit x86, which Rosetta does not accelerate, so that
one command stays slow everywhere. It is quick enough for the occasional check.

## Troubleshooting

**`the Docker daemon is not reachable`** — start Docker Desktop, or run
`colima start`.

**`the project folder is not visible inside the container`** — Docker can only
bind-mount folders it is allowed to share. Keep the repository under your home
directory, or add its location under Docker Desktop → Settings → Resources →
File sharing.

**`./dev.sh: Permission denied`** — `chmod +x dev.sh`.

**PowerShell refuses to run `dev.ps1`** — allow local scripts once:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

**Files are owned by `root` (Linux only)** — `./dev.sh` passes your user ID into
the container, so this should not happen. If you ran `docker run` by hand, add
`-e HOST_UID=$(id -u) -e HOST_GID=$(id -g)`.

**CLion crashes or hangs when you reopen the dev container** — the backend
leaves a `workspace/.idea` behind, which the IDE then sees as a project inside
your project. The `initializeCommand` in `.devcontainer/devcontainer.json`
deletes it on the host before each start, so this should not happen. If you hit
it once, delete `workspace/.idea` yourself and open the project again.

**`make` says a target is up to date after you edited `grammar`** — if the
clocks of host and container disagree, `make clean && make` sorts it out.

**Warnings from `lex.cc` or `parse.cc`** — those files are generated, and
`-Wextra` finds unused parameters in them. Warnings in your own files are worth
reading; those two are not.

## Known differences from pandora

The dev image runs 64-bit, pandora is 32-bit, so `sizeof(long)` and pointer
widths differ by default. Compile with `-m32` or run `./dev.sh verify` when
that matters — see [Matching pandora's 32-bit build](#matching-pandoras-32-bit-build).

The dev image also has a newer C library than pandora, so a function added to
glibc after 2016 would compile there and fail on pandora. `./dev.sh verify`
catches this too. Running it once before submitting is the whole mitigation.

## License

MIT — see [LICENSE](LICENSE). Use it, fork it, share it with your year.
