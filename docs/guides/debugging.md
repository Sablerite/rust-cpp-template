# Debugging Rust and C++

## In VS Code

- **F5** runs "Debug app (Rust + C++)" (`.vscode/launch.json`). It builds first, then starts
  the Microsoft debugger (`cppvsdbg`), which reads the PDB debug info both compilers emit.
  Breakpoints work in `.rs` and `.cc` files alike, and you can step from Rust into C++.
- **Debugging a test:** click **Debug** above any `#[test]`. rust-analyzer is set to use the
  same debugger (`rust-analyzer.debug.engine`).
- **Breaking on C++ exceptions:** in the Breakpoints panel, enable **C++ Exceptions**. This
  stops at the `throw`, before cxx turns it into an `Err`.
- Arguments for the app go in `"args"` in `launch.json`.

To debug in Visual Studio instead: `devenv target\debug\app.exe`.

## Logs

The app logs with [`tracing`](https://docs.rs/tracing) to stderr. Choose what to see with
`RUST_LOG` (or put it in `.env`):

```powershell
$env:RUST_LOG = "debug"        # everything at debug level
$env:RUST_LOG = "cpp=debug"    # only messages the C++ side sends through log_from_cpp
just run
```

`RUST_BACKTRACE=1` prints a backtrace when Rust panics.

## Limits to know about

- Third-party Rust crates are built with line tables only (`[profile.dev.package."*"]` in
  `Cargo.toml`). You can step through them but not inspect their locals. Set `debug = true`
  there temporarily if you need to.
- vcpkg libraries are release builds (see [ADR 0003](../adr/0003-vcpkg-manifest-mode-release-triplets.md)).
  You can step into your shim, but not usefully into the library's internals.
- A C++ exception thrown from a bridge function not declared `Result`, or a Rust panic inside
  a function C++ called, aborts the process. Run under the debugger to see where.
