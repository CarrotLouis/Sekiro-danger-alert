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
local adapter=dofile(root..'/src/menu.lua').new(function()end)
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
-- set() never invokes actions, including a saved value reloaded at startup.
assert(menu.set(p..'preview',2));assert(next(adapter:consume())==nil)
print('PASS real ModOptionsMenu API v'..menu.version..': slider, applied volume, independent one-shot actions')
