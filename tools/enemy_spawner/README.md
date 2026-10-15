# Sekiro danger alert - Enemy Spawner 0.3.1

用于警报实测的独立 Bingus Lua addon，支持 16 类敌人。0.3.1 修复数字地址未经指针转换直接传给 Bingus reader，导致 0.3.0 联机通道三次报错后停止的问题；双方均需更新并完整重启。GUID / 入口 / 选择索引保持稳定。与警报本体分别启用，不把生成按钮塞进警报设置页。

房主可在自己菜单直接生成。客机也可选择敌人并 APPLY，**双方都必须装并启用本版**：客机发起请求，由房主准备资源并创建在请求者前方约 20m，初始目标也是请求者。只装客机一端不能让未装工具的房主响应。双方在地面任务且潜兵存活，阵营匹配；粉碎者、猎杀器在光能族任务测试。首次等待资源，之后有 3 秒倒计时。镜头朝向在请求时取值，位置在实际生成时更新；请选平地，未进行地形射线校准。

通信使用游戏已接入的 PlayFab lobby member data，独占 `sda_spawn` 键。沿用 HD2Runtime 已核对的 ABI / 布局，并与本机保留代码复核；没有聊天消息、任意 RPC、内存写入或客机本地权威创建。无需安装 HD2Runtime。首次发现 lobby 后等 10–20 秒，属性异步传递还可能等数秒；发布间隔至少 5 秒。客机等待结果最长 180 秒，忙碌 / 失败后可重试，避免连续 APPLY。

房主根据 SDK 中的发送 peer，绑定当前玩家列表、网络 avatar、Health / Unit 和位置；请求不携带坐标、资源哈希、代码或地址。重放 / 过期请求不生成。任务 / 房主 / 请求者死亡或增援会取消；所有客机共享房主侧每任务 32 次、至少 3 秒间隔和容量 / 资源门禁。穿刺虫仍需 **5–10 难度**，并检查当前触手正权重、表身份和独立模型；保留此前低难度闪退修复。

每个客户端的日志和状态在 `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/Sekiro danger alert - Enemy Spawner.log` 与同名前缀 `-STATUS.txt`。客机不出怪时同时保留房主和客机日志。双方启用此测试工具后，会响应同房间内有效的白名单生成请求；平时可禁用独立工具。

离线已用真实游戏 LuaJIT 和真实 ModOptionsMenu 检查菜单 / 封包、native ABI、资源等待与召唤检查、双端请求 / ACK、一次性、当前房主 / 请求者绑定、超时、换任务 / 死亡取消、消息边界、发布限流和故障隔离。**新联机传递、跨端模型 / AI / 攻击同步及房主迁移没有实机结论**。旧单人创建证据不能替代这些检查。详情见 [0.8.2 验证记录](../../docs/VALIDATION-0.8.2.md)。

构建：

```powershell
$env:HD2_LUA51_DLL = '你的游戏目录/bin/lua51.dll'
python tools/enemy_spawner/build.py --mom-source work/ModOptionsMenu
```

未自动部署或发布 Release，ZIP 只写入忽略的 `outputs/`。完整随包说明来自 [入口内嵌指南](src/entry.lua)。

Uses code / research from HD2Runtime by SkyeShade (MIT)
https://github.com/SkyeShade/HD2Runtime
