<#
.SYNOPSIS
    Assembles dist/<bin>/ from a `--profile dist` build: the executable and
    the assets folder next to it (where app_core::assets looks first).
    Run via `just dist`.
#>
param(
    [Parameter(Mandatory)]
    [string]$Bin,

    # Cargo target directory the build used (relative to the workspace root).
    [string]$TargetDir = 'target'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root "$TargetDir\dist\$Bin.exe"
if (-not (Test-Path $exe)) { throw "$exe not found. Run: cargo build -p app --profile dist" }

$out = Join-Path $root "dist\$Bin"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force -Path $out | Out-Null
Copy-Item $exe $out
Copy-Item (Join-Path $root 'assets') (Join-Path $out 'assets') -Recurse
Get-ChildItem (Join-Path $out 'assets') -Recurse -Filter 'README.md' | Remove-Item

Write-Host "Packaged $out"
