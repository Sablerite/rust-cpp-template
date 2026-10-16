# Architecture decision records

Each ADR records one decision that would be expensive to reverse: the context, what was
decided, and what it costs. When a decision changes, add a new ADR that supersedes the old
one, and mark the old one `Superseded by NNNN`. Don't rewrite history.

| # | Decision | Status |
|---|---|---|
| [0001](0001-cargo-drives-the-build.md) | Cargo drives the whole build | Accepted |
| [0002](0002-cxx-for-rust-cpp-interop.md) | cxx for Rust/C++ interop | Accepted |
| [0003](0003-vcpkg-manifest-mode-release-triplets.md) | vcpkg in manifest mode with release-only, static, `/MD` triplets | Accepted |
| [0004](0004-one-bridge-crate-per-cpp-library.md) | One bridge crate per C++ library | Accepted |
| [0005](0005-msvc-toolchain-on-windows.md) | MSVC toolchain on Windows | Accepted |

New ADR: copy the newest one, bump the number, keep the same headings
(Status, Context, Decision, Consequences, Alternatives considered).
