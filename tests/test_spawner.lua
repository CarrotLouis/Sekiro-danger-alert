local root=arg[1]
local ffi=require('ffi')
local module=dofile(root..'/tools/enemy_spawner/src/native.lua')
local controller_module=dofile(root..'/tools/enemy_spawner/src/controller.lua')
local function u32(s,o)
    local a,b,c,d=s:byte(o+1,o+4);return a+b*256+c*65536+d*16777216
end
local function bytes(n,size)
    local out={};for i=1,size do out[i]=string.char(n%256);n=math.floor(n/256)end
    return table.concat(out)
end
local function unhex(h)
    local out={};for i=#h-1,1,-2 do out[#out+1]=string.char(tonumber(h:sub(i,i+1),16))end
    return table.concat(out)
end
local enemy={id='test_enemy',hash='a05bd1ec67b3ac4c',label='Test enemy',faction=2,behavior=104,
    packages={'578fd2bcda91ee2f'},package_record='00000000000000002fee91dabcd28f5700000000000000000000000000000000',
    required_units={{entity='a05bd1ec67b3ac4c',unit='3aff5fd7d5450b99'}}}
local avatar={id=123,position={x=1,y=2,z=3}}
local d=module.descriptor(enemy,avatar,{x=4,y=5,z=6},{x=0,y=-1})
assert(tonumber(ffi.cast('uintptr_t',d.at))%8==0 and tonumber(ffi.cast('uintptr_t',d.context))%16==0)
assert(d.at[0]==1 and ffi.cast('uint32_t *',d.at+4)[0]==0x7fff)
assert(ffi.string(d.entity,8)==unhex(enemy.hash))
local pose=ffi.cast('float *',d.at+8)
assert(pose[0]==-1 and pose[5]==-1 and pose[10]==1 and pose[12]==4 and pose[13]==5 and pose[14]==6 and pose[15]==1)
assert(ffi.cast('void **',d.at+0x48)[0]==ffi.cast('void *',d.context))
assert(ffi.cast('void **',d.at+0x50)[0]==nil)
assert(ffi.cast('uint32_t *',d.context+0x66c)[0]==123)
local target=ffi.cast('float *',d.context+0x670)
assert(target[0]==1 and target[1]==2 and target[2]==3)
local raw=ffi.string(d.context,0x8a0)
assert(raw:sub(1,0x66c)==string.rep('\0',0x66c)and raw:sub(0x67c+1)==string.rep('\0',0x8a0-0x67c))
assert(not pcall(module.descriptor,enemy,avatar,{x=0/0,y=0,z=0},{x=0,y=1}))
assert(not pcall(module.descriptor,enemy,avatar,{x=1,y=2,z=3},{x=1,y=1}))
print('PASS spawn ABI: aligned descriptor, exact 64-bit hash, native pose, target-only context, no modifier pointer')

local live,ready,epoch,avatar_id=true,false,'mission1',123
local calls={spawn=0,prepare=0}
local mock={begin=function()end}
function mock:scene()
    if not live then return nil,'dead'end
    return {key=epoch,faction=2,avatar={id=avatar_id},mission=true}
end
function mock:prepare()calls.prepare=calls.prepare+1;return ready end
function mock:spawn()calls.spawn=calls.spawn+1;return {verified=true,entity=100,unit=200,behavior=104,
    target_local=true,position={x=20,y=0,z=0}}end
local c=controller_module.new(mock,function()end,function()end)
assert(c:request(enemy,0));c:step(0);c:step(1)
assert(calls.spawn==0 and c.pending.phase=='loading','resource wait cannot spawn')
assert(not c:request(enemy,1),'cannot stack requests')
ready=true;c:step(2);assert(c.pending.due==5)
c:step(4.99);assert(calls.spawn==0)
c:step(5);c:step(6);assert(calls.spawn==1 and c.pending==nil,'exactly one spawn after countdown')
assert(not c:request(enemy,6),'cooldown')
assert(c:request(enemy,8));c:step(8);avatar_id=124;c:step(9)
assert(c.pending==nil and calls.spawn==1,'death/respawn cancels without spawning')
assert(c:request(enemy,11));ready=false;c:step(11);c:step(101)
assert(c.pending==nil and calls.spawn==1,'90 second timeout cancels')
live=false;assert(not c:request(enemy,105));live=true
local wrong={id='wrong',hash=enemy.hash,faction=8};assert(not c:request(wrong,106))
assert(c:request(enemy,107));epoch='mission2';c:step(108);assert(c.pending==nil)
ready=true
function mock:spawn()calls.spawn=calls.spawn+1;return {verified=false,entity=100}end
assert(c:request(enemy,110));c:step(110);c:step(113)
assert(c.blocked and c.pending==nil and not c:request(enemy,117),'unverified creation stops further requests')
local refusal_status
local refused_controller=controller_module.new(mock,function()end,function(s)refusal_status=s end)
function mock:prepare()return nil,'Impaler requires difficulty 5–10'end
assert(refused_controller:request(enemy,120));local before_refusal=calls.spawn;refused_controller:step(120)
assert(refused_controller.pending==nil and refusal_status=='Impaler requires difficulty 5–10'and calls.spawn==before_refusal,
    'permanent summon refusal cancels immediately and reaches the menu status')
print('PASS controller: resources, delay, exactly once, cooldown, death, world change, timeout, failed creation stop')

-- A synthetic memory image exercises the production gate; the test never opens a game process.
local game,exe,world,mode,players,ai,instance=0x100000,0x200000,0x10000000,0x20000000,0x21000000,0x22000000,0x23000000
local blocks={}
local function put(at,s)blocks[at]=s end
local function pointer(at,p)put(at,bytes(p,8))end
local mem={module=function(name)return name and game or exe end,address=function(v)return v end,
    pointer=function(s,o)local n=u32(s,o or 0)+u32(s,(o or 0)+4)*4294967296;return n~=0 and n or nil end}
function mem.read(at,n)
    for start,s in pairs(blocks)do if at>=start and at+n<=start+#s then return s:sub(at-start+1,at-start+n)end end
    return nil
end
local profile={pins={{module='game',rva=0x1000,bytes='PROOF',label='fixture'}},world_global=0x10,
    ai_global=0x18,ai_faction=8,component_slot_base=0x100,loader={instanceGlobalRva=0x20,requestRva=0x1100,
    refcountMap={capacity=8,entries=0},engine={managerGlobalRva=0x30,packageManager=0x10,resourceManager=0x10,
    listCount=0,list=8,packageId=0,partCount=8,parts=16,partState=0,loadedState=4}},
    default_context=0x1000,context_size=0x8a0,invalid_entity=0x28,entity_handles=0x2000,entity_slots=2048,spawn_rva=0x1200}
local catalog={tables={}}
local offset=0x30000000
local function table_record(name,index,raw)
    catalog.tables[name]={index=index,slots=1,records=1,offset=16,stride=#raw}
    pointer(world+0x100+index*8,offset)
    put(offset,unhex(enemy.hash)..bytes(0,4)..bytes(0,4)..raw);offset=offset+0x1000
end
local raw_package=enemy.package_record:gsub('%x%x',function(h)return string.char(tonumber(h,16))end)
table_record('EnemyPackageComponentData',0,raw_package)
table_record('BehaviorComponentData',1,bytes(104,4)..string.rep('\0',8))
table_record('UnitComponentData',2,unhex(enemy.required_units[1].unit)..string.rep('\0',128))
put(game+0x1000,'PROOF');pointer(game+0x10,world);pointer(game+0x18,ai);put(ai+8,bytes(2,4))
pointer(game+53634152,players);put(players+132,bytes(1,4))
pointer(game+53634720,mode);put(mode+8,bytes(1,4));pointer(mode+56,0x20001000)
put(0x20001000,string.rep('\0',8)..bytes(99,4)..string.rep('\0',8)..bytes(1,4))
pointer(game+0x20,instance)
local refmap=0x24000000
put(instance,bytes(refmap,8)..bytes(16,4)..string.rep('\0',20));put(refmap,string.rep('\0',256))
local app,manager,resources,list,pkg,parts,part=0x25000000,0x26000000,0x27000000,0x28000000,0x29000000,0x2a000000,0x2b000000
pointer(exe+0x30,app);pointer(app+0x10,manager);pointer(manager+0x10,resources)
put(resources,bytes(1,4)..string.rep('\0',4)..bytes(list,8));pointer(list,pkg)
put(pkg,unhex(enemy.packages[1])..bytes(1,4)..string.rep('\0',4)..bytes(parts,8));pointer(parts,part);put(part,bytes(3,4))
put(world+0x1000,string.rep('\0',0x8a0));put(game+0x28,bytes(0xffffffff,4))
put(world+0x2000,string.rep(string.rep('\0',8)..bytes(0xffffffff,4)..string.rep('\0',12),2048))
local unit_ready=true;local core={begin=function()end,unit_ready=function()return unit_ready end}
function core:scene()return {mission=true,key='world',position={x=0,y=0,z=0},avatar={id=123,unit=500,resource='avatar',owned=true}}end
function core:health_header()return {}end
function core:resolve(_,id,scope)
    return {id=id,unit=id==123 and 500 or 600,owned=true,resource=id==123 and'avatar'or enemy.hash}
end
function core:camera()return {forward={0,1,0}}end
-- Use the actual common AI reader at this boundary, so renamed fields cannot be hidden by a fake.
local ai_manager,keys,owners,records,actor_pointer=0x31000000,0x31001000,0x31002000,0x31003000,0x31004000
pointer(game+0x3326740,ai_manager)
put(ai_manager+0x40,bytes(keys,8)..bytes(1,4)..bytes(0xffffffff,4)..bytes(1,4)..bytes(0,4)..bytes(owners,8)..bytes(records,8))
put(keys,bytes(321,4)..bytes(0,4));pointer(owners,actor_pointer)
local actor_descriptor=unhex(enemy.hash)..bytes(321,4)..bytes(600,4)..bytes(0x7fff,4)..bytes(1,4)
put(actor_pointer,actor_descriptor)
local ai_record=ffi.new('uint8_t[0x1f8]')
ffi.cast('uint32_t *',ai_record)[0]=104
ffi.cast('uint32_t *',ai_record+0x18)[0]=123
ffi.cast('uint32_t *',ai_record+0x60)[0]=0x11
ai_record[0x78]=1;put(records,ffi.string(ai_record,0x1f8))
local actual_core=dofile(root..'/src/native.lua').new(mem,{targeting_pins={{rva=0x1000,bytes='PROOF',label='fixture'}}})
function core:behavior_target(e,a)
    actual_core:begin()
    return actual_core:behavior_target({id=e.id,pointer=actor_pointer,identity=actor_descriptor:sub(1,20),owned=true},a)
end
local native_calls={requests=0,spawns=0}
local invoke={request=function(entry,sys,hash)
    assert(entry==game+0x1100 and sys==instance and hash==unhex(enemy.packages[1]));native_calls.requests=native_calls.requests+1
end,spawn=function(entry,args)
    assert(entry==game+0x1200 and ffi.cast('uint32_t *',args.context+0x66c)[0]==123)
    native_calls.spawns=native_calls.spawns+1;return 321
end}
local n=module.new(mem,profile,catalog,core,function()end,invoke)
n:begin();local s=assert(n:scene());assert(s.faction==2)
assert(n:prepare(enemy,s)==false and native_calls.requests==1 and native_calls.spawns==0,'loading is not ready')
put(part,bytes(4,4));n:begin();assert(n:prepare(enemy,s)==true and native_calls.requests==1,'holds are not requested twice')
unit_ready=false;n:begin();assert(n:prepare(enemy,s)==false);unit_ready=true
n:begin();local made=assert(n:spawn(enemy,s));assert(made.verified and native_calls.spawns==1)
for count=2,4 do
    put(players+132,bytes(count,4));n:begin();assert(n:scene().player_count==count)
end
n:begin();assert(n:spawn(enemy,s).verified and native_calls.spawns==2,'multiplayer host uses the proven creation path')
put(0x20001000,string.rep('\0',8)..bytes(99,4)..string.rep('\0',12))
n:begin();assert(n:scene()==nil);n:begin();assert(n:spawn(enemy,s)==nil and native_calls.spawns==2,'peer must never call authoritative creation')
put(0x20001000,string.rep('\0',8)..bytes(99,4)..string.rep('\0',8)..bytes(1,4))
for _,count in ipairs({0,5})do put(players+132,bytes(count,4));n:begin();assert(n:scene()==nil)end
put(players+132,bytes(1,4))
-- Regression: the same native picker that caused both crashes rejects tentacles
-- at difficulties 1..4. Resources alone must never authorize this parent spawn.
local child_hash='672f7da17f3ba34a'
local impaler={id='impaler',hash=enemy.hash,label='Impaler',faction=2,behavior=104,
    packages=enemy.packages,package_record=enemy.package_record,required_units=enemy.required_units,
    min_difficulty=5,summons={{entity=child_hash,group='aff5b26b',row=29}}}
profile.summon_gate={difficulty=0x10,roster=0x20,descriptor=0x4000,rows=0x5000,count=45,
    stride=128,weights=48,tags=88,tag_bytes=32}
pointer(ai+0x20,game+0x4000);put(game+0x4000,bytes(game+0x5000,8)..bytes(45,4))
local row=ffi.new('uint8_t[128]')
ffi.cast('uint32_t *',row)[0]=tonumber('aff5b26b',16);ffi.copy(row+8,unhex(child_hash),8)
local weights=ffi.cast('float *',row+48)
for i=4,9 do weights[i]=1 end
local function roster_row()put(game+0x5000+29*128,ffi.string(row,128))end
roster_row()
local guarded=module.new(mem,profile,catalog,core,function()end,invoke)
local before_requests,before_spawns=native_calls.requests,native_calls.spawns
for difficulty=1,4 do
    put(ai+0x10,bytes(difficulty,4));guarded:begin()
    local allowed,reason=guarded:prepare(impaler,s)
    assert(allowed==nil and reason:find('requires difficulty 5',1,true))
    guarded:begin();assert(guarded:spawn(impaler,s)==nil)
end
assert(native_calls.requests==before_requests and native_calls.spawns==before_spawns,'low difficulty refuses before either native call')
for difficulty=5,10 do
    put(ai+0x10,bytes(difficulty,4));guarded:begin();assert(guarded:prepare(impaler,s)==true)
end
assert(native_calls.requests==before_requests+1,'eligible summon holds packages once')
put(ai+0x10,bytes(5,4));weights[4]=0;roster_row();guarded:begin()
local allowed,reason=guarded:prepare(impaler,s)
assert(allowed==nil and reason:find('tentacles disabled',1,true))
guarded:begin();assert(guarded:spawn(impaler,s)==nil and native_calls.spawns==before_spawns,'changed weight is rechecked before spawn')
for _,weight in ipairs({-1,math.huge,0/0})do
    weights[4]=weight;roster_row();guarded:begin();assert(guarded:prepare(impaler,s)==nil)
end
weights[4]=1;row[88]=1;roster_row();guarded:begin();assert(not pcall(guarded.prepare,guarded,impaler,s),'changed tags refuse')
row[88]=0;ffi.cast('uint32_t *',row)[0]=0;roster_row();guarded:begin();assert(not pcall(guarded.prepare,guarded,impaler,s),'wrong group refuses')
ffi.cast('uint32_t *',row)[0]=tonumber('aff5b26b',16);row[8]=0;roster_row();guarded:begin();assert(not pcall(guarded.prepare,guarded,impaler,s),'wrong child refuses')
ffi.copy(row+8,unhex(child_hash),8);roster_row()
put(game+0x4000,bytes(game+0x5000,8)..bytes(46,4));guarded:begin();assert(not pcall(guarded.prepare,guarded,impaler,s),'changed roster bounds refuse')
put(game+0x4000,bytes(game+0x5000,8)..bytes(45,4));guarded:begin()
assert(guarded:spawn(impaler,s).verified and native_calls.spawns==before_spawns+1,'eligible Impaler keeps native summon AI')
-- The catalog now includes the delayed child unit, so unloaded children block
-- a ready parent even when every package part is marked loaded.
local unit_table=catalog.tables.UnitComponentData
local unit_at=assert(mem.pointer(mem.read(world+0x100+unit_table.index*8,8)))
unit_table.slots,unit_table.records,unit_table.offset=4,2,64
local data=ffi.new('uint8_t[336]')
ffi.copy(data,unhex(enemy.hash),8);ffi.cast('uint32_t *',data+8)[0]=0
ffi.copy(data+32,unhex(child_hash),8);ffi.cast('uint32_t *',data+40)[0]=1
ffi.copy(data+64,unhex(enemy.required_units[1].unit),8);ffi.copy(data+200,unhex(child_hash),8)
put(unit_at,ffi.string(data,336))
impaler.required_units={{entity=enemy.hash,unit=enemy.required_units[1].unit},{entity=child_hash,unit=child_hash}}
function core:unit_ready(hash)return hash~=child_hash end
guarded:begin();local ready,why=guarded:prepare(impaler,s)
assert(ready==false and why:find(child_hash,1,true),'child unit is independently required')
guarded:begin();assert(guarded:spawn(impaler,s)==nil and native_calls.spawns==before_spawns+1)
function core:unit_ready()return true end
guarded:begin();assert(guarded:prepare(impaler,s)==true)
print('PASS Impaler regression: low difficulty has zero native calls; eligible roster, live weight, tags, identity, layout, child readiness and pre-spawn recheck')
put(game+0x1000,'WRONG');n:begin();assert(not pcall(n.prepare,n,enemy,s)and native_calls.spawns==before_spawns+1)
print('PASS production native gates: 1–4 player host authority, peer rejection, exact resources and bounded native insertion')

-- Real production requester lookup: peer roster -> network avatar map ->
-- canonical health/unit -> current authoritative position, never a supplied XYZ.
put(game+0x1000,'PROOF');put(players+132,bytes(2,4))
local avatar_hash='f123456789abcdef';local remote_alive=true
local net_manager,net_rows=0x35000000,0x35001000
profile.remote_players={players={global=53634152,count=132,maxPlayers=4,peers=0x2c8,peerStride=56},
    avatars={lifecycle=0x2e0,lifecycleStride=56,avatarId=0x3a8,avatarIdStride=32,noNetworkId=32767,
        entities=0x38,mapSlots=0x100,entityBase=0x200,entityStride=24}}
pointer(players+0x2c8,1);pointer(players+0x2c8+56,2)
put(players+0x2e0,bytes(3,4));put(players+0x2e0+56,bytes(3,4))
put(players+0x3a8,bytes(11,4));put(players+0x3a8+32,bytes(22,4))
pointer(game+0x38,net_manager)
put(net_manager+0x100,bytes(net_rows,8)..bytes(2,4)..bytes(0xffffffff,4)..bytes(1,4))
put(net_rows,bytes(22,4)..bytes(0,4)..bytes(0xffffffff,4)..bytes(0,4))
put(net_manager+0x200-8,unhex(avatar_hash)..bytes(222,4)..bytes(700,4)..bytes(22,4)..bytes(0,4))
function core:scene()return {mission=true,key='world',position={x=0,y=0,z=0},
    avatar={id=123,unit=500,network_id=11,resource=avatar_hash,owned=true}}end
function core:position(unit)assert(unit==700);return {x=50,y=60,z=7}end
function core:resolve(_,id)
    if id==222 then if not remote_alive then return nil end;return {id=222,unit=700,network_id=22,owned=false,resource=avatar_hash}end
    return {id=id,unit=id==123 and 500 or 600,owned=true,network_id=11,resource=id==123 and avatar_hash or enemy.hash}
end
ffi.cast('uint32_t *',ai_record+0x18)[0]=222;put(records,ffi.string(ai_record,0x1f8))
local remote_spawns=0
local remote_native=module.new(mem,profile,catalog,core,function()end,{request=invoke.request,spawn=function(_,args)
    assert(ffi.cast('uint32_t *',args.context+0x66c)[0]==222)
    local pose=ffi.cast('float *',args.at+8);assert(pose[12]==70 and pose[13]==60)
    local target=ffi.cast('float *',args.context+0x670);assert(target[0]==50 and target[1]==60 and target[2]==7)
    remote_spawns=remote_spawns+1;return 321
end})
local requester={peer='0000000000000002',network=22,direction={x=1,y=0}}
remote_native:begin();local remote_scene=assert(remote_native:scene(requester))
assert(remote_scene.avatar.id==222 and remote_scene.avatar.owned==false and remote_scene.position.x==50)
remote_native:begin();assert(remote_native:spawn(enemy,remote_scene).verified and remote_spawns==1)
remote_alive=false;remote_native:begin();assert(not remote_native:scene(requester))
remote_native:begin();assert(not remote_native:spawn(enemy,remote_scene)and remote_spawns==1)
remote_alive=true;put(players+0x3a8+32,bytes(23,4));remote_native:begin();assert(not remote_native:scene(requester))
put(players+0x3a8+32,bytes(22,4));put(players+0x2e0+56,bytes(2,4))
remote_native:begin();assert(not remote_native:scene(requester))
put(players+0x2e0+56,bytes(3,4));pointer(players+0x2c8+56,3)
remote_native:begin();assert(not remote_native:scene(requester),'another peer cannot claim this avatar')
pointer(players+0x2c8+56,2)
put(0x20001000,string.rep('\0',8)..bytes(99,4)..string.rep('\0',12))
remote_native:begin();assert(remote_native:peer_scene().host==false,'clients may inspect/queue requests')
remote_native:begin();assert(not remote_native:spawn(enemy,remote_scene)and remote_spawns==1,'clients never directly create')
print('PASS production remote creation: current peer/network/lifecycle/health binding, host-chosen requester position/target and peer create rejection')
