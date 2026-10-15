# Sekiro danger alert - Enemy Spawner 0.2.0

独立 Bingus Lua 生成工具，依赖 Bingus Shared Loader v18+、Mod Options Menu v1.2 / API 3，无需安装 HD2Runtime 或警报本体。

由房主在对应阵营的地面任务使用，支持 1–4 人；客机不直接创建。选择敌人，将“生成一只”改为生成并 APPLY，关闭菜单。资源就绪后等待三秒，在执行时镜头水平前方约 20m 生成一只，初始 AI 目标指向房主。按实际位置和高度放置，没有地形射线校准，请选开阔平地。

列表前 14 项不变：四种强袭虫、穿刺虫、吐酸泰坦、蟑龙、孢裂泰坦、巨型者、移动工厂、强化纵步者、湮灭坦克、铁幕坦克、巨型炙焰者。最后追加 **粉碎者、猎杀器**，共 16 项，恰好符合 MOM 的 16 项下拉上限。光能族敌人只能在光能族任务生成。

联机采集时，房主生成后避开，让客机靠近，等待敌人实际转向并攻击客机；**采集版安装在客机电脑，由客机按 F8**。生成位置和初始目标仍是房主，本版不新增目标玩家选择或客机请求转发。

仍保留穿刺虫 5–10 难度检查、当前触手生成权重 / 表身份 / 资源就绪检查，避免 1–4 难度召唤空指针。每次一只，间隔至少三秒，每任务最多 32 次；资源等待最多 90 秒，死亡 / 换场景 / 丧失房主身份取消请求，未校验成功的创建会停止该任务后续生成。

状态写入设置说明、`Sekiro danger alert - Enemy Spawner.log` 和同名 `-STATUS.txt`，位于 `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/`。

离线证明：真实游戏 LuaJIT 编译、真实 MOM 注册 16 项、合成 1–4 人房主门禁及客机零创建调用、原有原生创建 ABI / 资源加载 / 召唤拒绝检查。未增加新的原生调用、内存写入或补丁。**多人创建后的跨端可见性、新增两类完整 AI / 武器行为和地形落点仍需实测**，不把合成测试说成实机确认。

构建：在根目录设置 `HD2_LUA51_DLL` 后执行 `python scripts/build.py`、`python scripts/test.py --mom-source work/ModOptionsMenu`、`python tools/enemy_spawner/build.py --mom-source work/ModOptionsMenu`。源码门禁 / 测试失败不封包，无自动部署或发布。GUID / 入口与 0.1.1 相同。

本轮证据见 [0.8.0 验证范围](../../docs/VALIDATION-0.8.0.md)，旧穿刺虫问题见 [0.1.1 证据](../../docs/ENEMY-SPAWNER-0.1.1.md)。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

Bingus helpers: CowboyBingus, 0BSD；资源映射：FileDiver by xypwn。许可证和来源见工程 `vendor/` 与 `CREDITS.txt`。
