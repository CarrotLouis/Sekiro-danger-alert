# Sekiro danger alert - Enemy Spawner

独立的 Bingus Lua 测试 addon，用于为 Sekiro danger alert 采集敌人招式。依赖 Bingus Shared Loader v18+ 和 Mod Options Menu v1.2 / API 3；无需安装 HD2Runtime。

在 `MODS → Sekiro danger alert - Enemy Spawner` 中选择敌人，将“生成一只”切换为“生成一只”，点击 APPLY 并关闭设置。首次使用先加载该敌人的原生资源包，完成后等待 3 秒，在执行时镜头水平前方约 20m 创建一只，朝向并以本人为初始 AI 目标。切换敌人本身不触发生成，保存的动作也不会在启动时重放。

包含 14 类：强袭虫、孢子强袭虫、巨兽强袭虫、钻地强袭虫、穿刺虫、吐酸泰坦、蟑龙、孢裂泰坦、巨型者、移动工厂、强化纵步者、湮灭坦克、铁幕坦克、巨型炙焰者。穿刺虫由自身 AI 召唤触手。

当前为 **0.1.1**。**穿刺虫请在 5–10 难度测试**：1–4 难度的原生触手权重为 0，虽然可创建本体，但后续召唤会访问空指针。工具现在在原生创建前拒绝这种情况；5–10 难度也须当前触手权重为正、生成表身份匹配、触手模型可用。提示原因写入设置说明、STATUS 和日志。保留原生召唤行为，不修改游戏难度或生成表。

需要对应阵营的单人主持任务和存活潜兵，游戏启动后至少等 20 秒。坐标按当前位置和高度计算，未做地形射线校准，请在开阔平地操作。每次一只、间隔至少 3 秒，每任务最多 32 次；资源等待最多 90 秒，死亡 / 换场景取消请求，容量不足会拒绝。生成后状态检查失败时，该任务停止继续生成。

重新打开设置、选中“生成一只”，说明区可查看状态。详细日志在 `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/Sekiro danger alert - Enemy Spawner.log`，同目录还有 `Sekiro danger alert - Enemy Spawner-STATUS.txt`。

请搭配警报采集版 0.5.1：这版修正了强化纵步者和巨型炙焰者的实体筛选。两个 addon 的 GUID、入口、全局和设置 ID 独立；警报的“恢复全部默认值”只影响警报设置。

构建：先在工程根目录运行 `python scripts/build.py` 和 `python scripts/test.py --mom-source work/ModOptionsMenu`，再运行 `python tools/enemy_spawner/build.py --mom-source work/ModOptionsMenu`。都需设置 `HD2_LUA51_DLL`。生成工具每次封包先执行源码门禁和离线测试，输出仅在 `outputs/`；没有自动部署或发布。

离线已验证真实 MOM 注册与动作消费、加载 / 召唤门禁、版本拒绝、单人限制、创建参数及封包。日志确认普通 / 孢子 / 钻地强袭虫、穿刺虫本体创建；两次穿刺虫召唤闪退均已定位到同一空指针。**本版 5 难召唤触手、其余完整 AI / 武器行为、各类地形落点仍需实测。** 见 [0.1.1 修复证据与测试范围](../../docs/ENEMY-SPAWNER-0.1.1.md)及 [原始创建研究](../../docs/ENEMY-SPAWNER-0.1.0.md)。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

Bingus helpers: CowboyBingus, 0BSD；资源映射：FileDiver by xypwn。许可证和来源见工程 `vendor/` 与 `CREDITS.txt`。
