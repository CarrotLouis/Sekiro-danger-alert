local root=arg[1]
local C=dofile(root..'/tools/diagnostics/src/capture.lua')
local catalog=dofile(root..'/build/diagnostics/catalog.lua')
local tracking=dofile(root..'/tools/diagnostics/src/tracking.lua')
local t,unit,available,mission,world,actor_reads=0,7,true,true,'mission-a',0
local native={reads=0,bytes=0,memory={address=function(p)return p end},begin=function()end}
function native:scene()return {mission=mission,key=world,
    avatar=available and {id=unit+100,unit=unit,network_id=unit+200}or nil,
    position=available and {x=0,y=0,z=0}or nil}end
function native:health_header()actor_reads=actor_reads+1;return {count=1}end
function native:discover()return {{id=20,unit=30}},0 end
function native:resolve()return {id=20,unit=30,pointer=40,resource='d465d9c7f77a07cb',owned=true}end
function native:position()return {x=10,y=0,z=0}end
function native:abilities()return {{id=999,entity=20,slot=4,time=.1,active=true,speed=1}}end
function native:targeting_header()return {count=1,owned_prefix=1}end
function native:combat_state()return {entity=20,unit=30,resource='d465d9c7f77a07cb',owned=true,
    distance=10,ai={has_target=true,tracks_entity=true,target=unit+100}}end
function native:animation()return {{layer=0,index=1,hash='fixture'}}end
local function new()return C.new(native,root..'/build/test_logs',function()end,function()return t end,tracking,catalog,'1.1.0-dev.2')end
local function upvalue(f,key)
    for i=1,80 do local k,v=debug.getupvalue(f,i);if k==key then return v,i end end
    error('missing upvalue '..key)
end
local function almost_full_part(c)
    local emit=upvalue(c.mark,'emit');local _,i=upvalue(emit,'bytes_written')
    debug.setupvalue(emit,i,c.part_limit-1000)
end
local cap=new();cap:start('combat','hive_lord_body_slam_emerging','requested');cap:step()
assert(cap.long_capture and cap.requested_move.id=='hive_lord_all')
assert(cap.duration_limit==3600 and cap.part_seconds==300 and cap.part_limit==8388608 and cap.total_limit==268435456)
assert(not cap:mark()and not cap:mark('x')and cap.marker_count==0,'unclassified keys cannot label a Hive attack')
for i,key in ipairs({'-','=','[',']'})do t=i*.1;cap:step();assert(cap:mark(key))end
t=121;cap:step();assert(cap.active,'a Hive recording must outlive the old two-minute limit')
t=300;cap:step();assert(cap.part_index==2 and cap.marker_count==4)
t=300.1;assert(cap:mark('='))
local before=actor_reads;available=false;t=301;cap:step()
assert(cap.active and actor_reads==before and cap.observation==nil,'dead-player waiting performs no actor reads or stale annotation')
assert(cap:mark('['))
available=true;unit=8;t=302;cap:step();assert(cap.active and cap.avatar_epoch==2)
cap:record_detection({t=300,scene={key=world,mission=true,avatar={unit=7}}})
assert(cap.avatar_epoch==2,'an older detector snapshot cannot restore an old player epoch')
assert(cap:mark(']'))
t=600;cap:step();assert(cap.part_index==3);assert(cap:mark('-'))
t=3600;cap:step();assert(not cap.active and cap.stop_reason=='60 minutes complete')
for _,key in ipairs({'-','=','[',']'})do assert(cap.marker_counts[key]==2)end
local long_paths=cap.paths
-- Ordinary scopes keep F8, 120 seconds and the original avatar-change stop.
t=3700;cap:start('combat','hulk_rotary_saw','requested');cap:step()
assert(not cap.long_capture and not cap.marker_bindings and cap.duration_limit==120)
assert(not cap:mark('-')and cap:mark())
unit=9;t=3701;cap:step();assert(not cap.active)
t=3800;cap:start('combat','hulk_rotary_saw','requested');t=3920;cap:step();assert(not cap.active)
-- World changes still stop the long mode before reading the other world.
t=4000;local changed=new();changed:start('combat','hive_lord_all');changed:step()
before=actor_reads;world='mission-b';t=4001;changed:step();assert(not changed.active and actor_reads==before)
-- Simulate a byte quota without writing hundreds of MiB in the offline suite.
t=5000;local quota=new();quota:start('combat','hive_lord_all');quota:step()
almost_full_part(quota);assert(quota:mark('-')and quota.part_index==2)
quota.total_bytes=quota.total_limit-4096-1
assert(not quota:mark('=')and not quota.active and quota.stop_reason=='256 MiB session limit')
-- A failed next-part open must stop, never silently continue without a file.
t=6000;local failed=new();failed:start('combat','hive_lord_all');failed:step();almost_full_part(failed)
local original_open=io.open
io.open=function(path,mode)if path:find('-part002',1,true)then return nil,'fixture disk unavailable'end;return original_open(path,mode)end
local ok,why=pcall(failed.mark,failed,'-');io.open=original_open
assert(ok and why==false and not failed.active and failed.stop_reason:find('cannot create capture log',1,true))
local fail_kind
io.open=function(path,mode)
    local f=assert(original_open(path,mode));t=t+.00005
    return {write=function(_,line)
        if fail_kind and line:find('"event":"'..fail_kind..'"',1,true)then return nil,'fixture disk full'end
        t=t+.00005;return f:write(line)
    end,flush=function()t=t+.00005;return f:flush()end,close=function()return f:close()end}
end
t=7000;local clocked=new();clocked:start('combat','hive_lord_all');clocked:step()
t=7300.1;assert(clocked:mark('='));clocked:stop('fixture complete')
t=8000;local write_failed=new();write_failed:start('combat','hive_lord_all');write_failed:step();fail_kind='user_attack_mark'
assert(not write_failed:mark('[')and not write_failed.active and write_failed.marker_count==0)
assert(write_failed.stop_reason:find('capture log write failed',1,true))
fail_kind=nil;t=9000;local sample_failed=new();sample_failed:start('combat','hive_lord_all')
fail_kind='research_sample';sample_failed:step()
assert(not sample_failed.active and sample_failed.errors==0 and sample_failed.successful_samples==0,
    'a failed sample write cannot continue optional reads or masquerade as a native read error')
io.open=original_open
local edges=dofile(root..'/tools/diagnostics/src/marker.lua').edges()
assert(#edges(true,{true,false,true,false})==0,'held at capture start is a baseline')
assert(#edges(true,{true,false,true,false})==0)
assert(#edges(true,{false,false,false,false})==0)
local pressed=edges(true,{true,false,false,true});assert(#pressed==2 and pressed[1]==1 and pressed[2]==4)
assert(#edges(false,{})==0)
assert(#edges(true,{true,false,false,true})==0,'returning focus cannot manufacture presses')
edges(true,{false,false,false,false});pressed=edges(true,{false,true,false,false});assert(#pressed==1 and pressed[1]==2)
print('PASS Hive duration, four labels, rotations/quotas, player epochs, mission guard, file-open failure and focused independent key edges')
print('HIVE_RESULT '..C.json({long_paths=long_paths,quota_paths=quota.paths,failed_paths=failed.paths,
    clocked_paths=clocked.paths,write_failed_paths=write_failed.paths}))
