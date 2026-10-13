local root=arg[1];local tracking=dofile(root..'/src/tracking.lua')
local detector=dofile(root..'/src/detector.lua');local profile=dofile(root..'/src/profile.lua')
local count=16;local distances={};local calls=0;local alive={}
for i=1,300 do distances[i]=30+i/100;alive[i]=true end
local native={memory={address=function(p)return p end},begin=function()calls=0 end,
    scene=function()return {mission=true,key='world',avatar={unit=700},position={x=0,y=0,z=0}}end,
    health_header=function()return {count=count}end,
    discover=function(_,h,start,limit)
        local out={};local last=math.min(h.count,start+limit)
        for i=start+1,last do out[#out+1]={id=i}end
        return out,last>=h.count and 0 or last
    end,
    resolve=function(_,h,id)if alive[id]then return {id=id,unit=id,pointer=1000+id}end end,
    position=function(_,unit)calls=calls+1;return {x=distances[unit],y=0,z=0}end,
    abilities=function(_,owners)
        if owners[1017] then return {{entity=17,slot=1,id=1415,time=0}}end
        return {}
    end}
local events={};local d=detector.new(native,profile,function()end,function(e)events[#events+1]=e end,tracking)
d:step(0);assert(#d.snapshot.selected==16)
-- Regression: sixteen distant, still-alive enemies previously occupied all slots forever.
count=17;distances[17]=7;d:step(.2)
assert(d.tracked[17] and not d.tracked[16] and #events==1 and events[1].ability==1415)
assert(#d.snapshot.selected==16 and calls<=32)
assert(d.snapshot.tracking.capacity_excluded==1)
local reason=d.snapshot.decisions[1].reason;assert(reason=='trigger')
-- A selected enemy leaving the observation range gives up its slot.
distances[17]=100;d:step(.4);assert(not d.tracked[17])
-- Fair bounded candidate rotation; no silently dropped discovered candidate.
local tracker=tracking.new(native);count=300;distances[300]=1
for i=0,39 do
    calls=0;local selected,stats=tracker:step({count=count},native:scene(),i*.05)
    assert(calls<=32 and #selected<=16 and stats.pending<=4096)
end
assert(tracker.tracked[300],'later candidates must eventually be examined')
alive[300]=false;tracker:step({count=count},native:scene(),3);assert(not tracker.tracked[300])
tracker:reset();assert(next(tracker.tracked)==nil and tracker.cursor==0)
print('PASS near enemy replaces first-16 distant occupants; bounded candidate queue, despawn and detector decisions')
