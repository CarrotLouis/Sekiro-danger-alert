-- Byte-backed boundary test of the actual diagnostic reader, without a game process.
local root=arg[1];local ffi=require('ffi');local blocks={}
local function pointer(n)return ffi.cast('uint8_t *',n)end
local function address(p)return tonumber(ffi.cast('uintptr_t',p))end
local function region(at,n)blocks[at]=string.rep('\0',n)end
local function store(at,s)
    for base,bytes in pairs(blocks)do if at>=base and at+#s<=base+#bytes then
        local o=at-base;blocks[base]=bytes:sub(1,o)..s..bytes:sub(o+#s+1);return
    end end;error('fixture store outside block')
end
local function pack(n,size)local out={};for i=1,size do out[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(out)end
local function u(at,n)store(at,pack(n,4))end
local function p(at,n)store(at,pack(n,8))end
local function read(at,n)
    at=address(at)
    for base,bytes in pairs(blocks)do if at>=base and at+n<=base+#bytes then return bytes:sub(at-base+1,at-base+n)end end
end
local function from(s,o)
    o=o or 0;local n=0;for i=8,1,-1 do n=n*256+s:byte(o+i)end
    return n>=65536 and pointer(n)or nil
end
local mem={module=function(name)return pointer(name and 0x10000000 or 0x20000000)end,
    read=read,pointer=from,address=address,distance=function(a,b)return address(a)-address(b)end}
local game=0x10000000
local profile=dofile(root..'/src/profile.lua');profile.vehicle_probe=dofile(root..'/build/diagnostics/vehicle_profile.lua')
local research=dofile(root..'/tools/diagnostics/src/native.lua')
research.vehicle=dofile(root..'/tools/diagnostics/src/vehicle.lua')
for _,pin in ipairs(profile.vehicle_probe.pins)do
    local s=pin.hex:gsub('..',function(x)return string.char(tonumber(x,16))end)
    region(game+pin.rva,#s);store(game+pin.rva,s)
end
local function descriptor(at,hash,id,unit,network,flags)
    region(at,24);store(at,hash:gsub('..',function(x)return string.char(tonumber(x,16))end):reverse())
    u(at+8,id);u(at+12,unit);u(at+16,network);u(at+20,flags or 1)
    return {id=id,unit=unit,network_id=network,resource=hash,owned=true,pointer=pointer(at),identity=read(pointer(at),20)}
end
local function map(at,rows,id,index)
    p(at,rows);u(at+8,2);u(at+12,0xffffffff);u(at+16,1)
    region(rows,16);store(rows,string.rep('\255',16));local slot=rows+(id%2)*8
    u(slot,id);u(slot+4,index or 0)
end
local avatar=descriptor(0x41000000,profile.avatar_resource,17,1001,201)
local vehicle=descriptor(0x41000100,'16474112801385b6',30,1100,300)
local other=descriptor(0x41000200,'16474112801385b6',31,1101,301)
local seater,collection=0x42000000,0x43000000
region(game+profile.vehicle_probe.globals.seater,8);p(game+profile.vehicle_probe.globals.seater,seater)
region(game+profile.vehicle_probe.globals.collection,8);p(game+profile.vehicle_probe.globals.collection,collection)
region(seater,0x50);u(seater+8,1);u(seater+12,1);map(seater+0x20,0x42001000,17)
p(seater+0x38,0x42002000);region(0x42002000,8);p(0x42002000,0x41000000)
p(seater+0x48,0x42003000);region(0x42003000,64)
u(0x42003000,30);u(0x42003004,9);u(0x42003008,1)
u(0x42003014,0);u(0x42003018,0xffffffff);u(0x4200301c,0);u(0x42003020,0xffffffff);store(0x42003032,'\1')
region(collection,0x58);u(collection+8,1);u(collection+12,1);map(collection+0x20,0x43001000,30)
p(collection+0x38,0x43002000);region(0x43002000,8);p(0x43002000,0x41000100)
p(collection+0x48,0x43003000);region(0x43003000,100);u(0x43003000,9)
local n=dofile(root..'/src/native.lua').new(mem,profile,research)
n.position=function(_,unit)return {x=unit,y=0,z=0}end
local scene={mission=true,avatar=avatar,position={x=0,y=0,z=0}}
region(game+53634152,8);p(game+53634152,0x45000000);region(0x45000000,0x400)
u(0x45000084,1);u(0x45000088,1);u(0x450003a8,1001)
region(game+54968216,8);p(game+54968216,0x46000000)
region(0x46000000+0xf22ec8,20);map(0x46000000+0xf22ec8,0x47000000,1001)
local controlled_at=0x46000000+0xf32f18
descriptor(controlled_at,profile.avatar_resource,17,1001,201)
n:begin();assert(n:local_control_state().controlled.entity==17)
-- If the game ever returns a vehicle resource as the controlled entity, retain
-- it explicitly even though the production local-avatar resource gate rejects it.
store(controlled_at,('16474112801385b6'):gsub('..',function(x)return string.char(tonumber(x,16))end):reverse())
n:begin();assert(n:local_control_state().controlled.resource=='16474112801385b6')
n:begin();local v=n:vehicle_state(scene,true)
assert(v.vehicle.entity==30 and v.vehicle.network_id==300 and v.vehicle.class_name=='bastion')
assert(v.stable_seat and v.seat.node==0 and #v.seat.raw_hex==128 and #v.collection_raw_hex==200)
assert(n.reads<120 and n.bytes<8192,'bounded seat observation')
-- Driver/gunner nodes are read from the actual row. No nearest-vehicle inference.
u(0x42003014,1);u(0x4200301c,1);n:begin();assert(n:vehicle_state(scene).seat.node==1)
u(0x42003018,0);n:begin();assert(not n:vehicle_state(scene).stable_seat)
u(0x42003018,0xffffffff);u(0x42003000,0);n:begin();assert(n:vehicle_state(scene).status=='not_seated')
u(0x42003000,30);u(0x43001000,31);n:begin();assert(n:vehicle_state(scene).status=='collection_unavailable');u(0x43001000,30)
-- Unowned vehicles are observable on peers; no authority or warning is invented.
u(0x41000114,0);n:begin();assert(n:vehicle_state(scene).vehicle.owned==false);u(0x41000114,1)
u(0x41000108,32);n:begin();assert(not pcall(n.vehicle_state,n,scene));u(0x41000108,30)
p(0x42002000,0x41000200);n:begin();assert(not pcall(n.vehicle_state,n,scene));p(0x42002000,0x41000000)
u(seater+12,257);n:begin();assert(not pcall(n.vehicle_state,n,scene));u(seater+12,1)
local health=0x44000000;region(health,4200);map(health+4144,0x44001000,31)
u(health+4112,1);u(health+4128,1);p(health+4168,0x44002000)
region(0x44002000,8);p(0x44002000,0x41000200)
local h={manager=pointer(health),count=1,descriptors=pointer(0x44002000)}
n:begin();v=n:vehicle_state(scene)
local targets=n:target_descriptions(h,{{ai={target=17},aim={aim_target=30},replicated_target={target=31}}},scene,v)
assert(#targets==3 and targets[1].relation=='local_avatar'and targets[2].relation=='current_seat_collection')
assert(targets[3].relation=='other_entity'and targets[3].class_name=='bastion')
_G.stingray={Gui={resolution=function()return 1920,1080 end}}
n.head_anchor=function()return nil,'head behind camera'end
assert(n:presentation_geometry().head_projectable==false)
n.head_anchor=function()return {x=500,y=400}end;assert(n:presentation_geometry().head_projectable)
-- Pin refusal happens before a layout read; existing warning rules are untouched.
local pin=profile.vehicle_probe.pins[1];store(game+pin.rva,string.rep('\0',#pin.hex/2))
n=dofile(root..'/src/native.lua').new(mem,profile,research);n:begin()
assert(not pcall(n.vehicle_state,n,scene))
print('PASS diagnostic vehicle byte layout: real owner/collection join, both seat nodes, exits/transitions, peer ownership, target identities, projection and pin/count/identity refusal')

-- Collector-level distinction: local lock mismatch, submitted warning, hidden
-- projection and a manual preview remain separate events in the actual JSONL.
local tracking=dofile(root..'/tools/diagnostics/src/tracking.lua')
local capture=dofile(root..'/tools/diagnostics/src/capture.lua')
local catalog=dofile(root..'/build/diagnostics/catalog.lua')
catalog.moves[#catalog.moves+1]={id='cannon_preparation',resources={profile.cannon.resource}}
catalog.resources[#catalog.resources+1]={hash=profile.cannon.resource,class_name='turret_heavycannon'}
local t,work,avatar_available=12000,0,true
local fake={reads=0,bytes=0,memory={address=function(v)return v end},begin=function()end}
function fake:scene()return {mission=true,key='vehicle-test',avatar=avatar_available and {id=17,unit=1001,network_id=201}or nil,
    position=avatar_available and {x=0,y=0,z=0}or nil}end
function fake:health_header()t=t+work;return {count=1}end
function fake:discover()return {{id=20,unit=1200}},0 end
function fake:resolve()return {id=20,unit=1200,pointer=1300,resource=profile.cannon.resource,owned=true}end
function fake:position()return {x=20,y=0,z=0}end
function fake:abilities()return {}end
function fake:targeting_header()return {count=1}end
function fake:combat_state()return {entity=20,ai={target=30,has_target=true,tracks_entity=true}}end
function fake:animation()return {{layer=0,index=1,hash='fixture'}}end
function fake:local_control_state()return {controlled_handle=1001,controlled={entity=17,unit=1001}}end
function fake:vehicle_state()return {status='seat_record',vehicle={entity=30,resource='16474112801385b6'},seat={node=1}}end
function fake:target_descriptions()return {{entity=30,relation='current_seat_collection'}}end
function fake:presentation_geometry()return {head_projectable=false,reason='head behind camera'}end
local c=capture.new(fake,root..'/build/test_logs',function()end,function()return t end,tracking,catalog,'1.1.0-dev.3')
c:start('combat','cannon_preparation','requested','bastion_gunner')
c:step();assert(c:mark())
c:record_detection({t=t,scene=fake:scene(),selected={},abilities={},tracking={},
    decisions={{entity=20,reason='other_target',target_entity=30,avatar_entity=17}}})
c:record_warning({source='manual_preview'},true,true)
c:record_presentation({ready=true,until_time=t+1,id=nil,anchor_status='head behind camera'},t)
c:stop('fixture complete')
local function contents(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local s=contents(c.path)
assert(s:find('"vehicle_scenario":"bastion_gunner"',1,true)and s:find('"relation":"current_seat_collection"',1,true))
assert(s:find('"reason":"other_target"',1,true)and s:find('"source":"manual_preview"',1,true))
assert(s:find('"event":"presentation_state"',1,true)and s:find('"bitmap_present":false',1,true))
fake.vehicle_state=function()error('fixture changed seat')end
t=t+1;c:start('combat','cannon_preparation','requested','bastion_driver');c:step()
assert(c.active and c.errors==0 and c.successful_samples==1 and c:mark());c:stop('fixture complete')
assert(contents(c.path):find('fixture changed seat',1,true))
avatar_available=false;t=t+1;c:start('combat','cannon_preparation','requested','bastion_driver');c:step()
assert(c.active and c.successful_samples==0);c:stop('fixture complete')
assert(contents(c.path):find('"event":"vehicle_local_state"',1,true))
avatar_available=true;t=t+1;c:start('combat','cannon_preparation');work=.025;c:step()
assert(c.active and c.backoff_until>t and c.overruns.capture==1,'one moderate sample spike backs off')
work=0;t=t+.2;c:step();assert(c.overruns.capture==0,'a recovered sample clears the strike')
work=.025;for i=1,2 do t=t+.2;c:step();assert(c.active)end
t=t+.2;c:step();assert(not c.active and c.stop_reason=='capture sampling budget exceeded')
work=.051;t=t+1;c:start('combat','cannon_preparation');c:step();assert(not c.active,'one severe sample still stops immediately')
print('PASS actual collector: vehicle scenarios, target/output/projection separation, unavailable seat/avatar retention, isolated-spike backoff and consecutive/severe budget stops')
