local root=arg[1];local module=dofile(root..'/src/detector.lua')
local profile=dofile(root..'/src/profile.lua')
local events={};local avatar={id=7,unit=70}
local d=module.new({},profile,function()end,function(e)events[#events+1]=e end)
local e={unit=2,resource=profile.crusher_resource,class_name='crusher',distance=8,owned=true}
local targets={[1]=e}
local function lock(target,has,tracks)
    e.ai={target=target or 7,has_target=has~=false,tracks_entity=tracks~=false,behavior=123,stage=1}
end
local function sample(t,id,time,speed,paused)
    return d:observe(id and {{entity=1,id=id,time=time,speed=speed or 1,paused=paused,slot=1}} or {},targets,t,avatar)
end
lock();sample(0,1412,.02);sample(.05,1412,.07);sample(5,1412,5.02)
e.distance=1500;sample(6,1412,.03);assert(#events==2,'distance must not gate a local-target attack')
sample(7,1434,0);sample(8,1426,0);assert(#events==2,'non-attack actions must not trigger')
sample(9,nil);sample(10,1411,1);assert(#events==2,'first seen late must not trigger')
lock(8);assert(sample(11,1411,0)[1].reason=='other_target')
lock();sample(11.1,1411,.1);assert(#events==3,'a redirected early windup may warn')
sample(11.15,nil);sample(11.2,1411,.2);assert(#events==3,'short partial scans must not duplicate')
sample(12,1411,1);sample(13,1411,0);assert(#events==4,'timer reset must re-arm')
lock(8);sample(14,1411,0);lock();sample(14.5,1411,.5);assert(#events==4,'late target change must not warn')
-- Old captures had no target identity. They are NOT evidence that the new target filter works.
d:reset();events={};e.ai=nil
for _,row in ipairs(dofile(root..'/tests/fixtures/crusher_ability_replay.lua')) do
    e.distance=row[4];sample(row[1],row[2]~=0 and row[2] or nil,row[3])
end
assert(#events==0,'934 historical rows without target evidence must not fabricate a lock')
-- Synthetic target conditions exercise all reviewed branches, independent of distance.
d:reset();lock();local clock=100
for _,id in ipairs({1411,1412,1413,1414,1415,1416,1417,1418,1419,1420,1421,1422,1424}) do
    sample(clock,id,0);sample(clock+.1,id,.1);clock=clock+3
end
assert(#events==13)
for _,id in ipairs({1409,1410,1423}) do assert(sample(clock,id,0)[1].reason=='stomp');clock=clock+3 end
profile.attack_states[1409]=true;assert(sample(clock,1409,0)[1].reason=='stomp');profile.attack_states[1409]=nil
assert(#events==13)
-- Missing, stale, non-entity, other-player, peer, dead and paused states fail closed.
e.aim_target_is_local=true;e.position_only=true -- stale aim must never override missing/invalid AI.
local function reject(reason)
    d:reset();assert(sample(0,1411,0)[1].reason==reason)
end
lock(0);reject('no_entity_target');lock(7,false);reject('no_entity_target')
lock(7,true,false);reject('no_entity_target');lock(8);reject('other_target')
e.ai=nil;reject('no_ai_target');lock();e.owned=false;reject('unverified_peer_target');e.owned=true
e.alive=false;reject('dead_or_replaced');e.alive=true
assert(sample(1,1411,0,1,true)[1].reason=='inactive_clock')
assert(#events==13)
-- Cannon: cue at 1.0 seconds, trigger deadline 1.2, native fire at 1.5.
e.resource=profile.cannon.resource;e.class_name='turret_heavycannon';e.distance=2500
d:reset();events={};lock()
assert(sample(0,1037,0)[1].reason=='before_cue')
sample(.95,1037,.95);assert(#events==0)
sample(1.05,1037,1.05);sample(1.1,1037,1.1);assert(#events==1)
sample(1.6,1037,1.6);assert(#events==1)
d:reset();assert(sample(5,1037,1.25)[1].reason=='late_sample')
d:reset();assert(sample(6,1037,1.1,3)[1].reason=='insufficient_lead')
d:reset();e.resource='unreviewed_tank_cannon';assert(sample(7,1037,1)[1].reason=='unmapped')
e.resource=profile.cannon.resource
-- Replay real clocks/ownership/target flags from both valid captures (no invented local locks).
local replay=dofile(root..'/tests/fixtures/cannon_targeting_replay.lua')
local counts={};local leads={}
for capture_index,capture in ipairs(replay) do
    events={};d:reset()
    for _,r in ipairs(capture.samples) do
        e.owned=r[5];e.unit=r[2]+100;e.ai={has_target=r[6],tracks_entity=r[7],target=r[8] and 7 or 0}
        e.aim_target_is_local=r[9];e.position_only=r[10]
        sample(r[1],1037,r[3],r[4])
    end
    counts[capture_index]=#events
    for _,event in ipairs(events) do
        local lead=(profile.cannon.fire_time-event.ability_time)/event.ability_speed
        assert(lead>=.3 and lead<=.5,'replayed cue must precede the native firing event')
        leads[#leads+1]=lead
    end
end
assert(counts[1]==2 and counts[2]==8,'two captures should yield 10 preparation events, including the unmarked last shot')
print('PASS 313 real cannon samples: 2 + 8 warnings; no duplicate cue, no distance gate; target/stomp/late exclusions')
-- Polling joins canonical owners; rejects replaced actors and epoch changes before any trigger.
local mission,player,alive,time=true,7,true,0
local actor={id=1,unit=2,resource=profile.crusher_resource,class_name='crusher',owned=true,pointer=100,identity='actor'}
local n={begin=function()end,
 scene=function()return {mission=mission,key='world',avatar={id=player,unit=70}}end,
 attack_candidates=function()return {{entity=1,id=1411,slot=1,time=time,speed=1}},{actor},{cursor=0}end,
 health_header=function()return {count=1}end,
 resolve=function()if alive then return actor end end,
 behavior_target=function()return {target=player,has_target=true,tracks_entity=true}end}
events={};d=module.new(n,profile,function()end,function(x)events[#events+1]=x end)
d:step(0);time=1;d:step(1);assert(#events==1)
player=8;time=0;d:step(2);assert(#events==2)
alive=false;d:reset();d:step(3);assert(#events==2 and d.snapshot.decisions[1].reason=='dead_or_replaced')
mission=false;d:step(4);assert(d.context==nil)
mission=true;alive=true;local calls=0
n.scene=function()calls=calls+1;return {mission=true,key='world',avatar={id=calls,unit=70}}end
d:step(5);assert(#events==2 and d.snapshot==nil,'mid-read avatar change must reject whole batch')
n.scene=function()error('unreadable')end
for i=6,12 do d:step(i)end;assert(d.disabled)
print('PASS Crusher branch rules, incomplete legacy evidence, canonical owner/lifecycle and eight-error shutdown')
