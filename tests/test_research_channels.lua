-- Bounded, diagnostic-only byte readers; these fixtures do not establish a
-- live Dragon target or a Factory pre-fire commitment signal.
local root=arg[1];local ffi=require('ffi')
local Native=dofile(root..'/src/native.lua')
local extension=dofile(root..'/tools/diagnostics/src/native.lua')
local profile=dofile(root..'/src/profile.lua')
local blocks={};local game=0x10000000;local actor_at=0x60000000
local function pointer(n)return ffi.cast('uint8_t *',n)end
local function address(n)return tonumber(ffi.cast('uintptr_t',n))end
local function pack(n,size)
    local b={};for i=1,size do b[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(b)
end
local function region(at,size)blocks[at]=string.rep('\0',size)end
local function put(at,s)
    for base,b in pairs(blocks)do if at>=base and at+#s<=base+#b then
        local p=at-base;blocks[base]=b:sub(1,p)..s..b:sub(p+#s+1);return
    end end;error('fixture write outside region')
end
local function u(at,n)put(at,pack(n,4))end
local function p(at,n)put(at,pack(n,8))end
local function read(at,size)
    assert(type(at)=='cdata','reader requires a pointer')
    at=address(at)
    for base,b in pairs(blocks)do if at>=base and at+size<=base+#b then return b:sub(at-base+1,at-base+size)end end
end
local function decode(s,off)
    local n=0;for i=8,1,-1 do n=n*256+s:byte((off or 0)+i)end
    if n>=65536 then return pointer(n)end
end
local mem={module=function(name)return pointer(name and game or 0x20000000)end,
    read=read,pointer=decode,address=address}
for _,pins in ipairs({profile.peer_pins,profile.combat_pins})do
    for _,pin in ipairs(pins)do region(game+pin.rva,#pin.bytes);put(game+pin.rva,pin.bytes)end
end
region(actor_at,24);u(actor_at+8,100);u(actor_at+12,1000);u(actor_at+16,91)
local function actor(hash,owned)
    local b={};for i=15,1,-2 do b[#b+1]=string.char(tonumber(hash:sub(i,i+1),16))end
    put(actor_at,table.concat(b));u(actor_at+20,owned and 1 or 0)
    return {id=100,unit=1000,network_id=91,resource=hash,owned=owned,
        pointer=pointer(actor_at),identity=read(pointer(actor_at),20)}
end
local function manager(global,base,map,handles,records,stride,count)
    region(game+global,8);p(game+global,base);region(base,0x100)
    p(base+map,base+0x1000);u(base+map+8,1);u(base+map+12,0xffffffff);u(base+map+16,1)
    region(base+0x1000,8);u(base+0x1000,100)
    p(base+handles,base+0x2000);region(base+0x2000,8);p(base+0x2000,actor_at)
    p(base+records,base+0x3000);region(base+0x3000,stride)
    if count then u(base+count,1)end
end
manager(0x33266d8,0x61000000,0x50,0x68,0x78,0xa8)
manager(0x3326de0,0x62000000,0x20,0x38,0x48,0x1c,8)
manager(0x3326740,0x63000000,0x40,0x58,0x68,0xa0)
local clock=ffi.new('float[2]',{.3,1});put(0x61003008,ffi.string(clock,8));put(0x61003000,'\1\2\3')
u(0x62003004,12345);u(0x63003000,6);u(0x63003004,108)
local n=Native.new(mem,profile,extension);local e=actor('843d18d4b5512b63',false)
n:begin();local state=n:projectile_state(e)
assert(math.abs(state.fire_gate_timer-.3)<.00001 and state.shot_interval==1 and state.state_bytes[3]==3)
assert(#state.raw_hex==0xa8*2 and state.interpretation=='diagnostic_only_not_committed_shot')
assert(n:flight_network_state(e)==nil)
e=actor('960b48a421a3faaa',false);n:begin();state=n:flight_network_state(e)
assert(state.words[2]==12345 and #state.raw_hex==0x1c*2 and state.interpretation=='diagnostic_only_not_verified_target')
assert(n:projectile_state(e)==nil)
state=n:behavior_network_state(e);assert(state.stage==6 and state.behavior==108 and #state.raw_hex==0xa0*2)
assert(state.interpretation=='received_network_state')
e=actor(e.resource,true);assert(n:behavior_network_state(e).interpretation=='last_encoded_network_state')
u(actor_at+20,0);assert(not pcall(n.flight_network_state,n,e),'ownership changes must invalidate a sampled owner')
e=actor(e.resource,false);u(actor_at+20,2);assert(not pcall(n.flight_network_state,n,e),'destroyed entities must not be read')
e=actor(e.resource,false);u(0x62000008,5000);assert(not pcall(n.flight_network_state,n,e),'controller count must be bounded')
u(0x62000008,0);assert(n:flight_network_state(e)==nil);u(0x62000008,1)
p(0x62002000,actor_at+8);assert(n:flight_network_state(e)==nil);p(0x62002000,actor_at)
local pin=profile.combat_pins[#profile.combat_pins];put(game+pin.rva,string.rep('\0',#pin.bytes))
local rejected=Native.new(mem,profile,extension);assert(not pcall(rejected.flight_network_state,rejected,e))
put(game+pin.rva,pin.bytes)
-- New optional readers must not stop other channels or create alert decisions.
n=Native.new(mem,profile,extension)
n.behavior_target=function()return {stage=6,target=7}end
n.weapon_inputs=function()return {replicated_input_bits=0}end
n.replicated_target=function()return {verified=true,target=7}end
n.replicated_behavior=function()return {verified=true,stage=6}end
n.flight_network_state=function()error('optional flying controller unavailable')end
n:begin();state=n:combat_state(nil,e,{id=7},false)
assert(state.observation_errors.flight_network_state and state.observation_errors.aim)
assert(state.weapon_inputs and state.replicated_target and state.behavior_network_state)
assert(n.reads<100 and n.bytes<4096,'new channels must stay well inside the shared budget')
print('PASS diagnostic projectile/flying/network readers: typed reads, scope, raw provenance, identity/count/pin guards and optional-channel isolation')
