# Adding a C++ library

## 1. Do you need a bridge at all?

1. **Search [crates.io](https://crates.io) and [lib.rs](https://lib.rs).** Many popular C and
   C++ libraries already have maintained Rust crates. Use one if it exists.
2. **Is it a C library** (plain C header, no classes)? A crate generated with
   [bindgen](https://rust-lang.github.io/rust-bindgen/) is the conventional route. cxx works
   too, by declaring the C functions in a bridge, which is fine for a handful of functions.
3. **It's C++ and has no Rust crate:** write a bridge, as below.

## 2. Add the library

```powershell
vcpkg search opencv          # find the port name (or browse https://vcpkg.io/en/packages)
just add-cpp opencv4         # adds it to vcpkg.json
just new-bridge opencv       # creates crates/ffi/cpp-opencv
```

In `crates/ffi/cpp-opencv/build.rs`, list the port:

```rust
let includes = build_support::vcpkg(&["opencv4"]);
```

`build_support::vcpkg` links every library the port installs, plus their dependencies.

## 3. Write the three layers

Look at `crates/ffi/cpp-example` for a complete, tested example.

**C++ shim** (`cpp/include/opencv.h`, `cpp/src/opencv.cc`): small functions that call the library
and convert its types into ones cxx understands. Expose what *your app* needs, not the
library's whole API. A single `detect_faces(image) -> Vec<Rect>` beats wrapping `cv::Mat`,
`cv::CascadeClassifier` and friends one by one.

**Bridge declarations** (`src/bridge.rs`): mirror the shim's signatures.

```rust
#[cxx::bridge(namespace = "cpp_opencv")]
pub(crate) mod ffi {
    struct Rect { x: i32, y: i32, width: i32, height: i32 }   // shared: same layout in both languages

    unsafe extern "C++" {
        include!("cpp-opencv/cpp/include/opencv.h");
        fn detect_faces(pixels: &[u8], width: u32, height: u32) -> Result<Vec<Rect>>;
    }
}
```

**Safe API** (`src/lib.rs`): the only thing other crates see. Convert errors into your own
error type, hide `UniquePtr` and other cxx types, and document behavior.

Then use it: add `cpp-opencv.workspace = true` under `[dependencies]` in the crate that
needs it, and write tests in `crates/ffi/cpp-opencv/tests/`.

## Rules at the boundary

- **Anything that can throw is declared `-> Result<T>`.** cxx catches the exception and
  returns `Err`. An exception escaping a non-`Result` function aborts the process.
- **Don't panic in `extern "Rust"` functions** that C++ calls. A panic there aborts.
- **C++ objects stay behind `UniquePtr` or `SharedPtr`.** Mutating methods take `Pin<&mut T>`.
- **Threads:** opaque C++ types are not `Send` or `Sync`. Add
  `unsafe impl Send for ffi::Thing {}` in `bridge.rs` only when the C++ type really is safe
  to move between threads, with a `// SAFETY:` comment saying why.
- **Keep cxx out of your public API.** Callers should never need to depend on `cxx`.
- **Include paths start with the crate name:** `#include "cpp-opencv/cpp/include/opencv.h"`.
  The cxx-generated header for `src/bridge.rs` is `"cpp-opencv/src/bridge.rs.h"`.

## Type cheat sheet

| Rust (in `bridge.rs`) | C++ |
|---|---|
| `String` / `&str` | `rust::String` / `rust::Str` |
| `&[T]` / `&mut [T]` | `rust::Slice<const T>` / `rust::Slice<T>` |
| `Vec<T>` | `rust::Vec<T>` |
| `Box<T>` | `rust::Box<T>` |
| `UniquePtr<T>` / `SharedPtr<T>` | `std::unique_ptr<T>` / `std::shared_ptr<T>` |
| `&CxxString`, `&CxxVector<T>` | `const std::string&`, `const std::vector<T>&` |
| `Result<T>` | `T`, with exceptions becoming `Err` |
| `i32`, `u32`, `i64`, `f32`, `f64`, `usize`, `bool` | `int32_t`, `uint32_t`, `int64_t`, `float`, `double`, `size_t`, `bool` |
| shared `struct` / `enum` | generated struct / enum with the same layout |

Full reference: [cxx.rs/bindings](https://cxx.rs/bindings.html).

## Updating C++ library versions

All ports come from one registry snapshot (the `baseline` in `vcpkg-configuration.json`).
To move to newer versions:

```powershell
git -C $env:VCPKG_ROOT pull
& "$env:VCPKG_ROOT\vcpkg" x-update-baseline
```

Then build. Only packages whose version changed are rebuilt. To pin a single port to a
specific version, use an `overrides` entry in `vcpkg.json`
([docs](https://learn.microsoft.com/vcpkg/users/versioning)).

## C++ that isn't in vcpkg

See [third_party/README.md](../../third_party/README.md).
