//! Exercises every kind of crossing the bridge supports.

use cpp_example::{Accumulator, greeting, parse_positive};

#[test]
fn rust_calls_cpp_and_cpp_calls_back_into_rust() {
    let text = greeting("Ada", 2);
    assert!(text.starts_with("Hello, Ada!"), "{text}");
    assert!(text.contains("2 times"), "{text}");
}

#[test]
fn cpp_result_arrives_as_ok() {
    assert_eq!(parse_positive("42"), Ok(42));
}

#[test]
fn cpp_exception_arrives_as_err() {
    let err = parse_positive("oops").unwrap_err();
    assert!(err.to_string().contains("'oops'"), "{err}");
    assert!(parse_positive("0").is_err());
    assert!(parse_positive("").is_err());
    assert!(parse_positive("12abc").is_err());
}

#[test]
fn rust_owns_a_cpp_object() {
    let mut acc = Accumulator::new();
    assert_eq!(acc.mean(), None);
    for value in [1.0, 2.0, 6.0] {
        acc.push(value);
    }
    assert_eq!(acc.count(), 3);
    assert!((acc.mean().unwrap() - 3.0).abs() < f64::EPSILON);
}
