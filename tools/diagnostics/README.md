# Development-only collection sources

For the 2026-10-19 expansion, use `python scripts/build.py --diagnostics --next-attacks`.
This explicitly creates `1.1.0-dev.1 Diagnostics` with 13 new collection scopes;
the root project version and ordinary ZIP remain 1.0.0. New scopes are marked
`pending_capture`, not enabled as warning rules. See [新增招式采集说明](README-新增招式采集.txt)
and [the source evidence / pending integration record](../../docs/EXPANSION-1.1-PREPARATION.md).
The unchanged `--diagnostics` command still refuses stable release versions.

These modules are retained for offline regression and optional collection. The ordinary 0.8.2 ZIP does **not** contain them. `python scripts/build.py --diagnostics` produces an alternative ZIP with the **same addon GUID and entry**, a separate six-row capture page and F8 only while recording. Enable either variant, never both. See [采集说明](README-采集说明.txt).

- `src/capture.lua`: bounded JSONL capture and delayed F8 annotation logic from the research builds.
- `src/tracking.lua`: distance-prioritized diagnostic candidate selection; this is not the production attack scan.
- `src/marker.lua`: the research-only F8 reader.
- `src/native.lua`: optional read-only animation / targeting / weapon-input observations. Offline tests explicitly pass this module as the third argument to the production reader's `new(memory, profile, extension)`. Without that argument none of these methods is installed.
- `src/instrument.lua`: optional entry lifecycle and real MOM capture controls; constructor, registration and startup do not read F8 or collect game data. Saved actions never start on load. Reset cancels pending collection even before native initialization.

The normal builder declares a nil instrumentation hook and includes only production modules. The explicit diagnostic variant installs the extension after the same build gate and 20-second startup delay. It records real detector snapshots plus independent bounded observations; optional collection failure does not stop the warning guard. The capture page now reports successful sample/marker counts and stop reasons; optional aim failure preserves other observations. The shared Aiming header uses total +0x140 and owned-prefix +0x144. Original logs, game binaries and third-party checkouts remain outside Git.

Prior capture instructions and evidence are in `docs/ENEMY-EXPANSION-0.5.0.md` and `docs/VALIDATION-0.6.0.md`; both describe historical research builds.

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime
