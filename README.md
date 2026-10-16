# rust-cpp-template

A base for Rust projects that reach into C++ libraries when Rust has no equivalent.
Cargo builds everything, [vcpkg](https://vcpkg.io) supplies the C++ libraries, and
[cxx](https://cxx.rs) generates a type-checked bridge in both directions. C++ libraries are
linked in statically, so the result is a single `.exe` with no third-party DLLs.

## Quick start

```powershell
just doctor     # check the toolchain (fix anything missing: docs/guides/toolchain-setup.md)
just run        # build and run the demo; the first build also compiles C++ deps
just test
```

The demo greets you from C++ (using the {fmt} library), reads `assets/data/sample-values.txt`
in Rust, parses each line in C++ (a bad line becomes a Rust `Err`), and averages the values
in a C++ object that Rust owns.

**Start a real project:** `just new-project my-game` creates `../my-game` with the executable
renamed and a fresh git repository.

## Daily commands

| Command | What it does |
|---|---|
| `just run [args]` | Build and run the app |
| `just test` | All tests (nextest) plus doc tests |
| `just fmt` | Format Rust and C++ |
| `just lint` | What CI checks: rustfmt, clippy (warnings are errors), clang-format |
| `just tidy` | C++ static analysis (clang-tidy) |
| `just deny` | Licenses, security advisories, dependency sources |
| `just doc` | Build and open API docs |
| `just add-cpp <port>` | Add a C++ library from vcpkg to `vcpkg.json` |
| `just new-bridge <name>` | Scaffold a bridge crate for a C++ library |
| `just dist` | Optimized build plus assets in `dist/` |
| `just dist-static` | Same, with the C runtime linked in too (runs on PCs without the VC++ runtime) |
| `just` | List every recipe |

## Layout

```
Cargo.toml              workspace: members, shared dependency versions, lints, build profiles
vcpkg.json              C++ libraries the project uses
vcpkg-configuration.json  pins exact C++ library versions (registry baseline)
justfile                task runner recipes
crates/
  app/                  the executable; thin wiring only
  app-core/             pure-Rust logic; most of your code goes here
  ffi/
    build-support/      shared build.rs helper: vcpkg install/lookup, C++ compiler flags
    cpp-example/        example bridge: src/bridge.rs (boundary), cpp/ (C++), src/lib.rs (safe API)
assets/                 runtime files (images, fonts, audio, data), shipped next to the exe
docs/                   architecture, guides, decision records
scripts/                PowerShell helpers behind the just recipes
third_party/            vendored C/C++ source that isn't in vcpkg (rare)
.vscode/                IntelliSense for both languages, mixed Rust/C++ debugging
.github/workflows/      CI
```

The full "where does X go?" table is in [docs/where-things-go.md](docs/where-things-go.md).

## Using a C++ library

1. Check [crates.io](https://crates.io) first. A maintained Rust crate beats a bridge you write.
2. `just add-cpp <port>` (find port names with `vcpkg search <name>` or on [vcpkg.io](https://vcpkg.io/en/packages)).
3. `just new-bridge <name>`, then wrap only the calls you need.

Step-by-step: [docs/guides/adding-a-cpp-library.md](docs/guides/adding-a-cpp-library.md).

## Documentation

- [Architecture](docs/architecture.md): how the build and the Rust/C++ boundary work
- [Where things go](docs/where-things-go.md)
- [Adding a C++ library](docs/guides/adding-a-cpp-library.md)
- [Debugging Rust and C++](docs/guides/debugging.md)
- [Toolchain setup and troubleshooting](docs/guides/toolchain-setup.md)
- [Decision records](docs/adr/README.md): why things are the way they are
