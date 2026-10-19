# 1.1 新招式扩展：资源确认与待采集事项

日期：2026-10-19。当前普通版仍为 **1.0.0**；另有 **1.1.0-dev.1 Diagnostics**。两类指挥官、三类喷涌虫和四类强袭虫的返回记录及 Gazer 核心生成候选，见[首批采集分析](EXPANSION-1.1-FIRST-CAPTURES.md)。新增招式尚未接入普通预警，不能把单位存在或选项可选等同于警报已完成。

## 已确认的静态身份

本机 Steam build 为 25480438，与现有原生读接口一致。使用已有 FileDiver 明文镜像和类型库，按组件 owner、Behavior、Unit、Health 及游戏内名称 ID 交叉确认。镜像 SHA-256 为 `21377252b81fdbc670eba1e59a8ab64b170323df208f175e708992e4c1fb515e`，类型库 SHA-256 为 `4d04870d0a0d4dc1284998c72cdfa6f8ff6d21aba0e36b6f758c6f73dd0417a4`。

[config/expansion_v2.json](../config/expansion_v2.json) 保存此次需求、默认值、资源身份、游戏自带各语言单位名、合并关系及菜单行数规划。这里不填写未确认的攻击 ID 或时间窗。

| 单位及招式 | 主资源 | Behavior | 后续默认值 |
|---|---|---:|---|
| [Gazer](https://helldivers.wiki.gg/wiki/Gazer) · Gazer Burner | `0883366204e1ccc5` | 305 | 开 |
| [Gazer Spire](https://helldivers.wiki.gg/wiki/Gazer_Spire) · Spire Hyperbeam | `1448d494665d01a0` | 306 | 开 |
| [Lightning Spire](https://helldivers.wiki.gg/wiki/Lightning_Spire) · Tesla Displacer | `0d382ae7ffea9d45` | 286 | 开 |
| [A/ARC-3 Tesla Tower](https://helldivers.wiki.gg/wiki/A/ARC-3_Tesla_Tower) · Tesla Turret Arc | `74599e56f72f9d7e` | 661 | 开，仍需确认提前判断是否可行 |
| [Nursing Spewer](https://helldivers.wiki.gg/wiki/Nursing_Spewer) · Putrid Regurgitation | `cc7022fdd172089b` | 116 | 关 |
| [Bile Spewer](https://helldivers.wiki.gg/wiki/Bile_Spewer) · Corrosive Regurgitation | `36aa99cce5e60146` | 101 | 关 |
| [Rupture Spewer](https://helldivers.wiki.gg/wiki/Rupture_Spewer) · Corrosive Regurgitation | `a381a11c07d3eb94` | 102 | 关 |
| [Hive Lord](https://helldivers.wiki.gg/wiki/Hive_Lord) · Body Slam、Bile Rain | `d465d9c7f77a07cb` | 109 | 开，各一项 |
| Brood Commander · Charge | `d522fd4748d443a5` | 138 | 开，与阿尔法共用指挥官冲锋项 |
| Alpha Commander · Charge | `f79cd8bb654397df` | 139 | 同上 |

Nursing 与 Bile 依用户确认，以英文单位和链接为准，没有采用原清单中对调的中文对应。采集还包含 Nursing 的任务变体 `6021e22338333d88` 和 Bile 的装甲变体 `ccae5264acd591b7`。

Lightning Spire 的完整资源路径尚未破解，不能编一个路径来解释哈希。其身份来自类型 `0x8a40fe2f` 的第 147 条、56 字节名称组件：普通名称 ID `4bc6d48a` 与大写名称 ID `1d722190` 对应同一 owner，再核对 Behavior 286、Unit、Health 及 ArcWeapon 类型 5。这是静态身份依据，不是电击时序依据。

现有采集器可针对这些 Health owner 记录活动及非活动 Ability、权威 AI 目标、处理后的客机目标、Aiming 与 WeaponInput。调用沿用既有指纹、描述符身份和读取预算，没有新增原生调用或内存写入。

## 为什么还需要实机记录

单位名、行为类和武器配置无法单独确定哪一条运行时 Ability 是吐酸、下压或冲锋，也不能证明某个前摇一定会发射。不能把现有原生 Ability 表里相邻的数字猜成新招式。

- 霸王虫出土后下压与破土拍击需分别对应状态，最终合成 **Body Slam** 一项。
- 霸王虫扫射吐酸与直线吐酸需分别对应状态，最终合成 **Bile Rain** 一项。
- 三类喷涌虫必须区分持续吐酸与近战、钻地、破土和抛射。
- Gazer、激光塔及光能电塔需要记录锁定、前摇和真正发射之间的关系。
- 友军特斯拉塔锁定敌人不等于即将击中本人。直接目标、连锁命中和提前可读的目标链是否存在，仍需数据确认；不以距离或“正在开火”冒充锁定本人。
- 冲锋要分清奔跑、真正的冲锋、停止与新的一轮；多阶段 ID 是否属于同一次冲锋，也需要按画面对应。

本次划分 **13 个采集范围**，比最终新增的 11 个开关多，是因为霸王虫的两种攻击各拆两个变体记录。采集分组仍保留原三组索引，追加“虫族新增”；光能组包含明确标注的友军电塔。每份 choice 列表均在 2–16 项内，诊断页共 7 行。普通预警页仍是已验证的 29 行，没有假装新增规则已生效。

完整操作见[新增招式采集说明](../tools/diagnostics/README-新增招式采集.txt)。本包记录实际出招而保留旧预警，不能用“有没有弹危”给新状态贴标签。

## 冲锋机制的离线实现

[tools/next_attacks/charge.lua](../tools/next_attacks/charge.lua) 实现不依赖游戏地址的首次入圈状态机；[tests/test_charge_rule.lua](../tests/test_charge_rule.lua) 验证它。它尚未接到发行入口，原生“正在冲锋”和周期标识仍待采集确认。

输入必须同时包含：同一实体及单位生命周期、同一冲锋周期、有效距离、经过校验的本人目标与连贯采样。用户在首批采集返回后将范围改为 **0–15m、1m 步进、默认 5m**，强袭虫与指挥官各有独立滑块 `charger_charge_range`、`commander_charge_range`；各自的 0 值关闭对应距离预警。两组冲锋开关也保持独立。每个实体只读取所属组的范围，调整强袭虫不能影响指挥官正在进行的冲锋。

规则包括：

- 从范围外首次进入且此时确认锁定本人，才触发。
- 同次冲锋离开后再次进入不重复；第一次进入时锁定别人，随后在圈内改锁本人也不补报。
- 初次观察时已经在圈内，只建立基线；仅明确证明是新冲锋刚开始时，才允许贴身启动的提示。
- 采样中断、时间回退或冲锋中修改距离，不制造新的入圈事件。
- 已结束冲锋、死亡或新生命周期可以清理；新冲锋周期重新允许一次。
- 独立状态最多 128 个，满额时拒绝新状态，不移除已预警状态来制造重复。

这些是逻辑测试结果，尚不证明对原生冲锋状态的识别已经完成。最终接入时，只有冲锋读取距离；旧有跺脚、戳腿、劈砍及其他招式继续按其原索敌和时机工作，不增加距离门槛。

## 设置合并与容量规划

本次记录下列合并，待新规则可接入后一起应用，不改动普通 1.0.0 的设置行为：

| 新显示 | 沿用的设置后缀 | 合并成员 |
|---|---|---|
| 所有强袭虫 · 跺脚 / All Charger · Heavy Crush | `move.charger_heavy_crush` | 普通、孢子、巨兽、钻地四项 |
| 所有泰坦 · 戳腿 / All Bile Titan · Cataclysmic Slam | `move.titan_cataclysmic_slam` | 吐酸泰坦、孢裂泰坦两项 |
| 巨型者 · 劈砍 / Hulk Scorcher · Heavy Rotary Saw | `move.hulk_rotary_saw` | 普通与喷气旅两项 |

合并后旧开关从 20 项降到 15 项。再加此次 9 个普通攻击开关和 2 个冲锋开关，共 **26 项**。加上现有音画、猎杀器延迟、预览、重置及新范围滑块，仍超过单页 32 行。

拟保留原类别 ID `peril_warning.crusher` 为招式页：26 开关、两个独立范围及重置共 29 行；另用 `peril_warning.appearance` 放音画、预览及猎杀器延迟，共 8 行。保存前缀仍为 `peril_warning.crusher.`。合并项沿用表中的原主开关标识，其他旧分支保存项不再注册但不删除共享文件。所有新语言标签应与现有 14 个语言包一同验证后再进入功能包。

## 放怪工具 0.4.0

本节保留首次准备包的来源记录；后续 0.4.1 的两种单人 Gazer 核心与验证范围见[首批采集分析](EXPANSION-1.1-FIRST-CAPTURES.md)。

现有创建接口、原生调用和包加载流程保持不变，新增六个有 `EnemyPackageComponentData` 的移动单位：Nursing、Bile、Rupture、Hive Lord、Brood Commander、Alpha Commander。保留原 16 项顺序，新六项追加为索引 17–22。

设置分为原有与新增两份 choice 列表，每份不超过 16 项。原 `enemy` 和 `spawn` 标识保留，新增 `list` 与 `extra`。所有选择只在 APPLY 的生成动作时冻结，不因改列表或载入保存值自动放怪。

联机使用版本化 `SDAES2` 数据，继续只发布独占的 `sda_spawn` 成员属性；原生联机调用与 ABI 未增加。房主仍是唯一创建者，拒绝未列入目录的索引。**双方均需 0.4.0**，旧协议被拒绝。

霸王虫最低难度限制为 7，创建前拒绝已有实例，每任务最多请求成功创建一只；原有穿刺虫的触手权重、难度与模型门禁保持不变。普通 Gazer 和 Gazer Spire 没有对应的敌人生成包记录，属于固定防御建筑，本次不改用单位接口硬造；Lightning Spire 同样不列入移动敌人目录。友军电塔通过支援配备召唤。

新单位创建仍需实机确认。单例与难度拒绝通过离线字节缓冲验证，不代表已验证霸王虫在所有地图上的 AI、破土位置或地形交互。

## 构建和验证范围

```powershell
$env:HD2_LUA51_DLL = 'F:/SteamLibrary/steamapps/common/Helldivers 2/bin/lua51.dll'
python scripts/build.py
python scripts/test.py --mom-source work/ModOptionsMenu
python scripts/build.py --diagnostics --next-attacks
python tools/enemy_spawner/build.py --mom-source work/ModOptionsMenu
python scripts/verify_package.py
```

`--next-attacks` 必须与 `--diagnostics` 一起使用，版本只在这一次开发构建中覆盖为 `1.1.0-dev.1`。`project.json` 保持 1.0.0，普通 ZIP 不被该构建覆盖。只传 `--diagnostics` 的稳定版拒绝逻辑仍保留。

普通 1.0.0 重建 SHA-256 为 `f374b2b1112015ac1f54227fa6cdf8039b1dbff5f6a01ba70297d2bba3a34571`，与原发行包一致。离线检查涵盖名称 owner 对应、默认值及分组上限、真实菜单注册、隔离构建、日志标记、首次入圈逻辑、旧识别回放、新增索引联机传递、生成门禁、LuaJIT 编译及封包往返。

首次交付件记录（不入库；此后采集包指南更新不改变运行代码，当前生成工具候选见首批分析）：

| ZIP | 日志 build ID | 字节数 | SHA-256 |
|---|---|---:|---|
| `Sekiro danger alert 1.1.0-dev.1 Diagnostics.zip` | `9eab1ac240ff` | 2,185,066 | `f1bb8cf0e25ae6fe420370f4f69e7dd83e90f45f523a1ad81267c113737d083e` |
| `Sekiro danger alert - Enemy Spawner 0.4.0.zip` | `e7764e6d1fbd` | 63,558 | `dc6e4f54a17cfb6f54d5349225a5a4b51a7df3b151fe6a761bdf293ab957f3fd` |

待用户返回数据后，才进行新招式 ID / 时间窗映射、友军电弧可行性判断、原生冲锋周期接入、设置合并与多语言更新，并构建实际功能包。没有创建 GitHub Release，没有自动部署游戏，也没有提交原始记录、游戏文件或输出 ZIP。
