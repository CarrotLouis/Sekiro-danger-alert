Sekiro danger alert 0.2.0 — Crusher 测试版

本次修改
- 危动画每帧跟随本机潜兵的头部位置，随人物和镜头移动；不会再使用固定屏幕中心。
- Crusher 在 10 米内开始已识别的攻击（能力 1411 / 1412）时自动触发。
- 连续施放同一攻击也会重新预警，单次施放不反复播放。
- 统一菜单、封包和日志名称；保留旧版 GUID 和音量设置。

安装 / 升级
1. 在 HD2Arsenal 中用 Sekiro danger alert 0.2.0.zip 替换旧的 Peril Warning 测试包。
   保持仅一个版本启用，部署后完整重启游戏。
2. 依赖 Bingus Shared Loader v18+ 和 Mod Options Menu v1.2 / API 3。
   https://github.com/CowboyBingus/BingusSharedLoader/releases/latest
   https://github.com/CowboyBingus/ModOptionsMenu/releases/latest
3. 本版只适配 Steam build 25480438，会验证游戏文件哈希与关键指令。
4. 进入舰船后等待约 30 秒，ESC > MODS > SEKIRO DANGER ALERT。
   菜单会自动将模组标题显示为大写。

选项
- 自动预警：默认开启；需要 APPLY 应用。
- 音量：0～100，默认 60；0 静音。只控制本模组提示音。
- 立即试听：选“播放一次”，APPLY 后按本次应用的音量立即播放；可重复。
- 动画预览：选“三秒后播放”，APPLY 后关闭菜单，查看潜兵头顶效果。
- Crusher 采集：可选开启两分钟采集；出招时按 F8 做人工标记并手动预览。
  F8 只在采集期间有效，不代表已经自动识别攻击。

建议本次测试
1. 先预览，走动、转动镜头、蹲伏或趴下，确认危字跟随头顶。
2. 推荐自己做房主，让 10 米内的 Crusher 进行抬手攻击；确认不用按 F8 也会提示。
3. 留意同一只敌人连续攻击能否每次提示、是否出现误报，以及危字是否离头太近或太远。
4. 如果动画不出现或定位不对，保留日志；必要时再开启采集并提供一小段画面。

日志目录
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs
- Sekiro danger alert.log
- Sekiro danger alert-STATUS.txt
- Sekiro danger alert-Crusher-日期-时间.jsonl（仅手动开始采集时生成）
日志会记录自动触发时的能力与距离、成功定位的头骨节点或隐藏原因。
旧版日志保留，不会被改名或覆盖。

已知验证范围
已用游戏 lua51.dll 完成八组离线测试，并对这次采集的 934 条能力记录回放，识别到 9 次支持的攻击起点。
按键标记比实际起点晚 0.35～1.30 秒，不影响代码直接读取能力开始。
第一次标记对应的 1434 动作与其他攻击不同，尚未确认性质，暂未加入自动预警。
新版头顶对齐与实际预警时机仍需游戏内确认；现有采集不能证明客机能力读取有效。
无法读到头部或头部离开画面时动画隐藏；音效可以独立播放。

素材和音频
采用 48 帧游戏原生纹理/材质和原生 GUI，不使用游戏外浮窗。
动画有效画面约 0.8 秒，来源于用户提供的黑底 MP4；Alpha 为重建结果。
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
