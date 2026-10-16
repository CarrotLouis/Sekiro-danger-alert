local KEY='SekiroDangerAlert'
if rawget(_G,KEY) then return rawget(_G,KEY) end
local api={version=project.version,build=build_id,automatic_warning=true,status='starting'}
rawset(_G,KEY,api)
local loader=rawget(_G,'CowboyBingusModLoader') or {}
local directory=loader.log_directory or ((os.getenv('LOCALAPPDATA') or '.')..'/CowboyBingus/Helldivers2/Logs')
local function log(line)
    local f=io.open(directory..'/Sekiro danger alert.log','ab')
    if f then f:write(os.date('!%Y-%m-%dT%H:%M:%SZ')..' '..tostring(line)..'\r\n');f:close()end
end
local function status(s)
    if api.status==s then return end
    api.status=s;log('status: '..s)
end
log('Sekiro danger alert loaded '..api.version..' build '..tostring(build_id or'source')
    ..'; Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime')
local text=localization_module.new(locales)
local menu=menu_module.new(log,catalog,profile,text)
local memory=memory_module.new(runtime)
local audio,native,overlay,detector
local last_warning_sample
local origin=memory.time();local next_attack_sample=0;local pending_visual=nil;local refused=false
local function now()return memory.time()-origin end
local function play_audio()
    if not audio then audio=audio_module.new(assets.pcm,assets.rate,assets.channels,log)end
    return audio:play(menu:volume())
end
local function initialize()
    local ok,why=memory.verify_build(profile)
    if not ok then refused=true;status('unsupported build: '..tostring(why));return end
    for _,pin in ipairs(profile.pins)do
        local base
        if pin.module=='exe' then base=memory.module(nil)else base=memory.module('game.dll')end
        assert(base and memory.read(base+pin.rva,#pin.bytes)==pin.bytes,'runtime layout mismatch: '..pin.label)
    end
    native=native_module.new(memory,profile)
    overlay=overlay_module.new(native,assets,log,function()return menu:appearance()end)
    detector=detector_module.new(native,profile,log,function(event)
        if event.sample_time~=last_warning_sample then
            last_warning_sample=event.sample_time;overlay:play(now());play_audio()
        end
    end,function(move)return menu:enabled(move)end,function(move)return menu:delay(move)end,false)
    status('build matched; preparing visual')
end
local function visual_step(t)
    if not overlay or api.visual_failed then return end
    local ok,why=pcall(function()
        native:begin()
        if not overlay.ready and overlay:warmup()then status('ready: head tracking and targeted attack warning')end
        if pending_visual and t>=pending_visual then
            pending_visual=nil
            if overlay:play(t)then play_audio()end
        end
        overlay:step(t)
    end)
    if not ok then
        api.visual_failed=true;log('visual stopped: '..tostring(why));pcall(overlay.close,overlay)
        status('visual unavailable; see log')
    end
end
local function step()
    local t=now()
    if not menu:register()then status('waiting for ModOptionsMenu v1.2 / API version 3');return end
    local actions=menu:consume()
    if actions.reset==2 then
        if detector then detector:reset()end
        pending_visual=nil;last_warning_sample=nil
    end
    if actions.preview==2 then play_audio()end
    if audio then audio:poll()end
    if t<20 then return end
    if not native and not refused then initialize()end
    if not native then return end
    if actions.visual==2 then pending_visual=t+3 end
    visual_step(t)
    api.automatic_warning=not detector.disabled
    if api.automatic_warning and t>=next_attack_sample then
        detector:step(t);next_attack_sample=t+0.05
        if detector.disabled then api.automatic_warning=false;status('automatic warning unavailable; see log')end
    end
end
local function stop(reason)
    if overlay then pcall(overlay.close,overlay)end
    if audio then pcall(audio.release,audio)end
    status('stopped: '..tostring(reason))
end
api.guard=runtime.guard({name=KEY,step=step,stop=stop,log=log,errors=3}):install()
return api
