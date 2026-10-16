<#
.SYNOPSIS
    Checks that every tool this template needs is installed and configured.
    Prints one line per check and how to fix anything missing.
#>
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$failures = 0

function Report([string]$status, [string]$what, [string]$detail) {
    $color = @{ OK = 'Green'; WARN = 'Yellow'; MISSING = 'Red' }[$status]
    Write-Host ('[{0,-7}] ' -f $status) -ForegroundColor $color -NoNewline
    Write-Host ('{0,-22} {1}' -f $what, $detail)
    if ($status -eq 'MISSING') { $script:failures++ }
}

function Check-Command([string]$name, [string]$what, [string]$fix, [switch]$Optional) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        Report OK $what $cmd.Source
    } elseif ($Optional) {
        Report WARN $what "not found (optional). $fix"
    } else {
        Report MISSING $what "not found. $fix"
    }
}

Write-Host "Checking toolchain for $root`n"

# Rust
Check-Command cargo 'Rust (cargo)' 'Install from https://rustup.rs'
$hostLine = (rustc -vV 2>$null) -match '^host:'
if ($hostLine -match 'msvc') {
    Report OK 'Rust MSVC host' ($hostLine -replace 'host:\s*', '')
} elseif ($hostLine) {
    Report MISSING 'Rust MSVC host' "default host is '$hostLine'. Run: rustup default stable-x86_64-pc-windows-msvc"
}

# MSVC C++ compiler
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = if (Test-Path $vswhere) {
    & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}
if ($vs) {
    Report OK 'MSVC C++ tools' $vs
} else {
    Report MISSING 'MSVC C++ tools' 'Install Visual Studio or Build Tools with "Desktop development with C++"'
}

# vcpkg
$vcpkg = if ($env:VCPKG_ROOT) { Join-Path $env:VCPKG_ROOT 'vcpkg.exe' }
if ($vcpkg -and (Test-Path $vcpkg)) {
    Report OK 'vcpkg (VCPKG_ROOT)' $vcpkg
} else {
    Report MISSING 'vcpkg (VCPKG_ROOT)' 'Clone https://github.com/microsoft/vcpkg, run bootstrap-vcpkg.bat, set VCPKG_ROOT (see docs/guides/toolchain-setup.md)'
}

# Workflow tools
Check-Command just 'just' 'winget install Casey.Just'
Check-Command cargo-nextest 'cargo-nextest' 'winget install nextest.cargo-nextest'
Check-Command cargo-deny 'cargo-deny' 'cargo install cargo-deny --locked'
Check-Command sccache 'sccache' 'winget install Mozilla.sccache' -Optional
Check-Command clang-format 'clang-format' 'Comes with LLVM, or use the one in Visual Studio (VC\Tools\Llvm\x64\bin)' -Optional
Check-Command clang-tidy 'clang-tidy' 'Comes with LLVM, or use the one in Visual Studio (VC\Tools\Llvm\x64\bin)' -Optional

if ($root -match '\s') {
    Report WARN 'Path has spaces' 'Most vcpkg ports cope, but a few (autotools-based) do not. Prefer paths without spaces.'
}

Write-Host ''
if ($failures -gt 0) {
    Write-Host "$failures required tool(s) missing." -ForegroundColor Red
    exit 1
}
Write-Host 'All required tools found.' -ForegroundColor Green
