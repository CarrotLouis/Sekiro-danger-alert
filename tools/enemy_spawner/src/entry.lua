local GUIDE=[===[Sekiro danger alert - Enemy Spawner — 测试说明

依赖：Bingus Shared Loader v18+、Mod Options Menu v1.2。
这是独立测试工具，可与 Sekiro danger alert 同时启用。

1. 导入并启用本 ZIP，启动游戏后等待至少 20 秒。
2. 进入对应阵营的单人任务，找开阔平地，平视前方。
3. 在 MODS → Sekiro danger alert - Enemy Spawner 中选择敌人。
4. 将“生成一只”改为“生成一只”，点击 APPLY 并关闭设置。
5. 首次使用会等待资源加载；就绪后再等 3 秒，在镜头前方约 20m 生成一只。
6. 下次生成时再次选择“生成一只”并 APPLY。切换敌人本身不生成。
   重开设置并选中“生成一只”，说明区可查看当前状态。

包含用户要求的 14 类敌人。穿刺虫由自身 AI 召唤触手；不单独伪造触手。
穿刺虫请在 5–10 难度测试。1–4 难度的原生触手生成权重为 0，工具会拒绝生成并显示原因。
生成前还会检查当前任务的触手生成表和独立触手模型；仅加载本体资源无法保证召唤安全。
敌人保留原生血量、武器和行为，创建时目标指向本人。
仅限对应阵营的单人主持任务；菜单选择、资源等待和版本检查不会直接生成实体。
每次一只、间隔至少 3 秒，每任务最多 32 次；实体容量不足会拒绝。
资源最多等待 90 秒；潜兵死亡或场景变化会取消待执行请求。
坐标按镜头水平前方和当前高度计算，没有地形射线校准，请避开坡地、悬崖和建筑。

状态和日志：
%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/Sekiro danger alert - Enemy Spawner.log
%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/Sekiro danger alert - Enemy Spawner-STATUS.txt
“native spawn begin”没有对应“returned”可定位到原生调用阶段；不要持续重复尝试。

离线已检查菜单、一次性动作、资源 / 召唤门禁、生成参数和封包。
日志已确认多种强袭虫和穿刺虫本体创建；穿刺虫 1 难召唤闪退已从两次转储定位。
本版对危险条件的拒绝经过离线验证；5 难召唤触手、其余完整行为和地形落点仍需实测。
不自动发布 GitHub Release；成品仅在本地 outputs/。

Uses code / research from HD2Runtime by SkyeShade
https://github.com/SkyeShade/HD2Runtime
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
local origin=memory.time();local controller,refused
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
        controller=controller_module.new(native,log,status)
        status('已就绪 / Ready')
    end
    if not controller then return end
    if enemy then controller:request(enemy,now)end
    controller:step(now)
end
runtime.guard({name=project.name,step=step,log=log,errors=1,
    stop=function(reason)
        if controller then controller:stop(reason)end
        status('已停止 / Stopped: '..tostring(reason))
    end}):install()
return api
