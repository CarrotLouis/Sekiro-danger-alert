# Replacing the animation and sound

English / [简体中文](https://github.com/CarrotLouis/Sekiro-danger-alert/blob/main/docs/REPLACING-ASSETS_cn.md)

This guide describes the **1.0.0 source layout**. Work in your own fork or copy. You can replace just the sound, just the animation, or both; attack recognition and the head-following overlay can stay as they are. A personal replacement uses the original addon identity and replaces the original installation. An independently distributed mod needs its own identity, as explained below.

The game does not load an MP4 or an After Effects project. The builder turns image masks into native textures/materials and embeds decoded PCM sound in the Lua entry. Users import the resulting addon ZIP.

## 1. Prepare the source and tools

Clone your fork and run commands from its root. Install Python 3 with the dependencies in [requirements.txt](../requirements.txt). You also need the installed game's `bin/lua51.dll` and a local [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) source checkout for the offline checks. FFmpeg is optional, for media conversion; install it separately and put it on PATH.

```powershell
python -m pip install -r requirements.txt
git clone https://github.com/CowboyBingus/ModOptionsMenu work/ModOptionsMenu
$env:HD2_LUA51_DLL = 'F:/SteamLibrary/steamapps/common/Helldivers 2/bin/lua51.dll'
```

Change the DLL path for your installation. Skip the clone if that checkout already exists. Do not bundle the game DLL, FFmpeg or the checkout with your mod. The game needs Bingus Shared Loader and Mod Options Menu; it does not need HD2Runtime installed separately.

| File | Purpose |
|---|---|
| [assets/peril.wav](../assets/peril.wav) | Sound source embedded at build time |
| `assets/frames/000.png` through `049.png` | Encoded image masks, one per animation frame |
| [assets/effect.json](../assets/effect.json) | Frame count, rate, size, palette and provenance |
| [src/overlay.lua](../src/overlay.lua) | Playback timing, scale and head anchoring |
| [src/audio.lua](../src/audio.lua) | In-memory sound playback and volume |
| [project.json](../project.json), [src/entry.lua](../src/entry.lua), [src/menu.lua](../src/menu.lua), [scripts/build.py](../scripts/build.py) | Addon identity, menu, assembly and packaging |

`build/assets.lua`, the assembled Lua entry, `src/profile.lua` and `src/catalog.lua` are generated. Edit their inputs, not those generated files. A normal build uses the committed media and needs neither the original video nor a font.

## 2. Replace the sound

Convert your sound to **uncompressed WAV, signed 16-bit little-endian PCM, 48,000 Hz, stereo** and save it as `assets/peril.wav`. A renamed MP3, floating-point WAV, mono WAV or 44.1 kHz WAV will not work with the existing builder/player.

```powershell
ffmpeg -y -i 'work/my_audio.wav' -map 0:a:0 -vn -ac 2 -ar 48000 -c:a pcm_s16le 'assets/peril.wav'
python -c "import wave; w=wave.open('assets/peril.wav','rb'); print(w.getparams()); assert (w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getcomptype())==(2,2,48000,'NONE'); w.close()"
```

The input can also be another audio format or a video containing audio. Edit leading silence, loudness and duration before conversion. The mod's volume slider and sound preview continue to control the replacement sound.

Audio and animation have independent durations: the original sound is about 5.01 seconds, while the animation lasts about 0.834 seconds. Ending the animation does not cut the sound. A new warning restarts the single playback voice instead of layering multiple copies. PCM costs 192,000 bytes per second before its Lua representation and ZIP compression; avoid unnecessarily long files. No loose WAV is read or exported while the game runs.

## 3. Prepare the animation

The simplest replacement keeps the current format:

| Property | Required value for this workflow |
|---|---|
| Source | Ordinary straight-alpha RGBA PNG sequence |
| Names | `000.png` through `049.png`, exactly 50 files |
| Canvas | 512 × 512 pixels, same centered composition in every frame |
| Rate | 60000/1001 frames per second, approximately 59.94 |
| Duration | 50 / (60000/1001) = approximately 0.834167 seconds |
| Edges | At least two fully transparent pixels on all four sides, including the glow |
| End | Frame `049.png` fully transparent |
| Colours | Red/white/yellow light with **red ≥ green ≥ blue** after premultiplication |

Put these source frames in `work/my_animation/`. Bake every visual change into the frames: both text layers, expansion, erosion, fading and smooth glow. The runtime selects a frame; it does not recreate After Effects layers or add a separate bloom pass. Keep enough transparent padding for the glow and avoid a solid black background.

Export real alpha from your animation editor whenever possible. Converting an opaque MP4 to RGBA changes the file format but does **not** restore transparency. Chroma keying or reconstructing alpha from a black background is a separate, lossy preparation step. Premultiplied exports must be converted back to straight alpha before using the example below; otherwise alpha is applied twice and edges darken.

### Why ordinary PNGs cannot overwrite the packaged masks

The existing `assets/frames/` images look yellow-green because they encode weights for the native icon material. Their alpha channel is 255, including empty regions. Visible transparency comes from the colour weights, not that PNG alpha channel. The build compresses them to BC1_UNORM with mipmaps.

For the current palette, a source pixel is first premultiplied by alpha. Its linear combination is then stored as:

```text
mask.R = source.blue
mask.G = source.red - source.green
mask.B = source.green - source.blue
mask.A = 255
```

Here source channels are normalized premultiplied values; the PNG stores the mask channels as 8-bit values. `effect.json` palette vectors use **(alpha, red, green, blue)**, rather than RGBA. The three palette colours are white, red and yellow; the builder pads them to four slots with a transparent vector. Empty pixels are `(0, 0, 0, 255)` in the encoded PNG.

This basis is intended for luminous warm colours. It does not preserve independently opaque black or arbitrary full-colour RGBA artwork. For a single-colour icon in another hue, you can encode a white-with-alpha sequence and change the first palette vector to that hue; also update the preview decoder and palette assertions. Arbitrary colour/opacity combinations need their own validated encoder and material/palette arrangement, beyond this example.

### Convert your own sequence

[scripts/import_effect.py](../scripts/import_effect.py) is specifically the approved R2 importer: it requires 768 × 768 source frames and R2 preview metadata. [scripts/prepare_media.py](../scripts/prepare_media.py) also assumes the original video. Neither is a general converter for replacement media. Do not fabricate approval metadata to make them accept unrelated artwork.

For the 512 × 512 warm-colour workflow above, save the following as **`scripts/import_custom_frames.py` in your own fork**, then run it. It reuses the existing colour encoder, checks all inputs before writing assets, and records new source hashes without claiming R2 approval.

```python
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image
from import_effect import COLOURS, encode, premultiplied

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "work/my_animation"
COUNT, SIZE = 50, 512
paths = sorted(SOURCE.glob("*.png"))
if [p.name for p in paths] != [f"{i:03}.png" for i in range(COUNT)]:
    raise ValueError("Expected exactly 000.png through 049.png")

masks, records = [], []
for index, path in enumerate(paths):
    with Image.open(path) as image:
        if image.mode != "RGBA" or image.size != (SIZE, SIZE):
            raise ValueError(f"Expected 512x512 RGBA: {path.name}")
        rgb = premultiplied(image)
        alpha = np.asarray(image.getchannel("A"))
    if (alpha[:2].any() or alpha[-2:].any()
            or alpha[:, :2].any() or alpha[:, -2:].any()):
        raise ValueError(f"Nonempty two-pixel border: {path.name}")
    if index == COUNT - 1 and alpha.any():
        raise ValueError("The final source frame must be fully transparent")
    masks.append(encode(rgb))
    records.append({"frame": index, "source_png_sha256":
                    hashlib.sha256(path.read_bytes()).hexdigest()})
if np.asarray(masks[-1])[:, :, :3].any():
    raise ValueError("The final frame must be empty")

metadata_path = ROOT / "assets/effect.json"
metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
metadata.update(
    renderer="custom-sequence", approved_revision="custom",
    font_bundled=False, texture_size=SIZE, frames=COUNT,
    fps_numerator=60000, fps_denominator=1001, colours=COLOURS,
    mask_encoding="R=blue, G=red-green, B=green-blue, A=255",
    note="Custom straight-alpha sequence converted to native icon masks.",
    source_frames=records,
)
for key in ("font_family", "font_sha256"):
    metadata.pop(key, None)
output = ROOT / "assets/frames"
output.mkdir(parents=True, exist_ok=True)
for index, mask in enumerate(masks):
    mask.save(output / f"{index:03}.png")
metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print("Converted 50 custom frames; update the asset-specific checks next.")
```

```powershell
python scripts/import_custom_frames.py
```

The example preserves `quad_ratio_to_v020`, so the existing overlay size and head anchor still apply. Use the in-game size and position settings first. A different amount of padding changes the visible glyph's apparent size even when the canvas size stays the same.

## 4. Give an independent mod its own identity

Skip this section only for a personal replacement that will **replace** Sekiro danger alert. For a separately named addon, change the following in your fork once, then keep your new identifiers stable across its upgrades. Do not change the upstream project's identifiers.

Generate a new GUID; do not reuse either this mod's GUID or somebody else's example GUID:

```powershell
python -c "import uuid; print(uuid.uuid4())"
```

For example, choose the public name `Aurora alert`, Lua global `YourNameAuroraAlert`, resource `mods/your_name/aurora_alert`, menu ID `your_name.aurora_alert` and saved prefix `your_name.aurora_alert.`. Replace `your_name` with your own namespace. These are examples, not reserved identifiers.

| Location | Changes required in your fork |
|---|---|
| [project.json](../project.json) | Set the new `guid`, `name`, `resource` and your version. An initial independent release can use `1.0.0`. |
| [src/entry.lua](../src/entry.lua) | Change `KEY='SekiroDangerAlert'`, the `Sekiro danger alert.log` filename and branded startup text. The runtime guard uses `KEY`. |
| [scripts/build.py](../scripts/build.py) | Change both `SekiroDangerAlert` references in the generated duplicate-load guard; the assembled Lua filename; ZIP filename; manifest `Name`, option `Name` and description. These strings are currently hardcoded: changing `project.json.name` alone is insufficient. |
| [src/menu.lua](../src/menu.lua) | Change `spec.mod`, `spec.mod_id='peril_warning.crusher'`, `prefix='peril_warning.crusher.'` and branded reset text. Retain the trailing dot on the saved prefix. |
| [scripts/verify_package.py](../scripts/verify_package.py), `tests/` | Update assertions and paths that intentionally name the original GUID, name, global, menu ID, saved prefix, Lua filename, ZIP filename or release version. |
| User documents and [CREDITS.txt](../CREDITS.txt) | Describe your own name, sound, animation, runtime log and attribution. Update both packaged guides, `README.txt` and `README-使用说明.txt`, as well as repository READMEs. |

Useful identity checks include `tests/test_catalog.py`, `tests/test_entry.lua`, `tests/test_menu.lua`, `tests/test_release.py` and `tests/test_release_source.py`. Search the entire tracked source for the old identifiers and review matches individually. Enemy IDs such as `crusher_melee`, game resource paths and targeting rules are gameplay data; a global replacement of every occurrence of `crusher` would break recognition.

The entry resource and image names derive from `project.json.resource`; the builder recalculates their hashes. Leave the physical archive carrier `9ba626afa44a3aa3.patch_0` and its format intact. It is not the addon's logical namespace; the mod manager assigns deployment patch slots. Preserve the native guards, memory-read bounds, API declarations and game-build fingerprints when changing branding or media.

A new identity isolates loader state, settings, logs and resource names. It does not merge warnings: enabling the original and your derivative together can produce two alerts. Preserve dependency attribution and license files, and state which code and media came from which source. The dependency MIT/0BSD files do not by themselves license every asset in this repository; use replacement media you are entitled to redistribute. Update your fork's contributor instructions to describe its own stable identity.

## 5. Update the media checks and build

The repository checks its approved artwork, rather than accepting any 50 images. For a custom sequence, update the expectations in **your fork** to describe your new media. In particular:

- `tests/test_effect.py` checks the R2 revision, original font metadata, 50-frame format, palette, scale and fade curve. Replace approval/font/curve expectations with the properties of your own sequence; retain checks for dimensions, encoding, empty borders and ending.
- `tests/test_compile.lua` compiles with the installed game's LuaJIT and checks frame count, duration, last resource name and palette. Keep compilation and bytecode-size checks; adjust only media-specific values that you change.
- `tests/test_preview_effect.py` covers the original procedural R2 renderer. It does not validate a newly imported animation. Add or adapt checks for your actual conversion path without calling unrelated artwork R2.
- `scripts/verify_package.py` decodes packaged BC1 textures and compares them to source masks. Keep this check. It currently assumes 512 × 512, 10 mip levels, the original palette and keyframes, plus frame 49 as the empty tail. A palette change also needs a matching decoder.
- Keep the source/manifest identity checks, dependency-menu checks, resource hashes, archive round trip and all unchanged attack/native-reader checks. Renaming a mod is not a reason to remove those checks.

The shortest route keeps 50 frames, 512 × 512, 60000/1001 fps and the existing palette. Other frame counts/rates or power-of-two sizes also need matching metadata, converter and check changes. Playback duration is `frame_count / fps`; [src/overlay.lua](../src/overlay.lua) already uses that relationship. Texture resolution and GUI display size are separate. More frames or larger textures increase payload size and resource warm-up work.

After adapting the identity and media expectations, run:

```powershell
python scripts/build.py
python scripts/test.py --mom-source work/ModOptionsMenu
python scripts/verify_package.py
```

The builder runs the LuaJIT compilation gate **before writing the ZIP**. A failure at that stage must be resolved, not bypassed. For an audio-only personal replacement, the original animation expectations can stay unchanged. See [BUILD.md](../BUILD.md) for more details about the existing checks.

The output is `outputs/<your mod name> <version>.zip` after the filename changes above. A standard package contains these nine entries; with 50 frames its archive has 101 resources: one Lua entry, 50 textures and 50 materials.

```text
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

Keep `outputs/`, `build/`, `work/`, original working media, third-party tools and game files out of commits. Commit the final encoded frames, PCM sound, metadata, source, checks and documentation that belong to your mod. Import the **built addon ZIP**, not GitHub's automatically generated source-code ZIP. Publishing a repository does not publish a playable package; distribute your release ZIP separately when ready.

## 6. Check the result in game

Deploy with a mod manager and restart the game. Allow about 20 seconds for startup and time for image resources to become ready. Use the menu's sound and animation previews to check volume, mute, head anchoring, size, position and the end of the fade. Check on both bright and dark backgrounds; black-only previews can conceal poor alpha edges or clipped glow. Confirm that restored defaults and saved settings belong to your new menu prefix and that the new log uses its own filename.

Then check recognized attacks in actual play, including host/guest play if you distribute it for co-op. The offline checks establish source compilation, format consistency, resource identity and packaged-image fidelity. They do not establish live-game appearance, audible loudness, attack timing, multiplayer behavior or a fixed frame-rate cost. Record those observations separately before publishing.
