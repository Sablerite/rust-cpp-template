# 0005. MSVC toolchain on Windows

- **Status:** Accepted
- **Date:** 2026-10-16

## Context

Rust on Windows has two toolchains: MSVC (`x86_64-pc-windows-msvc`) and GNU
(`x86_64-pc-windows-gnu`, MinGW). C++ libraries must use the same ABI as the code that links
them.

## Decision

Use the MSVC toolchain for Rust and C++. `build-support` refuses to build bridges for a
non-MSVC Windows target.

## Consequences

- It's Rust's default and best-supported Windows target, and vcpkg's default Windows triplets
  use MSVC.
- The Visual Studio debugger, and VS Code's `cppvsdbg`, debug Rust and C++ together through PDBs.
- Visual Studio (or Build Tools) with the C++ workload is required.
- MinGW-built LLVM tools on `PATH`, such as llvm-mingw's clang-tidy and clangd, can't find
  the MSVC headers. `scripts/cpp.ps1` prefers the LLVM tools bundled with Visual Studio.

## Alternatives considered

- **GNU/MinGW.** Unsupported by the `vcpkg` crate, a different C++ ABI from most prebuilt
  Windows libraries, and weaker debugger integration.
- **clang-cl.** MSVC-compatible and usable by setting `CXX=clang-cl` if ever needed. MSVC
  stays the default because it's what vcpkg and Visual Studio test against.
