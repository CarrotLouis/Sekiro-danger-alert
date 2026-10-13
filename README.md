# Sekiro danger alert

《绝地潜兵 2》的 Bingus Shared Loader Lua 模组：以只狼风格的“危”动画与音效提示 Crusher 攻击。

依赖 [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader) 和 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) v1.2 / API 3。游戏内可独立调整提示音量，并立即试听。

当前版本为 **0.3.1 测试版**：接入已确认的 R2 双层“危”动画，包含亮白转暗红、动态宽光晕与边缘侵蚀淡出；当 10 米内的 Crusher 开始已识别攻击时播放提示。动画每帧跟随本机潜兵头部，可调整左右、上下位置及 50%～300% 大小。仅支持已核对的 Steam build 25480438。

能力白名单现覆盖 13 个经过静态核对的非脚部近战分支，明确排除三个跺脚分支。1411 / 1412 已有采集和使用者实测支持；新增分支包含多段连击路径，但“三连锤击”的准确编号和全部招式覆盖仍需实测，不能仅凭离线测试宣称已全部识别。详见 [攻击研究与验证范围](docs/VALIDATION-0.3.0.md) 和 [测试说明](README-测试说明.txt)。

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
| `assets/` | 50 张 512² 材质遮罩、效果参数与提示音；不包含字体文件 |
| `vendor/` | 必要的第三方辅助代码、许可证和来源记录 |
| `docs/` | 开发记录与验证范围 |
| `outputs/` | 本地产物，Git 忽略；由维护者自行发布 Release |
| `build/`, `work/`, `research/` | 本地缓存、参考仓库与原始研究数据，Git 忽略 |

修改经过检查后正常 commit / push。仓库不自动发布 Release，也不包含游戏 DLL、HUD Plus 源码或原始采集日志。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

第三方代码许可见 `vendor/`；素材来自用户提供的只狼视频，未声明拥有第三方素材版权。详见 [致谢](CREDITS.txt)。
