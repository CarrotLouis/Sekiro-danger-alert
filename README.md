# Sekiro danger alert

《绝地潜兵 2》的 Bingus Shared Loader Lua 模组：以只狼风格的“危”动画与音效提示 Crusher 攻击。

依赖 [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader) 和 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) v1.2 / API 3。游戏内可独立调整提示音量，并立即试听。

当前版本为 **0.5.0 招式采集版**。用户已确认上一版单人测试没有明显问题；Crusher 和普通重炮塔继续按“有效 AI 目标为本人 + 已识别攻击”触发，保持无距离限制。

新增 **16 个待研究招式的独立开关**（均默认开启）、既有 Crusher 13 个能力分支 / 普通重炮塔的独立开关，以及跨设置页的“恢复全部默认值”。由于 ModOptionsMenu 每页最多 32 项，主页面与 `Sekiro danger alert - Attacks` 分页注册。两个吐酸泰坦招式、穿刺虫本体与触手等都可分别控制。

**16 个新增招式尚未开启自动识别**：已定位匹配当前版本的本体 / 武器候选，提供逐招式只读采集，仍需把动作名称与实际前摇、目标及开火模式对应。设置默认为开，完成映射后按同一设置 ID 生效。不要把生成能力或共有武器当作已确认的攻击事件。

新采集保留 AI 完整状态、未知能力、武器输入、动画变化和 F8 延迟；尤其覆盖没有 Ability 组件的炮塔部件。铁幕坦克要分别采直射和抛射，最终只识别直射。具体资源结论和操作见 [0.5.0 研究与采集说明](docs/ENEMY-EXPANSION-0.5.0.md)。

视觉沿用已确认 R2 动画，位置、大小与音量可调。依赖和 GUID / 内部资源路径 / 既有设置 ID 稳定，仅适配 Steam build 25480438。现有预警证据见 [0.4.0 验证](docs/VALIDATION-0.4.0.md)。

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
| `config/` | 炮塔候选资源与只读采集指令校验 |
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
