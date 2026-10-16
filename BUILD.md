# Building Sekiro danger alert

This is a Bingus Lua addon. HD2Runtime is not required in the game. The repository includes the approved 50 animation masks and PCM sound, so a normal build needs neither the original video nor a font or After Effects project.

Use Python 3 with Pillow and NumPy. Set `HD2_LUA51_DLL` to the `bin/lua51.dll` from your installed Helldivers 2. The builder compiles the assembled entry with that exact LuaJIT before writing the ZIP; it does not start or modify the game.

```powershell
$env:HD2_LUA51_DLL = 'F:/SteamLibrary/steamapps/common/Helldivers 2/bin/lua51.dll'
python scripts/build.py
python scripts/test.py --mom-source work/ModOptionsMenu
python scripts/verify_package.py
```

Replace the paths with your installed game and local Mod Options Menu source checkout. Each offline check runs in a separate process. The audio check plays a digital-silence buffer through the system sound API to verify cleanup. Archive verification decodes all 50 packaged BC1 images and compares them with the approved masks. Neither these checks nor compilation establish live-game frame cost or appearance.

The ZIP is written to ignored `outputs/`; intermediate source and records go to ignored `build/`. `--output-dir <directory>` changes the package destination. The standard release includes only its production modules, two user guides, credits and license texts. Version 1.x refuses the alternate development package variant.

The actual Mod Options Menu v1.2 / API 3 contract is checked with all 29 controls on one category, all 15 native language codes, saved values, previews and defaults. Translation packs live in `locales/`. The builder requires the same complete key set for all 14 packs and enforces the menu's text limits.

`src/profile.lua` and `src/catalog.lua` are generated. Edit `scripts/build.py` or the relevant `config/` inputs instead of those generated files. Keep the explicit attack exclusions, resource identities, build gates and bounded read budgets. `src/entry.lua` is the production entry; optional developer modules are never attached there.

The GUID, `mods/peril_warning/crusher_probe` entry, `SekiroDangerAlert` global and `peril_warning.crusher.` saved identifiers must remain stable. The user-facing name is Sekiro danger alert.

For a reproducible comparison of the factory descriptor reader against the pinned 0.8.2 source:

```powershell
python scripts/benchmark_release.py --json
```

This uses owned synthetic buffers with the installed Lua DLL and the vendored Windows reader. It never opens a game process. Results are written to `outputs/` and exclude full attack processing, graphics and live-game contention. See [the 1.0.0 validation record](docs/VALIDATION-1.0.0.md) for the scope and remaining live-game checks.

The game assets in `assets/frames/` are RGB masks for the native icon material, not ordinary straight-alpha PNGs. Their yellow-green appearance is expected. The approved procedural effect is documented in [Animation R2](docs/ANIMATION-PREVIEW-R2.md); normal packaging does not regenerate it.

Do not commit `outputs/`, `build/`, local tools, third-party checkouts or game binaries. Complete relevant checks, commit and push normally. The owner publishes GitHub Releases manually; the builder neither deploys nor uploads the package.

Uses code / research from HD2Runtime by SkyeShade: https://github.com/SkyeShade/HD2Runtime. See `CREDITS.txt` and `vendor/` license files.
