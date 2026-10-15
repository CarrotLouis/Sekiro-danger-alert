local root=arg[1]
local detector=dofile(root..'/src/detector.lua')
local profile=dofile(root..'/src/profile.lua')
local replay=dofile(root..'/tests/fixtures/expanded_attack_replay.lua')
local covered={};local counts={};local samples=0;local total=0;local artillery_rows,hover_rows=0,0
local expected={
    ['annihilator_fusion_cannon-1']={annihilator_fusion_cannon=10},
    ['barrager_direct_mlrs-1']={barrager_direct_mlrs=9},['barrager_direct_mlrs-2']={barrager_direct_mlrs=3},
    ['behemoth_superheavy_crush-1']={behemoth_superheavy_crush=6},['charger_heavy_crush-1']={charger_heavy_crush=9},
    ['dragon_alchemical_pyrosis-1']={dragon_alchemical_pyrosis=4},['hulk_rotary_saw-1']={hulk_rotary_saw=24},
    ['impaler_momentous_slam-1']={impaler_momentous_slam=4},['jet_hulk_rotary_saw-1']={jet_hulk_rotary_saw=30},
    ['reinforced_heavy_rockets-1']={reinforced_heavy_rockets=4},['rupture_hardened_crush-1']={rupture_hardened_crush=10},
    ['spore_charger_heavy_crush-1']={spore_charger_heavy_crush=15},
    ['spore_titan_cataclysmic_slam-1']={spore_titan_cataclysmic_slam=1},
    ['spore_titan_cataclysmic_slam-2']={spore_titan_cataclysmic_slam=7},
    ['tentacle_slam-1']={tentacle_slam=8,impaler_momentous_slam=1},
    ['titan_cataclysmic_slam-1']={titan_cataclysmic_slam=2,titan_caustic_surge=3},
    ['titan_cataclysmic_slam-2']={titan_cataclysmic_slam=5,titan_caustic_surge=7},
    ['titan_caustic_surge-1']={titan_cataclysmic_slam=3,titan_caustic_surge=5},
}
for _,capture in ipairs(replay.captures)do
    local fired={};local per_id={}
    local d=detector.new({},profile,function()end,function(event)
        covered[event.move]=true;fired[event.move]=(fired[event.move]or 0)+1
        per_id[event.ability]=(per_id[event.ability]or 0)+1;total=total+1
    end)
    local last_t,items,targets
    local function submit()
        if last_t then d:observe(items,targets,last_t,{id=7,unit=70})end
    end
    for line in capture.data:gmatch('[^\r\n]+')do
        local row={};for cell in line:gmatch('[^,]+')do row[#row+1]=assert(tonumber(cell))end
        assert(#row==14);samples=samples+1
        if last_t~=row[1]then submit();last_t=row[1];items={};targets={}end
        local resource=assert(replay.resources[row[4]])
        targets[row[2]]={id=row[2],unit=row[3],resource=resource,owned=row[9]==1,alive=true,
            ai={has_target=row[10]==1,tracks_entity=row[11]==1,target=row[12]==1 and 7 or 8,
                behavior=row[13],stage=row[14]}}
        items[#items+1]={entity=row[2],id=row[5],time=row[6],speed=row[7],slot=row[8]}
        if row[5]==1019 then artillery_rows=artillery_rows+1 end
        if row[5]==252 then hover_rows=hover_rows+1 end
    end
    submit();assert(not per_id[1019]and not per_id[252],'excluded real attack modes must never warn')
    counts[capture.name]=fired
    for move,count in pairs(assert(expected[capture.name]))do assert(fired[move]==count,capture.name..' count changed: '..move)end
    for move in pairs(fired)do assert(expected[capture.name][move],'unexpected move in '..capture.name)end
    local out={};for move,count in pairs(fired)do out[#out+1]=move..'='..count end;table.sort(out)
    print('REPLAY '..capture.name..': '..table.concat(out,', '))
end
local catalog=dofile(root..'/src/catalog.lua')
for _,move in ipairs(catalog.moves)do
    if move.status=='enabled_from_capture'and move.id~='factory_fusion_repeater'then
        assert(covered[move.id],'no captured ability replay triggers '..move.id)
    end
end
assert(artillery_rows>100 and hover_rows>100,'negative comparisons must be real captured rows')
assert(samples>5000 and total>100)
assert(counts['barrager_direct_mlrs-1'].barrager_direct_mlrs==9,'three direct bursts should warn for each of nine shots')
print('PASS '..samples..' captured anonymous samples: 15 ability-based moves, direct burst shots, excluded artillery/hover, stable target filters and deduplication')
