# 0004. One bridge crate per C++ library

- **Status:** Accepted
- **Date:** 2026-10-16

## Context

Interop code is where memory-safety and build problems concentrate. Without a rule, C++
types and `unsafe` tend to spread through the codebase.

## Decision

Each C++ library gets its own crate in `crates/ffi/cpp-<name>/`, containing:

- `cpp/`: a thin C++ shim that calls the library and converts its types
- `src/bridge.rs`: the cxx declarations (the only place `unsafe` is allowed)
- `src/lib.rs`: a safe, idiomatic Rust API, the only thing other crates use
- `tests/`: tests through that safe API

Shims expose coarse operations the application needs, not the library's full API. `unsafe`
is denied workspace-wide, and bridge crates opt back in only on `mod bridge;`.

## Consequences

- Swapping a C++ library for a Rust crate later touches one crate and its callers' imports.
- Each bridge builds, tests and links independently; deleting one is clean.
- Small upfront cost per library (`just new-bridge` scaffolds it).
- Shared C++ types between two bridges need one bridge to export headers (both crates set
  `links`, which the scaffold already does).

## Alternatives considered

- **One big `ffi` crate for all C++.** Simpler at first, but every C++ change rebuilds
  everything, and the boundary grows without limit.
- **C++ calls directly from app code.** Spreads `unsafe` and cxx types everywhere.
