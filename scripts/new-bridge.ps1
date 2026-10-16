<#
.SYNOPSIS
    Scaffolds a new C++ bridge crate at crates/ffi/cpp-<name> and registers it
    in the workspace. The result builds and passes its test immediately; then
    you replace the placeholder function with real calls into your library.
.EXAMPLE
    ./scripts/new-bridge.ps1 -Name opencv
#>
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z][a-z0-9-]*$')]
    [string]$Name
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$short = $Name -replace '^cpp-', ''
$crate = "cpp-$short"
$ident = $short -replace '-', '_'        # C++ file names and namespace
$namespace = "cpp_$ident"
$dir = Join-Path $root "crates\ffi\$crate"
if (Test-Path $dir) { throw "$dir already exists." }

$utf8 = New-Object Text.UTF8Encoding $false
function Write-File([string]$relative, [string]$content) {
    $path = Join-Path $dir $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($content -replace "`r`n", "`n").TrimStart("`n"), $utf8)
}

Write-File 'Cargo.toml' @"
[package]
name = "$crate"
description = "Safe Rust API over the $short C++ library."
version.workspace = true
edition.workspace = true
rust-version.workspace = true
publish.workspace = true
links = "$crate"

[dependencies]
cxx.workspace = true

[build-dependencies]
build-support.workspace = true

[lints]
workspace = true
"@

Write-File 'build.rs' @"
fn main() {
    // vcpkg ports this bridge links (add them to vcpkg.json first: `just add-cpp <port>`).
    let includes = build_support::vcpkg(&[]);

    build_support::bridge("src/bridge.rs")
        .file("cpp/src/$ident.cc")
        .includes(&includes)
        .compile("$crate");

    build_support::rerun_if_changed(&["src/bridge.rs", "cpp"]);
}
"@

Write-File 'src/bridge.rs' @"
//! The Rust <-> C++ boundary for $short. Keep it small; lib.rs wraps it.

#[cxx::bridge(namespace = "$namespace")]
pub(crate) mod ffi {
    unsafe extern "C++" {
        include!("$crate/cpp/include/$ident.h");

        /// Placeholder: replace with the calls you need.
        fn library_version() -> String;
    }
}
"@

Write-File 'src/lib.rs' @"
//! Safe Rust API over the $short C++ library. This is the only API the rest
//! of the workspace should use; keep cxx types out of it.

#[allow(unsafe_code)] // cxx bridge declarations are the one place unsafe is allowed
mod bridge;

use bridge::ffi;

/// Version string reported by the C++ side.
#[must_use]
pub fn library_version() -> String {
    ffi::library_version()
}
"@

Write-File "cpp/include/$ident.h" @"
// C++ side of the $crate bridge. Must match the declarations in src/bridge.rs.
#pragma once

#include "rust/cxx.h"

namespace $namespace {

rust::String library_version();

}  // namespace $namespace
"@

Write-File "cpp/src/$ident.cc" @"
#include "$crate/cpp/include/$ident.h"

namespace $namespace {

rust::String library_version() {
  // Placeholder: #include your library and return its real version.
  return rust::String("$short (placeholder)");
}

}  // namespace $namespace
"@

$rustCrate = $crate -replace '-', '_'
Write-File 'tests/smoke.rs' @"
use $rustCrate::library_version;

#[test]
fn bridge_links_and_runs() {
    assert!(!library_version().is_empty());
}
"@

# Register in [workspace.dependencies] so other crates can use `$crate.workspace = true`.
$cargoToml = Join-Path $root 'Cargo.toml'
$text = [IO.File]::ReadAllText($cargoToml)
$entry = "$crate = { path = `"crates/ffi/$crate`" }"
if ($text -notmatch [regex]::Escape($entry)) {
    $text = [regex]::Replace($text, '(?m)^(build-support = .*)$', "`$1`n$entry", 1)
    [IO.File]::WriteAllText($cargoToml, $text, $utf8)
}

Write-Host "Created crates/ffi/$crate" -ForegroundColor Green
Write-Host @"

Next:
  1. just add-cpp <vcpkg-port>          add the C++ library to vcpkg.json
  2. crates/ffi/$crate/build.rs          list that port in build_support::vcpkg(&["<port>"])
  3. cpp/ + src/bridge.rs + src/lib.rs   wrap the calls you need (see docs/guides/adding-a-cpp-library.md)
  4. In the crate that uses it:          $crate.workspace = true   under [dependencies]
  5. just test
"@
