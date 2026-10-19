local root,upstream=arg[1],arg[2]
local Text=dofile(upstream..'/src/bingus_text.lua')
_G.mom_text={module=Text,locales={en=dofile(upstream..'/locales/en.lua'),bundled={}}}
_G.mom_files=setmetatable({},{__index=function(t,k)local f=assert(loadfile(upstream..'/src/'..k..'.lua'));rawset(t,k,f);return f end})
_G.update=function()end
_G.CowboyBingusModLoader={log_directory=root..'/build/test_logs'}
Text.registry().steam_language='en'
dofile(upstream..'/src/mod_options_menu.lua')
local menu=assert(ModOptionsMenu)
local function upvalue(f,key)
    for i=1,80 do local k,v=debug.getupvalue(f,i);if k==key then return v end end
    error('missing upvalue '..key)
end
local state=upvalue(menu.register_option,'state')
local original=dofile(root..'/src/catalog.lua')
local full=dofile(root..'/build/diagnostics/catalog.lua')
local profile=dofile(root..'/src/profile.lua')
local capture={}
function capture.new()
    return {active=false,start=function(_,mode,id,context,scenario)capture.selected={mode=mode,id=id,context=context,scenario=scenario}end,
        stop=function(c)c.active=false end,step=function()end,record_detection=function()end}
end
local marked={}
local marker={new=function(bindings)
    assert(#bindings==4 and bindings[1].key=='-')
    return function()return {'-','=','[',']'}end
end}
local instrument=dofile(root..'/tools/diagnostics/src/instrument.lua').new({},capture,{},marker,full,profile,'1.1.0-dev.2')
local texts=dofile(root..'/build/locales.lua')
local text=dofile(root..'/src/localization.lua').new(texts)
local adapter=dofile(root..'/src/menu.lua').new(function()end,original,profile,text)
instrument:attach_menu(adapter,function()end)
assert(adapter:register()and instrument.ready)
local p='peril_warning.diagnostics.'
assert(#state.options[p..'group'].choices==4)
for _,key in ipairs({'bugs','bots','illuminate','bugs_new'})do
    local n=#state.options[p..key].choices
    assert(n>=2 and n<=16,'each collection list must fit the actual framework')
end
assert(#state.options[p..'bugs_new'].choices==10)
assert(#state.options[p..'illuminate'].choices==7)
assert(#state.options[p..'context'].choices==7 and #state.options[p..'action'].choices==4)
for _,category in ipairs(state.mods)do
    if category.id=='peril_warning.crusher'then assert(#category.order==29)end
    if category.id=='peril_warning.diagnostics'then assert(#category.order==7)end
end
instrument:initialize({}, {snapshot=nil}, function()return 0 end,function()end,root..'/build/test_logs')
assert(not capture.selected)
assert(menu.set(p..'group',4));assert(menu.set(p..'bugs_new',5))
assert(menu.set(p..'action',2));assert(not capture.selected,'programmatic saved actions do not start recording')
for _,callback in ipairs(state.callbacks[p..'action'])do callback(2)end
instrument:step(0,{})
assert(capture.selected.id=='hive_lord_all','a legacy Hive selection must redirect to joint four-key capture')
assert(menu.get(p..'action')==1)
assert(menu.set(p..'group',3));assert(menu.set(p..'illuminate',6))
for _,callback in ipairs(state.callbacks[p..'action'])do callback(2)end
instrument:step(1,{})
assert(capture.selected.id=='tesla_turret_arc','friendly tower belongs to the explicitly labeled mixed group')
assert(menu.set(p..'group',4));assert(menu.set(p..'bugs_new',9))
for _,callback in ipairs(state.callbacks[p..'action'])do callback(2)end
instrument:step(2,{})
assert(capture.selected.id=='charger_charge')
local combined;for _,move in ipairs(full.moves)do if move.id=='hive_lord_all'then combined=move end end
instrument.collector.active=true;instrument.collector.marker_bindings=combined.manual_markers
function instrument.collector:mark(key)marked[#marked+1]=key end
instrument:step(3,{})
assert(table.concat(marked,' ' )=='- = [ ]','the lifecycle routes four independent keys to the collector')
for _,callback in ipairs(state.callbacks[p..'action'])do callback(4)end
local chosen=capture.selected
instrument:step(3.05,{})
assert(instrument:consume_preview()and not instrument:consume_preview())
assert(capture.selected==chosen and menu.get(p..'action')==1,'preview must not restart an active recording')
assert(menu.set(p..'context',5))
for _,callback in ipairs(state.callbacks[p..'action'])do callback(2)end
instrument:step(4,{})
assert(capture.selected.scenario=='bastion_gunner'and capture.selected.context=='requested')
assert(menu.set(p..'context',7))
for _,callback in ipairs(state.callbacks[p..'action'])do callback(2)end
instrument:step(5,{})
assert(capture.selected.scenario=='empty_vehicle'and capture.selected.context=='comparison')
instrument:reset();assert(instrument.pending==nil)
local collector=dofile(root..'/tools/diagnostics/src/capture.lua').new({},root..'/build/test_logs',function()end,
    function()return 23 end,{new=function()return {}end},full,'1.1.0-dev.2')
collector:start('combat','hive_lord_body_slam_emerging','requested')
collector:stop('fixture complete')
local f=assert(io.open(collector.path,'rb'));local contents=f:read('*a');f:close()
assert(contents:find('"requested_controls":["hive_lord_body_slam","hive_lord_bile_rain"]',1,true))
assert(contents:find('"requested_status":"pending_capture"',1,true))
assert(contents:find('"requested_warning_enabled":false',1,true),'a pending scope must never claim new live warning support')
print('PASS actual MOM: four groups, bounded 10/7-item lists, 14 scopes, seven contexts, non-restarting preview, frozen vehicle scenarios and untouched 29-row warning page')
