# MDL3 compatibility investigation

English / [简体中文](https://github.com/CarrotLouis/Sekiro-danger-alert/blob/main/docs/MDL3-COMPATIBILITY_cn.md)

Initial review on 2026-11-01. Bundle rechecks on 2026-11-03 (dev.33) and 2026-11-06 (dev.43). Sekiro danger alert 1.0.0 targets Steam build 25480438.

## Result

MDL3 dev.43 supplies public screen drawing and audio APIs. **HD2 Data Hub 0.6.0 still lacks the data that the attack detector needs**, including enemy ability and attack progress, authoritative or replicated attack targets, and updates when the attack changes or cancels. Following the player's head also requires a supported head position and projection path.

The supported route is to have Data Hub expose these observations, or obtain an explicitly authorized read-only native module from the MDL3 author. This report does not modify the loader, its authorization mechanism, the anti-cheat, or game memory. No replacement warning package has been produced.

## dev.43 and Data Hub 0.6.0 recheck (2026-11-06)

The supplied `MDL3-3.0.0-dev.43-preview-Data-Hub-0.6.0.zip` has SHA-256 `f2bfe300b166471344ade74c06482cc6d5ae88eef7a216dedd8cbf44c9c03f0c`. The ZIP CRC check passes and the actual DLL and loader patch hashes match `BUILD.json`. The new Hub Lua body has SHA-256 `d8d074a1f1e1076800f1827180a96190f4deb08ebea3e2a4adb6e5d0d0b1f970`. The native bridge DLL is byte-identical to dev.33 (native host 0.4.5), and the Hub still starts through a signed manifest and a trusted owner.

Hub 0.6.0 adds `enemy_pool`, `buffs`, `lobby`, `lobby_search` and `backpacks` to the public API from 0.3.0. It exposes 23 functions and the same 16 event names. The field reference, public table and native dispatcher agree on the scope of the new data.

| Interface | What the supplied implementation provides |
|---|---|
| `HD2Data.enemy_pool()` | Predicted entity types that a mission may load. It has no live enemy instances or attack states. |
| `entity_damaged`, `entity_died` | Additional attacker or killer entity identity. The damage event reads this from the latest damage attribution after observing a health decrease. It cannot supply a warning before that hit. |
| `HD2Data.lobby()` | `host_is_local` and member roles when lobby data is available. The public API exposes no enemy attack targets or their replicas on host or client. |
| `HD2Data.strikes()` and `aim()` | The same strike reader and local aiming reader as 0.3.0. They cover specific strike mechanisms and the local player's aim, respectively. |

The bundled GUI guide documents `MDL3.gui` API 1. A canvas can draw packaged image frames at screen coordinates, which gives the animation a supported rendering path. The API has no world-to-screen projection, and `HD2Data.player().position` describes the avatar's root. The head anchor still needs a verified position and projection source. The GUI guide also says moving an image rebuilds the canvas, so in-game frame cost matters for a tracked animation.

The bundled audio guide documents `MDL3.audio` API 2. Our 48 kHz stereo PCM16 cue fits the documented format, and the namespace volume API can implement the independent slider. The approved art and sound are reusable source assets. Image deployment, visual fidelity and playback still need an in-game check. [Author's dev.43 release notes](https://ayakamods.com/mods/mdl3-preview-%E9%BA%A6%E5%BD%93%E5%8A%B33-%E9%A2%84%E8%A7%88%E7%89%88%EF%BC%81.5710/update/8864/)

The migration prerequisite remains a supported source of pre-hit enemy attack and target observations on host and client. This recheck covers the supplied archive, Hub implementation, and GUI and audio documentation offline. Warning timing, head tracking and multiplayer behavior remain unverified in the current game.

## dev.33 recheck (2026-11-03)

The supplied `MDL3-3.0.0-dev.33-preview-Data-Hub-0.3.0.zip` has SHA-256 `da60ebd6f96e890516c156992703cf8c7afc826d5ac234f56ce09ab173e5dda4`. Its ZIP CRC check passes, and its declared native DLL and loader-patch hashes match the packaged bytes. Direct comparison with the dev.21 bundle gives:

| Component | dev.33 result | SHA-256 shared with dev.21 |
|---|---|---|
| Complete Data Hub addon archive | Byte-identical; Hub 0.3.0, API 1 | `b9f5f0899d519825e903b191fd4829c302f83c8060b2679a0c72965c4385458b` |
| Native bridge DLL | Byte-identical; native host 0.4.5 | `99877159a6914fb4d5dc5efb0d3a12f87c56d75949c119800ebf08de3e61c08d` |
| Packaged field reference | Byte-identical | `820b011ce3102bb58be5cb611d911377c2254a0df88784c9096b2f944ad06a90` |

The Hub still exposes the same 18 public functions and 16 events listed below. It adds no enemy ability/attack clock, selected attack target, cancellation or preparation-state observation. It therefore cannot restore the existing pre-hit, local-target warning rules. Damage and explosion events remain too late for this purpose.

The loader boot patch changed; its Lua header identifies dev.33, PUC Lua 5.1 and a protected preview. This review did not deobfuscate or execute that boot script. The detailed loader trust-flow discussion below comes from the readable dev.21 source. In dev.33, the unchanged Hub still loads a signed manifest and opens a trusted native owner; the native DLL is also unchanged. The supplied public reference provides no new supported interface for our own attack reader.

The [official update history](https://ayakamods.com/mods/mdl3-preview-%E9%BA%A6%E5%BD%93%E5%8A%B33-%E9%A2%84%E8%A7%88%E7%89%88%EF%BC%81.5710/updates) describes installation, compatibility, audio and crash fixes. The unchanged Hub and its actual API, rather than the release notes alone, establish that the attack-data blocker remains. Updating the loader alone is insufficient; no new warning package or additional manual recording is requested on this evidence.

## Evidence and scope

This section records the original dev.21 assessment. The owner's supplied files were inspected as data. The missing temporary copy of the field reference was recovered from the adjacent `For Modder.zip`.

| Artifact | Identity |
|---|---|
| Supplied bundle | `MDL3-3.0.0-dev.21-preview-Data-Hub-0.3.0-r2.zip` |
| Bundle SHA-256 | `7350f91f500ef6be9987b8da0a3feef8eb83a890ac5d724b778a9e669591538e` |
| Loader | `3.0.0-dev.21`, public preview; native host `0.4.5` |
| Loader Lua resource hash | `f476df93691895fa` |
| Loader source SHA-256 | `0d2c9158a03b5f159a6f9ab9654e5e54ff6227daabaebe8fbec18b050f92f24b` |
| Hub | `0.3.0`, global `HD2Data`, API `1` |
| Hub Lua resource hash | `774742d411cea285` |
| Hub source SHA-256 | `6e553c8f9681fe66f15be1bedb496b41ee9cd7c0f539a9a54825664c1c055ce1` |
| Field reference SHA-256 | `820b011ce3102bb58be5cb611d911377c2254a0df88784c9096b2f944ad06a90` |
| Adapted comparison mod | `BFV-Hit-and-Kill-Feedback-MDL3-1.7.4beta-mdl3.5.zip` |
| Comparison Lua resource hash | `93e5d0431533cbc9` |

The installed Steam manifest reports build `26251122`. The Hub contains baked profiles for `25988413` and `26251122`; it is incorrect to infer that this Hub only supports the older build from its introductory comment. Profile presence is not live validation: the Hub also verifies the loaded modules' identity. Its field reference explicitly distinguishes static proof, inferred meanings and pending live verification.

The [author's MDL3 Preview page](https://ayakamods.com/mods/mdl3-preview-%E9%BA%A6%E5%BD%93%E5%8A%B33-%E9%A2%84%E8%A7%88%E7%89%88%EF%BC%81.5710/) describes the read-only public preview and separate Data Hub dependency. Conclusions here apply to the supplied bytes, not to an unlocked developer edition or future release. No third-party loader, DLL, extracted source, original logs or reference documents are added to this repository.

## How this loader works

The startup patch runs in the game's **PUC Lua 5.1** VM. MDL3 discovers addon declarations and provides compatibility globals, including `CowboyBingusModLoader`, `ModOptionsMenu` and `ModBindingsMenu`. It manages each mod's callbacks and lifecycle.

MDL3 loads its native bridge into the process. A separate LuaJIT environment executes the authorized native modules; typed requests and results pass between the two VMs. Loading an ordinary addon does not give that addon LuaJIT FFI in the game VM.

Data Hub uses an authorized native owner, reads build-specific data chains and returns ordinary Lua snapshots and events through `HD2Data`. Features are demand-driven: calls such as `D.player()` renew a three-second lease; the first call can return nil, and callers must account for data age, mission changes and Hub reloads. The Hub's idle path tracks mission state at 4 Hz when no features or events are requested.

The public audio service follows the same separation: a mod uses `MDL3.audio`, and the authorized audio module owns the system audio objects. Drawing through the existing Stingray GUI remains in the game VM; native-pointer assumptions do not become portable through this bridge.

## Why the old mod fails

| Current dependency | Old implementation | MDL3 migration requirement |
|---|---|---|
| Script environment | `src/native.lua` requires `ffi` at module evaluation; audio and memory helpers also use FFI | Separate game-VM logic from an authorized data provider; no direct FFI in the addon |
| Build verification | Exact old executable / `game.dll` file hashes and instruction pins for build `25480438` | Use a verified current-build provider; do not delete the old guards to make reads run |
| Attack observations | Native ability slots, progress and speed; behavior / aiming target; Factory preparation and replicated state | Missing from the public Hub; this is the main blocker |
| Warning policy | `src/detector.lua` combines a valid attack window with a verified local target, then deduplicates and handles cancellation | Mostly reusable pure Lua logic, after new observations and attack mappings are verified |
| Menus | MOM API `1`, version `3`, sliders / choices / toggles | MDL3 supplies this contract; preserve `peril_warning.crusher.` option IDs |
| Menu language | `BingusTranslations` registry | Verify MDL3 language integration and all supported game languages; menu API compatibility alone does not prove localization |
| Sound | PCM16 assets played through WinMM via FFI | Use `MDL3.audio`; the supplied service supports PCM16 as well as MS-ADPCM |
| Visuals | 50 compiled image/material families; native readiness checks, UI-world resolution, head/camera projection | Reuse approved artwork; replace or verify the old native-dependent readiness and head-anchor paths |

The image animation and original sound do not need artistic reconstruction. The current 48 kHz, stereo, PCM16 sound fits the audio service's format validation, so changing it to ADPCM is optional. It would still require a proper format header, base64 asset upload, readiness checks, volume control and namespace cleanup. This format compatibility is an offline observation, not a claim that playback has been tested in game.

## What Data Hub actually exposes

The original 0.3.0 field reference was cross-checked against the packaged public API and native dispatcher. Its public functions cover local/squad player data, local aim, stratagems and catalogs, active strikes, mission state, subscriptions and diagnostics. The dev.43 recheck above covers the additions in 0.6.0.

Its 16 event names are:

```text
mission_started, mission_ended, entity_spawned, entity_damaged,
entity_died, entity_killed, player_fired, player_hit,
player_damage_dealt, player_kill_credited, explosion, bughole_destroyed,
stratagem_called, stratagem_used, strike_started, strike_ended
```

Important distinctions for this mod:

- `D.aim()` describes the **local player's** aim. Its `target` is a position, not an enemy's selected victim.
- Entity handles expose identity, faction, a cached maximum health and optional event-time position, not the current ability or AI target. Post-damage current health is carried by damage events; there is no arbitrary-entity current-health getter.
- `D.strikes()` covers the barrage / eagle / orbital mechanisms described in the reference. It is not a feed of every enemy melee, beam, cannon or charge attack.
- Damage, death and explosion observations do not provide the pre-hit attack state needed to warn the player in time to dive.
- Catalog strings containing `ability` or `behavior` are not proof of a live attack interface. Such strings also occur in the static explosion-name catalog.

The adapted BFV mod illustrates a valid migration for its own purpose: it subscribes to damage/kill/stat events from `HD2Data` and plays sounds through `MDL3.audio`. It does not recover enemy pre-attack targeting. Copying that event adapter would not restore Sekiro danger alert's behavior.

## Why a private reader cannot just be added

In the readable dev.21 loader, `PREVIEW` is true. Its FFI facade contains no functioning FFI operations; unsupported operations raise `E_UNTRUSTED`. Source submission and module loading are subject to native trust checks. Existing authorized audio and Hub modules have signed manifests with source hashes and permitted exports. See the dev.33 recheck above for the scope of the current comparison.

Consequently, the existence of `client`, owner objects or module-definition methods is not authorization for our own source. Changing a trusted module's body also changes its source hash. This investigation does not remove those checks, reuse another author's authorization, or treat internal native helpers as public addon APIs.

## Interface request for the provider author

The following is the **proposed data contract** for the attack observations still missing in Hub 0.6.0. A filtered snapshot or equivalent pre-attack event stream would both work, provided they include cancellation and retargeting updates.

| Required information | Purpose |
|---|---|
| Build/profile identity, mission epoch, sample time and data age | Reject unsupported or stale observations and clear state across mission / Hub restarts |
| Local avatar entity, unit and network identity | Match the victim without confusing entity IDs and network IDs |
| Attacker entity, unit, type/resource, network identity, life and ownership | Select the correct rule, reject reused entities and distinguish authoritative from replicated state |
| Current ability / attack ID and slot, instance token, elapsed time, speed and paused state | Detect a new attack, place the cue before damage, deduplicate variants and bursts, and cancel stalled clocks |
| Selected attack target, whether it is an entity target, corresponding network target and provenance | Warn only the actual local target; distinguish host behavior data from verified client replicas |
| Relevant behavior / attack phase, preparation state and its freshness | Support attacks such as Factory Strider that do not use the same cue source as ordinary ability slots |
| Position and charge-active state | Restore the planned first-range-entry charge rule without guessing from mere proximity |
| Optional occupied vehicle identity and seat lifecycle | Continue the unresolved Bastion investigation without accepting an arbitrary nearby vehicle as the local player |
| Optional head anchor / camera projection / UI-world support | Replace build-bound presentation reads if supported engine APIs cannot provide them safely |

The essential first milestone is one ordinary enemy's **attack state plus correct target**, on both host and client. Returning only nearby enemies or only a lock-on flag is insufficient. Returning only a fired/damaged event is too late for the intended warning.

A concise request to forward to the MDL3 / Data Hub author:

> Sekiro danger alert needs read-only, pre-hit enemy attack observations. Could HD2Data expose the active ability/attack ID, instance and progress/speed, selected target entity/network ID with host/client provenance, and relevant behavior/preparation state, tagged with mission epoch and sample age? We also need cancellation and retargeting updates. Current damage/kill/explosion events cannot provide a warning before the hit. We can adapt our detector and public audio/menu consumers; we would prefer a supported Hub interface, or an explicitly authorized read-only module, over private memory access.

## Migration and validation sequence

1. Agree on a supported data interface or obtain explicit authorization for a read-only module. Re-verify current build chains and attack semantics; keep old captured IDs as research clues, not new-build proof.
2. Implement a bounded observation adapter. Resolve the Hub lazily, honor nil/age/epoch and provider replacement, and keep authoritative and replicated target evidence distinct. Preserve fail-closed behavior.
3. Reconnect the existing detector, options and approved media. Replace WinMM with public audio; adapt language, head tracking and resource lifecycle. Preserve GUID, resource path, saved IDs, delays and cancellation rules.
4. Run PUC Lua 5.1 checks as well as detector/fixture regression. Exercise stale samples, retargeting, respawn, death, provider reload, duplicate attacks, stop/reload cleanup and unsupported builds.
5. Validate real pre-damage warning timing in game: targeted player versus teammate, host versus client, light-only cancellation, and each supported move. Independently validate animation/sound and vehicle views. Measure frame cost in live play before claiming a performance result.

No additional manual F8 attack recording is requested at this stage: the prerequisite is a supported observation path. New recordings become useful once that path can actually read attack and target state.

## Verification in this investigation

Completed offline: archive/resource inspection, addon identity and public API cross-check, preview trust-path review, PCM format compatibility, current Steam manifest comparison and preservation of the existing 1.0.0 ZIP. Local logs independently show MDL3 starting in Lua 5.1 with native host 0.4.5 and signed trust; they do not establish this mod's functionality.

The current installation no longer contains the previous `bin/lua51.dll`. The required legacy build and full regression entry points cannot pass their installed-game-Lua prerequisite here. No skipped check is counted as passed, and no MDL3 warning behavior or performance has been validated live. This change adds documentation only.
