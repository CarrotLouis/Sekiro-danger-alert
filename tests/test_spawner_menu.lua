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
-- Only the curated labels matter for this host contract; native facts are checked separately.
local catalog={enemies={}}
for i=1,16 do catalog.enemies[i]={id='enemy_'..i,label='Enemy '..i}end
local adapter=dofile(root..'/tools/enemy_spawner/src/menu.lua').new(catalog,function()end)
assert(adapter:register()and adapter.ready)
local p='peril_warning.enemy_spawner.'
assert(#state.options[p..'enemy'].choices==16)
assert(menu.get(p..'spawn')==1 and adapter:consume()==nil)
assert(menu.set(p..'enemy',16))
assert(adapter:consume()==nil,'enemy selection must not spawn')
assert(menu.set(p..'spawn',2))
assert(adapter:consume()==nil,'saved or programmatic actions must not spawn')
for _,callback in ipairs(state.callbacks[p..'spawn'])do callback(2,p..'spawn')end
assert(adapter:consume().id=='enemy_16')
assert(menu.get(p..'spawn')==1 and adapter:consume()==nil,'action resets and consumes once')
-- Selection at APPLY is fixed even if another selection is made before the update.
assert(menu.set(p..'enemy',2))
for _,callback in ipairs(state.callbacks[p..'spawn'])do callback(2)end
assert(menu.set(p..'enemy',9))
assert(adapter:consume().id=='enemy_2')
local n=0
for _,mod in ipairs(state.mods)do
    if mod.id=='peril_warning.enemy_spawner'then
        assert(mod.source=='Sekiro danger alert - Enemy Spawner'and #mod.order==2);n=n+1
    end
end
assert(n==1)
print('PASS real ModOptionsMenu: 16 selections, 2 rows, Apply-only one-shot action, saved-action suppression')
