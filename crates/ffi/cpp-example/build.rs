fn main() {
    // C++ libraries this bridge links, by vcpkg port name (see vcpkg.json).
    let includes = build_support::vcpkg(&["fmt"]);

    build_support::bridge("src/bridge.rs")
        .file("cpp/src/example.cc")
        .includes(&includes)
        .compile("cpp-example");

    build_support::rerun_if_changed(&["src/bridge.rs", "cpp"]);
}
