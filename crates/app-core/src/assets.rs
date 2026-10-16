//! Locating files under `assets/`.
//!
//! Lookup order:
//! 1. The `APP_ASSETS_DIR` environment variable, if set.
//! 2. `assets/` next to the executable (the layout `just dist` produces).
//! 3. The workspace `assets/` folder (running from a checkout via `cargo run`).

use std::env;
use std::path::{Path, PathBuf};

/// Environment variable that overrides the assets directory.
pub const ENV_VAR: &str = "APP_ASSETS_DIR";

/// The assets directory, resolved as described in the module docs.
#[must_use]
pub fn dir() -> PathBuf {
    if let Some(dir) = env::var_os(ENV_VAR) {
        return PathBuf::from(dir);
    }
    let beside_exe = env::current_exe()
        .ok()
        .and_then(|exe| exe.parent().map(|dir| dir.join("assets")));
    if let Some(dir) = beside_exe.filter(|dir| dir.is_dir()) {
        return dir;
    }
    // crates/app-core -> workspace root
    let workspace = Path::new(env!("CARGO_MANIFEST_DIR")).ancestors().nth(2);
    workspace
        .expect("crate lives two levels below the workspace")
        .join("assets")
}

/// Path of one asset, e.g. `assets::path("data/sample-values.txt")`.
#[must_use]
pub fn path(relative: impl AsRef<Path>) -> PathBuf {
    dir().join(relative)
}

#[cfg(test)]
mod tests {
    #[test]
    fn finds_workspace_assets_in_a_checkout() {
        assert!(super::path("data/sample-values.txt").is_file());
    }
}
