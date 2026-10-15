local root=arg[1];local tracking=dofile(root..'/tools/diagnostics/src/tracking.lua');local t=0;local mission=true;local state=1;local cmod=dofile(root..'/tools/diagnostics/src/capture.lua')
local mock={reads=0,bytes=0,memory={address=function(p)return p end},begin=function()end,
 scene=function()return {mission=mission,key='session-a',avatar={unit=7},position={x=0,y=0,z=0}}end,
 health_header=function()return {count=1}end,
 discover=function()return {{id=100,unit=9,owned=true}},0 end,
 resolve=function()return {id=100,unit=9,owned=true,health=6000,pointer=101}end,
 position=function()return {x=8,y=0,z=0}end,
 animation=function()return {{layer=0,index=state,hash='test'}}end,
 abilities=function()return {}end,
}
local cap=cmod.new(mock,root..'/build/test_logs',function()end,function()return t end,tracking)
cap:start();cap:step();t=0.05;cap:step();state=2;t=0.10;cap:mark();cap:step();mission=false;t=0.15;cap:step()
assert(not cap.active)
local f=assert(io.open(cap.path,'rb'));local s=f:read('*a');f:close()
local _,changes=s:gsub('"event":"animation_change"','');assert(changes==2)
assert(s:find('"event":"user_attack_mark"',1,true));assert(s:find('"distance":8.000000',1,true))
assert(s:find('left mission',1,true))
mission=true;cap:start();t=121;cap:step();assert(not cap.active)
print('PASS capture change deduplication, manual timestamp, mission exit and two-minute stop')
-- The automatic detector's actual set/decisions, including onsets between animation samples.
t=200;mission=true;cap:start()
local scene=mock:scene();scene.avatar.id=70
local snapshot={t=t,scene=scene,health_records=20,selected={{id=117,unit=17,distance=7,owned=true}},
    abilities={{entity=117,id=1415,time=0,slot=2}},
    decisions={{entity=117,ability=1415,reason='trigger',distance=7}},tracking={selected=1,pending=0}}
cap:record_detection(snapshot);cap:record_detection(snapshot)
t=200.9;cap:mark();cap:stop('test')
f=assert(io.open(cap.path,'rb'));s=f:read('*a');f:close()
local _,samples=s:gsub('"event":"detector_sample"','');assert(samples==1)
assert(s:find('"reason":"trigger"',1,true) and s:find('"observation_age":0.900000',1,true))
-- Targeting capture is opt-in and separate; does not mislabel the selected target as an attack.
mock.targeting_header=mock.health_header;mock.targeting_discover=mock.discover;mock.targeting_resolve=mock.resolve
mock.targeting_state=function(_,h,e,avatar)
    return {entity=e.id,aim_target=70,aim_target_is_local=true,entity_target_valid=true,
        ai={behavior=123,stage=2,has_target=true,target_is_local=true}}
end
t=300;cap:start('targeting');snapshot.t=t;snapshot.scene=mock:scene();cap:record_detection(snapshot);cap:step();t=300.2;cap:mark();cap:stop('test')
f=assert(io.open(cap.path,'rb'));s=f:read('*a');f:close()
assert(cap.path:find('Sekiro danger alert-Targeting-',1,true))
assert(s:find('"event":"targeting_sample"',1,true) and s:find('"automatic_warning_supported":true',1,true))
assert(s:find('"event":"detector_sample"',1,true) and s:find('"last_detection"',1,true))
assert(s:find('"last_observation"',1,true))
t=400;cap:start();snapshot.t=t;cap:record_detection(snapshot)
snapshot.scene.avatar.unit=8;snapshot.t=t+.1;cap:record_detection(snapshot)
assert(not cap.active,'detector recording must stop before mixing avatar epochs')
t=500;cap:start();t=621;snapshot.t=t;cap:record_detection(snapshot)
assert(not cap.active,'detector recording must respect the two-minute limit itself')
print('PASS shared detector capture, explicit F8 sample age, and separate targeting observations with actual warning decisions')

-- A selected research move scopes body and child resources, records unknown abilities,
-- and tags comparison runs without pretending the requested move is already identified.
local catalog=dofile(root..'/src/catalog.lua')
cap=cmod.new(mock,root..'/build/test_logs',function()end,function()return t end,tracking,catalog,'0.6.0')
mock.combat_state=function(_,h,actor,local_avatar,raw)
    return {entity=actor.id,unit=actor.unit,resource='test',class_name='tank_turret_rocketlauncher',
        ai={target=70,has_target=true,tracks_entity=true,stage=3},
        weapon_inputs={replicated_input_bits=2},root_forward={x=0,y=1,z=0}}
end
mock.abilities=function()return {{entity=100,id=2999,time=.1,speed=1,slot=3}}end
mission=true;t=700;cap:start('combat','barrager_direct_mlrs','comparison');cap:step()
t=700.5;cap:mark();cap:stop('test')
f=assert(io.open(cap.path,'rb'));s=f:read('*a');f:close()
assert(cap.path:find('Combat-barrager_direct_mlrs-comparison-',1,true))
assert(s:find('"event":"research_sample"',1,true) and s:find('"id":2999.000000',1,true))
assert(s:find('"new_moves_automatic_warning":true',1,true) and s:find('"capture_context":"comparison"',1,true))
assert(s:find('"version":"0.6.0"',1,true),'capture header must use the actual runtime version')
assert(s:find('"observation_age":0.500000',1,true) and s:find('"weapon_inputs"',1,true))
assert(cap.resources['63df3d07b7424588'] and cap.resources['5d142c3a73ebc634'])
assert(not cap.resources['1a7fcdff98c664b0'],'capture selection must not include unrelated enemies')
assert(not pcall(cap.start,cap,'combat','not-a-move'))
print('PASS resource-scoped combat capture, unknown action clocks, F8 sample age and direct/artillery labels')
