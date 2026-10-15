# Sekiro danger alert

《绝地潜兵 2》的 Bingus Shared Loader Lua 模组：以只狼风格的“危”动画与音效提示敌人锁定本人后的危险攻击。

依赖 [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader) 和 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) v1.2 / API 3。游戏内可独立调整提示音量，并立即试听。

当前版本为 **0.7.0 客机修正测试版**，按维护者要求继续使用 0.x.x 编号。房主继续使用有效 AI 实体目标；客机改读同步目标，以敌人招式和本机潜兵身份判断，无距离限制。移动工厂的客机路径使用同步准备信号，不使用房主 AI 时间。**客机路径已通过离线边界测试，仍待真实联机验证。**

**全部 25 项设置集中在一页**：18 个默认开启的招式开关，左右 / 上下 / 大小 / 音量四个滑块，试听、动画预览和恢复默认值。粉碎者的危险近战变体合并为一个开关；吐酸泰坦戳腿 / 吐酸、穿刺虫本体 / 触手仍分别控制。

覆盖四种强袭虫跺脚、穿刺虫跺脚 / 触手下砸、吐酸泰坦戳腿 / 吐酸、孢裂泰坦戳腿、巨型者 / 巨型炙焰者劈砍、移动工厂炮击、强化纵步者火箭、湮灭坦克炮击和铁幕坦克直射火箭。**蟑龙仅俯冲吐息，悬浮吐息不触发；铁幕坦克抛射不触发**，直射三发各有预警窗口。

依据用户采集和当前版本原生代码映射；原有 6,169 条匿名状态及 313 条炮塔回放继续通过，它们是房主数据，不能证明客机触发时机。提前提示不能预知之后是否取消攻击，移动工厂尤其可能在准备后没有实际开炮。当前客机读取与验证边界见 [0.7.0 验证范围](docs/VALIDATION-0.7.0.md)；历史映射见 [0.6.0 验证范围](docs/VALIDATION-0.6.0.md)。

安装包不含采集、F8 标记、索敌 / 武器 / 动画诊断、按次攻击转储及 STATUS 文件；研究源码仅在 [tools/diagnostics](tools/diagnostics/README.md) 保留，不封包。日常日志记录启动、菜单、错误及每 30 秒最多一行的观察统计，不保存原始内存或逐次攻击数据。

视觉沿用已确认 R2 动画，位置、大小与音量可调。GUID / 内部资源路径 / 保留选项 ID 不变；“粉碎者 · 危险近战”沿用上一包的合并开关 ID，保存值继续保留。仅适配 Steam build 25480438。安装与升级见 [使用说明](README-使用说明.txt)。

独立测试工具 **Sekiro danger alert - Enemy Spawner 0.1.1**，在 ModOptionsMenu 选择 14 类敌人并 APPLY 生成一只。工具通过游戏原生接口加载该敌人的资源包，再创建实体及其 AI；只允许对应阵营的单人主持任务。0.1.1 补上穿刺虫召唤检查：**穿刺虫需 5–10 难度**，1–4 难度触手权重为 0，会拒绝生成以避免后续空指针闪退。离线检查通过，修复后的召唤仍需实测。安装和证据边界见 [生成工具说明](tools/enemy_spawner/README.md)。0.5.1 同时修正强化纵步者 / 巨型炙焰者的采集资源筛选。

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
| `config/` | 招式映射、资源身份与版本限定读取校验 |
| `scripts/` | 素材处理、构建与测试入口 |
| `tests/` | 离线测试 |
| `tools/enemy_spawner/` | 独立生成工具的源码、配置与封包入口 |
| `tools/diagnostics/` | 不进入发行包的采集、标记与研究读取器 |
| `assets/` | 50 张 512² 材质遮罩、效果参数与提示音；不包含字体文件 |
| `vendor/` | 必要的第三方辅助代码、许可证和来源记录 |
| `docs/` | 开发记录与验证范围 |
| `outputs/` | 本地产物，Git 忽略；由维护者自行发布 Release |
| `build/`, `work/`, `research/` | 本地缓存、参考仓库与原始研究数据，Git 忽略 |

修改经过检查后正常 commit / push。仓库不自动发布 Release，也不包含游戏 DLL、HUD Plus 源码或原始采集日志。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

第三方代码许可见 `vendor/`；素材来自用户提供的只狼视频，未声明拥有第三方素材版权。详见 [致谢](CREDITS.txt)。
