# Architecture

## The idea

Rust is the main language. C++ exists only to reach libraries that have no good Rust
equivalent. Each C++ library sits behind its own bridge crate, which exposes a small, safe
Rust API. Nothing outside `crates/ffi/` knows C++ is involved.

```
app (exe) ──► app-core (pure Rust)
   │
   └────────► cpp-example (bridge crate) ──► C++ shim (cpp/) ──► {fmt} (from vcpkg)
              safe Rust API in src/lib.rs     your code           third-party library
```

## What `cargo build` does

1. Cargo builds Rust dependencies as usual.
2. For each bridge crate, its `build.rs` calls `build-support`, which:
   1. Runs `vcpkg install` for everything in `vcpkg.json`, at the versions pinned by
      `vcpkg-configuration.json`, into `target/vcpkg/<triplet>/`. This only happens
      when those files change, and it serializes with a lock so parallel build scripts and
      rust-analyzer don't collide.
   2. Finds the requested ports there and tells Cargo to link their static libraries,
      including transitive dependencies.
   3. Runs cxx-build: generates C++ glue from `src/bridge.rs`, then compiles it together with
      `cpp/src/*.cc` using MSVC (C++20, `/W4`, `/permissive-`, `/utf-8`) into a static library.
3. Rust code, bridge libraries and vcpkg libraries are linked into one executable.

## Shipping

`just dist` puts the executable and `assets/` in `dist/<name>/`. C++ libraries are linked in
statically, so there are no third-party DLLs. Like any program built with Visual Studio, the
exe still uses Microsoft's C/C++ runtime DLLs (`VCRUNTIME140.dll`, `MSVCP140.dll`). They're
already present on most Windows PCs, and the
[VC++ Redistributable](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)
installs them where they're missing.

To avoid even that, `just dist-static` builds with `+crt-static`. `build-support` then
switches vcpkg to the static-CRT triplet (`x64-windows-static-release`), and the exe depends
only on DLLs that ship with Windows.

## Why it's fast

- **vcpkg binary cache.** Every compiled C++ package is stored in
  `%LOCALAPPDATA%\vcpkg\archives`, keyed by version, triplet and compiler. Any project on
  this machine that needs the same package restores it in seconds instead of rebuilding.
  `cargo clean` is cheap for the same reason.
- **Release-only triplets.** Rust always links the release C runtime, so vcpkg builds only
  release variants (`x64-windows-static-md-release`). That halves C++ dependency build time.
- **sccache** (enabled user-wide in `%USERPROFILE%\.cargo\config.toml`) shares Rust compile
  results across projects. On MSVC the `cc` crate does not route `cl.exe` through sccache,
  so your bridge `.cc` files are recompiled when they change. They are small; the expensive
  C++ is the vcpkg libraries, which are cached as above.
- **Small debug info for dependencies.** `[profile.dev.package."*"]` keeps only line tables
  for third-party crates. PDBs stay small and links stay fast.

## The boundary, at runtime

| Concern | How it's handled |
|---|---|
| Type safety | cxx checks both sides of `src/bridge.rs` at build time; a mismatch is a compile error |
| C++ exceptions | Functions declared `-> Result<T>` in the bridge catch `std::exception` and return `Err`. A throw from a function *not* declared `Result` aborts the process. |
| Rust panics | A panic in an `extern "Rust"` function called from C++ aborts the process; it never unwinds into C++ |
| Ownership | C++ objects live in `UniquePtr` / `SharedPtr` on the Rust side and are destroyed by C++ |
| Mutation | C++ methods that mutate take `Pin<&mut T>` |
| Threads | Opaque C++ types are neither `Send` nor `Sync` unless you add `unsafe impl` with a justification |
| C runtime | Everything uses the dynamic release CRT (`/MD`): Rust's default, the `cc` crate's default, and the `-static-md` vcpkg triplets. Mismatches cause `LNK2038` errors |
| `unsafe` | Denied workspace-wide; only the `mod bridge;` declarations opt back in |

## Crates

| Crate | Role | Depends on C++? |
|---|---|---|
| `app` | Executable: parses input, wires things together, reports errors (`anyhow`), sets up logging (`tracing`) | Indirectly |
| `app-core` | Application logic and asset lookup. Pure Rust, fast to build and test | No |
| `build-support` | Build-script library shared by all bridges | Build time only |
| `cpp-example` | Worked example of a bridge. Delete it once you have real ones | Yes |

Decisions behind this design are recorded in [adr/](adr/README.md).
