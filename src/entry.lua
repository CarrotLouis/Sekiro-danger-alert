local KEY='SekiroDangerAlert'
if rawget(_G,KEY) then return rawget(_G,KEY) end
local api={version=project.version,automatic_warning=true,status='starting'}
rawset(_G,KEY,api)
local loader=rawget(_G,'CowboyBingusModLoader') or {}
local directory=loader.log_directory or ((os.getenv('LOCALAPPDATA') or '.')..'/CowboyBingus/Helldivers2/Logs')
local function log(line)
    local f=io.open(directory..'/Sekiro danger alert.log','ab')
    if f then f:write(os.date('!%Y-%m-%dT%H:%M:%SZ')..' '..tostring(line)..'\r\n');f:close() end
end
local function status(s)
    if api.status==s then return end
    api.status=s;log('status: '..s)
    local f=io.open(directory..'/Sekiro danger alert-STATUS.txt','wb')
    if f then
        f:write('Sekiro danger alert '..api.version..' | targeted attack warning\r\n'..s..'\r\n',
            'Automatic warning: 16 additional moves plus Crusher / heavy cannon; local entity target; no range gate.\r\n',
            'Visual: game-native GUI; live local-avatar head projection.\r\n',
            'Sound: independent PCM playback, not a Wwise event.\r\n');f:close()
    end
end
log('Sekiro danger alert loaded '..api.version..'; Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime')
local menu=menu_module.new(log,catalog,profile)
local memory=memory_module.new(runtime)
local audio,native,overlay,capture,key,detector
local last_warning_sample
local origin=memory.time();local next_sample=0;local next_attack_sample=0;local pending_visual=nil;local refused=false
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
    overlay=overlay_module.new(native,assets,log,function()return menu:appearance()end)
    capture=capture_module.new(native,directory,log,now,tracking_module,catalog,api.version)
    detector=detector_module.new(native,profile,log,function(event)
        log('automatic_trigger '..capture_module.json(event))
        if event.sample_time~=last_warning_sample then
            last_warning_sample=event.sample_time;overlay:play(now());play_audio()
        end
    end,function(move)return menu:enabled(move)end)
    key=marker_module.new()
    status('build matched; preparing visual; capture is ready')
end
local function visual_step(t)
    if not overlay or api.visual_failed then return end
    local ok,why=pcall(function()
        native:begin()
        if not overlay.ready then
            if overlay:warmup() then status('ready: head tracking and automatic targeted attack warning') end
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
    if actions.reset==2 then
        capture:stop('defaults restored');detector:reset();pending_visual=nil;last_warning_sample=nil
    end
    if actions.visual==2 then pending_visual=t+3;log('visual preview scheduled in three seconds') end
    if actions.capture==2 then capture:start() end
    if actions.capture==3 then capture:stop('user stopped') end
    if actions.target_capture==2 then capture:start('targeting') end
    if actions.target_capture==3 then capture:stop('user stopped') end
    if actions.research_capture==2 then capture:start('combat',menu:research_move(),menu:research_context()) end
    if actions.research_capture==3 then capture:stop('user stopped') end
    if capture.active and key() then
        capture:mark()
        if capture.mode=='crusher' then pending_visual=t end
        log('F8 user attack marker ('..capture.mode..')')
    end
    visual_step(t)
    api.automatic_warning=menu:automatic() and not detector.disabled
    if api.automatic_warning and t>=next_attack_sample then
        detector:step(t);next_attack_sample=t+0.05
        capture:record_detection(detector.snapshot)
        if detector.disabled then api.automatic_warning=false;status('automatic warning unavailable; see log') end
    elseif not menu:automatic() then
        detector:reset()
    end
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
