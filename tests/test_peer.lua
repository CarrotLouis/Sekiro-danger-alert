-- Synthetic engine boundaries, not captures from a live multiplayer session.
local root=arg[1];local ffi=require('ffi')
local profile=dofile(root..'/src/profile.lua')
local Native=dofile(root..'/src/native.lua');local Detector=dofile(root..'/src/detector.lua')
local blocks={};local game=0x10000000
local function pointer(n)return ffi.cast('uint8_t *',n)end
local function address(n)return tonumber(ffi.cast('uintptr_t',n))end
local function pack(n,size)
    local b={};for i=1,size do b[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(b)
end
local function region(at,n)blocks[at]=string.rep('\0',n)end
local function put(at,s)
    for base,b in pairs(blocks)do if at>=base and at+#s<=base+#b then
        local p=at-base;blocks[base]=b:sub(1,p)..s..b:sub(p+#s+1);return
    end end;error('fixture write outside region')
end
local function u(at,n)put(at,pack(n,4))end
local function p(at,n)put(at,pack(n,8))end
local function read(at,n)
    at=address(at)
    for base,b in pairs(blocks)do if at>=base and at+n<=base+#b then return b:sub(at-base+1,at-base+n)end end
end
local function decode_pointer(s,offset)
    local n=0;for i=8,1,-1 do n=n*256+s:byte((offset or 0)+i)end
    if n>=65536 then return pointer(n)end
end
local mem={module=function(name)return pointer(name and game or 0x20000000)end,
    read=read,pointer=decode_pointer,address=address}
for _,pins in ipairs({profile.targeting_pins,profile.attack_pins,profile.expanded.pins,profile.peer_pins})do
    for _,pin in ipairs(pins)do region(game+pin.rva,#pin.bytes);put(game+pin.rva,pin.bytes)end
end
local function hash(h)local b={};for i=15,1,-2 do b[#b+1]=string.char(tonumber(h:sub(i,i+1),16))end;return table.concat(b)end
local actor_at=0x40000000;region(actor_at,24)
put(actor_at,hash('3e0537d606438fea'));u(actor_at+8,100);u(actor_at+12,1000);u(actor_at+16,91)
local function actor()
    return {id=100,unit=1000,network_id=91,resource='3e0537d606438fea',owned=false,
        identity=read(pointer(actor_at),20),pointer=pointer(actor_at)}
end
local avatar={id=7,unit=70,network_id=77}
region(game+0x3326d30,8);p(game+0x3326d30,0x41000000);region(0x41000000,0x188)
u(0x41000140,0);u(0x41000144,1)
p(0x41000150,0x41001000);u(0x41000158,1);u(0x4100015c,0xffffffff);u(0x41000160,1)
region(0x41001000,8);u(0x41001000,100)
p(0x41000168,0x41002000);region(0x41002000,8);p(0x41002000,actor_at)
p(0x41000178,0x41003000);region(0x41003000,0xd0);u(0x41003000,7);u(0x41003004,77)
p(0x41000180,0x41004000);region(0x41004000,24);u(0x41004000,77)
local n=Native.new(mem,profile)
local function target()n:begin();return n:replicated_target(actor(),avatar)end
local lock=target();assert(lock.verified and lock.target_is_local and lock.source=='replicated_aim')
u(0x41003004,76);assert(not target().verified,'unprocessed network change cannot use the cached entity ID');u(0x41003004,77)
put(0x41004014,'\1');assert(not target().verified,'position-only mode cannot inherit a lock');put(0x41004014,'\0')
u(0x41004000,0x7fff);assert(not target().verified);u(0x41004000,77)
avatar.network_id=78;assert(not target().verified,'reinforcement must invalidate the old network identity');avatar.network_id=77
avatar.network_id=nil;assert(not target().verified);avatar.network_id=77
u(0x41003000,8);lock=target();assert(lock.verified and not lock.target_is_local);u(0x41003000,7)
p(0x41002000,actor_at+8);assert(target()==nil,'a different canonical owner cannot inherit the target');p(0x41002000,actor_at)
u(0x41000144,5000);assert(not pcall(target));u(0x41000144,1)
local old_actor=actor();u(actor_at+16,92);n:begin();assert(not pcall(n.replicated_target,n,old_actor,avatar));u(actor_at+16,91)
print('PASS peer target: processed network/entity/avatar identities, position mode, respawn, ownership and bounded table reads')

-- Ability row 1 lies outside the native update prefix (0), yet must be scanned.
region(game+53634624,8);p(game+53634624,0x42000000);region(0x42000000,64)
u(0x42000008,2);u(0x4200000c,0);p(0x42000030,0x42001000);p(0x42000038,0x42002000)
region(0x42001000,16);p(0x42001008,actor_at);region(0x42002000,448)
u(0x42002000+224,821);put(0x42002000+224+16,'\1')
local clock=ffi.new('float[2]',{.05,1});put(0x42002000+224+8,ffi.string(clock,8))
n:begin();local active,selected,stats=n:attack_candidates(0)
assert(#active==1 and #selected==1 and not selected[1].owned and selected[1].network_id==91)
assert(stats.ability_records==2 and stats.local_ability_records==0 and stats.scanned==2)
print('PASS unowned Hulk active row outside update prefix is selected without positions or ownership filtering')

region(game+0x3326740,8);p(game+0x3326740,0x43000000);region(0x43000000,0x70)
p(0x43000040,0x43001000);u(0x43000048,1);u(0x4300004c,0xffffffff);u(0x43000050,1)
region(0x43001000,8);u(0x43001000,100)
p(0x43000058,0x43002000);region(0x43002000,8);p(0x43002000,actor_at)
p(0x43000068,0x43003000);region(0x43003000,0xa0)
u(0x43003000,3);u(0x43003004,99);u(0x43003078,0x10000000)
n:begin();local b=n:replicated_behavior(actor())
assert(b.verified and b.stage==3 and b.behavior==99 and b.preparation_ready)
u(0x43003078,0);n:begin();assert(not n:replicated_behavior(actor()).preparation_ready)
local pin=profile.peer_pins[#profile.peer_pins];put(game+pin.rva,string.rep('\0',#pin.bytes))
local rejected=Native.new(mem,profile);rejected:begin();assert(not pcall(rejected.replicated_target,rejected,actor(),avatar))
put(game+pin.rva,pin.bytes)
print('PASS network Behavior array decoding, readiness clearing and native code mismatch refusal')

-- Production polling must not consult cached owner AI on a peer. Require a
-- progressing native ability clock before warning on the synchronized target.
local e=actor();local tclock=0;local events={};local local_target=77
local fake={begin=function()end,scene=function()return {mission=true,key='world',avatar=avatar}end,
    attack_candidates=function()return {{entity=100,id=821,slot=1,time=tclock,speed=1}},{e},{cursor=0,ability_records=2,local_ability_records=0}end,
    factory_candidates=function()return {},{cursor=0}end,
    health_header=function()return {count=1}end,resolve=function()return e end,
    behavior_target=function()error('peer must not trust host-only AI')end,
    replicated_target=function()return {source='replicated_aim',verified=true,target=local_target==77 and 7 or 8,
        network_target=local_target,has_target=true,tracks_entity=true}end}
local d=Detector.new(fake,profile,function()end,function(event)events[#events+1]=event end)
d:step(0);assert(#events==0 and d.snapshot.decisions[1].reason=='peer_clock_unconfirmed')
d:step(.05);assert(#events==0,'unchanged stale clock must not warn')
tclock=.05;d:step(.1);assert(#events==1 and events[1].target_source=='replicated_aim')
tclock=.1;d:step(.15);assert(#events==1,'same windup must not duplicate')
local_target=88;tclock=0;d:step(3);tclock=.05;d:step(3.05);assert(#events==1,'attacking another diver must not warn')
local_target=77;tclock=0;d:step(6);tclock=.05;d:step(6.05);assert(#events==2)
d:reset();e.ai={target=7,has_target=true,tracks_entity=true,behavior=56}
fake.replicated_target=function()return nil end
tclock=0;d:step(9);tclock=.05;d:step(9.05)
assert(#events==2 and d.snapshot.decisions[1].reason=='unverified_peer_target','cached AI is not a peer fallback')
print('PASS synthetic client Hulk polling: clock progression, self/other/missing target, repeated attacks and cached AI rejection')

-- Factory's remote ready transition uses no host-owned timestamps. Starting
-- mid-preparation or receiving an already-running state is only a baseline.
e.resource=profile.expanded.factory.resource
local ready,stage,network=true,3,77
fake.attack_candidates=function()return {},{},{cursor=0}end
fake.factory_candidates=function()return {e},{cursor=0}end
fake.replicated_target=function()return {source='replicated_aim',verified=network~=nil,target=network==77 and 7 or 8,
    network_target=network,has_target=network~=nil,tracks_entity=network~=nil}end
fake.replicated_behavior=function()return {verified=true,behavior=99,stage=stage,preparation_ready=ready}end
events={};d=Detector.new(fake,profile,function()end,function(event)events[#events+1]=event end)
d:step(0);d:step(.05);assert(#events==0,'joining a ready state cannot fabricate a preparation edge')
ready=false;d:step(.1);ready=true;d:step(.15)
assert(#events==1 and events[1].attack_source=='factory_replica')
d:step(.2);d:step(.25);assert(#events==1)
ready=false;d:step(2);ready=true;d:step(2.05);assert(#events==2)
ready=false;network=88;d:step(4);ready=true;d:step(4.05)
network=77;d:step(4.1);assert(#events==2,'switching the target after someone else\'s preparation edge cannot warn')
ready=false;d:step(6);ready=true;network=nil;d:step(6.05);network=77;d:step(6.1)
assert(#events==3,'target and preparation packets may arrive in adjacent polls')
ready=false;d:step(8);ready=true;d:step(8.5);assert(#events==3,'a scan gap cannot produce a fresh edge')
ready=false;d:step(10);ready=true;network=nil;d:step(10.05);network=77;d:step(10.3)
assert(#events==3,'missing target cannot produce an arbitrarily late preparation cue')
stage=2;d:step(12);ready=true;stage=3;d:step(12.05);assert(#events==4)
local stale={entity=100,id=0,source='factory_stage',slot='factory',time=.6,speed=1,token=123}
assert(d:observe({stale},{[100]=e},15,avatar)[1].reason=='unverified_peer_preparation',
    'host AI timestamps cannot serve as peer preparation evidence')
events={};ready=false;network=77
d=Detector.new(fake,profile,function()end,function(event)events[#events+1]=event end,
    function(move)return move~='factory_fusion_repeater'end)
d:step(20);ready=true;d:step(20.05);assert(#events==0 and d.snapshot.decisions[1].reason=='move_disabled')
print('PASS client Factory: initial baseline, fresh network ready edge, repeated cycles, packet order, retarget and scan/target gaps')

-- Join the actual production readers, health table and detector. Only scene()
-- substitutes the local game context; target/ability/health/world reads use the
-- byte-addressed memory boundary above, including a missing full AI record.
region(game+53634696,8);p(game+53634696,0x44000000);region(0x44000000,4300)
u(0x44000000+4112,1);u(0x44000000+4128,1)
p(0x44000000+4144,0x44002000);u(0x44000000+4152,1)
u(0x44000000+4156,0xffffffff);u(0x44000000+4160,1)
region(0x44002000,8);u(0x44002000,100)
p(0x44000000+4168,0x44003000);region(0x44003000,8);p(0x44003000,actor_at)
p(0x44000000+4184,0x44004000);region(0x44004000,440);u(0x44004000+20,5000)
local F=profile.expanded.factory
region(game+F.world_global,8);p(game+F.world_global,0x45000000)
local world_rows=0x45000000+F.descriptors_offset
region(world_rows,F.slots*24);region(game+F.invalid_entity_global,4);u(game+F.invalid_entity_global,0xffffffff)
n=Native.new(mem,profile)
n.scene=function()return {mission=true,key='synthetic-scene',avatar=avatar}end
events={};d=Detector.new(n,profile,function()end,function(event)events[#events+1]=event end)
clock[0]=0;put(0x42002000+224+8,ffi.string(clock,8));d:step(0)
clock[0]=.05;put(0x42002000+224+8,ffi.string(clock,8));d:step(.05)
assert(#events==1 and events[1].move=='hulk_rotary_saw' and events[1].owned==false)
assert(n.reads<2500 and n.bytes<1048576)
put(0x42002000+224+16,'\0')
put(world_rows,hash(F.resource));u(world_rows+8,100);u(world_rows+12,2000);u(world_rows+16,91)
for _,at in ipairs({0x44003000,0x41002000,0x43002000})do p(at,world_rows)end
u(0x43003078,0);d:step(3)
u(0x43003078,0x10000000);d:step(3.05)
assert(#events==2 and events[2].move=='factory_fusion_repeater' and events[2].owned==false)
assert(events[2].attack_source=='factory_replica' and n.reads<2500 and n.bytes<1048576)
u(0x43003078,0);d:step(5);u(0x44004000+20,0);u(0x43003078,0x10000000);d:step(5.05)
assert(#events==2,'canonical health death must reject a valid network preparation')
print('PASS integrated native peer readers + canonical health + detector: Hulk and Factory warnings, dead owner rejection and read budgets')
local host={id=100,unit=1000,resource='3e0537d606438fea',owned=true,alive=true,
    peer_target={source='replicated_aim',verified=true,target=7,network_target=77,has_target=true,tracks_entity=true}}
d:reset()
local decision=d:observe({{entity=100,id=821,slot=1,time=.05,speed=1}},{[100]=host},20,avatar)[1]
assert(decision.reason=='no_ai_target','owned AI absence cannot fall through to a cached peer target')
