//! Entry point. Keep it thin: read input, call into app-core and the C++
//! bridges, report errors. Logic belongs in app-core.

use anyhow::Context as _;
use tracing_subscriber::EnvFilter;

fn main() -> anyhow::Result<()> {
    // Logs go to stderr. Filter with RUST_LOG, e.g. `RUST_LOG=debug` or `RUST_LOG=cpp=debug`.
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .with_writer(std::io::stderr)
        .init();

    let name = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "world".to_owned());
    println!("{}", cpp_example::greeting(&name, 1));

    // Rust reads an asset; C++ parses and averages it.
    let path = app_core::assets::path("data/sample-values.txt");
    let text =
        std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    let mut values = cpp_example::Accumulator::new();
    for line in app_core::data_lines(&text) {
        match cpp_example::parse_positive(line) {
            Ok(value) => values.push(f64::from(value)),
            Err(err) => tracing::warn!("skipping line: {err}"),
        }
    }
    match values.mean() {
        Some(mean) => println!(
            "Mean of {} values, computed in C++: {mean:.2}",
            values.count()
        ),
        None => println!("No values in {}", path.display()),
    }
    Ok(())
}
