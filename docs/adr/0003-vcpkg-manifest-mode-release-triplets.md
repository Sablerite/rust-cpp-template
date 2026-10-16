# 0003. vcpkg in manifest mode with release-only, static, `/MD` triplets

- **Status:** Accepted
- **Date:** 2026-10-16

## Context

C++ libraries need to be downloaded, built with a compatible compiler and C runtime, pinned
to known versions, and linked into the Rust executable, ideally without shipping DLLs.

## Decision

- Use **vcpkg in manifest mode**: `vcpkg.json` lists ports, and `vcpkg-configuration.json`
  pins the registry baseline (and so every port version).
- `build-support` runs `vcpkg install` into `target/vcpkg/<triplet>/installed` when the
  manifest changes, then uses the `vcpkg` crate to emit link directives. The `vcpkg` crate
  (0.2.15) only understands classic-mode layouts, so `build-support` installs into a layout
  it recognizes (a `.vcpkg-root` marker plus `installed/`). Each triplet gets its own tree,
  because a manifest-mode install removes other triplets' packages from its install root.
- Default triplets are **static libraries, dynamic release CRT, release-only**: on x64
  Windows, `x64-windows-static-md-release`. With `+crt-static`, `x64-windows-static-release`.
  On Linux and macOS, the `-release` variants.

## Consequences

- One `.exe` with no third-party DLLs. It needs only the standard VC++ runtime, or nothing
  extra with `just dist-static` (`+crt-static` selects the static-CRT triplet).
- The C runtime matches Rust's default (`/MD`), avoiding `LNK2038` mismatches.
- Release-only builds halve C++ dependency build time. Debug builds of C++ libraries would
  never be linked anyway, because Rust always uses the release CRT.
- vcpkg's binary cache shares compiled packages across every project on the machine.
- Upgrading C++ libraries is one baseline change (`vcpkg x-update-baseline`).
- Stepping into library internals in the debugger is limited (release code).
- If the `vcpkg` crate breaks, only `build-support` needs changing: replace the lookup with
  pkg-config (`.pc`) parsing of `target/vcpkg/<triplet>/installed/<triplet>/lib/pkgconfig`.

## Alternatives considered

- **Conan.** Capable, but a Python dependency and less common with MSVC/Rust setups.
- **CMake FetchContent / CPM.** Builds dependencies from source per project, with no
  cross-project binary cache.
- **Dynamic linking (`x64-windows`).** Requires shipping and locating DLLs.
- **vcpkg-bundled-with-Visual-Studio.** Works (and `build-support` could fall back to it),
  but a standalone clone with `VCPKG_ROOT` behaves the same on every machine and in CI.
