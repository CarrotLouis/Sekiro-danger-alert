# Sekiro danger alert

《绝地潜兵 2》的 Bingus Shared Loader Lua 模组：以只狼风格的“危”动画与音效提示敌人锁定本人后的危险攻击。

依赖 [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader) 和 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) v1.2 / API 3。游戏内可独立调整提示音量，并立即试听。

当前为 **0.8.1 测试版**。猎杀器电击和激光的单人采集已核对，现各有独立延迟滑块：**0–2 秒、步进 0.1 秒、默认 0**，图标和音效一起延后。0 保持原预警时机；等待中取消攻击、换目标、死亡或换潜兵会取消提示。最佳飞扑值仍需用户实测。

**普通包 29 项设置集中一页**：20 个招式开关，左右 / 上下 / 大小 / 音量和两项猎杀器延迟，试听、动画预览和恢复默认值。敌人按虫族 → 机器人 → 光能族排列，最后是粉碎者、猎杀器电击及其延迟、猎杀器激光及其延迟。所有原有保存 ID 和开关值不变。

覆盖四种强袭虫跺脚、穿刺虫跺脚 / 触手下砸、吐酸泰坦戳腿 / 吐酸、孢裂泰坦戳腿、巨型者 / 巨型炙焰者劈砍、移动工厂炮击、强化纵步者火箭、湮灭坦克炮击和铁幕坦克直射火箭。**蟑龙仅俯冲吐息，悬浮吐息不触发；铁幕坦克抛射不触发**，直射三发各有预警窗口。

依据用户采集和当前版本原生代码映射；原有 6,169 条匿名状态及 313 条炮塔回放继续通过；本次另加 1,072 条猎杀器匿名输入，复现日志中的 29 次预警。它们是房主数据，不能证明客机触发时机。提前提示不能预知之后是否取消攻击，移动工厂尤其可能在准备后没有实际开炮。当前客机读取与验证边界见 [0.7.0 验证范围](docs/VALIDATION-0.7.0.md)；历史映射见 [0.6.0 验证范围](docs/VALIDATION-0.6.0.md)。

普通包不含采集、F8、原始 AI / 武器状态或逐次攻击转储。另提供同 GUID / 同入口的 **Diagnostics 采集版**，包含完整警报和额外六项采集设置，测试时替换普通包；二者不能同时启用。按阵营选择招式、开始、F8 标记、停止，最多 120 秒 / 8 MiB；保存客机同步目标、活动及非活动能力、网络准备状态和真实警报决策。完整步骤见 [采集说明](tools/diagnostics/README-采集说明.txt)。

联机测试时，**双方都安装 Enemy Spawner 0.3.0，客机可在自己的菜单 APPLY 请求生成**，由房主创建在客机前方并将初始目标指向客机。客机在自己的电脑采集本人被攻击；主机代采不能证明客机读取路径。只装客机一端不能让未装工具的房主生成。猎杀器单人调时可独立进行，不必等到联机。

视觉沿用已确认 R2 动画，位置、大小、音量及 GUID / 入口 / 原有保存 ID 不变。仅适配 Steam build 25480438。安装见 [使用说明](README-使用说明.txt)，本轮原生证据和离线 / 实机边界见 [0.8.1 验证范围](docs/VALIDATION-0.8.1.md)。

独立 **Enemy Spawner 0.3.0** 支持房主本地生成和客机请求房主生成，16 项选择索引、GUID 和资源 / 召唤检查保留。通信复用已核对的 PlayFab 成员属性 ABI，使用独立键，重核当前成员、房主、请求者网络潜兵和实际落点。穿刺虫仍需 5–10 难度。使用 [工具说明](tools/enemy_spawner/README.md)；请求传递和跨端可见性 / AI 尚需联机实测。

## 开发

```sh
python -m pip install -r requirements.txt
python scripts/build.py
python scripts/test.py --mom-source /path/to/ModOptionsMenu
python tools/enemy_spawner/build.py --mom-source /path/to/ModOptionsMenu
```

测试入口也会构建并检查 Diagnostics 变体；可单独用 `python scripts/build.py --diagnostics` 构建。测试前设置 `HD2_LUA51_DLL` 指向本机游戏的 `bin/lua51.dll`。详见 [构建说明](BUILD.md)。

| 目录 | 内容 |
| --- | --- |
| `src/` | Lua 模块与版本限定的读取布局 |
| `config/` | 招式映射、资源身份与版本限定读取校验 |
| `scripts/` | 素材处理、构建与测试入口 |
| `tests/` | 离线测试 |
| `tools/enemy_spawner/` | 独立生成工具的源码、配置与封包入口 |
| `tools/diagnostics/` | 仅进入 Diagnostics 变体的采集、F8 和研究读取器 |
| `assets/` | 50 张 512² 材质遮罩、效果参数与提示音；不包含字体文件 |
| `vendor/` | 必要的第三方辅助代码、许可证和来源记录 |
| `docs/` | 开发记录与验证范围 |
| `outputs/` | 本地产物，Git 忽略；由维护者自行发布 Release |
| `build/`, `work/`, `research/` | 本地缓存、参考仓库与原始研究数据，Git 忽略 |

修改经过检查后正常 commit / push。仓库不自动发布 Release，也不包含游戏 DLL、HUD Plus 源码或原始采集日志。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

第三方代码许可见 `vendor/`；素材来自用户提供的只狼视频，未声明拥有第三方素材版权。详见 [致谢](CREDITS.txt)。
