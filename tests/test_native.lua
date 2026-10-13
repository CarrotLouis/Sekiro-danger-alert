local root=arg[1];local ffi=require('ffi');local bytes={}
local function pointer(n)return ffi.cast('uint8_t *',n)end
local function addr(n)return tonumber(ffi.cast('uintptr_t',n))end
local function region(at,n)bytes[at]=string.rep('\0',n)end
local function write(at,s)
    for base,b in pairs(bytes) do if at>=base and at+#s<=base+#b then
        local off=at-base;bytes[base]=b:sub(1,off)..s..b:sub(off+#s+1);return
    end end;error('fixture write outside block')
end
local function pack(n,size)local out={};for i=1,size do out[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(out)end
local function u(at,n)write(at,pack(n,4))end
local function p(at,n)write(at,pack(n,8))end
local function read(at,n)
    at=addr(at)
    for base,b in pairs(bytes) do if at>=base and at+n<=base+#b then return b:sub(at-base+1,at-base+n)end end
end
local function from(s,o)
    o=o or 0;local n=0;for i=8,1,-1 do n=n*256+s:byte(o+i)end
    if n<65536 then return nil end;return pointer(n)
end
local mem={module=function(name)return pointer(name and 0x10000000 or 0x20000000)end,
    read=read,pointer=from,address=addr,distance=function(a,b)return addr(a)-addr(b)end}
local exe=0x20000000
region(exe+27328752,8);region(0x40000000,512);p(exe+27328752,0x40000000)
u(0x40000000+152,10);p(0x40000000+160,0x40001000);p(0x40000000+136,0x40002000)
region(0x40001000,10);write(0x40001003,'\1');region(0x40002000,80);p(0x40002000+24,0x40003000)
region(0x40003000,512);u(0x40003008,4194307);p(0x40003000,0x40004000)
region(0x40004000,512);p(0x40004000+0xe8,exe+2873456)
region(exe+2873456,5);write(exe+2873456,'\072\141\065\096\195')
region(0x40005000,64);p(0x40003000+136,0x40005000)
local pos=ffi.new('float[3]',{1,2,3});write(0x40005000+48,ffi.string(pos,12))
p(0x40004000+0x1b0,exe+0x2bd9c0);region(exe+0x2bd9c0,8);write(exe+0x2bd9c0,'\072\139\129\120\001\000\000\195')
p(0x40003000+0x178,0x40006000);region(0x40006000,128)
p(0x40006000+0x28,0x40007000);p(0x40006000+0x50,0x40008000)
region(0x40007000,512);region(0x40008000,16);u(0x40007004,2);u(0x40007008,64)
u(0x40007040,2);u(0x40007044,64);u(0x40007048,192)
u(0x40007088,2);u(0x4000708c,48);u(0x40007090,64)
p(0x40008000,0x400070c0);write(0x400070c0,pack(123456,8))
u(0x40007108,1);u(0x4000710c,32);p(0x40008008,0x40007120);write(0x40007120,pack(987654,8))
local n=dofile(root..'/src/native.lua').new(mem,{})
n:begin();local v=n:position(4194307);assert(v.x==1 and v.y==2 and v.z==3)
local states=n:animation(4194307)
assert(#states==2 and states[1].layer==0 and states[1].index==1 and states[1].hash=='000000000001e240')
assert(states[2].index==0 and states[2].hash=='00000000000f1206')
write(0x40001003,'\2');assert(not pcall(n.position,n,4194307));assert(not pcall(n.animation,n,4194307))
write(0x40001003,'\1');u(0x40007004,33);assert(not pcall(n.animation,n,4194307))
u(0x40007004,2);p(0x40008000,0x60000000);assert(not pcall(n.animation,n,4194307))
print('PASS read-only unit generation, position and animation-layer decoding; invalid handles/counts/pointers rejected')
-- Health discovery, entity re-resolution and ability-owner join share a canonical descriptor.
local game=0x10000000
region(game+53634696,8);p(game+53634696,0x41000000);region(0x41000000,4300)
u(0x41000000+4112,1);u(0x41000000+4128,1)
p(0x41000000+4144,0x41002000);u(0x41000000+4152,1);u(0x41000000+4156,0xffffffff);u(0x41000000+4160,1)
p(0x41000000+4168,0x41010000);p(0x41000000+4184,0x41004000)
region(0x41010000,8);p(0x41010000,0x41003000)
region(0x41002000,8);u(0x41002000,100);u(0x41002004,0)
region(0x41003000,24);write(0x41003000,pack(1234,8));u(0x41003008,100);u(0x4100300c,4194307);u(0x41003014,1)
region(0x41004000,440);u(0x41004000+20,6000)
n=dofile(root..'/src/native.lua').new(mem,{crusher_resource='00000000000004d2'})
n:begin();local h=n:health_header();assert(h.count==1)
local found,cursor=n:discover(h,0,128);assert(#found==1 and cursor==0 and found[1].id==100)
local e=n:resolve(h,100);assert(e.health==6000 and e.owned)
region(game+53634624,8);p(game+53634624,0x41005000);region(0x41005000,64)
u(0x41005000+8,1);u(0x41005000+12,1);p(0x41005000+48,0x41006000);p(0x41005000+56,0x41007000)
region(0x41006000,8);p(0x41006000,0x41003000);region(0x41007000,224)
u(0x41007000,567);local tm=ffi.new('float[2]',{0.25,1});write(0x41007008,ffi.string(tm,8));write(0x41007010,'\1')
local a=n:abilities({[0x41003000]=e});assert(#a==1 and a[1].id==567 and a[1].time==0.25 and a[1].entity==100)
write(0x41007010,'\0');assert(#n:abilities({[0x41003000]=e})==0)
u(0x41004000+20,0);assert(n:resolve(h,100)==nil)
print('PASS health discovery/re-resolution, dead-target rejection and canonical ability-owner join')
-- Named head lookup uses the animated node, not the entity root or a fixed height.
u(0x40003000+0x70,2);p(0x40003000+0xa0,0x42000000);region(0x42000000,8)
u(0x42000000,123);u(0x42000004,0x8c5570c9)
region(0x42001000,128);p(0x40003000+0x88,0x42001000)
local head=ffi.new('float[3]',{2,10,1.7});write(0x42001000+64+48,ffi.string(head,12))
local hp=n:head_position(4194307);assert(hp.node==1 and hp.x==2 and hp.y==10 and math.abs(hp.z-1.7)<0.0001)
head[2]=0.7;write(0x42001000+64+48,ffi.string(head,12));assert(n:head_position(4194307).z<0.71)
u(0x42000004,0);assert(n:head_position(4194307)==nil);u(0x42000004,0x8c5570c9)
-- Camera manager matrix and actual engine camera FOV.
region(game+54973792,8);p(game+54973792,0x42002000);region(0x42002000,80)
p(0x42002000,0x42003000);region(0x42003000,64)
local matrix=ffi.new('float[16]',{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1})
write(0x42002000+12,ffi.string(matrix,64));local fov=ffi.new('float[1]',math.pi/2)
write(0x42003000+0x34,ffi.string(fov,4))
local camera=n:camera();assert(math.abs(camera.fov-math.pi/2)<0.0001)
n.scene=function()return {avatar={unit=4194307}}end
local screen=n:head_anchor(1920,1080);assert(screen and screen.node==1 and screen.unit==4194307)
n.scene=function()return {}end;assert(n:head_anchor(1920,1080)==nil)
print('PASS animated head-name lookup, crouching pose change, camera decoding and unavailable-avatar hiding')
-- Independent synthetic layout for the read-only targeting probe. No live process required.
local profile=dofile(root..'/src/profile.lua')
for _,pin in ipairs(profile.targeting_pins) do region(game+pin.rva,#pin.bytes);write(game+pin.rva,pin.bytes)end
profile.targeting_resources={['00000000000004d2']='test_turret'}
region(game+0x3326d30,8);p(game+0x3326d30,0x43000000);region(0x43000000,0x188)
u(0x43000140,1);u(0x43000144,1)
p(0x43000150,0x43001000);u(0x43000158,1);u(0x4300015c,0xffffffff);u(0x43000160,1)
region(0x43001000,8);u(0x43001000,100);u(0x43001004,0)
p(0x43000168,0x43002000);region(0x43002000,8);p(0x43002000,0x41003000)
p(0x43000178,0x43003000);region(0x43003000,0xd0);u(0x43003000,777)
u(0x43003004,99)
p(0x43000180,0x43004000);region(0x43004000,24);u(0x43004000,99)
region(game+0x3326740,8);p(game+0x3326740,0x44000000);region(0x44000000,0x68)
p(0x44000040,0x44001000);u(0x44000048,1);u(0x4400004c,0xffffffff);u(0x44000050,1)
region(0x44001000,8);u(0x44001000,100);u(0x44001004,0)
p(0x44000058,0x44002000);region(0x44002000,8);p(0x44002000,0x41003000)
p(0x44000060,0x44003000);region(0x44003000,0x1f8)
u(0x44003000,321);u(0x44003008,5);u(0x4400300c,6);u(0x44003018,777)
u(0x44003060,1);write(0x44003078,'\1')
n=dofile(root..'/src/native.lua').new(mem,profile);n:begin()
h=n:targeting_header();found=n:targeting_discover(h,0,128);assert(#found==1 and found[1].class_name=='test_turret')
e=n:targeting_resolve(h,100);e.distance=120
local state=n:targeting_state(h,e,{id=777})
assert(state.aim_target_is_local and state.entity_target_valid and state.ai.target_is_local)
assert(state.network_target_consistent)
u(0x43004000,88);assert(not n:targeting_state(h,e,{id=777}).network_target_consistent);u(0x43004000,99)
assert(state.ai.tracks_entity and state.ai.stage==5 and state.ai.pending_stage==6 and state.distance==120)
-- Position mode can retain an entity ID; it must not qualify as an entity-target lock.
write(0x43004014,'\1');state=n:targeting_state(h,e,{id=777})
assert(state.aim_target_is_local and not state.entity_target_valid and state.position_only)
write(0x43004014,'\0');u(0x43004000,0x7fff);assert(not n:targeting_state(h,e,{id=777}).entity_target_valid)
u(0x43004000,99);u(0x43003000,888);assert(not n:targeting_state(h,e,{id=777}).aim_target_is_local)
-- A peer may have aiming data without a usable Behavior record. Never invent one.
u(0x44001000,0xffffffff);state=n:targeting_state(h,e,{id=777});assert(not state.ai_available and not state.ai)
-- Wrong owner, changed table, invalid count and pin mismatch all reject the observation.
u(0x41003008,101);assert(not pcall(n.targeting_state,n,h,e,{id=777}));u(0x41003008,100)
u(0x43000140,5000);assert(not pcall(n.targeting_header,n));u(0x43000140,1)
local pin=profile.targeting_pins[1];write(game+pin.rva,string.rep('\0',#pin.bytes))
n=dofile(root..'/src/native.lua').new(mem,profile);n:begin();assert(not pcall(n.targeting_header,n))
print('PASS targeting/AI ownership, local-target distinction, position-only mode, peer absence and build/layout rejection')
