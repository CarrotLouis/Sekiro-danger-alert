local root=arg[1];local module=dofile(root..'/src/detector.lua')
local profile=dofile(root..'/src/profile.lua')
local events={}
local d=module.new({},profile,function()end,function(e)events[#events+1]=e end)
local target={[1]={unit=2,distance=8}}
local function sample(t,id,time)
    d:observe(id and {{entity=1,id=id,time=time,slot=1}} or {},target,t)
end
sample(0,1412,0.02);sample(.05,1412,.07);sample(5,1412,5.02)
sample(6,1412,0.03);assert(#events==2,'same ability ID must re-arm when its timer resets')
sample(7,1434,0);sample(8,1426,0);assert(#events==2,'non-attack actions must not trigger')
sample(9,nil);sample(10,1411,1);assert(#events==2,'first seen late in an attack must not trigger')
target[1].distance=11;sample(11,1411,0)
target[1].distance=9;sample(11.1,1411,0.1);assert(#events==2,'entering range after attack onset must not trigger')
sample(17,1411,5.9);sample(17.1,1411,0);assert(#events==3)
sample(17.15,nil);sample(17.2,1411,0.1);assert(#events==3,'short read gaps must not duplicate warnings')
d:reset();sample(20,1411,0);assert(#events==4)
-- A sanitized replay preserves every captured ability row and the latest observed distance.
local replay=dofile(root..'/tests/fixtures/crusher_ability_replay.lua')
d:reset();events={}
for _,row in ipairs(replay) do
    target[1].distance=row[4]
    sample(row[1],row[2]~=0 and row[2] or nil,row[3])
end
assert(#events==9,'capture replay expected 9 in-range onsets, got '..#events)
local counts={};for _,event in ipairs(events)do counts[event.ability]=(counts[event.ability] or 0)+1 end
assert(counts[1411]==3 and counts[1412]==6 and not counts[1424])
-- Exercise every statically reviewed branch separately; exclude every foot branch.
events={};d:reset();local clock=100;target[1].distance=8
for _,id in ipairs({1411,1412,1413,1414,1415,1416,1417,1418,1419,1420,1421,1422,1424}) do
    sample(clock,nil);sample(clock+.1,id,0);sample(clock+.2,id,.1);clock=clock+3
end
assert(#events==13,'every reviewed non-stomp branch triggers exactly once')
for _,id in ipairs({1409,1410,1423}) do sample(clock,nil);sample(clock+.1,id,0);clock=clock+3 end
assert(#events==13,'stomps must never warn')
-- The explicit stomp exclusion wins even if a future profile accidentally enables it.
profile.attack_states[1409]=true;sample(clock,1409,0);assert(#events==13);profile.attack_states[1409]=nil
-- Exercise native polling, ownership join, despawn and local-player context transitions.
local mission,avatar,alive,time=true,7,true,0
local n={memory={address=function(p)return p end},begin=function()end,
 scene=function()return {mission=mission,key='world',avatar={unit=avatar},position={x=0,y=0,z=0}}end,
 health_header=function()return {}end,discover=function()return {{id=1}},0 end,
 resolve=function()if alive then return {id=1,unit=2,pointer=100}end end,
 position=function()return {x=8,y=0,z=0}end,
 abilities=function(_,owners)
    if not owners[100] then return {}end
    return {{entity=1,id=1411,slot=1,time=time}}
 end}
events={};d=module.new(n,profile,function()end,function(e)events[#events+1]=e end)
d:step(0);time=1;d:step(1);assert(#events==1)
avatar=8;time=0;d:step(2);assert(#events==2)
alive=false;d:step(3);assert(not d.tracked[1])
mission=false;d:step(4);assert(d.context==nil)
n.scene=function()error('unreadable')end
for i=5,12 do d:step(i)end;assert(d.disabled)
print('PASS 934-row replay (9 in-range onsets), 13 melee branches, explicit stomp exclusion and lifecycle/read guards')
