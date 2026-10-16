local root,upstream=arg[1],arg[2]
local Text=dofile(upstream..'/src/bingus_text.lua')
_G.mom_text={module=Text,locales={en=dofile(upstream..'/locales/en.lua'),bundled={}}}
_G.mom_files=setmetatable({},{__index=function(t,k)local f=assert(loadfile(upstream..'/src/'..k..'.lua'));rawset(t,k,f);return f end})
_G.update=function()end;_G.CowboyBingusModLoader={log_directory=root..'/build/test_logs'}
Text.registry().steam_language='en';dofile(upstream..'/src/mod_options_menu.lua')
local menu=ModOptionsMenu
local function upvalue(f,key)
    for i=1,80 do local k,v=debug.getupvalue(f,i);if k==key then return v end end;error('missing '..key)
end
local state=upvalue(menu.register_option,'state');local p='peril_warning.diagnostics.'
upvalue(menu.register_option,'saved_values')()[p..'action']='2'
local catalog=dofile(root..'/src/catalog.lua');local profile=dofile(root..'/src/profile.lua')
local t=21;local start_count,stop_count,mark_count,read_count,poll_count=0,0,0,0,0
local last_start;local collector={active=false,cost=0}
function collector:start(mode,move,context)
    if self.active then self:stop('restarted')end
    self.active=true;start_count=start_count+1;last_start={mode,move,context}
end
function collector:stop()if self.active then stop_count=stop_count+1 end;self.active=false end
function collector:mark()mark_count=mark_count+1 end
function collector:step()read_count=read_count+1 end
function collector:record_detection(snapshot)assert(snapshot.t==21)end
local fake_capture={new=function(_,_,_,clock,_,c)
    assert(clock()==21 and #c.moves==20 and #c.resources>=#catalog.resources);return collector
end}
local key_down=false;local marker_allocated=0
local marker={new=function()marker_allocated=marker_allocated+1;return function()
    poll_count=poll_count+1;local edge=key_down;key_down=false;return edge
end end}
local extension={tag='research'}
local instrument=dofile(root..'/tools/diagnostics/src/instrument.lua').new(extension,fake_capture,{},marker,catalog,profile,'0.8.0')
local adapter=dofile(root..'/src/menu.lua').new(function()end,catalog,profile,dofile(root..'/src/localization.lua').new(dofile(root..'/build/locales.lua')))
instrument:attach_menu(adapter,function()end);assert(adapter:register())
assert(instrument.native_extension==extension and marker_allocated==0 and start_count==0)
local count=0
for _,mod in ipairs(state.mods)do if mod.id=='peril_warning.diagnostics'then
    count=#mod.order;assert(count==6)
    for _,option in ipairs(mod.order)do if option.kind=='choice'then assert(#option.choices<=16)end end
end end
assert(count==6 and menu.get(p..'action')==1)
for _,callback in ipairs(state.callbacks[p..'action'])do callback(2)end
for _,callback in ipairs(state.callbacks['peril_warning.crusher.reset'])do callback(2)end
local reset=adapter:consume()
assert(reset.reset==2 and not instrument.pending,'reset before native initialization must cancel queued collection')
instrument:initialize({}, {snapshot={t=21}},function()return t end,function()end,'unused')
instrument:step(t,{});assert(marker_allocated==0 and poll_count==0 and read_count==0)
local function apply(value)for _,callback in ipairs(state.callbacks[p..'action'])do callback(value)end end
apply(2);instrument:step(t,{})
assert(start_count==1 and last_start[2]=='harvester_tesla_ripper' and last_start[3]=='requested')
assert(menu.get(p..'action')==1 and marker_allocated==1 and read_count==1)
key_down=true;t=21.05;instrument:step(t,{});assert(mark_count==1 and read_count==1)
assert(menu.set(p..'context',2));apply(2);t=21.1;instrument:step(t,{})
assert(start_count==2 and stop_count==1 and last_start[3]=='comparison')
apply(3);instrument:step(t,{});assert(not collector.active and stop_count==2)
local before=poll_count;t=22;instrument:step(t,{});assert(poll_count==before,'stopped capture must not poll keys')
assert(menu.set(p..'group',2))
local factory_index
for i,move in ipairs(catalog.moves)do if move.faction==8 then
    factory_index=(factory_index or 0)+1
    if move.id=='factory_fusion_repeater'then break end
end end
assert(menu.set(p..'bots',factory_index));apply(2)
assert(menu.set(p..'group',3));instrument:step(t,{})
assert(last_start[2]=='factory_fusion_repeater','APPLY must freeze the selected target')
instrument:step(t,{reset=2});assert(not collector.active and menu.get(p..'group')==3 and menu.get(p..'context')==1)
instrument:stop('shutdown')
collector.stop_reason='eight read failures';collector.successful_samples=0;collector.marker_count=0
local description=state.options[p..'action'].sources.description()
assert(description:find('eight read failures',1,true)and description:find('有效样本 0',1,true))
collector.active=true;collector.successful_samples=12;collector.marker_count=2
description=state.options[p..'action'].sources.description()
assert(description:find('正在采集',1,true)and description:find('有效样本 12',1,true)and description:find('F8 2',1,true))
print('PASS real MOM diagnostic page: bounded faction lists, Apply-only capture, F8 gating, restart/stop/reset and frozen selection')
