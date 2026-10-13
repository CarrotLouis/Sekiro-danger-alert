Sekiro danger alert 0.3.2 — Crusher 修正 / 炮塔索敌研究版

本次修改
- 修复最早发现的 16 只远处 Crusher 长期占据观察名额的问题，近处新候选可以替换远处对象。
- Crusher 采集直接记录检测决策；动画按批次读取，F8 增加最近观察和时间差。
- 新增单独开启的炮塔索敌采集，记录 AI 目标、瞄准目标、坐标模式与行为阶段。
- 机器人自动预警尚未启用，需要先确认闪光 / 开火前摇与目标数据的对应关系。
- 动画、音效、头顶跟随、位置/大小设置和已识别攻击表沿用 0.3.1。

安装 / 升级
1. 在 HD2Arsenal 中用 Sekiro danger alert 0.3.2.zip 替换旧版 Sekiro danger alert 测试包。
   保持仅一个版本启用，部署后完整重启游戏。
2. 依赖 Bingus Shared Loader v18+ 和 Mod Options Menu v1.2 / API 3。
   https://github.com/CowboyBingus/BingusSharedLoader/releases/latest
   https://github.com/CowboyBingus/ModOptionsMenu/releases/latest
3. 本版只适配 Steam build 25480438，会验证游戏文件哈希与关键指令。
4. 进入舰船后等待约 30 秒，ESC > MODS > SEKIRO DANGER ALERT。
   菜单会自动将模组标题显示为大写。

选项
- 左右 / 上下：-100～100，默认 0 保留旧版头顶锚点；正数向右 / 向上。
  最大偏移各为画面高度的 10%，1080p 下各 108 像素，约一身位 / 两个头高。
- 大小：50%～300%，默认 100%，相对旧版字形大小近似校准。
- 自动预警：默认开启；所有选项需要 APPLY 应用。
- 音量：0～100，默认 60；0 静音。只控制本模组提示音。
- 立即试听：选“播放一次”，APPLY 后按本次应用的音量立即播放；可重复。
- 动画预览：选“三秒后播放”，APPLY 后关闭菜单，查看潜兵头顶效果。
- Crusher 采集：可选开启两分钟采集；出招时按 F8 做人工标记并手动预览。
  F8 只在采集期间有效，不代表已经自动识别攻击。
- 炮塔索敌采集：选择开始或结束，再 APPLY；与 Crusher 采集互斥。

建议本次测试
1. Crusher：可保持现有设置。若仍遇到漏报，开启 Crusher 采集，并继续只在漏报招式之后按 F8。
   新日志会保留检测器的真实观察对象和判断原因；不要求按键和抬手同步。
2. 炮塔索敌：在一座普通重炮塔附近，选“炮塔索敌采集”，开始两分钟采集并 APPLY。
   等待转向、闪光、射击若干次；看到闪光或开火后按 F8。此模式 F8 只标记，不播放危。
3. 优先自己做房主。如果有队友，可分别让炮塔瞄准本人和队友；客机情况建议另做一次。
   这几种场景可以分开采集。最好同时录下画面，便于精确判断闪光到发射的时间；F8 仅定位段落。
4. 炮塔采集与 Crusher 采集互斥；自动 Crusher 预警可继续使用。机器人暂不自动预警。
   目标识别和开火阶段需要实测对齐，不能把“正在瞄准本人”直接当作“立即会开炮”。

日志目录
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs
- Sekiro danger alert.log
- Sekiro danger alert-STATUS.txt
- Sekiro danger alert-Crusher-日期-时间.jsonl（Crusher 采集）
- Sekiro danger alert-Targeting-日期-时间.jsonl（炮塔索敌采集）
日志会记录自动触发时的能力与距离、成功定位的头骨节点或隐藏原因。
旧版日志保留，不会被改名或覆盖。

已知验证范围
离线检查验证游戏 LuaJIT 编译、菜单接入、只读字段解码和身份/计数/版本拒绝、观察名额替换、采集及包结构。
934 条历史能力记录的回放仍识别到 9 次范围内攻击起点。动画沿用用户确认的 R2 版本。
本次新日志没有足够证据确认新的漏报攻击编号，因此保留既有 13 个非脚部攻击分支，未盲目扩充。
1409 / 1410 / 1423 脚部攻击明确排除；其他未知动作不自动视为攻击。
新版观察选择是否解决实际漏报，需继续游戏验证；无法读到头部或头部离开画面时动画隐藏，音效独立。
炮塔采集只读取十类原生炮塔候选的 AI / 瞄准状态，最多持续观察 8 个候选，范围上限 2000 米。
这一范围是采集预算，不是未来机器人预警的触发距离。目标数据存在网络接收路径，但客机时效性尚未验证。
默认采集约 20 Hz，耗时较大时自动降频；超过两分钟、8 MiB、八次读取错误或单次 20 ms 会停止。
F8 记录最近样本的年龄，不把它当作准确的攻击起点。未选择的对象和未验证的武器仍可能缺少数据。

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
