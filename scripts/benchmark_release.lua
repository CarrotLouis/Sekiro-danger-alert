-- Offline native-boundary comparison. All buffers belong to this process;
-- ReadProcessMemory/QPC are the vendored reader, never an engine entry point.
local root,baseline=arg[1],arg[2]
local ffi=require('ffi')
local runtime=dofile(root..'/vendor/bingus_runtime.lua')
local memory=dofile(root..'/vendor/bingus_memory.lua').new(runtime)
local game=ffi.new('uint8_t[64]');local world=ffi.new('uint8_t[?]',0x100+2048*24)
local function address(p)return tonumber(ffi.cast('uintptr_t',p))end
local function put(at,n,size)
    local b={};for i=1,size do b[i]=string.char(n%256);n=math.floor(n/256)end
    ffi.copy(at,table.concat(b),size)
end
put(game+0x10,address(world),8);put(game+0x18,0xffffffff,4);game[0x28]=0x90
memory.module=function()return ffi.cast('uint8_t *',game)end
local resource='843d18d4b5512b63';local hash={}
for i=15,1,-2 do hash[#hash+1]=string.char(tonumber(resource:sub(i,i+1),16))end
hash=table.concat(hash)
local profile={expanded={pins={{rva=0x28,bytes='\144',label='owned buffer'}},factory={
    world_global=0x10,invalid_entity_global=0x18,slots=2048,stride=24,descriptors_offset=0x100,resource=resource}},
    health_resources={[resource]={class_name='big_walker_turret_cannon'}}}
local before=dofile(baseline..'/native.lua').new(memory,profile)
local after=dofile(root..'/src/native.lua').new(memory,profile)
local function fixture(count)
    ffi.fill(world,ffi.sizeof(world),0)
    for i=0,count-1 do
        local slot=count==1 and 2047 or math.floor(i*2047/math.max(count-1,1))
        local at=world+0x100+slot*24
        ffi.copy(at,hash,8);put(at+8,i+1,4);put(at+12,i+101,4);put(at+16,i+201,4);put(at+20,1,4)
    end
end
local function compare()
    local a,b=0,0;local seen={}
    repeat
        before:begin();after:begin()
        local old,sa=before:factory_candidates(a);local new,sb=after:factory_candidates(b)
        assert(#old==#new and sa.cursor==sb.cursor and sa.scanned==sb.scanned and sa.remaining==sb.remaining)
        for i,e in ipairs(old)do
            assert(new[i].id==e.id and new[i].unit==e.unit and new[i].identity==e.identity)
            assert(not seen[e.id]);seen[e.id]=true
        end
        a,b=sa.cursor,sb.cursor
    until a==0
end
local function measure(reader)
    local cursor=0
    for _=1,200 do reader:begin();local _,s=reader:factory_candidates(cursor);cursor=s.cursor end
    local times={};local reads,bytes=0,0;local n=600
    for trial=1,7 do
        collectgarbage('collect')
        local started=memory.time()
        for _=1,n do
            reader:begin();local _,s=reader:factory_candidates(cursor);cursor=s.cursor
            reads=reads+reader.reads;bytes=bytes+reader.bytes
        end
        times[#times+1]=(memory.time()-started)*1000/n
    end
    table.sort(times)
    return times[4],reads/(n*7),bytes/(n*7)
end
for _,count in ipairs({0,1,8,25})do
    fixture(count);compare()
    local old,old_reads,old_bytes=measure(before)
    local new,new_reads,new_bytes=measure(after)
    assert(math.abs(old_reads-new_reads)<.1 and math.abs(old_bytes-new_bytes)<3)
    print(string.format('RESULT %d %.9f %.9f %.3f %.3f',count,old,new,new_reads,new_bytes))
end
-- A resource byte sequence in the middle of a descriptor is not its identity.
fixture(0);ffi.copy(world+0x100+3,hash,8);compare()
-- Destroyed and invalid descriptors remain excluded.
fixture(1);put(world+0x100+2047*24+20,2,4);compare()
fixture(1);put(world+0x100+2047*24+8,0xffffffff,4);compare()
print('PASS baseline-equivalent cursor fairness, identities, unaligned bytes and destroyed/invalid rejection')
