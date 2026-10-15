local root=arg[1]
local file=assert(io.open(root..'/src/entry.lua','rb'));local source=file:read('*a');file:close()
local factory=assert(loadstring('return function(project,runtime,memory_module,menu_module,catalog,profile,assets,audio_module,native_module,overlay_module,detector_module,instrumentation)\n'..source..'\nend'))()
_G.CowboyBingusModLoader={log_directory=root..'/build/test_logs'}
local t=0;local actions={};local frame,trigger,allowed,delay
local volume=37;local sounds,visuals,steps,resets,releases,closed=0,0,0,0,0,0
local menu={register=function()return true end,consume=function()local out=actions;actions={};return out end,
    volume=function()return volume end,appearance=function()return {x=0,y=0,scale=1}end,
    enabled=function(_,move)return move~='disabled' end,delay=function(_,move)return move=='harvester_tesla_ripper'and .7 or 0 end}
local memory={time=function()return t end,verify_build=function()return true end}
local native={begin=function()end}
local overlay={ready=false,warmup=function(self)self.ready=true;return true end,
    play=function()visuals=visuals+1;return true end,step=function()end,close=function()closed=closed+1 end}
local audio={play=function(_,v)assert(v==volume);sounds=sounds+1 end,poll=function()end,
    release=function()releases=releases+1 end}
local detector={step=function()steps=steps+1 end,reset=function()resets=resets+1 end}
local runtime={guard=function(spec)frame=spec;return {install=function()return spec end}end}
local params={version='1.0.0'}
local received_extension
local function load(instrument)
    return factory(params,runtime,{new=function()return memory end},{new=function()return menu end},{},{pins={}},
        {pcm='',rate=48000,channels=2},{new=function()return audio end},{new=function(_,_,ext)received_extension=ext;return native end},
        {new=function()return overlay end},{new=function(_,_,_,callback,enabled,delayed)trigger=callback;allowed=enabled;delay=delayed;return detector end},instrument)
end
local api=load();assert(load()==api,'duplicate load must reuse the cached release')
actions={preview=2};frame.step();assert(sounds==1 and visuals==0 and steps==0)
t=20;frame.step();assert(overlay.ready and steps==1 and api.automatic_warning)
assert(allowed('enabled') and not allowed('disabled'))
assert(delay('harvester_tesla_ripper')==.7 and delay('other')==0,'entry connects the applied per-move delay')
trigger({sample_time=20});trigger({sample_time=20});assert(sounds==2 and visuals==1,'same batch must merge sound and visual')
actions={visual=2};t=21;frame.step();t=23.9;frame.step();assert(visuals==1)
t=24;frame.step();assert(visuals==2 and sounds==3)
actions={visual=2};t=25;frame.step()
actions={reset=2};t=26;frame.step();assert(resets==1)
t=29;frame.step();assert(visuals==2,'reset must cancel a scheduled preview')
detector.disabled=true;t=30;local before=steps;frame.step()
assert(not api.automatic_warning and steps==before)
frame.stop('test');assert(releases==1 and closed==1)
assert(not source:find('capture',1,true) and not source:find('marker',1,true) and not source:find('automatic_trigger',1,true))
_G.SekiroDangerAlert=nil
local attached,initialized,ticked,stopped=0,0,0,0
local instrument={native_extension={}}
function instrument:attach_menu()attached=attached+1 end
function instrument:initialize(actual,actual_detector,clock)
    assert(actual==native and actual_detector==detector and clock()==20);initialized=initialized+1
end
function instrument:step()ticked=ticked+1;if ticked==2 then error('diagnostic I/O failure')end end
function instrument:stop()stopped=stopped+1 end
t=50;load(instrument);assert(attached==1 and initialized==0)
t=70;frame.step();assert(initialized==1 and ticked==1 and received_extension==instrument.native_extension)
assert(detector.disabled and not SekiroDangerAlert.automatic_warning,'collection lifecycle is independent of disabled attack polling')
t=71;frame.step();assert(ticked==2 and stopped==1)
t=72;frame.step();assert(ticked==2,'a failed optional collector stays stopped without stopping the main guard')
frame.stop('test');_G.SekiroDangerAlert=nil
print('PASS release entry: automatic warning, retained previews/volume, batch merging, reset cancellation, no capture path and cleanup')
