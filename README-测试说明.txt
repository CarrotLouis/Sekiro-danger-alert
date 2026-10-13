Peril Warning — Crusher 测试包 0.1.0

本次可测试：游戏原生 GUI 显示危动画、原片音效、独立音量滑块、试听、Crusher 动作采集。
目前是“预览 + 采集”版：未确认 Crusher 攻击状态编号，不会自动判断攻击并报警。
动画目前显示在画面中上方的固定位置；精准跟随潜兵头顶将在触发识别后接入。

依赖
- Bingus Shared Loader v18 或更新：https://github.com/CowboyBingus/BingusSharedLoader/releases/latest
- Mod Options Menu v1.2（API version 3，支持滑块）：https://github.com/CowboyBingus/ModOptionsMenu/releases/latest
- 本版适配 Steam build 25480438；会同时验证游戏 EXE、game.dll 文件哈希及关键代码。
本包只依赖上述两个 Lua 模组，不要求安装 HD2Runtime。

安装
1. 把 PerilWarning_Crusher_Test_0.1.0.zip 导入 HD2Arsenal，启用本模组及两个依赖、部署。
2. 重新启动游戏，进入舰船后等待约 30 秒。
3. ESC > MODS > 危提示测试 / Peril Warning。

音量和预览
- 音量 / Volume：0～100，默认 60；0 为静音。只调整本模组音效。
- 立即试听 / Preview：选“播放一次”，按 APPLY（键盘通常 Tab），立即播放。
  试听使用这次一起应用的新音量；操作后自动回到“待命”，可重复。
- 动画预览：选“三秒后播放”，APPLY 后关闭菜单；三秒后播放动画和音效。
- 菜单的选项需要 APPLY 提交；只移动滑块或改选择、然后直接退出，不会生效。

请进行一次 Crusher 采集
1. 先做一遍音量、声音与动画预览，确认能否显示、是否有黑底、音量是否独立生效。
2. 推荐先自己做房主，找到 Crusher（Illuminate 的 bodyhorror_helmetguy）。
3. 任务内打开“Crusher 采集”，选择“开始两分钟采集”，按 APPLY，关菜单。
4. 让同一只 Crusher 连续进行 3～5 次明显的抬手砸地攻击。
   每次看见它抬手时按一次 F8：日志会标记这个时刻，并手动播放危提示。
   F8 是人工标记/预览，不表示模组已经识别了攻击。按住不会重复触发。
5. 也保留几秒它只行走或待机的片段，便于排除非攻击状态。
6. 两分钟后自动结束；也可在菜单中选“结束采集”并 APPLY。
   可选：录一段包含 3 次攻击的小视频，和日志一起提供，便于校准抬手时刻。
7. 把下面目录中的最新 Crusher JSONL、PerilWarning.log、PerilWarning-STATUS.txt 发回本聊天。

日志目录（粘贴到资源管理器地址栏）
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs
采集文件名：PerilWarning-Crusher-日期-时间.jsonl
即使动画没有显示，也请发送上述日志。先保留测试结果，不需要反复重装。

采集内容
- 只读取任务内 Crusher 的身份、位置/距离、动画层状态、运行中的能力及时间。
- 采集范围暂为 50 米，用于确认远距离抬手与靠近过程；正式预警目标范围仍是 10 米。
- 目标 20 次/秒；读取偏慢时降频。最多 2 分钟、16 个目标、8 MiB 日志。
- 记录动作变化和每秒状态，能力运行时记录采样值；不会导出完整内存或修改敌人行为。
- 离开任务、本地潜兵暂时不可用、版本不匹配或连续读取失败时停止。

素材
PNG 已从用户提供的黑底 MP4 重建透明通道，动画保留原片约 0.8 秒的有效画面。
模组中使用 48 张 256×256 游戏纹理和原生 GUI 材质；不用运行游戏外浮窗。
声音用 Lua 调用系统 WinMM 私有播放通道，并对本模组 PCM 单独缩放。
这是临时音频通路，不受游戏“音效音量”滑块控制，也不是 Wwise 原生声音事件。
原片完整 1920×1080、300 帧 PNG 序列和 WAV 单独提供，不要作为 mod ZIP 导入管理器。

验证状态
已通过游戏自带 lua51.dll 的离线编译、菜单接口、数据读取、音频生命周期与 GUI 生命周期检查。
具体通过结果见随包外提供的验证记录；尚未在运行中的游戏里测试画面、音效或网络状态。
主机/客机能否看到相同动画与能力状态，需要实际采集确认。

卸载
在模组管理器禁用本包并重新部署、重启游戏。日志保留以便反馈。

鸣谢
Uses code / research from HD2Runtime by SkyeShade
https://github.com/SkyeShade/HD2Runtime
使用其资源编译工具和已核查的只读布局研究，未捆绑 HD2Runtime。
Bingus Shared Runtime / Bingus memory helpers / Mod Options Menu by CowboyBingus (0BSD)
https://github.com/CowboyBingus/ModOptionsMenu
未复用或分发 HD2 HUD Plus 的模组代码/资源。只狼影像、音效来自用户提供素材；不主张其版权。
