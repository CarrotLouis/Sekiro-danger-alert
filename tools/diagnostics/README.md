# Development-only collection sources

These modules are retained for offline regression and future investigation. They are **not included in the 1.0.0 release** and do not register a menu, hotkey or native hook on their own.

- `src/capture.lua`: bounded JSONL capture and delayed F8 annotation logic from the research builds.
- `src/tracking.lua`: distance-prioritized diagnostic candidate selection; this is not the production attack scan.
- `src/marker.lua`: the research-only F8 reader.
- `src/native.lua`: optional read-only animation / targeting / weapon-input observations. Offline tests explicitly pass this module as the third argument to the production reader's `new(memory, profile, extension)`. Without that argument none of these methods is installed.

The main package builder includes only the production modules listed in `scripts/build.py`. Do not re-enable diagnostics in the release entry. Original logs, game binaries and third-party checkouts remain outside Git.

Prior capture instructions and evidence are in `docs/ENEMY-EXPANSION-0.5.0.md` and `docs/VALIDATION-0.6.0.md`; both describe historical research builds.

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime
