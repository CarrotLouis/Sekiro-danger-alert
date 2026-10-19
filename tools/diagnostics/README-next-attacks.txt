Sekiro danger alert 1.1.0-dev.1 - next-attack collection

Requires Bingus Shared Loader v18+ and Mod Options Menu v1.2 (API 3).
Replace the ordinary warning addon; the GUID, entry and saved settings are shared.
Only the original 1.0.0 attacks currently warn. New attacks require live state/timing mapping.
This ZIP does not implement the proposed new toggles, merged toggles or charge-radius controls yet.
The plan now uses independent Charger/Commander sliders: 0-15m, 1m steps, each defaulting to 5m.

See README-使用说明.txt for the complete collection procedure and files to return.
Select a collection group and move, start with APPLY, close the menu and press F8 at the described cue.
Four groups separate the original Terminids, Automatons, Illuminate/allied towers and new Terminids.
Each segment stops at two minutes or 8 MiB. Only a manual start enables collection/F8.
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
Offline verification is not live validation of new attack timing or new spawns.
Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime
