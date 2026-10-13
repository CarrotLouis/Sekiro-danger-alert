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
`python vendor/game_lua.py tests/test_compile.lua .`。
其他测试使用相同方式；test_menu.lua 需要第二个参数指定 ModOptionsMenu 源码仓库根目录。
测试使用离线模拟数据；test_audio.lua 还会用系统声音接口播放一段数字静音，以检查资源释放。
它们不启动游戏，不证明游戏内渲染或联机行为。

素材约定：完整 PNG 原片为 straight alpha；assets/frames 是游戏图标着色器使用的 R/G mask，
外观看起来偏黄绿是正常的，不能拿它们代替透明素材包。

自动识别尚未实现；src/profile.lua 的 attack_states 为空且构建时生成。
下一步需要用户带 F8 标记的 Crusher 采集日志，为每个攻击状态建立经过验证的映射。
正式 10 米判定、重复触发管理和头顶位置投影在完成映射后加入。
