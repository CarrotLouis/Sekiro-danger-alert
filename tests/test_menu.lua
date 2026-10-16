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
local p='peril_warning.crusher.'
local saved=upvalue(menu.register_option,'saved_values')()
-- Real persisted values from the old two-page build, including retired actions.
saved[p..'offset_x']='25';saved[p..'size']='150';saved[p..'volume']='42'
saved[p..'move.titan_caustic_surge']='false';saved[p..'move.crusher_1411']='false'
saved[p..'delay.harvester_tesla_ripper']='0.7'
for _,key in ipairs({'automatic','capture','target_capture','research_capture','preview','visual','reset'})do saved[p..key]='2'end
local catalog=dofile(root..'/src/catalog.lua');local profile=dofile(root..'/src/profile.lua')
local texts=dofile(root..'/build/locales.lua')
local text=dofile(root..'/src/localization.lua').new(texts)
local adapter=dofile(root..'/src/menu.lua').new(function()end,catalog,profile,text)
assert(adapter:register() and adapter.ready)
assert(adapter:volume()==42 and adapter:appearance().x==.25 and adapter:appearance().scale==1.5)
assert(not adapter:enabled('titan_caustic_surge') and adapter:enabled('titan_cataclysmic_slam'))
assert(adapter:enabled('crusher_1411'),'new combined Crusher control defaults on')
assert(next(adapter:consume())==nil,'persisted actions must never replay on startup')
for _,key in ipairs({'preview','visual','reset'})do assert(menu.get(p..key)==1)end
for _,key in ipairs({'automatic','capture','target_capture','research_move','research_context','research_capture'})do
    assert(not state.options[p..key] and not state.callbacks[p..key],'retired control still registered: '..key)
end
local category
for _,mod in ipairs(state.mods)do
    assert(mod.id~='peril_warning.crusher.moves','release must not create a second page')
    if mod.id=='peril_warning.crusher'then category=mod end
end
assert(category and category.source=='Sekiro danger alert' and #category.order==29)
assert(menu.max_options==32 and #category.order<=menu.max_options)
local switches=0
for _,option in ipairs(category.order)do if option.kind=='toggle'then switches=switches+1 end end
assert(switches==20)
local expected={};for _,faction in ipairs({2,8,4})do
    if faction==8 then expected[#expected+1]='cannon_preparation'end
    if faction==4 then expected[#expected+1]='crusher_melee'end
    for _,move in ipairs(catalog.moves)do if move.faction==faction then expected[#expected+1]=move.id end end
end
local index=0
for _,option in ipairs(category.order)do if option.kind=='toggle'then
    index=index+1;assert(option.id==p..'move.'..expected[index],'faction order changed')
end end
assert(expected[#expected-2]=='crusher_melee'and expected[#expected-1]=='harvester_tesla_ripper'
    and expected[#expected]=='harvester_disintegration_beamer')
assert(state.options[p..'move.crusher_melee'].label=='Crusher · Dangerous melee')
for id in pairs(profile.attack_states)do assert(not state.options[p..'move.crusher_'..id])end
assert(menu.set(p..'move.crusher_melee',false))
local detector=dofile(root..'/src/detector.lua').new({},profile,function()end,function()error('disabled Crusher triggered')end,
    function(move)return adapter:enabled(move)end)
for id in pairs(profile.attack_states)do
    assert(not adapter:enabled('crusher_'..id))
    detector:reset()
    local result=detector:observe({{entity=1,id=id,slot=1,time=.02,speed=1}},
        {[1]={id=1,unit=100,resource=profile.crusher_resource,owned=true,alive=true,
            ai={target=7,has_target=true,tracks_entity=true}}},0,{id=7})
    assert(result[1].reason=='move_disabled','combined control missed branch '..id)
end
assert(menu.set(p..'move.crusher_melee',true))
for id in pairs(profile.attack_states)do assert(adapter:enabled('crusher_'..id))end
assert(not adapter:enabled('crusher_1409') and not adapter:enabled('unknown'))
assert(adapter:enabled('cannon_preparation') and adapter:enabled('titan_cataclysmic_slam'))
for _,move in ipairs(catalog.moves)do assert(menu.set(p..'move.'..move.id,true))end
assert(state.options[p..'offset_x'].kind=='slider' and state.options[p..'offset_y'].kind=='slider')
assert(menu.set(p..'offset_x',-100));assert(menu.set(p..'offset_y',100));assert(menu.set(p..'size',300))
local appearance=adapter:appearance();assert(appearance.x==-1 and appearance.y==1 and appearance.scale==3)
assert(menu.set(p..'size',50));assert(adapter:appearance().scale==.5)
assert(menu.set(p..'volume',0));assert(adapter:volume()==0)
assert(menu.set(p..'volume',100));assert(adapter:volume()==100)
assert(adapter:delay('harvester_tesla_ripper')==.7 and adapter:delay('harvester_disintegration_beamer')==0)
assert(adapter:delay('crusher_1411')==0)
for _,move in ipairs({'harvester_tesla_ripper','harvester_disintegration_beamer'})do
    local o=state.options[p..'delay.'..move]
    assert(o.kind=='slider'and o.min==0 and o.max==2 and o.step==.1 and o.default==0)
    assert(menu.set(p..'delay.'..move,2));assert(adapter:delay(move)==2)
    assert(menu.set(p..'delay.'..move,.1));assert(adapter:delay(move)==.1)
end
for _,cb in ipairs(state.callbacks[p..'preview'])do cb(2)end
assert(menu.set(p..'volume',27))
local actions=adapter:consume();assert(actions.preview==2 and not actions.visual and not actions.capture)
assert(adapter:volume()==27 and menu.get(p..'preview')==1 and next(adapter:consume())==nil)
for _,cb in ipairs(state.callbacks[p..'visual'])do cb(2)end
assert(adapter:consume().visual==2)
assert(menu.set(p..'preview',2));assert(next(adapter:consume())==nil)
assert(menu.register_option('test.unrelated',{type='toggle',mod='Unrelated',mod_id='test.unrelated',label='Unrelated',default=false}))
assert(menu.set('test.unrelated',true))
for id,default in pairs(adapter.defaults)do if type(default)=='boolean'then assert(menu.set(id,false))end end
for _,key in ipairs({'preview','visual','reset'})do for _,cb in ipairs(state.callbacks[p..key])do cb(2)end end
local reset=adapter:consume();assert(reset.reset==2 and not reset.preview and not reset.visual)
local count=0
for id,default in pairs(adapter.defaults)do count=count+1;assert(menu.get(id)==default,'reset missed '..id)end
assert(count==29 and menu.get('test.unrelated')==true and next(adapter:consume())==nil)
local translation=upvalue(menu.register_option,'translation')
local codes={us='en',gb='en',bp='pt-BR',de='de',es='es',fr='fr',it='it',jp='ja',ko='ko',
    ms='es-419',pl='pl',pt='pt',ru='ru',cn='zh-Hans',tc='zh-Hant'}
for code,language in pairs(codes)do
    local registry=Text.registry();registry.game_code=code;registry.game_language=language;registry.serial=registry.serial+1
    translation.refresh()
    assert(state.options[p..'move.crusher_melee'].label==texts[language]['move.crusher_melee'])
    assert(state.options[p..'offset_x'].label==texts[language].horizontal)
    assert(state.options[p..'preview'].choices[2]==Text.upper(texts[language].play))
    for _,option in ipairs(category.order)do
        assert(type(option.sources.label)=='function'and type(option.sources.description)=='function')
        assert(option.label==option.sources.label()and option.description==option.sources.description())
        assert(not option.label:find('/',1,true)and not option.description:find('/',1,true))
        assert(Text.length(option.label)<=64 and Text.length(option.description)<=400)
    end
    assert(menu.get(p..'size')==100 and menu.get(p..'volume')==60 and #category.order==29)
end
print('PASS actual MOM refresh: all 15 native language codes, 14 complete locales, single-language fields and stable values')
print('PASS real MOM API v3: one 29-row page, 20 switches, two 0-2s/.1s delay sliders, persisted values and complete reset')
