# 1.0.0 maintainer validation

This document describes offline evidence, not a live-game performance or rendering certification. It is not included in the addon ZIP.

## Baseline and compatibility

- Baseline: standard 0.8.2 at `9a157976fb29d3be312a053395ba86579b752e16`.
- GUID: `1dc82965-3c84-4eec-bb72-88e8121ac0dc`.
- Entry: `mods/peril_warning/crusher_probe`; global: `SekiroDangerAlert`.
- All 29 option IDs and their order remain stable. The two Harvester delays now range from 0 to 0.5 seconds in 0.01-second steps, defaulting to 0.30 seconds. Old saved values are clamped and snapped by MOM; unset and restored values use the new default. Other ranges and defaults are unchanged. Twenty attack switches remain enabled by default.
- Attack resource mappings, wind-up windows, target checks, exclusions and batch limits remain unchanged. Delay scheduling retains its existing cancellation rules and 20 Hz sampling cadence. The approved R2 assets are unchanged.
- Factory Strider cancellation and guest Dragonroach target ambiguity remain known limitations. The later diagnostic investigation is not incorporated into attack behavior.
- Supported Steam build remains `25480438`; no additional native calls or memory writes are introduced.

## Language coverage

The native schema has 15 entries: `us`, `gb`, `bp`, `de`, `es`, `fr`, `it`, `jp`, `ko`, `ms`, `pl`, `pt`, `ru`, `cn`, `tc`. These map to 14 complete locale packs because both English entries use English.

Each pack contains 48 translated strings. Labels, descriptions and custom choice strings are function-valued texts refreshed by the real Mod Options Menu v1.2 / API 3 implementation. The mod consumes its existing `BingusTranslations` plain-data registry and adds no language-memory reader or periodic language poll. The raw native code takes precedence over Steam language, including `bp`, `ms` and `tc`, for which the current upstream translation helper lacks aliases.

The real MOM contract checks exercise every native language code, all translated texts, saved-value preservation, the 29-row category, preview actions and reset behavior. Both delay sliders use two decimal places, preserve hundredth-second values, clamp an old 0.7-second value to 0.5 seconds and restore to 0.30 seconds. The detector also retains this precision when arming a delay. Size limits and complete key coverage are build gates. Actual in-game font coverage and layout for every language have not been visually verified.

## Production boundary

The release entry has no instrumentation attachment, collection lifecycle or hotkey reader. Its detector does not allocate per-sample decision reports, retain observation snapshots or emit periodic observation statistics. Normal audio playback and muting do not write log entries. Startup, state transitions and failures remain logged.

The assembled Lua excludes developer modules and removes source comments while preserving quoted strings, long strings, escaped PCM and line boundaries. The actual decoded package is checked for forbidden development functions and terms. The public guides and manifest carry no collection instructions or development controls. Source-only maintenance tools and regression fixtures remain outside the package.

The ZIP has exactly nine members:

```
manifest.json
Addon/9ba626afa44a3aa3.patch_0
Addon/9ba626afa44a3aa3.patch_0.stream
Addon/9ba626afa44a3aa3.patch_0.gpu_resources
README.txt
README-使用说明.txt
CREDITS.txt
LICENSES/Bingus-0BSD.txt
LICENSES/HD2Runtime-MIT.txt
```

Both license files are byte-identical to their vendored originals. The guides disclose the directly written log, MOM shared values file and its `.bak` / `.tmp` companions, dependency logs and the loader-defined directory override.

## Performance evidence

Factory discovery still examines the same bounded descriptor table, preserves its cursor, handles at most eight matches per batch, validates identities and excludes invalid or destroyed entries. A first-byte guard avoids most eight-byte substring allocations; scanned-row accounting is computed once per batch. The attack cadence remains at most 20 Hz.

`scripts/benchmark_release.py` compares the pinned 0.8.2 reader and current reader using the installed game's Lua DLL in a separate Python process. ReadProcessMemory and QueryPerformanceCounter operate on owned synthetic buffers; the benchmark never opens a game process. Each result is the median of seven trials after warm-up.

| Matching actors | 0.8.2 discovery ms/poll | 1.0.0 discovery ms/poll | CPU reduction |
| ---: | ---: | ---: | ---: |
| 0 | 0.016447 | 0.009180 | 44.2% |
| 1 | 0.018254 | 0.011103 | 39.2% |
| 8 | 0.028009 | 0.021113 | 24.6% |
| 25 | 0.020002 | 0.017152 | 14.2% |

Read counts and byte budgets are unchanged. The 25-actor case also verifies cursor fairness; it does not imply only eight actors can ever be observed. At 20 Hz this measured discovery component consumes approximately 0.18–0.42 ms CPU per second. These numbers exclude complete AI/ability processing, live scene contention, graphics, GPU and driver costs. They are not FPS measurements or estimates of the whole mod's frame cost.

Head tracking caches only a validated node index. Every use still validates the unit, node count, name-array pointer and cached name hash, and reads the current animated world pose. Changed names invalidate the cache. Offline fixtures verify current-pose movement, cache reuse and invalidation. Projection still runs only during visible animation. The 50 textures contain 8,739,200 bytes of GPU resource payload; embedded PCM is 962,560 bytes. Neither number measures total runtime memory.

## Checks and resulting artifact

Commands completed successfully with `HD2_LUA51_DLL` pointing to the installed `bin/lua51.dll`:

```
python scripts/build.py
python scripts/test.py --mom-source work/ModOptionsMenu
python scripts/verify_package.py
python scripts/benchmark_release.py --json
```

The installed LuaJIT accepts all 129 prototypes; the largest contains 1,642 bytecodes. The full suite covers the actual MOM API, production entry, native bounds and identity invalidation, host/client target paths, all attack controls and existing anonymous replay fixtures. All 7,241 expanded replay samples use the production detector's reduced-report path and retain the expected alert results. Synthetic client checks cover all 41 resource/ability combinations.

The finished archive has 101 resources: one Lua entry, 50 textures and 50 materials. Every packaged BC1 frame is decoded and compared with the approved masks. The last frame is fully transparent; duration remains 50 frames at 59.94 Hz (approximately 0.83417 seconds).

- Package: `Sekiro danger alert 1.0.0.zip`.
- Size: 2,160,707 bytes.
- Build ID: `7ae478c22b67`.
- SHA-256: `91ab1b283697f5a7c57230f389050c0df7d71fb5c9f78df89b86e1b10f03408c`.

No new live-game validation or complete-frame profiling was performed for this release pass. The owner's earlier 0.8.2 gameplay confirmation does not prove every locale's appearance or the exact runtime overhead of 1.0.0. Outputs and raw logs remain ignored; the owner publishes the Release manually.
