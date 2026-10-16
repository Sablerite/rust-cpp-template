# assets

Files the program reads at runtime. Create subfolders by kind as you need them:

| Folder | For |
|---|---|
| `data/` | Text, JSON, CSV, config defaults the app ships with |
| `images/` | Textures, icons, sprites |
| `fonts/` | Font files |
| `audio/` | Sound effects, music |
| `shaders/` | Shader sources |

## Loading

```rust
let path = app_core::assets::path("data/sample-values.txt");
```

This works both from a checkout (`cargo run`) and from a packaged build (`just dist` copies
this folder next to the executable). Set `APP_ASSETS_DIR` to point somewhere else. See
`crates/app-core/src/assets.rs`.

## Conventions

- Lowercase, hyphenated file names: `main-menu.png`, not `Main Menu.PNG`.
- Third-party assets: record source and license in `assets/LICENSES.md`.
- Large binaries (over a few MB): track them with [Git LFS](https://git-lfs.com), e.g.
  `git lfs track "assets/audio/**"`.
- Files the code generates at runtime (saves, caches, logs) don't belong here. Write them to
  the user's data directory instead.
