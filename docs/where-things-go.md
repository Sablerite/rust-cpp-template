# Where things go

| You have... | Put it in | Notes |
|---|---|---|
| Application logic | `crates/app-core/src/` | Pure Rust; split into modules as it grows |
| Startup, CLI parsing, wiring | `crates/app/src/main.rs` | Keep it thin |
| Another Rust library | `crates/<name>/` | `cargo new crates/<name> --lib` adds it to the workspace |
| A C++ library you need | `vcpkg.json` | `just add-cpp <port>` |
| The Rust wrapper for it | `crates/ffi/cpp-<name>/` | `just new-bridge <name>`; one crate per C++ library |
| C++ code you write (the shim) | `crates/ffi/cpp-<name>/cpp/src/`, headers in `cpp/include/` | Thin adapters, not application logic |
| The Rust/C++ declarations | `crates/ffi/cpp-<name>/src/bridge.rs` | The only place `unsafe` is allowed |
| C/C++ source that isn't in vcpkg | `third_party/<name>/` | With its license; see `third_party/README.md` |
| Dependency versions | Root `Cargo.toml` `[workspace.dependencies]` | Member crates use `foo.workspace = true` |
| Unit tests | Same file, `#[cfg(test)] mod tests` | |
| Integration tests | `crates/<crate>/tests/*.rs` | Test bridges through their safe API |
| Benchmarks | `crates/<crate>/benches/` | Add `criterion` when you need it |
| Runnable examples | `crates/<crate>/examples/` | `cargo run --example <name>` |
| Images, fonts, audio, data, shaders | `assets/<kind>/` | Load with `app_core::assets::path("kind/file")` |
| Local settings and secrets | `.env` (copy `.env.example`) | Git-ignored; `just` loads it |
| Docs for people | `docs/`, guides in `docs/guides/` | API docs go in `///` comments |
| A decision that's hard to reverse | `docs/adr/NNNN-title.md` | Copy the format of an existing ADR |
| Release notes | `CHANGELOG.md` | |
| Scripts | `scripts/*.ps1`, exposed as recipes in `justfile` | |
| CI | `.github/workflows/` | |
| Editor settings | `.vscode/` | |
| Formatter/linter config | `rustfmt.toml`, `clippy.toml`, `.clang-format`, `.clang-tidy`, `deny.toml`, `.editorconfig` | Lint *levels* are in `Cargo.toml` `[workspace.lints]` |
| Build output | `target/` (includes vcpkg packages under `target/vcpkg/`) | Git-ignored |
| Packaged builds | `dist/` | `just dist`; git-ignored |
| License for your project | `LICENSE` at the root | Not included; choose one per project |
