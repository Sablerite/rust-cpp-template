# 0001. Cargo drives the whole build

- **Status:** Accepted
- **Date:** 2026-10-16

## Context

Projects are mostly Rust. C++ is used only to reach libraries that Rust lacks. Something has
to be the top-level build system, and one command should build everything.

## Decision

Cargo is the only entry point. C++ is compiled from bridge crates' `build.rs` scripts via the
`cc` crate (through `cxx-build`), and C++ libraries are installed by vcpkg from the same
build scripts, via the shared `build-support` crate. There is no top-level `CMakeLists.txt`.

## Consequences

- `cargo build`, `cargo test` and rust-analyzer work with no extra steps; the C++ is built as needed.
- C++ IntelliSense needs configuration: `.vscode/c_cpp_properties.json`, or
  `just compdb` for clangd, because `cc` doesn't emit `compile_commands.json`.
- A large C++ codebase of your own that already has a CMake build can still be built from a
  bridge's `build.rs` with the `cmake` crate, but that's an exception, not the default.

## Alternatives considered

- **CMake on top, with [Corrosion](https://github.com/corrosion-rs/corrosion) importing the
  Rust crates.** Best when C++ is the main language. Here it would make the common case,
  editing Rust, go through CMake.
- **Separate builds glued by scripts.** Easy to get out of sync, and slow.
