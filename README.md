# Sekiro danger alert 1.0.0

English / [简体中文](https://github.com/CarrotLouis/Sekiro-danger-alert/blob/main/README_cn.md)

A Helldivers 2 Lua mod that displays a Sekiro-style danger icon above your Helldiver and plays a warning sound for recognized dangerous attacks aimed at you.

## Installation

Import Sekiro danger alert 1.0.0.zip into your mod manager, replace the previous version, deploy and restart the game. Enable only one version. Allow about 20 seconds after startup.
Requires Bingus Shared Loader v18+ and Mod Options Menu v1.2 (API 3). HD2Runtime is not required. Supports Steam build 25480438.

## Settings

All 29 controls fit on one page. Labels, descriptions and custom choice text follow the game's Text Language: English, French, Italian, German, European and Latin American Spanish, Japanese, Korean, Polish, European and Brazilian Portuguese, Russian, Simplified Chinese and Traditional Chinese.
Apply changes to save. Upgrades preserve the existing setting identifiers and saved values.

The 20 attack switches are enabled by default, grouped by faction:

- Terminids: Charger and Spore Charger (Heavy Crush); Charger Behemoth (Superheavy Crush); Rupture Charger (Hardened Crush); Impaler (Momentous Slam and Tentacle Slam); Bile Titan (Cataclysmic Slam and Caustic Surge); Dragonroach (Alchemical Pyrosis); Spore Burst Bile Titan (Cataclysmic Slam).
- Automatons: Cannon Turret (Fusion Battle Cannon); Hulk Scorcher and Jet Brigade Hulk Scorcher (Heavy Rotary Saw); Factory Strider (Fusion Repeater Cannon); Reinforced Scout Strider (Heavy HE Rockets); Annihilator Tank (Fusion Battle Cannon); Barrager Tank (Heavy MLRS (HE)).
- Illuminate: Crusher (Heavy Cudgel); Harvester (Tesla Ripper and Disintegration Beamer).

Crusher Heavy Cudgel variants share one switch. Dragonroach Alchemical Pyrosis is limited to diving runs; Barrager Heavy MLRS (HE) is limited to direct fire. Crusher stomps, Dragonroach hovering fire and Barrager high-arc fire are excluded.
Horizontal and vertical position use the default head anchor as 0, with about one body width left/right and two head heights up/down. The icon follows head and camera movement, including crouching and going prone. Attack recognition has no enemy-distance limit.
Size: 50-300%, default 100%. Volume: 0-100, default 60; 0 mutes the sound.
Harvester Tesla Ripper and Disintegration Beamer each have a separate 0-0.5 second delay, in 0.01-second steps, default 0.30 seconds. Existing saved values are kept within the new range; use Restore defaults to apply the new defaults. Attack cancellation, retargeting, death or loss of valid attack state cancels a pending alert. A long delay may place the warning after damage.
Sound preview: select Play once and Apply to hear the saved volume. Animation preview: Apply and close the menu; the icon and sound play after 3 seconds.
Restore defaults enables all attacks, resets position to 0, both Harvester delays to 0.30 seconds, size to 100% and volume to 60, and cancels pending alerts and previews.

## Runtime files

Default folder: %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\
Usually: C:\Users\<your username>\AppData\Local\CowboyBingus\Helldivers2\Logs\
If the loader supplies a custom log directory, the files below use that directory instead.

Written directly by this mod:

- Sekiro danger alert.log: appended startup, readiness and error messages.

Settings are stored by Mod Options Menu and shared with other mods:

- ModOptionsMenu.values: saved settings; this mod uses the peril_warning.crusher. prefix.
- ModOptionsMenu.values.bak: the previous settings backup.
- ModOptionsMenu.values.tmp: a temporary save file, renamed to the main settings file on success.

ModOptionsMenu.log and BingusSharedLoader.log are managed by the respective dependencies, not written directly by this mod.
Animation and sound are embedded in the package. No PNG, WAV or separate mod configuration file is exported at runtime.
Import and deployment copies are managed by your mod manager; their locations depend on that manager.

## Performance and limits

Attack checks run at most 20 times per second. Head projection updates only during the approximately 0.83-second animation, with no permanently visible overlay. Text follows the settings screen refresh without another per-frame language reader. Attacks are not logged individually.
The 50 compressed animation textures contain about 8.34 MiB of resource data. Sound uses about 0.92 MiB of embedded PCM and plays from memory. These are payload sizes, not total game memory use. Actual cost depends on the scene and hardware; no fixed frame-rate impact is promised.
An alert is not a hit prediction or a guarantee that diving avoids damage. Enemies can cancel attacks or change targets after an alert.
Factory Strider preparations can be cancelled after an alert. Dragonroach alerts may be inaccurate when playing as a co-op guest.
An unsupported game layout stops automatic warnings; see Sekiro danger alert.log for details.

## Uninstall

Disable the mod in your manager, deploy and restart the game. You may remove Sekiro danger alert.log manually.
ModOptionsMenu.values and its backups are shared with other mods; do not delete the whole file to remove this mod's settings.

## Customization

To replace the animation or sound and create an independent addon, see the [resource replacement guide](docs/REPLACING-ASSETS.md). It covers the actual asset formats, conversion, addon identity, packaging and validation. General build instructions are in [BUILD.md](BUILD.md).

## Credits

Uses code / research from HD2Runtime by SkyeShade, and Bingus helpers by CowboyBingus.
See CREDITS.txt and the package's LICENSES folder for attribution and licenses. No HD2 HUD Plus code or assets are redistributed.
The repository does not upload build outputs or publish GitHub Releases automatically.
