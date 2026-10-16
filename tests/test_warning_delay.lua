local root=arg[1]
local module=dofile(root..'/src/detector.lua');local profile=dofile(root..'/src/profile.lua')
local avatar={id=7,unit=70,network_id=77}
local actor={id=1,unit=100,resource='965eae5a51acdd4a',owned=true,alive=true,
    ai={behavior=280,has_target=true,tracks_entity=true,target=7}}
local events={};local seconds,off=0,false
local d=module.new({},profile,function()end,function(e)events[#events+1]=e end,
    function()return not off end,function()return seconds end)
local input={entity=1,id=1961,slot=1,time=0,speed=1}
local function sample(t,clock)
    input.time=clock or t
    return d:observe({input},{[1]=actor},t,avatar)[1]
end
assert(sample(0).reason=='trigger'and #events==1,'zero keeps the original cue')
for _,id in ipairs({1961,1962,1956,1957})do
    input.id=id
    for _,value in ipairs({.01,.30,.31,.5})do
        seconds=value;events={};d:reset()
        assert(sample(0).reason=='delayed')
        for tick=1,math.floor(value*20)-1 do assert(sample(tick*.05).reason=='delayed')end
        local result=sample(value+.00001)
        assert(result.reason=='trigger'and #events==1 and result.warning_delay==value and result.detected_at==0)
        assert(sample(value+.05).reason=='already_warned'and #events==1)
    end
end
seconds=.30;input.id=1961
local function arm()events={};off=false;d:reset();assert(sample(0).reason=='delayed')end
local function cancelled(change,restore,reason)
    arm();change();assert(sample(.05).reason==reason);restore()
    for i=2,22 do sample(i*.05)end
    assert(#events==0,'cancelled warning must never reappear')
end
cancelled(function()actor.ai.target=8 end,function()actor.ai.target=7 end,'other_target')
cancelled(function()actor.alive=false end,function()actor.alive=true end,'dead_or_replaced')
cancelled(function()off=true end,function()off=false end,'move_disabled')
cancelled(function()input.paused=true end,function()input.paused=false end,'inactive_clock')
cancelled(function()avatar.unit=71 end,function()avatar.unit=70 end,'delay_cancelled')
arm();assert(sample(.2,0).reason=='delay_clock_stalled');sample(1,1);assert(#events==0)
arm();d:observe({},{},.05,avatar);assert(sample(.5,.5).reason=='already_warned');assert(#events==0)
arm();d:reset();assert(sample(1,1).reason=='late_sample'and #events==0,'reset clears scheduled alerts')
arm();sample(.2);input.id=1958;assert(sample(.3,.05).reason=='unmapped');sample(1,1);assert(#events==0)
input.id=1961
arm();seconds=.5;for i=1,10 do sample(i*.05)end
assert(#events==1 and events[1].warning_delay==.30,'APPLY changes affect the next attack, not an armed one')
-- Other enemies cannot acquire a delay even if a bad adapter returns one.
d:reset();events={};actor.resource=profile.crusher_resource;actor.ai.behavior=233;input.id=1411
assert(sample(0).reason=='trigger'and #events==1)
print('PASS Harvester delay: 0/.01/.30/.31/.5 seconds, independent ability instances, exact-once and cancellation on target/death/reset/clock/gaps')
