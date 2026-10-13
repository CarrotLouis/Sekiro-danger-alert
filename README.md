# Sekiro danger alert

《绝地潜兵 2》的 Bingus Shared Loader Lua 模组：以只狼风格的“危”动画与音效提示 Crusher 攻击。

依赖 [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader) 和 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) v1.2 / API 3。游戏内可独立调整提示音量，并立即试听。

当前版本为 **0.2.0 测试版**：当 10 米内的 Crusher 开始已识别攻击时播放提示；动画每帧跟随本机潜兵的头部，并保留声音预览和动作采集功能。仅支持已核对的 Steam build 25480438。

采集回放支持能力 1411 / 1412 的识别，共复现 9 次起点。头顶投影、重复触发管理和菜单接口通过离线测试；新版的游戏内头顶对齐与客机识别仍需实测。不会把尚未确认的状态 1434 当作攻击。详见 [验证记录](docs/VALIDATION-0.2.0.md) 和 [测试说明](README-测试说明.txt)。

## 开发

```sh
python -m pip install -r requirements.txt
python scripts/build.py
python scripts/test.py --mom-source /path/to/ModOptionsMenu
```

测试前设置 `HD2_LUA51_DLL` 指向本机游戏的 `bin/lua51.dll`。详见 [构建说明](BUILD.md)。

| 目录 | 内容 |
| --- | --- |
| `src/` | Lua 模块与版本限定的读取布局 |
| `scripts/` | 素材处理、构建与测试入口 |
| `tests/` | 离线测试 |
| `assets/` | 48 张游戏材质遮罩与提示音 |
| `vendor/` | 必要的第三方辅助代码、许可证和来源记录 |
| `docs/` | 开发记录与验证范围 |
| `outputs/` | 本地产物，Git 忽略；由维护者自行发布 Release |
| `build/`, `work/`, `research/` | 本地缓存、参考仓库与原始研究数据，Git 忽略 |

修改经过检查后正常 commit / push。仓库不自动发布 Release，也不包含游戏 DLL、HUD Plus 源码或原始采集日志。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

第三方代码许可见 `vendor/`；素材来自用户提供的只狼视频，未声明拥有第三方素材版权。详见 [致谢](CREDITS.txt)。
