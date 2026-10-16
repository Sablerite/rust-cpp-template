//! Safe Rust API over a small C++ shim built on {fmt} (from vcpkg).
//!
//! This is the template's worked example of the bridge pattern: cxx
//! declarations in `bridge.rs`, C++ in `cpp/`, and this file as the only API
//! the rest of the workspace sees. Start new bridges with
//! `just new-bridge <name>` instead of editing this one.

#[allow(unsafe_code)] // cxx bridge declarations are the one place unsafe is allowed
mod bridge;

use std::fmt;

use bridge::ffi;

/// Greets `name` using C++ and {fmt}.
#[must_use]
pub fn greeting(name: &str, times: u32) -> String {
    ffi::format_greeting(name, times)
}

/// Parses a positive integer in C++. A C++ exception arrives as `Err`.
pub fn parse_positive(text: &str) -> Result<u32, CppError> {
    Ok(ffi::parse_positive(text)?)
}

/// An exception thrown by the C++ side, carrying its `what()` message.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("{0}")]
pub struct CppError(String);

impl From<cxx::Exception> for CppError {
    fn from(err: cxx::Exception) -> Self {
        Self(err.what().to_owned())
    }
}

/// Running mean, implemented by a C++ class that Rust owns.
pub struct Accumulator {
    inner: cxx::UniquePtr<ffi::Accumulator>,
}

impl Accumulator {
    #[must_use]
    pub fn new() -> Self {
        Self {
            inner: ffi::new_accumulator(),
        }
    }

    pub fn push(&mut self, value: f64) {
        self.inner.pin_mut().add(value);
    }

    #[must_use]
    pub fn count(&self) -> usize {
        self.inner.count()
    }

    /// Mean of all pushed values, or `None` before the first push.
    #[must_use]
    pub fn mean(&self) -> Option<f64> {
        (self.count() > 0).then(|| self.inner.mean())
    }
}

impl Default for Accumulator {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Debug for Accumulator {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Accumulator")
            .field("count", &self.count())
            .field("mean", &self.mean())
            .finish()
    }
}
