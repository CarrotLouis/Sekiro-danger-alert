Sekiro danger alert 1.1.0-dev.3 - next-attack collection

Requires Bingus Shared Loader v18+ and Mod Options Menu v1.2 (API 3).
Replace the ordinary warning addon; the GUID, entry and saved settings are shared.
Only the original 1.0.0 attacks currently warn. New attacks require live state/timing mapping.
This ZIP does not implement the proposed new toggles, merged toggles or charge-radius controls yet.
The plan now uses independent Charger/Commander sliders: 0-15m, 1m steps, each defaulting to 5m.

See README-使用说明.txt for the complete collection procedure and files to return.
Select a collection group and move, start with APPLY and close the menu. Ordinary scopes use F8.
Hive Lord: choose the last new-Terminid scope (any old Hive scope also redirects to it).
Use - for surfaced Body Slam, = for emerging Body Slam, and either [ or ] for Bile Rain.
Bile Rain variants do not need separate labels; the two keys remain compatible aliases for the same final control.
Use the main keyboard without Shift. F8 is ignored in the combined Hive scope.
Four groups separate the original Terminids, Automatons, Illuminate/allied towers and new Terminids.
Ordinary scopes stop at two minutes or 8 MiB. Hive sessions run for up to 60 minutes, automatically
rotating at five minutes or 8 MiB; the session is capped at 256 MiB and 64 parts. No menu restart is needed.
Return EVERY part of the session, not only the final part. All timestamps keep the same session origin.
Hive capture pauses across death and resumes with an explicit player epoch after reinforcement;
a mission change still stops it. Only a manual start enables sampling and focused key-edge detection.
For co-op, collect on the attacked player's own computer.

The independent Enemy Spawner 0.4.1 keeps three spewers, Hive Lord and both commanders.
Both host and guest need 0.4.1 for mobile units. Two Gazer weapon cores are added for solo Illuminate missions only;
they remain unverified and do not create the decorative tower or mission site. Check appearance/aim/fire first,
then use this collection ZIP's Gazer/Gazer Spire scope. Lightning Spires still need a natural mission instance.
Use the stratagem to summon the allied Tesla Tower.

Ordinary logs and Combat JSONL files are in the loader log directory, usually:
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\
Return complete Combat JSONL files and Sekiro danger alert.log.

No new game-memory writes or native calls. Existing build, lifecycle and read-budget checks remain.
Version dev.3 adds five vehicle comparison contexts and a three-second icon/sound preview in the Record action.
See README-载具测试.txt: first verify on foot, then Bastion driver/gunner, FRV driver and an empty-vehicle control.
Only these explicitly selected contexts observe seat/vehicle identity and projected-head/output state.
The automatic local-target rule is unchanged; this is a diagnostic package, not a claimed vehicle fix.
Raw AI hex is recorded only at heartbeat cadence. One sample above 20 ms backs off, three consecutive
overruns or a single sample of at least 50 ms stop recording. Mandatory read failures still stop at eight.
Offline verification is not live validation of new attack timing or new spawns.
Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime
