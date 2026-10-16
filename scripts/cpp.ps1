<#
.SYNOPSIS
    C++ tooling for the bridge sources in crates/ffi/*/cpp.
.DESCRIPTION
    format        clang-format -i on every C++ file
    check-format  fail if any C++ file is not formatted
    compdb        write compile_commands.json (needs a prior `cargo build`)
    tidy          run clang-tidy using compile_commands.json
.EXAMPLE
    ./scripts/cpp.ps1 format
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('format', 'check-format', 'compdb', 'tidy')]
    [string]$Command
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Get-CppFiles([string[]]$Extensions) {
    Get-ChildItem (Join-Path $root 'crates\ffi') -Recurse -File |
        Where-Object { $Extensions -contains $_.Extension -and $_.FullName -match '[\\/]cpp[\\/]' }
}

# Prefer the LLVM copy bundled with Visual Studio: it is built with MSVC and
# finds the MSVC standard library headers on its own (MinGW builds of
# clang-tidy cannot). Fall back to whatever is on PATH.
function Get-LlvmTool([string]$name) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -property installationPath
        $bundled = Join-Path $vs "VC\Tools\Llvm\x64\bin\$name.exe"
        if (Test-Path $bundled) { return $bundled }
    }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "$name not found. Add the 'C++ Clang tools for Windows' Visual Studio component, or install LLVM."
}

$sources = @(Get-CppFiles '.cc', '.cpp', '.cxx')
$all = @(Get-CppFiles '.h', '.hpp', '.cc', '.cpp', '.cxx')

switch ($Command) {
    'format' {
        $tool = Get-LlvmTool 'clang-format'
        foreach ($file in $all) { & $tool -i $file.FullName }
        Write-Host "Formatted $($all.Count) C++ file(s)."
    }
    'check-format' {
        $tool = Get-LlvmTool 'clang-format'
        $bad = 0
        foreach ($file in $all) {
            & $tool --dry-run --Werror $file.FullName
            if ($LASTEXITCODE -ne 0) { $bad++ }
        }
        if ($bad -gt 0) { Write-Error "$bad C++ file(s) need formatting. Run: just fmt" }
        Write-Host "$($all.Count) C++ file(s) formatted correctly."
    }
    'compdb' {
        $triplet = if ($env:VCPKGRS_TRIPLET) { $env:VCPKGRS_TRIPLET } else { 'x64-windows-static-md-release' }
        $includes = @(
            (Join-Path $root 'crates\ffi'),                                   # "<crate>/cpp/include/x.h"
            (Join-Path $root 'target\cxxbridge'),                             # "rust/cxx.h", "<crate>/src/bridge.rs.h"
            (Join-Path $root "target\vcpkg\$triplet\installed\$triplet\include")  # vcpkg libraries
        )
        $entries = foreach ($file in $sources) {
            [ordered]@{
                directory = $root
                file      = $file.FullName
                # cl.exe-style flags matching build-support's configure().
                arguments = @('cl.exe', '/std:c++20', '/EHsc', '/permissive-', '/utf-8', '/Zc:__cplusplus') +
                            ($includes | ForEach-Object { "/I$_" }) + @($file.FullName)
            }
        }
        $json = ConvertTo-Json -InputObject @($entries) -Depth 4
        $out = Join-Path $root 'compile_commands.json'
        [IO.File]::WriteAllText($out, $json, (New-Object Text.UTF8Encoding $false))
        Write-Host "Wrote $out ($($sources.Count) file(s))."
    }
    'tidy' {
        $tool = Get-LlvmTool 'clang-tidy'
        & $tool -p $root --quiet @($sources | ForEach-Object FullName)
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}
