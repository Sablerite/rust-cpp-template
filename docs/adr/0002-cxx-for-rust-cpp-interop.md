# 0002. cxx for Rust/C++ interop

- **Status:** Accepted
- **Date:** 2026-10-16

## Context

Rust and C++ have no shared ABI beyond C. Hand-written `extern "C"` wrappers are unsafe on
both sides and lose C++ types such as strings, vectors, smart pointers and exceptions.

## Decision

Use [cxx](https://cxx.rs) (`cxx` + `cxx-build`). Each bridge declares both sides of the
boundary in one `#[cxx::bridge]` module; cxx generates the glue and checks both sides at
build time.

## Consequences

- Strings, slices, vectors and `unique_ptr`/`shared_ptr` cross without copying into C types.
- C++ exceptions become `Result::Err` for functions declared fallible. Rust panics never
  unwind into C++.
- Signature mismatches are compile errors, not runtime crashes.
- Each library still needs a hand-written C++ shim for anything cxx can't express, such as
  templates or library-specific types. This is deliberate: the shim is where the boundary is
  kept narrow (see ADR 0004).
- Chromium's Rust interop guidance also recommends cxx, so it's a well-trodden path.

## Alternatives considered

- **bindgen.** Generates raw unsafe bindings from headers. Excellent for C APIs, poor for
  modern C++. Still the right tool for a C library with no Rust crate.
- **autocxx.** Generates cxx bridges from C++ headers automatically. Less code, but less
  control and harder errors when it can't handle a header. Can be added per bridge later if
  a library needs a large surface.
- **Hand-written `extern "C"`.** Most work, least safety.
