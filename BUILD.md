# Build / 构建

Uses code / research from HD2Runtime by SkyeShade
https://github.com/SkyeShade/HD2Runtime

本工程是 Bingus Lua addon，不需要在游戏中安装 HD2Runtime。
Python 3 + Pillow 用于构建；完整透明序列的提取另需 NumPy 和 FFmpeg。
已包含 48 张游戏材质遮罩图及 PCM WAV，所以重新构建不需要 MP4、AE 或 FFmpeg。

运行 `python scripts/build.py`，成品写入 `outputs/`。
需要其他输出位置时使用 `--output-dir <目录>`。
`project.json` 的 GUID 和入口名称应在后续版本保持不变。

测试：设置 `HD2_LUA51_DLL` 指向自己安装游戏的 `bin/lua51.dll`，再运行
`python scripts/test.py --mom-source <ModOptionsMenu源码目录>`。
测试入口为每组测试启动独立进程；单独运行时可用 `python vendor/game_lua.py tests/test_native.lua .`。
测试使用离线模拟数据；test_audio.lua 还会用系统声音接口播放一段数字静音，以检查资源释放。
它们不启动游戏，不证明游戏内渲染或联机行为。

素材约定：完整 PNG 原片为 straight alpha；assets/frames 是游戏图标着色器使用的 R/G mask，
外观看起来偏黄绿是正常的，不能拿它们代替透明素材包。

`src/profile.lua` 在构建时生成，能力白名单为 1411 / 1412；修改版本适配与白名单时应编辑 `scripts/build.py`。
自动预警按当前能力计时识别起点，不按人工标记时刻延迟触发。头部定位读取当前头骨节点世界姿态，经主相机投影到原生 GUI。

需要从自己的原视频重新提取透明序列时运行：
`python scripts/prepare_media.py <MP4路径> --ffmpeg <ffmpeg可执行文件路径>`。
完整序列仍写入被忽略的 `outputs/`；不会自动上传或发布。
