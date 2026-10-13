local KEY='PerilWarningCrusher01'
if rawget(_G,KEY) then return rawget(_G,KEY) end
local api={version='0.1.0',automatic_warning=false,status='starting'}
rawset(_G,KEY,api)
local loader=rawget(_G,'CowboyBingusModLoader') or {}
local directory=loader.log_directory or ((os.getenv('LOCALAPPDATA') or '.')..'/CowboyBingus/Helldivers2/Logs')
local function log(line)
    local f=io.open(directory..'/PerilWarning.log','ab')
    if f then f:write(os.date('!%Y-%m-%dT%H:%M:%SZ')..' '..tostring(line)..'\r\n');f:close() end
end
local function status(s)
    if api.status==s then return end
    api.status=s;log('status: '..s)
    local f=io.open(directory..'/PerilWarning-STATUS.txt','wb')
    if f then
        f:write('Peril Warning 0.1.0 | Crusher capture + manual preview\r\n'..s..'\r\n',
            'Automatic attack warning: NOT ENABLED; awaiting captured attack identity.\r\n',
            'Visual: game-native GUI; fixed preview position, not head tracking yet.\r\n',
            'Sound: independent PCM playback, not a Wwise event.\r\n');f:close()
    end
end
log('loaded 0.1.0; Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime')
local menu=menu_module.new(log)
local memory=memory_module.new(runtime)
local audio,native,overlay,capture,key
local origin=memory.time();local next_sample=0;local pending_visual=nil;local refused=false
local function now()return memory.time()-origin end
local function play_audio()
    if not audio then audio=audio_module.new(assets.pcm,assets.rate,assets.channels,log) end
    return audio:play(menu:volume())
end
local function initialize()
    local ok,why=memory.verify_build(profile)
    if not ok then refused=true;status('unsupported build: '..tostring(why));return end
    for _,pin in ipairs(profile.pins) do
        local base
        if pin.module=='exe' then base=memory.module(nil) else base=memory.module('game.dll') end
        assert(base and memory.read(base+pin.rva,#pin.bytes)==pin.bytes,'runtime layout mismatch: '..pin.label)
    end
    native=native_module.new(memory,profile)
    overlay=overlay_module.new(native,assets,log)
    capture=capture_module.new(native,directory,log,now)
    key=marker_module.new()
    status('build matched; preparing visual; capture is ready')
end
local function visual_step(t)
    if not overlay or api.visual_failed then return end
    local ok,why=pcall(function()
        native:begin()
        if not overlay.ready then
            if overlay:warmup() then status('ready: preview and capture; automatic attack recognition pending') end
        end
        if pending_visual and t>=pending_visual then
            pending_visual=nil
            if overlay:play(t) then play_audio();log('manual visual preview') end
        end
        overlay:step(t)
    end)
    if not ok then
        api.visual_failed=true;log('visual stopped: '..tostring(why));pcall(overlay.close,overlay)
        status('visual unavailable; audio preview and capture remain available; see log')
    end
end
local function step()
    local t=now()
    if not menu:register() then status('waiting for ModOptionsMenu v1.2 / API version 3');return end
    local actions=menu:consume()
    if actions.preview==2 then play_audio() end
    if audio then audio:poll() end
    if t<20 then
        if next(actions) then log('native preview/capture waits until 20 seconds after load') end
        return
    end
    if not native and not refused then initialize() end
    if not native then return end
    if actions.visual==2 then pending_visual=t+3;log('visual preview scheduled in three seconds') end
    if actions.capture==2 then capture:start() end
    if actions.capture==3 then capture:stop('user stopped') end
    if capture.active and key() then
        capture:mark();pending_visual=t;log('F8 user attack marker')
    end
    visual_step(t)
    if capture.active and t>=next_sample then
        capture:step()
        next_sample=t+((capture.cost or 0)>0.005 and 0.15 or 0.05)
    end
end
local function stop(reason)
    if capture then capture:stop(reason) end
    if overlay then pcall(overlay.close,overlay) end
    if audio then pcall(audio.release,audio) end
    status('stopped: '..tostring(reason))
end
api.guard=runtime.guard({name=KEY,step=step,stop=stop,log=log,errors=3}):install()
return api
