//! Pure-Rust application logic.
//!
//! Most of your code belongs here: it builds and tests fast and knows nothing
//! about C++. The `app` binary wires this crate and the C++ bridges together.

pub mod assets;

/// The meaningful lines of a data file: trimmed, skipping blanks and `#` comments.
pub fn data_lines(text: &str) -> impl Iterator<Item = &str> {
    text.lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn data_lines_skips_blanks_and_comments() {
        let text = "# header\n\n  4 \n#8\n15\n";
        assert_eq!(data_lines(text).collect::<Vec<_>>(), ["4", "15"]);
    }
}
