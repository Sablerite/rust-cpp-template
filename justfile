# Task runner. `just` lists recipes; `just <recipe>` runs one.
# Every recipe is a thin wrapper, so you can always run the commands directly.

set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
set shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]
# Recipes see variables from .env (copy .env.example to start).
set dotenv-load := true

# Name of the executable (scripts/new-project.ps1 rewrites this).
bin := "app"

# List recipes
default:
    @just --list --unsorted

# Check that every required tool is installed and configured
doctor:
    ./scripts/doctor.ps1

# Build everything (the first build also installs C++ deps via vcpkg)
build:
    cargo build --workspace

# Run the app, e.g. `just run Sam`
run *args:
    cargo run -p app -- {{args}}

# Run all tests, then doc tests (nextest doesn't run those)
test:
    cargo nextest run --workspace
    cargo test --workspace --doc

# Format Rust and C++ sources
fmt:
    cargo fmt --all
    ./scripts/cpp.ps1 format

# Everything CI checks: formatting, clippy (warnings are errors), C++ format
lint:
    cargo fmt --all --check
    cargo clippy --workspace --all-targets -- -D warnings
    ./scripts/cpp.ps1 check-format

# C++ static analysis with clang-tidy
tidy: compdb
    ./scripts/cpp.ps1 tidy

# Write compile_commands.json (for clangd and clang-tidy; VS Code's C++ extension doesn't need it)
compdb: build
    ./scripts/cpp.ps1 compdb

# Licenses, security advisories and dependency sources
deny:
    cargo deny check

# Build and open the API docs
doc:
    cargo doc --workspace --no-deps --open

# Add a C++ library from vcpkg to vcpkg.json, e.g. `just add-cpp zlib`
add-cpp port:
    & (Join-Path $env:VCPKG_ROOT 'vcpkg') add port {{port}}

# Scaffold a new C++ bridge crate in crates/ffi, e.g. `just new-bridge opencv`
new-bridge name:
    ./scripts/new-bridge.ps1 -Name {{name}}

# Start a new project from this template, e.g. `just new-project my-game` (created next to this folder)
new-project name:
    ./scripts/new-project.ps1 -Name {{name}}

# Optimized build plus assets in dist/, ready to zip and ship
dist:
    cargo build -p app --profile dist
    ./scripts/dist.ps1 -Bin {{bin}}

# Like dist, but also links the C runtime statically: no VC++ redistributable needed.
# Uses its own target dir so the changed RUSTFLAGS don't invalidate normal builds.
dist-static:
    $env:RUSTFLAGS = '-C target-feature=+crt-static'; cargo build -p app --profile dist --target-dir target/static
    ./scripts/dist.ps1 -Bin {{bin}} -TargetDir target/static

# Delete build output, including vcpkg packages (rebuilt from vcpkg's cache)
clean:
    cargo clean
