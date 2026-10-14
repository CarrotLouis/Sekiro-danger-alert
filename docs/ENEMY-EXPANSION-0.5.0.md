# 0.5.0 敌人招式资源研究与采集

历史采集版记录。16 招现已接入 0.6.0，变体身份、蟑龙俯冲限定和铁幕直射 / 抛射结论见 [0.6.0 验证](VALIDATION-0.6.0.md)。

本版交付逐招式开关、恢复全部默认值和扩大后的只读采集。**16 个新招式的前摇 / 目标映射尚未确认，暂不产生自动预警；它们的开关已经存在并默认开启。** 0.4.0 的 Crusher 与普通重炮塔逻辑已获用户单人测试确认，继续生效。

## 静态资源结论

已从 [FileDiver 6bf7c1c](https://github.com/xypwn/filediver/tree/6bf7c1ccc4be465a35b4bc9d41087781b47034e6/datalibrary) 的明文实体表和类型库解码 BehaviorComponentData、AbilityComponentData、HealthComponentData。两份数据的哈希与 [HD2Runtime 75988a9](https://github.com/SkyeShade/HD2Runtime/tree/75988a992141023e50fc0193f4b1de017d9e4b57) 当前 F5FEE03DCFDB 资料一致：

- 实体表：`21377252b81fdbc670eba1e59a8ab64b170323df208f175e708992e4c1fb515e`
- 类型库：`4d04870d0a0d4dc1284998c72cdfa6f8ff6d21aba0e36b6f758c6f73dd0417a4`

游戏仍限定 Steam build 25480438，game.dll 指纹沿用 0.4.0；不能将这些偏移当跨版本接口。原表、类型库和参考源码只留在忽略的 work/，公开仓库保存推导的资源身份和取证说明。完整资源路径 / 哈希 / 行为 ID 在 `config/attack_catalog.json`。

能直接读取的是敌人的有效实体目标、行为阶段、活动能力计时，以及武器组件的输入状态。**没有发现可直接按 Wiki 招式名称订阅的事件。** AbilityComponentData 只有生成时按 AI job 触发的能力，不能把 Charger 的 231、Titan 的 439 等生成条目当成跺脚或吐酸。资源名字、伤害值和生成事件均不足以确认攻击起点。

湮灭坦克的 `tank_turret_heavycannon` 有 Health / Behavior 组件，但没有 Ability 组件，所以新采集通过健康组件发现本体及子实体，并同时记录武器输入。不能直接把普通重炮塔能力 1037 的时间表移植过去。

铁幕坦克的直射和抛射共用火箭武器。Wiki 也描述了两种模式：[Barrager Tank](https://helldivers.wiki.gg/wiki/Barrager_Tank)。采集必须区分两者；最终自动规则只接纳已确认的直射状态，不能用距离代替模式判定。

| 设置 / 采集目标 | 原生本体 / 子实体候选 | 行为 ID | 本次 F8 标记 |
| --- | --- | --- | --- |
| 强袭虫 · 跺脚（Heavy Crush） | `charger` | 104 | 看到指定招式起手后 |
| 孢子强袭虫 · 跺脚（Heavy Crush） | `charger_acid` | 105 | 看到指定招式起手后 |
| 巨兽强袭虫 · 跺脚（Superheavy Crush） | `charger_bull, charger_tier2` | 104, 104 | 看到指定招式起手后 |
| 钻地强袭虫 · 跺脚（Hardened Crush） | `charger_burrower` | 106 | 看到指定招式起手后 |
| 穿刺虫 · 跺脚（Momentous Slam） | `impaler` | 113 | 看到指定招式起手后 |
| 穿刺虫触手 · 下砸（Tentacle Slam） | `impaler, impaler_tentacle` | 113, 114 | 看到指定招式起手后 |
| 吐酸泰坦 · 戳腿（Cataclysmic Slam） | `strider` | 133 | 看到指定招式起手后 |
| 吐酸泰坦 · 吐酸（Caustic Surge） | `strider` | 133 | 看到指定招式起手后 |
| 蟑龙 · 吐息（Alchemical Pyrosis） | `dragon` | 108 | 看到指定招式起手后 |
| 孢子泰坦 · 戳腿（Cataclysmic Slam） | `strider_gloom` | 134 | 看到指定招式起手后 |
| 巨型者 · 劈砍（Heavy Rotary Saw） | `lieutenant_assault` | 56 | 看到指定招式起手后 |
| 移动工厂 · 炮击（Fusion Repeater Cannon） | `spawner, spawner_jammer, big_walker_turret_cannon, tank_turret_heavycannon` | 97, 97, 99, 79 | 看到指定招式起手后 |
| 强化纵步者 · 火箭弹（Heavy HE Rockets） | `walker_scout` | 94 | 看到指定招式起手后 |
| 湮灭坦克 · 炮击（Fusion Battle Cannon） | `tank_heavycannon, tank_turret_heavycannon` | 76, 79 | 看到指定招式起手后 |
| 铁幕坦克 · 直射火箭（Heavy MLRS (HE), direct only） | `tank_rocketlauncher, tank_turret_rocketlauncher` | 78, 80 | 直射准备；另采抛射作对照 |
| 巨型炙焰者 · 劈砍（Heavy Rotary Saw） | `lieutenant_assault, lieutenant_ivory_legion_assault` | 56, 56 | 看到指定招式起手后 |

表中的行为 ID 用于定位记录，不代表攻击已开始。巨兽强袭虫包含 bull / tier2 候选；巨型炙焰者、巨型者和强化纵步者的变体身份尚需实测确认。不同 Wiki 敌人可能共享本体，配件或生成配置才决定变体；同一资源也不能直接合并逐敌人开关。对这些候选不宣称已解析出精确变体。

## 如何采集

1. 导入 `Sekiro danger alert 0.5.0.zip` 替换旧包，部署后完整重启。保持同 GUID 的一个版本启用。
2. 进入任务后，在 **Sekiro danger alert** 页选择“新招式采集目标”。菜单包含上表 16 个招式，各自独立；尽量一次只安排一种敌人。
3. “采集类型”默认“目标招式”；选择“新招式采集 → 开始两分钟采集”，按 APPLY 并关闭菜单。选择和类型在启动时固定。
4. 看到选定招式起手后按 F8，每次攻击一次。晚按可以回溯，不用与起手精确同步；尽量获得 **3～5 次**。不需要故意承受伤害。最好配一段录像，帮助确定最早可见前摇与飞扑窗口。
5. 结束或换招式时先停止，选择新目标后再开始。每次生成独立文件。同一敌人的两种招式分别采，尤其吐酸泰坦的戳腿 / 吐酸、穿刺虫本体 / 触手。
6. **铁幕坦克分两份**：目标招式模式只在直射准备时 F8；对照动作模式只在向上抛射准备时 F8。日志文件名带 requested / comparison，避免把抛射混进直射事件。其他敌人也可用对照类型采冲锋、普通攻击等容易混淆的动作。
7. 单人或本人做房主优先。有条件可另采攻击队友的对照；非本机拥有的 AI 仅作研究观察，不据此宣称客机同步已支持。

可以分批提供，先普通强袭虫或吐酸泰坦即可；不必等全部 16 招采齐。遇到稀有敌人再补。

日志位于 `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs`，格式：

`Sekiro danger alert-Combat-招式ID-requested/comparison-日期-时间.jsonl`

F8 在新招式采集模式下只打标记，不手动播放危。文件中 `requested_move` 只是用户选择的研究目标，不代表程序已经认出该次攻击。分析可运行 `python scripts/analyze_capture.py <文件>`，报告写入忽略的 outputs/。

## 采集内容与边界

- 用已核对的 Health 实体映射发现本体与相关子实体；只读、身份复核、任务 / 本机潜兵更替时停止。
- 每份最多两分钟 / 8 MiB，观察最多 8 个相关的近处候选，诊断范围 2000 米；每次发现最多 128 条记录、检查最多 16 个新候选。它们是诊断预算，不影响自动预警的无距离规则。
- 名称、资源、实体 / 单位、所有权、距离、AI 目标 / 阶段、完整 0x1F8 AI 原始状态、活动能力计时、武器输入字节 / 同步位、槽首字段和根单位前向。
- 0x1D0 武器原始状态按低频心跳记录，动画层最多每轮 4 个实例轮转。根前向可能不同于动画炮管，不能直接当炮口仰角。未知字段保留原始证据，不命名为发射模式。
- 武器读法独立核对 `config/combat_probe.json` 的 8 处指令：管理器全局 `game+0x3326420`、映射 +0x30、句柄 +0x48、记录 +0x60 / 步长 0x1D0、本地输入 +0x58、同步位 +0x68。这些布局来自当前版本原生扳机路径，模组不调用该路径。
- 默认约 20 Hz，超过 5 ms 后降频，单次超过 20 ms 或累计 8 次读取失败停止。完整原始状态会增大日志；敌人多时可能先达到 8 MiB，可结束后重新开一份。
- F8 保留最近样本和实际年龄；原始 AI / 输入字段不等于已经确认攻击，也不据无能力记录推断未开火。

## 设置与恢复默认值

主设置页保持原来的设置 ID；新页 **Sekiro danger alert - Attacks** 提供 30 个独立开关：16 个新招式、13 个 Crusher 原生近战分支和普通重炮塔准备事件。Crusher 分支仍以编号标识，因为各编号与实际动作名称尚未一一对应。两个页面均在真实框架 32 行上限内。

主页面“恢复全部默认值 → 恢复全部默认值 → APPLY”会恢复所有注册选项，包括音量 60、偏移 0、大小 100%、自动预警开启、所有招式开启、采集目标 / 类型默认和动作待命状态，同时停止采集并取消预览队列。不会重放试听或启动采集，不影响其他模组。未确认的新招式开关默认为开，但本版不会以未知动作强行触发。

## 验证范围

离线测试覆盖真实 ModOptionsMenu 中 13 个主设置 / 30 个逐招式开关，跨页恢复、独立开关、采集目标 / 对照标签、未知能力保留、健康资源筛选、武器布局与所有者拒绝、原始状态边界、分析工具的独立采样间隔及原有警报回放。构建和实际 ZIP / 图像检查通过后才交付。

实际执行 `python scripts/build.py`、设置安装游戏的 `HD2_LUA51_DLL` 后执行 `python scripts/test.py --mom-source work/ModOptionsMenu`、`python scripts/verify_package.py`，全部通过：4 组 Python + 9 组 Lua。ZIP 共 101 个资源、50 帧已确认 R2 图像；2,139,552 字节，SHA-256 `6077ad00a0c00138493435877f6ec1ef68f5af5d3859e0bffe0387bacf4c3a09`。包和验证图保存在忽略的 outputs/，未上传仓库。

新读法未在本轮实机运行；尚待确认 16 招的能力 / 阶段 / 武器输入到可见起手的映射、变体识别、铁幕两种模式以及躲避窗口。0.4.0 的单人确认不能替代这些新路径的验证。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime
