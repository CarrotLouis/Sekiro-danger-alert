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
local adapter=dofile(root..'/src/menu.lua').new(function()end,dofile(root..'/src/catalog.lua'),dofile(root..'/src/profile.lua'))
assert(adapter:register());assert(adapter.ready)
assert(adapter:automatic())
local p='peril_warning.crusher.'
local named=false
for _,mod in ipairs(state.mods)do
    if mod.id=='peril_warning.crusher' then named=mod.source=='Sekiro danger alert' end
end
assert(named,'registered menu category must use the public mod name')
assert(menu.set(p..'automatic',2));assert(not adapter:automatic())
assert(menu.set(p..'automatic',1));assert(adapter:automatic())
local appearance=adapter:appearance()
assert(appearance.x==0 and appearance.y==0 and appearance.scale==1,'upgrades preserve the original zero anchor')
assert(state.options[p..'offset_x'].kind=='slider' and state.options[p..'offset_y'].kind=='slider')
assert(menu.set(p..'offset_x',-100));assert(menu.set(p..'offset_y',100));assert(menu.set(p..'size',300))
appearance=adapter:appearance();assert(appearance.x==-1 and appearance.y==1 and appearance.scale==3)
assert(menu.set(p..'size',50));assert(adapter:appearance().scale==0.5)
assert(state.options[p..'volume'].kind=='slider')
assert(menu.get(p..'volume')==60)
assert(menu.set(p..'volume',0));assert(adapter:volume()==0)
assert(menu.set(p..'volume',100));assert(adapter:volume()==100)
-- Simulate Apply delivery through the real menu's registered callback lists.
for _,cb in ipairs(state.callbacks[p..'preview']) do cb(2,p..'preview') end
assert(menu.set(p..'volume',27))
local a=adapter:consume();assert(a.preview==2 and a.visual==nil and a.capture==nil)
assert(adapter:volume()==27 and menu.get(p..'preview')==1)
assert(next(adapter:consume())==nil)
for _,cb in ipairs(state.callbacks[p..'visual']) do cb(2,p..'visual') end
assert(adapter:consume().visual==2)
for _,cb in ipairs(state.callbacks[p..'capture']) do cb(3,p..'capture') end
assert(adapter:consume().capture==3)
for _,cb in ipairs(state.callbacks[p..'target_capture']) do cb(2,p..'target_capture') end
assert(adapter:consume().target_capture==2 and menu.get(p..'target_capture')==1)
-- set() never invokes actions, including a saved value reloaded at startup.
assert(menu.set(p..'preview',2));assert(next(adapter:consume())==nil)
print('PASS real ModOptionsMenu API v'..menu.version..': slider, applied volume, independent one-shot actions')

-- Every new requested move has its own applied toggle, and the real host accepts both pages.
local catalog=dofile(root..'/src/catalog.lua');assert(#catalog.moves==16)
for _,move in ipairs(catalog.moves)do assert(adapter:enabled(move.id))end
assert(#state.options[p..'research_move'].choices==16)
assert(menu.set(p..'move.titan_caustic_surge',false));assert(not adapter:enabled('titan_caustic_surge'))
assert(adapter:enabled('titan_cataclysmic_slam'),'one Titan move must not disable another')
assert(menu.set(p..'research_move',15));assert(adapter:research_move()=='barrager_direct_mlrs')
assert(menu.set(p..'research_context',2));assert(adapter:research_context()=='comparison')
local counts={};for _,mod in ipairs(state.mods)do counts[mod.id]=#mod.order;assert(#mod.order<=32)end
assert(counts['peril_warning.crusher']==13 and counts['peril_warning.crusher.moves']==30)
assert(menu.register_option('test.unrelated',{type='toggle',mod='Unrelated',mod_id='test.unrelated',label='Unrelated',default=false}))
assert(menu.set('test.unrelated',true))
-- Reset takes precedence over queued one-shot actions and restores every registered setting.
for id,default in pairs(adapter.defaults)do
    if type(default)=='boolean' then assert(menu.set(id,not default))end
end
for _,cb in ipairs(state.callbacks[p..'preview'])do cb(2)end
for _,cb in ipairs(state.callbacks[p..'research_capture'])do cb(2)end
for _,cb in ipairs(state.callbacks[p..'reset'])do cb(2)end
local actions=adapter:consume();assert(actions.reset==2 and not actions.preview and not actions.research_capture)
for id,default in pairs(adapter.defaults)do assert(menu.get(id)==default,'reset missed '..id)end
assert(menu.get('test.unrelated')==true and next(adapter:consume())==nil)
print('PASS 30 independent move toggles, 16 capture targets, real 32-row limit, cross-page reset and action priority')
