local root=arg[1];local t=0;local mission=true;local state=1;local cmod=dofile(root..'/src/capture.lua')
local mock={reads=0,bytes=0,memory={address=function(p)return p end},begin=function()end,
 scene=function()return {mission=mission,key='session-a',avatar={unit=7},position={x=0,y=0,z=0}}end,
 health_header=function()return {count=1}end,
 discover=function()return {{id=100,unit=9,owned=true}},0 end,
 resolve=function()return {id=100,unit=9,owned=true,health=6000,pointer=101}end,
 position=function()return {x=8,y=0,z=0}end,
 animation=function()return {{layer=0,index=state,hash='test'}}end,
 abilities=function()return {}end,
}
local cap=cmod.new(mock,root..'/build/test_logs',function()end,function()return t end)
cap:start();cap:step();t=0.05;cap:step();state=2;t=0.10;cap:mark();cap:step();mission=false;t=0.15;cap:step()
assert(not cap.active)
local f=assert(io.open(cap.path,'rb'));local s=f:read('*a');f:close()
local _,changes=s:gsub('"event":"animation_change"','');assert(changes==2)
assert(s:find('"event":"user_attack_mark"',1,true));assert(s:find('"distance":8.000000',1,true))
assert(s:find('left mission',1,true))
mission=true;cap:start();t=121;cap:step();assert(not cap.active)
print('PASS capture change deduplication, manual timestamp, mission exit and two-minute stop')
