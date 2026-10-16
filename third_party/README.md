# third_party

Vendored C/C++ source code for libraries that **aren't available through vcpkg**. Most
projects never need this folder.

## Before vendoring

1. Search [vcpkg.io](https://vcpkg.io/en/packages). Ports often go by a different name.
2. If the library has a CMake build, a vcpkg **overlay port** keeps it in the vcpkg flow:
   cached, pinned, and linked like any other port. See the
   [overlay ports docs](https://learn.microsoft.com/vcpkg/concepts/overlay-ports).

## If you do vendor

- One folder per library, `third_party/<name>/`, with its `LICENSE` file and a `VERSION` note
  (upstream URL and commit or tag).
- Don't modify the code in place. Keep patches as separate `.patch` files next to it.
- Compile it from the bridge crate that uses it:
  - **A few source files:** add them to the bridge's `build.rs`:
    ```rust
    build_support::bridge("src/bridge.rs")
        .file("cpp/src/shim.cc")
        .file("../../../third_party/tinylib/tinylib.cpp")
        .include("../../../third_party/tinylib/include")
        .compile("cpp-tinylib");
    ```
  - **A CMake project:** build it with the [`cmake`](https://docs.rs/cmake) crate in `build.rs`
    and emit `cargo:rustc-link-lib` for its outputs.
- `.vscode/c_cpp_properties.json` already includes `third_party/` for IntelliSense.
