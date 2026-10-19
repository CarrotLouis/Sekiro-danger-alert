local GUIDE=[===[Sekiro danger alert - Enemy Spawner 0.4.1 — 测试说明

依赖：Bingus Shared Loader v18+、Mod Options Menu v1.2。
独立测试工具，可与 Sekiro danger alert 同时启用。无需安装 HD2Runtime。

1. 导入并启用本 ZIP，完整重启游戏，等待至少 20 秒。
2. 进入对应阵营地面任务，找开阔平地，平视前方。
3. 在 MODS → Sekiro danger alert - Enemy Spawner 中选“使用列表”，再在对应敌人列表中选择。
4. 将“生成一只”改为“生成一只”，APPLY 并关闭设置。
5. 房主直接准备资源；客机则先请求房主。资源就绪后倒计时 3 秒，在请求者前方约 20m 生成一只。
6. 下次再次选择生成并 APPLY。切换敌人本身不生成；说明区可查看当前状态。

客机用法
0.3.1 修复上一版数字地址传入 reader 引起的通道关闭；请双方更新并完整重启。
房主和客机均需安装并启用本版 0.4.1。沿用 SDAES2 协议，原有 22 项索引不变。房主无需代操作菜单。
客机只提交请求，权威创建在房主执行。只装客机一端无法让未装工具的房主响应。
请求者镜头水平朝向在 APPLY 时固定，位置按实际创建时房主读到的请求者当前位置取得。
初始目标指向发起请求的潜兵。房主自己生成仍在房主前方并以房主为初始目标。
双方进入任务后，联机通道需等 10–20 秒就绪；成员属性通过游戏联机服务异步传递，可能再等数秒。
单次请求等待结果最多 180 秒，房主只处理一项生成任务；提示忙碌 / 失败后检查房主状态，再重新 APPLY。
不要连续重复 APPLY。同一 token 只处理一次，过期请求、任务 / 房主 / 请求者变化会取消或拒绝。
房主必须仍在任务中且潜兵存活；请求者死亡、增援或离开任务会取消资源等待 / 倒计时。
没有聊天消息、任意 RPC、内存写入或客户端直接创建。网络请求和接收只针对独立 sda_spawn 成员属性。
客机采集仍在自己的电脑记录本人被攻击，不能让主机代采。

包含 24 项。原有列表 16 项的索引不变；新增列表包括抚育喷涌虫、胆汁喷涌虫、钻地喷涌虫、霸王虫、两类指挥官，以及两种 Gazer 核心。
Gazer 小炮台核心和 Gazer Spire 激光塔核心：仅支持单人光能任务；这两项尚需验证。尝试生成带有原生索敌、转向和激光组件的武器实体，不生成任务目标、塔基、营地或传送门。
两种核心没有 EnemyPackage；改为加载已核对内容的原生场景资源包，等待全部资源及模型就绪，并复核炮座、传感器、激光武器定义后创建。
多人任务拒绝两种核心，避免未验证的客机建筑资源加载。原有 22 类单位仍支持房主和客机请求。
请找空旷平地，完整重启后先各生成一只，确认外观、转向和开火，再用现有采集包分别选择 Gazer / Gazer Spire 记录。核心未开始索敌或生成后被工具判为未验证时，请保留日志。
光能电塔暂未加入。友军特斯拉塔请使用支援配备召唤。
只在对应阵营生成，粉碎者和猎杀器请进入光能族任务。
穿刺虫由原生 AI 召唤触手，不单独伪造触手。需 5–10 难度；1–4 难触手权重为 0 会被拒绝。
生成前检查当前触手生成表、正权重和独立模型，保留此前低难度闪退修复。
霸王虫仅在 7–10 难度开放；发现已有实例就拒绝，每任务本工具最多生成一只。新增炮台核心尚需实机验证。
每次一只，实际创建间隔至少 3 秒；每任务本工具合计最多 32 次，客机请求不会绕过总数。
资源最多等待 90 秒，包与全部本体 / 挂载 / 召唤物模型就绪后才创建；容量不足会拒绝。
坐标没有地形射线校准，请避开坡地、悬崖和建筑。

日志 / 状态：
%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/Sekiro danger alert - Enemy Spawner.log
%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/Sekiro danger alert - Enemy Spawner-STATUS.txt
“native spawn begin”没有对应“returned”可定位到原生调用阶段，不要持续重复尝试。

离线已检查菜单、ABI / 布局 pin、请求 / ACK、精确一次、超时、死亡 / 换任务取消、请求者绑定、资源 / 召唤门禁与封包。
旧版有单人创建证据；0.3.1 新增客机请求传递、跨端模型 / AI / 攻击同步、房主迁移仍需联机实测。
仅提供本地 outputs/ 测试包，不自动发布 GitHub Release。

Uses code / research from HD2Runtime by SkyeShade (MIT; bundled license)
https://github.com/SkyeShade/HD2Runtime
PlayFab member-data ABI and lobby guards adapted from peer_channel.lua / windows_write.lua;
re-decoded against retained build 25480438 code. Independent protocol and key; Runtime not bundled.
Enemy resource/package mappings researched from FileDiver by xypwn.
https://github.com/xypwn/filediver
]===]
local KEY='SekiroDangerAlertEnemySpawner'
if rawget(_G,KEY)then return rawget(_G,KEY)end
local api={version=project.version,build=build_id,status='starting'}
rawset(_G,KEY,api)
local loader=rawget(_G,'CowboyBingusModLoader')or{}
local directory=loader.log_directory or((os.getenv('LOCALAPPDATA')or'.')..'/CowboyBingus/Helldivers2/Logs')
local menu
local function log(line)
    local f=io.open(directory..'/Sekiro danger alert - Enemy Spawner.log','ab')
    if f then f:write(os.date('!%Y-%m-%dT%H:%M:%SZ')..' '..tostring(line)..'\r\n');f:close()end
end
local function status(value)
    if api.status==value then return end
    api.status=value;log('status: '..value)
    if menu then menu:set_status(value)end
    local f=io.open(directory..'/Sekiro danger alert - Enemy Spawner-STATUS.txt','wb')
    if f then f:write(project.name..' '..project.version..' build '..build_id..'\r\n'..value..'\r\n');f:close()end
end
log(project.name..' '..project.version..' build '..build_id..' loaded; Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime')
local memory=memory_module.new(runtime)
menu=menu_module.new(catalog,log)
local origin=memory.time();local controller,remote,refused
local nonce_sequence=0
local function nonce()
    nonce_sequence=nonce_sequence+1
    return string.format('%08x%08x',os.time()%4294967296,(math.floor(memory.time()*1000000)+nonce_sequence)%4294967296)
end
local function step()
    local now=memory.time()-origin
    if not menu:register()then status('等待 ModOptionsMenu v1.2 / Waiting for ModOptionsMenu');return end
    local enemy=menu:consume()
    if now<20 then
        if enemy then status('启动准备中，20 秒后再生成 / Wait 20 seconds after startup')end
        return
    end
    if not controller and not refused then
        local ok,why=memory.verify_build(profile)
        if not ok then refused=true;status('版本校验失败 / Unsupported build: '..tostring(why));return end
        local core=core_module.new(memory,profile)
        local native=native_module.new(memory,spawn_profile,catalog,core,log)
        native:begin();native:prove()
        controller=controller_module.new(native,log,status,function(requester,success,reason)
            if remote then remote:complete(requester,success,reason)end
        end)
        local channel=channel_module.new(memory,peer_profile,log)
        remote=remote_module.new(native,controller,channel,catalog,log,status,nonce,memory.time)
        status('已就绪 / Ready')
    end
    if not controller then return end
    if enemy then remote:request(enemy,now)end
    controller:step(now)
    remote:step(now)
end
runtime.guard({name=project.name,step=step,log=log,errors=1,
    stop=function(reason)
        if controller then controller:stop(reason)end
        if remote then remote:stop()end
        status('已停止 / Stopped: '..tostring(reason))
    end}):install()
return api
