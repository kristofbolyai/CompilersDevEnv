<#
.SYNOPSIS
    ELTE Compilers dev environment - one entry point for everything (Windows).

.DESCRIPTION
    The PowerShell counterpart of dev.sh. Both drive the same images and mount
    the same folder, so it makes no difference which one you use.

      .\dev.ps1                 open a shell in the container
      .\dev.ps1 build           (re)build the image
      .\dev.ps1 test            build and test the bundled example
      .\dev.ps1 verify          repeat the build on a real Debian 9 userland
      .\dev.ps1 new <name>      start a new project from the example skeleton
      .\dev.ps1 run <cmd...>    run a single command inside the container
      .\dev.ps1 doctor          check that the local setup can work
      .\dev.ps1 clean           remove the images this project created

    If PowerShell refuses to run this file, allow local scripts once with:
      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'shell',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest = @()
)

$ErrorActionPreference = 'Stop'

$RepoRoot      = $PSScriptRoot
$ImageDev      = 'elte-compilers:dev'
$ImagePandora  = 'elte-compilers:pandora'
$ContainerRepo = '/workspaces/elte-compilers'
# The dev image is amd64; the verification image is 32-bit, because that is
# what pandora is (Target: i686-linux-gnu).
$Platform        = 'linux/amd64'
$PlatformPandora = 'linux/386'

function Write-Info { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Bold { param($m) Write-Host $m -ForegroundColor White }
function Die       { param($m) Write-Host "error: $m" -ForegroundColor Red; exit 1 }

function Require-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Die 'docker is not installed. See the README for install instructions.'
    }
    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Die 'the Docker daemon is not reachable. Start Docker Desktop and try again.'
    }
}

function Test-Image { param($Image) docker image inspect $Image *> $null; return ($LASTEXITCODE -eq 0) }

function Build-Image {
    param($Image, $Dockerfile, $ImagePlatform = $Platform)
    Write-Info "building $Image (first time takes a few minutes)"
    docker build --platform $ImagePlatform -f (Join-Path $RepoRoot $Dockerfile) -t $Image $RepoRoot
    if ($LASTEXITCODE -ne 0) { Die "building $Image failed" }
}

function Ensure-Image {
    param($Image, $Dockerfile, $ImagePlatform = $Platform)
    if (-not (Test-Image $Image)) { Build-Image $Image $Dockerfile $ImagePlatform }
}

# If the caller is somewhere under workspace\, land in the matching folder
# inside the container.
function Get-ContainerWorkdir {
    $cwd = (Get-Location).Path
    $ws  = (Join-Path $RepoRoot 'workspace')
    if ($cwd.StartsWith($ws, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $cwd.Substring($ws.Length).Replace('\', '/')
        return "$ContainerRepo/workspace$relative"
    }
    return "$ContainerRepo/workspace"
}

function Invoke-Container {
    param($Image, [string[]]$CommandLine, $ImagePlatform = $Platform)

    $opts = @(
        '--rm',
        '--platform', $ImagePlatform,
        '-v', "${RepoRoot}:${ContainerRepo}",
        '-w', (Get-ContainerWorkdir)
    )
    # Docker Desktop on Windows maps ownership for us, so no HOST_UID here.
    if ([Environment]::UserInteractive) { $opts += '-it' }

    # Deliberately no return value: docker's own output already flows to the
    # host through this function's output stream, so anything returned here
    # would arrive at the caller mixed in with it. Callers read $LASTEXITCODE.
    docker run @opts $Image @CommandLine
}

function Cmd-Build  { Require-Docker; Build-Image $ImageDev 'docker/Dockerfile' }

function Cmd-Shell {
    Require-Docker; Ensure-Image $ImageDev 'docker/Dockerfile'
    Invoke-Container $ImageDev @('bash')
    exit $LASTEXITCODE
}

function Cmd-Run {
    if ($Rest.Count -eq 0) { Die 'run needs a command, e.g. .\dev.ps1 run make' }
    Require-Docker; Ensure-Image $ImageDev 'docker/Dockerfile'
    Invoke-Container $ImageDev $Rest
    exit $LASTEXITCODE
}

function Cmd-Test {
    Require-Docker; Ensure-Image $ImageDev 'docker/Dockerfile'
    Write-Info 'building and testing the example with gcc 6.3.0'
    $script = "cd $ContainerRepo/workspace/examples/calc && make clean >/dev/null && make && make test"
    Invoke-Container $ImageDev @('bash', '-lc', $script)
    exit $LASTEXITCODE
}

function Cmd-Verify {
    Require-Docker; Ensure-Image $ImagePandora 'docker/Dockerfile.pandora' $PlatformPandora
    $target = if ($Rest.Count -gt 0) { $Rest[0] } else { 'examples/calc' }
    if (-not (Test-Path (Join-Path $RepoRoot "workspace/$target"))) {
        Die "workspace/$target does not exist"
    }
    Write-Info "rebuilding '$target' on an untouched Debian 9 userland"
    $script = @"
set -e
cd '$ContainerRepo/workspace/$target'
make clean >/dev/null 2>&1 || true
make
if grep -qE '^test:' Makefile 2>/dev/null; then make test; fi
"@
    Invoke-Container $ImagePandora @('bash', '-lc', $script) $PlatformPandora
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Bold "verify: '$target' builds on Debian 9 exactly as pandora ships it."
}

function Cmd-New {
    if ($Rest.Count -eq 0) { Die 'new needs a project name, e.g. .\dev.ps1 new hazi1' }
    $name = $Rest[0]
    $dest = Join-Path $RepoRoot "workspace/$name"
    if (Test-Path $dest) { Die "workspace/$name already exists" }
    New-Item -ItemType Directory -Path $dest | Out-Null
    $skeleton = Join-Path $RepoRoot 'workspace/examples/calc'
    foreach ($f in 'grammar', 'lexer', 'scanner.h', 'scanner.ih', 'parser.h', 'parser.ih', 'main.cc', 'Makefile') {
        Copy-Item (Join-Path $skeleton $f) (Join-Path $dest $f)
    }
    Write-Bold "created workspace/$name"
    Write-Info "open a shell with '.\dev.ps1' and run 'make' inside it"
}

function Cmd-Doctor {
    Write-Bold 'ELTE Compilers dev environment - setup check'
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host '  docker cli      : MISSING'; exit 1
    }
    Write-Host "  docker cli      : $(docker --version)"

    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  docker daemon   : NOT reachable - start Docker Desktop'; exit 1
    }
    Write-Host '  docker daemon   : reachable'
    Write-Host "  host arch       : $env:PROCESSOR_ARCHITECTURE"

    docker run --rm --platform $Platform debian:bookworm-slim true *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '  linux/amd64     : runnable'
    } else {
        Write-Host '  linux/amd64     : NOT runnable - this environment is amd64-only, see the README'; exit 1
    }

    docker run --rm --platform $PlatformPandora i386/debian:stretch-slim true *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  linux/386       : runnable (needed only by '.\dev.ps1 verify')"
    } else {
        Write-Host "  linux/386       : NOT runnable - '.\dev.ps1 verify' will not work, everything else will"
    }

    Write-Host ("  image (dev)     : " + $(if (Test-Image $ImageDev) { 'built' } else { "not built yet ('.\dev.ps1 build')" }))
    Write-Host ("  image (pandora) : " + $(if (Test-Image $ImagePandora) { 'built' } else { "not built yet (built on first '.\dev.ps1 verify')" }))

    if (Test-Image $ImageDev) {
        Write-Host '  toolchain       :'
        docker run --rm --platform $Platform $ImageDev bash -lc 'printf "    %s\n" "$(g++ --version | head -1)" "$(bisonc++ -v)" "$(flexc++ -v)"'
    }
}

function Cmd-Clean {
    Require-Docker
    docker image rm -f $ImageDev $ImagePandora *> $null
    Write-Info 'removed project images'
}

switch ($Command.ToLower()) {
    'build'   { Cmd-Build }
    'shell'   { Cmd-Shell }
    'sh'      { Cmd-Shell }
    'bash'    { Cmd-Shell }
    'run'     { Cmd-Run }
    'test'    { Cmd-Test }
    'verify'  { Cmd-Verify }
    'new'     { Cmd-New }
    'doctor'  { Cmd-Doctor }
    'clean'   { Cmd-Clean }
    'help'    { Get-Help $PSCommandPath -Detailed }
    default   { Die "unknown command '$Command'. Try '.\dev.ps1 help'." }
}
