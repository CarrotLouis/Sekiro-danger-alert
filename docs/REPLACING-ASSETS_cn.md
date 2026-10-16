# 替换动画与音效

[English](https://github.com/CarrotLouis/Sekiro-danger-alert/blob/main/docs/REPLACING-ASSETS.md) / 简体中文

本文对应 **1.0.0 的源码结构**，请在自己的 fork 或副本中操作。可以只换音效、只换动画，也可以两者都换；攻击识别和头顶跟随逻辑可以继续使用。个人自用的替换版沿用原标识并替换原安装版本；单独发布的新模组则需要自己的标识，下文会逐项说明。

游戏不会直接读取 MP4 或 After Effects 工程。构建脚本会将图像遮罩编译成原生纹理与材质，并把解码后的 PCM 音频嵌入 Lua 入口。最终供用户导入的是构建得到的模组 ZIP。

## 1. 准备源码和工具

克隆自己的 fork，在仓库根目录运行命令。安装 Python 3 及 [requirements.txt](../requirements.txt) 中的依赖。离线检查还需要已安装游戏的 `bin/lua51.dll` 和一份本地 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) 源码。FFmpeg 只用于媒体转换，按需单独安装并加入 PATH。

```powershell
python -m pip install -r requirements.txt
git clone https://github.com/CowboyBingus/ModOptionsMenu work/ModOptionsMenu
$env:HD2_LUA51_DLL = 'F:/SteamLibrary/steamapps/common/Helldivers 2/bin/lua51.dll'
```

将 DLL 路径改为自己的安装位置。已有对应源码目录时跳过克隆命令。不要把游戏 DLL、FFmpeg 或依赖源码目录塞进模组包。游戏内需要 Bingus Shared Loader 和 Mod Options Menu，无需额外安装 HD2Runtime。

| 文件 | 作用 |
|---|---|
| [assets/peril.wav](../assets/peril.wav) | 构建时嵌入的音效源文件 |
| `assets/frames/000.png` 至 `049.png` | 已编码的图像遮罩，每张对应一帧 |
| [assets/effect.json](../assets/effect.json) | 帧数、帧率、尺寸、调色板及来源记录 |
| [src/overlay.lua](../src/overlay.lua) | 播放时序、缩放和头顶锚点 |
| [src/audio.lua](../src/audio.lua) | 内存音频播放及音量控制 |
| [project.json](../project.json)、[src/entry.lua](../src/entry.lua)、[src/menu.lua](../src/menu.lua)、[scripts/build.py](../scripts/build.py) | 模组标识、菜单、源码组装和封包 |

`build/assets.lua`、组装后的 Lua 入口、`src/profile.lua` 和 `src/catalog.lua` 都是生成文件。应修改它们的输入，而不是直接修改生成文件。正常构建使用仓库已有媒体，不需要原视频或字体。

## 2. 替换音效

将自己的声音转换为**未压缩 WAV、有符号 16 位小端 PCM、48,000 Hz、双声道**，保存为 `assets/peril.wav`。给 MP3 改扩展名，或使用浮点 WAV、单声道 WAV、44.1 kHz WAV，都不符合现有构建器与播放器的要求。

```powershell
ffmpeg -y -i 'work/my_audio.wav' -map 0:a:0 -vn -ac 2 -ar 48000 -c:a pcm_s16le 'assets/peril.wav'
python -c "import wave; w=wave.open('assets/peril.wav','rb'); print(w.getparams()); assert (w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getcomptype())==(2,2,48000,'NONE'); w.close()"
```

输入也可以是其他音频格式或含音轨的视频。转换前自行剪掉开头静音，并调整响度和时长。替换后仍由模组音量滑块和立即试听功能控制。

音效与动画时长独立：原音效约 5.01 秒，动画约 0.834 秒。动画结束不会截断声音。再次触发预警会重启同一个播放声部，不会叠加多个副本。PCM 每秒占 192,000 字节，之后还要转为 Lua 表示并压缩进 ZIP，因此不宜放入过长音频。游戏运行时不会读取或导出独立 WAV。

## 3. 准备动画

最直接的替换方式是保留当前规格：

| 属性 | 本流程要求 |
|---|---|
| 源文件 | 常规直通透明通道 RGBA PNG 序列，即未预乘 alpha |
| 命名 | `000.png` 至 `049.png`，恰好 50 张 |
| 画布 | 512 × 512 像素，每帧使用相同的居中构图 |
| 帧率 | 60000/1001 帧/秒，约 59.94 |
| 时长 | 50 / (60000/1001)，约 0.834167 秒 |
| 边界 | 四边至少留两像素完全透明的空边，光晕也不能越界 |
| 结尾 | `049.png` 完全透明 |
| 颜色 | 红、白、黄等发光效果，预乘后满足**红 ≥ 绿 ≥ 蓝** |

把源序列放在 `work/my_animation/`。两层文字、放大、侵蚀、淡出和平滑光晕都要预先渲染进每一帧。运行时只负责选择帧，不会重建 AE 图层，也不会额外添加辉光。为光晕留足透明空间，不要带实心黑底。

尽量从动画软件导出真正的透明通道。把不透明 MP4 转存为 RGBA 只改变文件格式，**不会**补回透明信息。从绿幕抠像或从黑底反推透明度是另一道有损处理。预乘 alpha 的导出图应先还原为直通 alpha，再使用下方示例，否则透明度会被乘两次，边缘发黑。

### 为什么不能用普通 PNG 直接覆盖封包遮罩

现有 `assets/frames/` 图片呈黄绿色，是因为它们保存的是原生图标材质的权重。整张图的 alpha 都为 255，空白处也一样。可见透明度来自颜色权重，而不是 PNG 的 alpha。构建时会将其压缩为带 mipmap 的 BC1_UNORM 纹理。

当前调色板先对源像素做 alpha 预乘，再按以下组合存储：

```text
mask.R = source.blue
mask.G = source.red - source.green
mask.B = source.green - source.blue
mask.A = 255
```

这里的 source 通道表示归一化的预乘值，实际 PNG 使用 8 位遮罩数值。`effect.json` 调色板向量顺序为 **(alpha, red, green, blue)**，不是 RGBA。三个颜色为白、红、黄；构建器会补一个全透明向量，凑齐四个槽。编码 PNG 的空像素为 `(0, 0, 0, 255)`。

这套基底适合暖色发光图像，无法保留独立的不透明黑色或任意全彩 RGBA。其他色相的单色图标可以先将白色加透明度的序列编码，再把调色板第一个向量改为目标颜色，同时更新预览解码器和调色板断言。任意颜色与透明度组合需要另行验证编码器及材质、调色板方案，不在此示例范围内。

### 转换自己的序列

[scripts/import_effect.py](../scripts/import_effect.py) 专用于已确认的 R2 效果，要求 768 × 768 源帧和 R2 预览元数据；[scripts/prepare_media.py](../scripts/prepare_media.py) 也绑定了原视频的规格。两者都不是通用的媒体导入器，不要编造确认记录来导入无关素材。

对于上面的 512 × 512 暖色流程，将以下代码保存为**自己 fork 中的 `scripts/import_custom_frames.py`**，再执行。它复用现有颜色编码器，全部输入通过检查后才写入资源，并记录新的源文件哈希，不会把新图像标成已确认的 R2。

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

示例会保留 `quad_ratio_to_v020`，继续沿用现有显示尺寸和头顶锚点。先通过游戏内大小与位置设置调整。同样尺寸的画布中，留白比例不同也会改变字形的实际观感大小。

## 4. 为独立模组设置自己的标识

只有用于**替换** Sekiro danger alert 的个人自用版才能跳过这一节。单独命名和分发的新模组，应在自己的 fork 中一次性更换下列标识，之后升级保持新标识稳定。不要修改上游项目的标识。

生成一个新的 GUID，不要沿用本模组的 GUID，也不要复制他人示例中的 GUID：

```powershell
python -c "import uuid; print(uuid.uuid4())"
```

例如，公开名称可用 `Aurora alert`，Lua 全局键为 `YourNameAuroraAlert`，资源路径为 `mods/your_name/aurora_alert`，菜单 ID 为 `your_name.aurora_alert`，保存前缀为 `your_name.aurora_alert.`。将 `your_name` 换为自己的命名空间。这些只作示例，不是预留标识。

| 位置 | 在自己 fork 中需要修改的内容 |
|---|---|
| [project.json](../project.json) | 设置新的 `guid`、`name`、`resource` 及自己的版本。独立首发可用 `1.0.0`。 |
| [src/entry.lua](../src/entry.lua) | 修改 `KEY='SekiroDangerAlert'`、`Sekiro danger alert.log` 文件名和启动文案。运行时防重复逻辑使用 `KEY`。 |
| [scripts/build.py](../scripts/build.py) | 修改生成的防重复加载逻辑中两处 `SekiroDangerAlert`、组装 Lua 文件名、ZIP 文件名，以及 manifest 的 `Name`、选项 `Name` 和说明。这些目前是写死的字符串，只改 `project.json.name` 不够。 |
| [src/menu.lua](../src/menu.lua) | 修改 `spec.mod`、`spec.mod_id='peril_warning.crusher'`、`prefix='peril_warning.crusher.'` 和重置日志文案。保存前缀末尾的点要保留。 |
| [scripts/verify_package.py](../scripts/verify_package.py)、`tests/` | 更新明确绑定原 GUID、名称、全局键、菜单 ID、保存前缀、Lua 文件名、ZIP 文件名或发行版本的断言与路径。 |
| 用户文档及 [CREDITS.txt](../CREDITS.txt) | 说明自己的名称、声音、动画、运行日志和来源署名。除仓库 README 外，还应更新包内的 `README.txt` 和 `README-使用说明.txt`。 |

需要重点核对的标识检查包括 `tests/test_catalog.py`、`tests/test_entry.lua`、`tests/test_menu.lua`、`tests/test_release.py` 和 `tests/test_release_source.py`。在全部已跟踪源码中检索旧标识，逐项判断。`crusher_melee` 等敌人 ID、游戏资源路径和索敌规则属于玩法数据，不能把所有 `crusher` 一键替换，否则会破坏识别。

入口资源和图片名称由 `project.json.resource` 派生，构建器会重新计算哈希。保持物理封包载体 `9ba626afa44a3aa3.patch_0` 及其格式不变：它不是模组的逻辑命名空间，部署的补丁槽由管理器分配。仅更换名称或媒体时，应保留原生接口保护、内存读取边界、API 声明和游戏版本指纹。

新标识会隔离加载状态、设置、日志和资源名，但不会合并预警。同时启用原版与衍生版可能出现两次提示。保留依赖署名与许可文件，写清代码和媒体各自来源。依赖的 MIT、0BSD 文件不代表本仓库所有素材都自动采用这些许可；请使用自己有权分发的替换素材。自己的 fork 中，贡献者说明也应改为维护新模组的稳定标识。

## 5. 更新媒体检查并构建

仓库会检查已经确认的美术效果，而不是任意接受 50 张图。换成自己的序列后，需要在**自己 fork 中**更新对应预期，描述新素材的实际性质，尤其是：

- `tests/test_effect.py` 检查 R2 修订、原字体信息、50 帧规格、调色板、大小和淡出曲线。将确认版本、字体、曲线预期改为自己的素材属性，同时保留尺寸、编码、空边和结束帧检查。
- `tests/test_compile.lua` 使用游戏自带 LuaJIT 编译，并检查帧数、时长、末帧资源名和调色板。保留编译及字节码大小检查，只调整实际更改的媒体规格。
- `tests/test_preview_effect.py` 覆盖的是原 R2 程序化渲染器，不能验证新导入的动画。为实际转换流程补充或调整检查，不要把无关素材称为 R2。
- `scripts/verify_package.py` 解码包内 BC1 纹理并与源遮罩比较，应保留。目前它假定 512 × 512、10 级 mip、原调色板和关键帧，以及第 49 帧为空。更换调色板后，解码器也必须同步。
- 保留源码与 manifest 标识、依赖菜单、资源哈希、封包往返，以及未修改的攻击识别和原生读取检查。重命名模组不构成删除这些检查的理由。

最省事的路径是保留 50 帧、512 × 512、60000/1001 帧率和原调色板。其他帧数、帧率或二次幂尺寸，需要同步修改元数据、转换器和检查。播放时长为 `frame_count / fps`，[src/overlay.lua](../src/overlay.lua) 已按此关系计算。纹理分辨率和 GUI 显示尺寸彼此独立。帧数更多或纹理更大会增加封包体积和资源预热开销。

完成标识和媒体预期的适配后运行：

```powershell
python scripts/build.py
python scripts/test.py --mom-source work/ModOptionsMenu
python scripts/verify_package.py
```

构建器会在**写 ZIP 之前**执行 LuaJIT 编译关卡，应解决失败原因，不要跳过。只换声音的个人替换版可以保留原动画预期。现有检查的更多说明见 [BUILD.md](../BUILD.md)。

按上文更改文件名后，输出为 `outputs/<your mod name> <version>.zip`。标准包有以下九个条目；使用 50 帧时，封包内有 101 个资源：一个 Lua 入口、50 个纹理和 50 个材质。

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

不要把 `outputs/`、`build/`、`work/`、原始制作媒体、第三方工具和游戏文件提交到仓库。只提交属于自己模组的最终编码帧、PCM 音效、元数据、源码、检查和文档。导入的是**构建后的模组 ZIP**，不是 GitHub 自动生成的源码 ZIP。公开源码仓库不等于发布可安装模组，准备就绪后再单独分发发行 ZIP。

## 6. 在游戏中检查结果

用模组管理器部署并重启游戏，启动后等待约 20 秒，并留出图像资源就绪时间。通过设置中的音效和动画预览检查音量、静音、头顶跟随、大小、位置及淡出结束状态。明暗背景都要看，纯黑预览容易掩盖透明边缘问题或光晕截断。确认恢复默认和保存设置使用自己的新前缀，日志也使用新文件名。

之后在实战中检查已有攻击识别；若用于联机，也应检查房主和客机。离线检查能确认源码编译、格式一致性、资源标识及封包图像保真，不能确认游戏内观感、实际响度、攻击时机、联机表现或固定帧率开销。发布前应分别记录这些实机观察结果。
