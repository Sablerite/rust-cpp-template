# Documentation

Docs for people working on this project. API docs come from `///` comments in the code;
build them with `just doc`.

| Document | Read it when |
|---|---|
| [architecture.md](architecture.md) | You want to know how the build and the Rust/C++ boundary work |
| [where-things-go.md](where-things-go.md) | You have a file and don't know where to put it |
| [guides/adding-a-cpp-library.md](guides/adding-a-cpp-library.md) | You need a C++ library |
| [guides/debugging.md](guides/debugging.md) | Something misbehaves at runtime |
| [guides/toolchain-setup.md](guides/toolchain-setup.md) | Setting up a machine, or the build fails before compiling your code |
| [adr/](adr/README.md) | You wonder why something is done this way, or want to change it |

Add new guides under `guides/`. Record decisions that are hard to reverse as ADRs in `adr/`.
