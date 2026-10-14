# Build / 构建

Uses code / research from HD2Runtime by SkyeShade
https://github.com/SkyeShade/HD2Runtime

本工程是 Bingus Lua addon，不需要在游戏中安装 HD2Runtime。
Python 3 + Pillow 用于构建；完整透明序列的提取另需 NumPy 和 FFmpeg。
已包含 50 张 512×512 游戏材质遮罩图及 PCM WAV，所以重新构建不需要字体文件、MP4、AE 或 FFmpeg。

运行 `python scripts/build.py`，成品写入 `outputs/`。
需要其他输出位置时使用 `--output-dir <目录>`。
`project.json` 的 GUID 和入口名称应在后续版本保持不变。

测试：设置 `HD2_LUA51_DLL` 指向自己安装游戏的 `bin/lua51.dll`，再运行
`python scripts/test.py --mom-source <ModOptionsMenu源码目录>`。
测试入口为每组测试启动独立进程；单独运行时可用 `python vendor/game_lua.py tests/test_native.lua .`。
测试使用离线模拟数据及去除真实身份信息的采集派生回放；test_audio.lua 还会用系统声音接口播放一段数字静音，以检查资源释放。
它们不启动游戏，不证明游戏内渲染或联机行为。

构建后运行 `python scripts/verify_package.py`，从实际 ZIP 检查清单、资源、Lua 与 BC1 纹理，并生成压缩前后关键帧对照。

素材约定：完整 PNG 原片为 straight alpha；assets/frames 是游戏图标着色器使用的 R/G/B 颜色遮罩，
外观看起来偏黄绿是正常的，不能拿它们代替透明素材包。

`src/profile.lua` 在构建时生成；修改版本适配与能力白名单时应编辑 `scripts/build.py`，并保留显式跺脚排除表。
自动预警按敌人资源、能力计时和有效 AI 实体目标判断，不按人工标记时刻延迟触发。头部定位读取当前头骨节点世界姿态，经主相机投影到原生 GUI。

需要从自己的原视频重新提取透明序列时运行：
`python scripts/prepare_media.py <MP4路径> --ffmpeg <ffmpeg可执行文件路径>`。
完整序列仍写入被忽略的 `outputs/`；不会自动上传或发布。

0.3.1 已接入用户确认的 R2 动画。需要重新生成时：

```powershell
python scripts/preview_effect.py --font '<極太行書.ttf>' --ffmpeg '<ffmpeg.exe>'
python scripts/import_effect.py --sequence 'outputs/Sekiro danger alert Animation R2'
python scripts/build.py
```

预览工具只写 `outputs/`；导入步骤才会替换生产素材。普通构建直接使用仓库内的 50 张遮罩，无需字体、视频或 FFmpeg。
字体仅从给定路径读取，不复制进仓库。旧 `render_effect.py` 仅为 0.3.0 历史工具，不应用来覆盖当前素材。
512² 纹理继续使用原生图标材质、BC1 格式及 10 级 mip 链；RGB 遮罩重建白、红、黄色贡献，宽红光晕放入精度更高的绿色通道。
默认绘制区域扩大以容纳光晕，主体的默认屏幕大小按 0.3.0 校准；设置 ID 和跟随锚点不变。
生成方式与观感调整记录见 [动画预览 R2](docs/ANIMATION-PREVIEW-R2.md)。实际游戏混合效果仍需实测。

0.3.2 的索敌探针配置在 `config/targeting_probe.json`；构建将资源哈希及关键指令写入生成的 `src/profile.lua`。0.4.0 的自动预警也使用其中的行为目标读取与校验。攻击时序和额外指令校验在 `config/attack_probe.json`。采集分析可运行 `python scripts/analyze_capture.py <日志路径>`，报告写入 `outputs/`。

资源和招式目录在 `config/attack_catalog.json`，构建生成 `src/catalog.lua`。0.6.0 的 `enabled_from_capture` 表示已从采集与当前版本代码映射，仍须实机确认新预警效果。规则、分段发射窗口及额外指令校验在 `config/expanded_attacks.json`，构建写入 `src/profile.lua`。原始日志 / 模块截取不入库，测试仅保留匿名最小状态回放。

移动工厂没有活动 Ability，自动路径扫描已核对的世界实体描述符，读取其 AI 准备阶段、目标就绪标志与原生微秒时钟；每批最多 8 个匹配后续扫，无永久观察名额，不读位置。整体保持每次 2500 次 / 1 MiB 的只读门禁。武器输入诊断校验在 `config/combat_probe.json`，仅手动采集使用。版本来自 `project.json`，入口和采集头均使用运行时版本。

独立生成工具：先运行上述主工程构建与测试，再运行
`python tools/enemy_spawner/build.py --mom-source work/ModOptionsMenu`。
它仍要求 `HD2_LUA51_DLL`，每次构建先执行真实 LuaJIT 编译、目录检查、原生边界模拟与真实 MOM 契约检查；全部通过才写 ZIP。
`--validate-only` 只写本地编译缓存，不写 ZIP。工具使用独立 GUID、入口与设置 ID，输出同样位于被忽略的 `outputs/`，不会部署。
具体字节证据和实机待验范围见 `docs/ENEMY-SPAWNER-0.1.1.md`。
