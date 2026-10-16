//! The Rust <-> C++ boundary. cxx checks both sides of these declarations at
//! build time. Keep this file small; `lib.rs` wraps it in a safe Rust API.

#[cxx::bridge(namespace = "cpp_example")]
pub(crate) mod ffi {
    // Rust functions that C++ may call.
    extern "Rust" {
        fn log_from_cpp(message: &str);
    }

    // C++ functions and types that Rust may call. Must match
    // cpp/include/example.h.
    unsafe extern "C++" {
        include!("cpp-example/cpp/include/example.h");

        /// Formats a greeting with {fmt}.
        fn format_greeting(name: &str, times: u32) -> String;

        /// Throws `std::invalid_argument` unless `text` is a positive integer.
        /// The `Result` return type makes cxx catch it and return `Err`.
        fn parse_positive(text: &str) -> Result<u32>;

        /// Opaque C++ class; Rust only ever holds it behind a `UniquePtr`.
        type Accumulator;
        fn new_accumulator() -> UniquePtr<Accumulator>;
        fn add(self: Pin<&mut Accumulator>, value: f64);
        fn count(self: &Accumulator) -> usize;
        fn mean(self: &Accumulator) -> f64;
    }
}

fn log_from_cpp(message: &str) {
    tracing::debug!(target: "cpp", "{message}");
}
