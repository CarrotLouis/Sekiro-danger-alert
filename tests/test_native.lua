local root=arg[1];local ffi=require('ffi');local bytes={}
local core=dofile(root..'/src/native.lua')
local research=dofile(root..'/tools/diagnostics/src/native.lua')
local function make_native(memory,profile)return core.new(memory,profile,research)end
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
local n=make_native(mem,{})
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
n=make_native(mem,{crusher_resource='00000000000004d2'})
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
n=make_native(mem,profile);n:begin()
h=n:targeting_header();found=n:targeting_discover(h,0,128);assert(#found==1 and found[1].class_name=='test_turret')
e=n:targeting_resolve(h,100);e.distance=120
local state=n:targeting_state(h,e,{id=777})
assert(state.aim_target_is_local and state.entity_target_valid and state.ai.target_is_local)
assert(state.network_target_consistent)
u(0x43004000,88);assert(not n:targeting_state(h,e,{id=777}).network_target_consistent);u(0x43004000,99)
assert(state.ai.tracks_entity and state.ai.stage==5 and state.ai.pending_stage==6 and state.distance==120)
u(0x41003014,0);assert(not pcall(n.behavior_target,n,e,{id=777}));u(0x41003014,1)
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
n=make_native(mem,profile);n:begin();assert(not pcall(n.targeting_header,n))
print('PASS targeting/AI ownership, local-target distinction, position-only mode, peer absence and build/layout rejection')

-- Attack-first scanning never reserves the first sixteen enemies or requests positions.
write(game+pin.rva,pin.bytes)
for _,ap in ipairs(profile.attack_pins) do region(game+ap.rva,#ap.bytes);write(game+ap.rva,ap.bytes)end
for _,ap in ipairs(profile.expanded.pins) do region(game+ap.rva,#ap.bytes);write(game+ap.rva,ap.bytes)end
profile.crusher_resource='00000000000004d2'
n=make_native(mem,profile)
local rows_at,owners_at,descriptors_at=0x45000000,0x45100000,0x45200000
region(rows_at,3000*224);region(owners_at,3000*8);region(descriptors_at,40*32)
u(0x41005000+8,3000);u(0x41005000+12,3000)
p(0x41005000+48,owners_at);p(0x41005000+56,rows_at)
local function attack(index,actor_index)
    local at=descriptors_at+actor_index*32
    write(at,pack(1234,8));u(at+8,101+actor_index);u(at+12,1001+actor_index);u(at+20,1)
    p(owners_at+index*8,at);u(rows_at+index*224,1411)
    local clock=ffi.new('float[2]',{.05,1});write(rows_at+index*224+8,ffi.string(clock,8))
    write(rows_at+index*224+16,'\1')
end
attack(2300,0)
n:begin();local items,actors,stats=n:attack_candidates(0)
assert(#items==0 and stats.scanned==2048 and stats.cursor==2048 and n.bytes<1048576)
n:begin();items,actors,stats=n:attack_candidates(stats.cursor)
assert(#items==1 and items[1].slot==2300 and stats.cursor==0 and actors[1].class_name=='crusher')
assert(items[1].speed==1 and not items[1].paused and actors[1].owned)
u(0x41005000+12,40)
for i=0,39 do attack(i,i)end
n:begin();items,actors,stats=n:attack_candidates(0)
assert(#items==32 and #actors==32 and stats.cursor==32 and stats.remaining==8)
local seen={};for _,actor in ipairs(actors)do seen[actor.id]=true end
n:begin();items,actors,stats=n:attack_candidates(stats.cursor)
assert(#items==8 and stats.cursor==0)
for _,actor in ipairs(actors)do assert(not seen[actor.id]);seen[actor.id]=true end
local total=0;for _ in pairs(seen)do total=total+1 end;assert(total==40)
-- Pause bit and unknown resource stay explicit; a reused owner cannot inherit the old attack.
u(0x41005000+12,1);write(rows_at+17,'\1')
n:begin();items=n:attack_candidates(0);assert(items[1].paused)
write(descriptors_at,pack(4321,8));n:begin();items=n:attack_candidates(0);assert(#items==0)
u(0x41005000+12,8193);n:begin();assert(not pcall(n.attack_candidates,n,0));u(0x41005000+12,1)
local ap=profile.attack_pins[1];write(game+ap.rva,string.rep('\0',#ap.bytes))
n=make_native(mem,profile);n:begin();assert(not pcall(n.attack_candidates,n,0))
print('PASS bounded attack-table sweep, 40 simultaneous actors, no permanent slots, pause/resource/count/pin rejection')

-- Research health discovery uses a named whitelist; it also sees actors without Ability components.
u(0x41004000+20,6000);u(0x44001000,100)
n=make_native(mem,profile);n:begin();h=n:health_header()
local names={['00000000000004d2']={class_name='named_test_actor'}}
found=n:discover(h,0,128,names);assert(#found==1 and found[1].class_name=='named_test_actor')
e=n:resolve(h,100,names);assert(e and e.class_name=='named_test_actor')
assert(n:resolve(h,100,{})==nil)
for _,cp in ipairs(profile.combat_pins)do region(game+cp.rva,#cp.bytes);write(game+cp.rva,cp.bytes)end
region(game+0x3326420,8);p(game+0x3326420,0x47000000);region(0x47000000,0x70)
p(0x47000030,0x47001000);u(0x47000038,1);u(0x4700003c,0xffffffff);u(0x47000040,1)
region(0x47001000,8);u(0x47001000,100);u(0x47001004,0)
p(0x47000048,0x47002000);region(0x47002000,8);p(0x47002000,0x41003000)
p(0x47000058,0x47003000);region(0x47003000,32);write(0x47003000,'\1')
p(0x47000060,0x47004000);region(0x47004000,0x1d0);u(0x47004000,321);u(0x47004004,654)
p(0x47000068,0x47005000);region(0x47005000,4);u(0x47005000,2)
n:begin();local inputs=n:weapon_inputs(e,true)
assert(inputs.replicated_input_bits==2 and inputs.local_input_bytes[1]==1)
assert(inputs.slot_head_words[1][1]==321 and inputs.slot_head_words[1][2]==654 and #inputs.raw_hex==0x1d0*2)
local aimh=n:targeting_header();local combat=n:combat_state(aimh,e,{id=777},true)
assert(combat.ai.has_target and #combat.ai.raw_hex==0x1f8*2 and combat.weapon_inputs and combat.root_forward)
p(0x47002000,0x41004000);assert(n:weapon_inputs(e)==nil);p(0x47002000,0x41003000)
local cp=profile.combat_pins[1];write(game+cp.rva,string.rep('\0',#cp.bytes))
n=make_native(mem,profile);n:begin();assert(not pcall(n.weapon_inputs,n,e))
print('PASS named health discovery, pinned weapon-input decoding, optional component ownership and raw diagnostic gating')

-- Exercise resource-specific selection in the production Ability scanner, not
-- only the pure detector. Shared IDs must still be tied to a reviewed actor.
write(game+ap.rva,ap.bytes)
u(0x41005000+12,1);u(rows_at,219);write(rows_at+17,'\0')
local function reviewed_hash(hash)
    local bytes={};for i=15,1,-2 do bytes[#bytes+1]=string.char(tonumber(hash:sub(i,i+1),16))end
    write(descriptors_at,table.concat(bytes))
end
reviewed_hash('a05bd1ec67b3ac4c')
n=make_native(mem,profile);n:begin()
items,actors=n:attack_candidates(0)
assert(#items==1 and items[1].id==219 and actors[1].class_name=='charger_tier2')
reviewed_hash('000000000000ffff');n:begin();assert(#n:attack_candidates(0)==0,'a shared attack ID cannot authorize an unknown resource')
reviewed_hash('5d142c3a73ebc634');u(rows_at,1019);n:begin();items=n:attack_candidates(0)
assert(#items==1 and profile.expanded.resources['5d142c3a73ebc634'].excluded[items[1].id]=='artillery')
print('PASS production expanded Ability selection: exact resource/class pairing, unknown identity refusal and explicit artillery decisions')

-- Production Factory path reads the same canonical world descriptors used by
-- native creation. All regions here are fake; no game process is opened.
write(game+cp.rva,cp.bytes)
local F=profile.expanded.factory
make_native=function(memory,profile)return core.new(memory,profile)end
region(game+F.world_global,8);p(game+F.world_global,0x48000000)
local descriptors=0x48000000+F.descriptors_offset
region(descriptors,F.slots*24);region(game+F.invalid_entity_global,4);u(game+F.invalid_entity_global,0xffffffff)
local function resource_bytes(hash)
    local out={};for i=15,1,-2 do out[#out+1]=string.char(tonumber(hash:sub(i,i+1),16))end
    return table.concat(out)
end
local function factory(index,id)
    local at=descriptors+index*24
    write(at,resource_bytes(F.resource));u(at+8,id);u(at+12,4194307);u(at+20,1)
end
factory(0,100)
n=make_native(mem,profile);n:begin()
local selected,scan=n:factory_candidates(0)
assert(#selected==1 and selected[1].pointer==pointer(descriptors)and scan.cursor==0 and scan.scanned==2048)
-- The canonical pointer is shared by Behavior and Health, not a cloned row.
p(0x44002000,descriptors);p(0x41010000,descriptors)
u(0x44003000,99);u(0x44003008,3);u(0x44003018,777);u(0x44003060,1);write(0x44003078,'\1')
write(0x44003000+F.stage_start_offset,pack(1000000,8));u(0x44003000+F.ready_offset,F.ready_mask)
region(game+F.clock_global,8);p(game+F.clock_global,0x49000000);region(0x49000000,64)
write(0x49000000+F.clock_offset,pack(1600000,8))
n:begin();local target=n:behavior_target(selected[1],{id=777})
assert(target.behavior==99 and target.stage==3 and target.target_is_local and target.preparation_ready)
assert(target.native_time==1600000 and target.preparation_started==1000000)
local current=n:resolve(n:health_header(),100,profile.health_resources)
assert(current.pointer==selected[1].pointer and current.identity==selected[1].identity)
u(descriptors+8,0xffffffff);n:begin();assert(#n:factory_candidates(0)==0,'invalid descriptors cannot be selected')
factory(0,100);u(descriptors+20,3);n:begin();assert(#n:factory_candidates(0)==0,'destroying descriptors cannot be selected')
factory(0,100)
for i=1,24 do factory(i,100+i)end
local all,cursor={},0
repeat
    n:begin();selected,scan=n:factory_candidates(cursor);cursor=scan.cursor
    assert(n.bytes<1048576 and #selected<=8)
    for _,actor in ipairs(selected)do assert(not all[actor.id]);all[actor.id]=true end
until cursor==0
local count=0;for _ in pairs(all)do count=count+1 end;assert(count==25,'batch limits cannot become permanent observation slots')
local ep=profile.expanded.pins[1];write(game+ep.rva,string.rep('\0',#ep.bytes))
n=make_native(mem,profile);n:begin();assert(not pcall(n.factory_candidates,n,0))
print('PASS Factory production reader: canonical descriptors, exact native microsecond clocks, readiness flag, lifecycle, fair 25-actor scan and pin rejection')

n=core.new(mem,profile)
for _,name in ipairs({'animation','discover','abilities','targeting_header','targeting_discover',
    'targeting_resolve','targeting_state','weapon_inputs','combat_state'})do
    assert(n[name]==nil,'release reader exposes a research function: '..name)
end
print('PASS release native reader has no research/animation/weapon-input collection methods')
