local root=arg[1]
local module=dofile(root..'/src/detector.lua')
local profile=dofile(root..'/src/profile.lua')
local catalog=dofile(root..'/src/catalog.lua')
local avatar={id=7,unit=70};local events={};local off
local d=module.new({},profile,function()end,function(e)events[#events+1]=e end,function(move)return move~=off end)
local at=0;local covered={}
for resource,entry in pairs(profile.expanded.resources)do
    for id,rule in pairs(entry.abilities)do
        local e={id=1,unit=100,resource=resource,owned=true,alive=true,distance=5000,
            ai={behavior=entry.behavior,has_target=true,tracks_entity=true,target=7}}
        d:reset();local before=#events
        for shot,cue in ipairs(rule.cues)do
            at=at+3
            local input={entity=1,id=id,slot=1,time=cue.time+.02,speed=1}
            local decisions=d:observe({input},{[1]=e},at,avatar)
            assert(decisions[1].reason=='trigger'and decisions[1].shot_index==shot and decisions[1].move==rule.move)
            d:observe({input},{[1]=e},at+.05,avatar)
            assert(#events==before+shot,'same window cannot warn twice')
        end
        covered[rule.move]=true
        off=rule.move;d:reset();at=at+3
        assert(d:observe({{entity=1,id=id,slot=1,time=rule.cues[1].time+.02,speed=1}},{[1]=e},at,avatar)[1].reason=='move_disabled')
        off=nil
        for _,case in ipairs({{'unverified_peer_target','owned',false},{'dead_or_replaced','alive',false},
            {'no_entity_target','has_target',false},{'no_entity_target','tracks_entity',false},
            {'other_target','target',8},{'other_behavior','behavior',0}})do
            local owner=case[2]=='owned'or case[2]=='alive';local table=owner and e or e.ai;local saved=table[case[2]]
            table[case[2]]=case[3];d:reset();at=at+3
            assert(d:observe({{entity=1,id=id,slot=1,time=rule.cues[1].time+.02,speed=1}},{[1]=e},at,avatar)[1].reason==case[1])
            table[case[2]]=saved
        end
        for id,reason in pairs(entry.excluded)do
            d:reset();at=at+3
            assert(d:observe({{entity=1,id=id,slot=1,time=0,speed=1}},{[1]=e},at,avatar)[1].reason==reason)
        end
    end
end
local F=profile.expanded.factory
local e={id=1,unit=100,resource=F.resource,owned=true,alive=true,
    ai={behavior=F.behavior,stage=3,has_target=true,tracks_entity=true,target=7,preparation_ready=true}}
local input={entity=1,id=0,source='factory_stage',slot='factory',time=.6,speed=1,token=1000000}
local function sample()d:reset();at=at+3;return d:observe({input},{[1]=e},at,avatar)[1]end
assert(sample().reason=='trigger');covered[F.move]=true
local before=#events;d:observe({input},{[1]=e},at+.05,avatar);assert(#events==before)
input.token=2000000;assert(d:observe({input},{[1]=e},at+3,avatar)[1].reason=='trigger','new native preparation timestamp rearms')
e.ai.preparation_ready=false;assert(sample().reason=='not_preparing');e.ai.preparation_ready=true
e.ai.stage=2;assert(sample().reason=='not_preparing');e.ai.stage=3
input.time=1.5;assert(sample().reason=='late_sample');input.time=.2;assert(sample().reason=='before_cue');input.time=.6
off=F.move;assert(sample().reason=='move_disabled');off=nil
for _,move in ipairs(catalog.moves)do assert(covered[move.id],'missing automatic path '..move.id)end
local new_count=0;for _ in pairs(covered)do new_count=new_count+1 end;assert(new_count==18)
print('PASS all 18 expanded move paths including native-reviewed Harvester, independent toggles, target gates and mode exclusions')

-- Factory integration uses health re-resolution and the canonical native clock.
local actor={id=1,unit=100,resource=F.resource,owned=true,alive=true,pointer=123,identity='canonical'}
local nt,start=1600000,1000000
local native={begin=function()end,scene=function()return {mission=true,key='world',avatar=avatar}end,
    attack_candidates=function()return {},{},{cursor=0}end,
    factory_candidates=function()return {actor},{cursor=0}end,
    health_header=function()return {count=1}end,resolve=function()return actor end,
    behavior_target=function()return {behavior=99,stage=3,target=7,has_target=true,tracks_entity=true,
        native_time=nt,preparation_started=start,preparation_ready=true}end}
events={};d=module.new(native,profile,function()end,function(x)events[#events+1]=x end)
d:step(0);d:step(.05);assert(#events==1 and events[1].attack_source=='factory_stage')
start=2000000;nt=2600000;d:step(4);assert(#events==2)
native.resolve=function()return {pointer=999,identity='replacement'}end
start=3000000;nt=3600000;d:step(8);assert(#events==2 and d.snapshot.decisions[1].reason=='dead_or_replaced')
print('PASS Factory detector joins fresh canonical health/target/timestamp and rejects replaced owners')
