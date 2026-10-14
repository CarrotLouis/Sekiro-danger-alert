Sekiro danger alert 0.4.0 — 锁定本人 + 攻击预警测试版

本次修改
- 普通重炮塔：能力 1037 在 1.0 秒准备阶段提示，原生武器扳机事件位于 1.5 秒。
- Crusher：保留已识别的 13 个非脚部攻击分支，起手时检查目标是否本人，继续排除跺脚。
- 两者均取消距离触发限制；只接受本机拥有的敌人 AI 的有效实体目标。
- 自动检测不再固定保留 16 个敌人：分批扫描攻击表，读取实际攻击者的目标。
- 两种采集均记录真实决策，F8 分别保存最近观察和最近自动判断的年龄。
- 动画、音效、跟随、位置 / 大小 / 音量选项沿用已确认版本，设置保留。

安装 / 升级
1. 在 HD2Arsenal 中用 Sekiro danger alert 0.4.0.zip 替换旧测试包。
   仅启用一个版本，部署后完整重启游戏。
2. 依赖 Bingus Shared Loader v18+ 和 Mod Options Menu v1.2 / API 3。
   https://github.com/CowboyBingus/BingusSharedLoader/releases/latest
   https://github.com/CowboyBingus/ModOptionsMenu/releases/latest
3. 仅适配 Steam build 25480438，验证文件哈希和只读布局。
4. 进入舰船等待约 30 秒，ESC > MODS > SEKIRO DANGER ALERT。

选项
- 左右 / 上下：-100～100；0 为既有头顶锚点，正数向右 / 向上。
- 大小：50%～300%，默认 100%；始终跟随本机潜兵头部。
- 自动预警：默认开启。所有选项需要 APPLY。
- 音量：0～100，默认 60；0 静音，仅影响本模组。
- 立即试听：选播放一次并 APPLY；可重复。
- 动画预览：APPLY 后关闭菜单，三秒后播放。
- Crusher 采集：两分钟；看到漏报出招后 F8 标记并手动预览。
- 炮塔索敌采集：两分钟；看到闪光时 F8 只标记，不手动播放危。
- 两种采集互斥，自动预警在采集期间仍工作。

本次验证重点
1. 优先本人做房主，用普通重炮塔验证危字与闪光的关系，以及立即飞扑能否躲开。
2. 让炮塔在本人 / 队友之间切换目标，确认不会为打队友的炮击提示。
3. 对 Crusher 验证普通攻击与连击仍能预警、跺脚不提示、攻击队友不提示。
4. 若有漏报或误报，开启对应采集，在事件后按 F8。按晚了没关系，最好配合录像。
5. 客机上的目标权威、同步和时效性尚未确认。本版对非本机拥有的攻击者跳过，
   原因记为 unverified_peer_target；不会用遗留瞄准 ID 冒充有效锁定。

数据结论与限制
最后两份有效采集包含 267 / 1587 个索敌样本、2 / 7 个 F8，均无读取错误。
313 条炮塔攻击样本回放得出 2 + 8 个准备事件（含最后一次未标记、未完整结束的攻击），
预警比原生扳机事件早 0.42～0.49 秒。F8 不是精确闪光时间，约 0.5 秒仅为人工估计。
游戏中实际显示延迟、弹丸飞行、躲避成功率、目标切换和 Crusher 新过滤需继续实测。
坦克、地堡、火箭等其他机器人攻击未启用，不能把普通重炮塔时序直接推广。
攻击目标为队友时不提示，因此也不会专门警告队友身旁的爆炸波及。

观察预算
自动检测每批最多扫 2048 条能力记录、检查 32 条相关攻击，下一批接着处理。
这是分批读取预算，不是永久只观察 32 个敌人，不限制触发距离。
极多同时攻击或低帧率仍可能延迟；错过前摇窗口时跳过，不在开火后补响。
可选的详细采集仍保留近处对象选择（Crusher 50 米 / 16 个，炮塔 2000 米 / 8 个），
仅用于控制动画、瞄准点等诊断数据的读取量；不约束自动检测器。

日志目录
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs
- Sekiro danger alert.log / Sekiro danger alert-STATUS.txt
- Sekiro danger alert-Crusher-日期-时间.jsonl
- Sekiro danger alert-Targeting-日期-时间.jsonl
自动触发包含攻击者、能力计时、实际目标实体和本机潜兵实体。
两种采集的 detector_sample 包含判断原因；F8 含 last_detection / detection_age。
诊断采集最多两分钟、8 MiB；八次读取错误或单次超过 20 ms 停止。

素材和音频
采用 50 帧 512×512 游戏纹理/材质和原生 GUI，不使用游戏外浮窗。
动画约 0.8 秒，来自字体字形、动态杂色、红色着色与多尺度辉光，按参考图独立近似实现。
没有调用 AE 插件，字体原文件不包含在封包或公开仓库中。
声音通过本模组独立的 WinMM PCM 通道播放，不受游戏音效音量滑块控制，也不是 Wwise 事件。
不需要 AE 工程，不需要安装 HD2Runtime。

卸载
在模组管理器禁用本包、部署并重启游戏。日志会保留。

鸣谢
Uses code / research from HD2Runtime by SkyeShade
https://github.com/SkyeShade/HD2Runtime
Bingus Shared Runtime / memory helpers / Mod Options Menu by CowboyBingus (0BSD)
https://github.com/CowboyBingus/ModOptionsMenu
未复用或分发 HD2 HUD Plus 代码/素材。只狼影像与音效来自用户提供素材，不主张其版权。
