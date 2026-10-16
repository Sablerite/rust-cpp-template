//! Shared helper for the `build.rs` of every C++ bridge crate.
//!
//! All Rust <-> C++ build glue lives here, so bridge crates stay tiny:
//!
//! - [`vcpkg`] installs the C++ libraries listed in the workspace `vcpkg.json`
//!   (only when that file changes) and tells Cargo how to link the ones a
//!   bridge asks for, including their transitive dependencies.
//! - [`bridge`] returns a `cxx_build` compiler preset with the workspace's
//!   C++ standard and warning flags.
//!
//! A bridge's `build.rs` is typically:
//!
//! ```no_run
//! let includes = build_support::vcpkg(&["fmt"]);
//! build_support::bridge("src/bridge.rs")
//!     .file("cpp/src/example.cc")
//!     .includes(&includes)
//!     .compile("cpp-example");
//! build_support::rerun_if_changed(&["src/bridge.rs", "cpp"]);
//! ```

use std::env;
use std::fs::{self, File};
use std::path::{Path, PathBuf};
use std::process::Command;

/// C++ language standard for all bridge code.
pub const CPP_STANDARD: &str = "c++20";

/// A `cxx_build` compiler for one bridge file, with workspace C++ settings.
#[must_use]
pub fn bridge(rust_source: impl AsRef<Path>) -> cc::Build {
    let mut build = cxx_build::bridge(rust_source);
    configure(&mut build);
    build
}

/// Like [`bridge`], for a crate that splits its bridge over several files.
#[must_use]
pub fn bridges(rust_sources: impl IntoIterator<Item = impl AsRef<Path>>) -> cc::Build {
    let mut build = cxx_build::bridges(rust_sources);
    configure(&mut build);
    build
}

/// Tell Cargo to rebuild when these paths (relative to the crate) change.
/// Directories are scanned recursively, so pass `"cpp"` for all C++ sources.
pub fn rerun_if_changed(paths: &[&str]) {
    for path in paths {
        println!("cargo:rerun-if-changed={path}");
    }
}

/// Install the workspace's vcpkg dependencies if needed, emit Cargo link
/// directives for each port in `ports`, and return the include directories
/// to compile against.
///
/// Port names are the ones listed in `vcpkg.json` (e.g. `"fmt"`).
#[must_use]
pub fn vcpkg(ports: &[&str]) -> Vec<PathBuf> {
    let workspace = workspace_root();
    let triplet = triplet();
    // One tree per triplet: in manifest mode `vcpkg install` removes every
    // other triplet's packages from its install root.
    let vcpkg_root = workspace.join("target").join("vcpkg").join(&triplet);
    ensure_installed(&workspace, &vcpkg_root, &triplet);

    // The vcpkg crate picks its triplet from this variable only.
    // SAFETY: build scripts run `main` on a single thread, and nothing has
    // spawned threads yet, so no other code can be reading the environment.
    #[allow(unsafe_code)]
    unsafe {
        env::set_var("VCPKGRS_TRIPLET", &triplet);
    }

    let mut includes = Vec::new();
    for port in ports {
        let library = vcpkg::Config::new()
            .vcpkg_root(vcpkg_root.clone())
            .find_package(port)
            .unwrap_or_else(|err| {
                panic!("vcpkg port `{port}` not found for {triplet}: {err}. Is it listed in vcpkg.json?")
            });
        includes.extend(library.include_paths);
    }
    includes.sort();
    includes.dedup();
    includes
}

/// The vcpkg triplet for the current Cargo target.
///
/// Release-only triplets are used where vcpkg has them: Rust always links the
/// release C runtime, so debug builds of C++ libraries would never be used.
/// Set `VCPKGRS_TRIPLET` to override.
#[must_use]
pub fn triplet() -> String {
    if let Ok(triplet) = env::var("VCPKGRS_TRIPLET") {
        return triplet;
    }
    let var = |name: &str| env::var(name).unwrap_or_default();
    let (arch, os, target_env) = (
        var("CARGO_CFG_TARGET_ARCH"),
        var("CARGO_CFG_TARGET_OS"),
        var("CARGO_CFG_TARGET_ENV"),
    );
    assert!(
        os != "windows" || target_env == "msvc",
        "C++ bridges need the MSVC toolchain on Windows (target env is `{target_env}`)"
    );
    let crt_static = var("CARGO_CFG_TARGET_FEATURE")
        .split(',')
        .any(|feature| feature == "crt-static");

    let triplet = match (arch.as_str(), os.as_str(), crt_static) {
        ("x86_64", "windows", false) => "x64-windows-static-md-release",
        ("x86_64", "windows", true) => "x64-windows-static-release",
        ("aarch64", "windows", false) => "arm64-windows-static-md",
        ("aarch64", "windows", true) => "arm64-windows-static-release",
        ("x86_64", "linux", _) => "x64-linux-release",
        ("aarch64", "linux", _) => "arm64-linux",
        ("x86_64", "macos", _) => "x64-osx-release",
        ("aarch64", "macos", _) => "arm64-osx-release",
        _ => panic!("no default vcpkg triplet for {arch}-{os}; set VCPKGRS_TRIPLET"),
    };
    triplet.to_owned()
}

fn configure(build: &mut cc::Build) {
    build.std(CPP_STANDARD).warnings(true).extra_warnings(true);
    if build.get_compiler().is_like_msvc() {
        for flag in [
            "/EHsc",                   // C++ exceptions on; cxx turns them into Rust `Result`s
            "/permissive-",            // standards-conforming mode
            "/utf-8",                  // UTF-8 source and execution charset
            "/Zc:__cplusplus",         // report the real C++ version in __cplusplus
            "/external:anglebrackets", // treat <...> includes (vcpkg libs) as external...
            "/external:W0",            // ...and don't warn about them
        ] {
            build.flag(flag);
        }
    }
}

fn workspace_root() -> PathBuf {
    // Set by .cargo/config.toml.
    if let Some(root) = env::var_os("WORKSPACE_ROOT") {
        return root.into();
    }
    let manifest_dir = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").expect("set by Cargo"));
    manifest_dir
        .ancestors()
        .find(|dir| dir.join("vcpkg.json").is_file())
        .map(Path::to_path_buf)
        .expect("no vcpkg.json above this crate, and WORKSPACE_ROOT is not set")
}

fn ensure_installed(workspace: &Path, vcpkg_root: &Path, triplet: &str) {
    let manifest = workspace.join("vcpkg.json");
    let configuration = workspace.join("vcpkg-configuration.json");
    println!("cargo:rerun-if-changed={}", manifest.display());
    println!("cargo:rerun-if-changed={}", configuration.display());
    for var in ["VCPKG_ROOT", "VCPKG_INSTALLATION_ROOT", "VCPKGRS_TRIPLET"] {
        println!("cargo:rerun-if-env-changed={var}");
    }

    fs::create_dir_all(vcpkg_root).expect("create target/vcpkg/<triplet>");
    // The vcpkg crate only accepts a tree that contains this marker file.
    let marker = vcpkg_root.join(".vcpkg-root");
    if !marker.exists() {
        File::create(&marker).expect("create .vcpkg-root marker");
    }

    // Several bridge build scripts (and rust-analyzer) can run at once:
    // one install at a time. The lock is released when `lock` is dropped.
    let lock = File::create(vcpkg_root.join(".install.lock")).expect("create install lock");
    lock.lock().expect("lock target/vcpkg/<triplet>");

    let stamp_file = vcpkg_root.join("manifest.stamp");
    let stamp = format!(
        "{triplet}\n{}\n{}",
        fs::read_to_string(&manifest).expect("read vcpkg.json"),
        fs::read_to_string(&configuration).unwrap_or_default(),
    );
    let installed = vcpkg_root.join("installed").join(triplet).is_dir();
    if installed && fs::read_to_string(&stamp_file).is_ok_and(|old| old == stamp) {
        return;
    }

    let exe = vcpkg_exe();
    let output = Command::new(&exe)
        .arg("install")
        .arg(format!("--triplet={triplet}"))
        .arg(format!("--x-manifest-root={}", workspace.display()))
        .arg(format!(
            "--x-install-root={}",
            vcpkg_root.join("installed").display()
        ))
        .env("VCPKG_DISABLE_METRICS", "1")
        .output()
        .unwrap_or_else(|err| {
            panic!(
                "could not run `{}`: {err}. Install vcpkg and set VCPKG_ROOT \
                 (see docs/guides/toolchain-setup.md)",
                exe.display()
            )
        });
    assert!(
        output.status.success(),
        "vcpkg install failed ({}).\n--- stdout ---\n{}\n--- stderr ---\n{}",
        output.status,
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr),
    );
    fs::write(&stamp_file, stamp).expect("write vcpkg stamp");
}

fn vcpkg_exe() -> PathBuf {
    let exe = if cfg!(windows) { "vcpkg.exe" } else { "vcpkg" };
    // VCPKG_INSTALLATION_ROOT is preset on GitHub Actions runners.
    ["VCPKG_ROOT", "VCPKG_INSTALLATION_ROOT"]
        .into_iter()
        .filter_map(env::var_os)
        .map(|root| PathBuf::from(root).join(exe))
        .find(|path| path.is_file())
        // Otherwise rely on PATH.
        .unwrap_or_else(|| PathBuf::from(exe))
}
