# Toolchain setup

Run `just doctor` (or `./scripts/doctor.ps1` if `just` isn't installed yet) to see what's missing.

## Fresh Windows machine

1. **Visual Studio 2022 or newer** (Community is fine) or **Build Tools for Visual Studio**, with:
   - the *Desktop development with C++* workload (MSVC compiler, Windows SDK)
   - the *C++ Clang tools for Windows* component (clang-format and clang-tidy for `just fmt` and `just tidy`)
2. **Rust** from [rustup.rs](https://rustup.rs). Keep the default `x86_64-pc-windows-msvc` host.
   `rust-toolchain.toml` installs rustfmt, clippy and rust-src on first use.
3. **vcpkg**:
   ```powershell
   git clone https://github.com/microsoft/vcpkg "$env:USERPROFILE\vcpkg"
   & "$env:USERPROFILE\vcpkg\bootstrap-vcpkg.bat" -disableMetrics
   [Environment]::SetEnvironmentVariable('VCPKG_ROOT', "$env:USERPROFILE\vcpkg", 'User')
   ```
4. **Workflow tools**:
   ```powershell
   winget install Casey.Just nextest.cargo-nextest Mozilla.sccache
   cargo install cargo-deny --locked
   ```
5. **sccache for every Rust project**: create `%USERPROFILE%\.cargo\config.toml` with
   ```toml
   [build]
   rustc-wrapper = "sccache"
   ```
6. **Restart** terminals and VS Code so they pick up the new `PATH` and `VCPKG_ROOT`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `could not run vcpkg.exe` | `VCPKG_ROOT` isn't set in this shell. Set it (step 3) and restart the terminal or editor. |
| `could not execute process sccache` | The terminal's `PATH` predates the sccache install (restart it), or sccache was removed (delete the `[build]` block from `%USERPROFILE%\.cargo\config.toml`). To skip it for one shell: `$env:RUSTC_WRAPPER = ""`. |
| `vcpkg port 'x' not found` | The port is missing from `vcpkg.json` (`just add-cpp x`), or the name in `build.rs` differs from the port name. |
| `LNK2019 unresolved external symbol` | The library isn't listed in that bridge's `build_support::vcpkg(&[...])`, or a declaration in `bridge.rs` doesn't match the C++ definition. |
| `LNK2038 mismatch detected for 'RuntimeLibrary'` | Something was compiled with a different C runtime. Keep the default `-static-md` triplet. If you enable `+crt-static`, every library must use the static-CRT triplet (build-support switches automatically). |
| A vcpkg port fails to build | Read the log path printed in the error. Some ports (mostly autotools-based) fail when the project path contains spaces; move the project to a path without spaces. |
| C++ red squiggles in VS Code | Build once with `cargo build`. That creates `target/cxxbridge` and `target/vcpkg`, which IntelliSense needs. |
| Want clangd instead of the Microsoft C++ extension | `just compdb` writes `compile_commands.json`. Use an MSVC build of clangd (from the official LLVM installer); MinGW builds can't find the MSVC headers. |
| `just tidy` reports `'cstddef' file not found` | It's using a MinGW-built clang-tidy. Install the *C++ Clang tools for Windows* VS component; `scripts/cpp.ps1` prefers that copy. |

## What this template expects

| Tool | Used for |
|---|---|
| MSVC (Visual Studio 2022+) | Compiling C++ and linking |
| Rust stable, MSVC host | Everything else |
| vcpkg (`VCPKG_ROOT`) | C++ libraries; installed automatically during `cargo build` |
| just | Recipes in `justfile` (optional: each recipe is a plain command you can run directly) |
| cargo-nextest | `just test` |
| cargo-deny | `just deny` |
| sccache | Optional; shared Rust compile cache |
| clang-format, clang-tidy | `just fmt`, `just lint`, `just tidy` |
