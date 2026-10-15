# Sekiro danger alert

《绝地潜兵 2》的 Bingus Shared Loader Lua 模组：以只狼风格的“危”动画与音效提示敌人锁定本人后的危险攻击。

依赖 [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader) 和 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) v1.2 / API 3。游戏内可独立调整提示音量，并立即试听。

当前为 **0.8.0 测试版**。继承 0.7.0 的客机同步目标路径，新增猎杀器 **Tesla Ripper 电击**和 **Disintegration Beamer 激光**两个独立默认开启的开关。两种招式由当前原生处理器映射，实际对应关系和飞扑时机仍需采集确认；没有冒充已实测。

**普通包 27 项设置集中一页**：20 个招式开关，左右 / 上下 / 大小 / 音量四个滑块，试听、动画预览和恢复默认值。敌人按虫族 → 机器人 → 光能族排列，最后三项是粉碎者危险近战、猎杀器电击、猎杀器激光。所有原有保存 ID 和开关值不变。

覆盖四种强袭虫跺脚、穿刺虫跺脚 / 触手下砸、吐酸泰坦戳腿 / 吐酸、孢裂泰坦戳腿、巨型者 / 巨型炙焰者劈砍、移动工厂炮击、强化纵步者火箭、湮灭坦克炮击和铁幕坦克直射火箭。**蟑龙仅俯冲吐息，悬浮吐息不触发；铁幕坦克抛射不触发**，直射三发各有预警窗口。

依据用户采集和当前版本原生代码映射；原有 6,169 条匿名状态及 313 条炮塔回放继续通过，它们是房主数据，不能证明客机触发时机。提前提示不能预知之后是否取消攻击，移动工厂尤其可能在准备后没有实际开炮。当前客机读取与验证边界见 [0.7.0 验证范围](docs/VALIDATION-0.7.0.md)；历史映射见 [0.6.0 验证范围](docs/VALIDATION-0.6.0.md)。

普通包不含采集、F8、原始 AI / 武器状态或逐次攻击转储。另提供同 GUID / 同入口的 **Diagnostics 采集版**，包含完整警报和额外六项采集设置，测试时替换普通包；二者不能同时启用。按阵营选择招式、开始、F8 标记、停止，最多 120 秒 / 8 MiB；保存客机同步目标、活动及非活动能力、网络准备状态和真实警报决策。完整步骤见 [采集说明](tools/diagnostics/README-采集说明.txt)。

联机分工：**房主使用生成工具；客机在自己的电脑采集本人被攻击**。房主代采朋友被打无法证明客机可读取什么。先复测巨型者劈砍、移动工厂炮击，再分别记录猎杀器两招，并做少量攻击队友的对照。

视觉沿用已确认 R2 动画，位置、大小、音量及 GUID / 入口 / 原有保存 ID 不变。仅适配 Steam build 25480438。安装见 [使用说明](README-使用说明.txt)，本轮原生证据和离线 / 实机边界见 [0.8.0 验证范围](docs/VALIDATION-0.8.0.md)。

独立 **Enemy Spawner 0.2.0** 支持 1–4 人任务的房主创建，保留客机拒绝和原生资源 / 召唤检查；增加粉碎者、猎杀器共 16 项，旧 14 项选择索引不变。穿刺虫仍需 5–10 难度。使用 [工具说明](tools/enemy_spawner/README.md)；多人创建后的跨端可见性与新敌人的完整行为仍需实测。

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
