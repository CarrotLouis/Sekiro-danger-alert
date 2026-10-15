local root=arg[1];local ffi=require('ffi')
local module=dofile(root..'/tools/enemy_spawner/src/channel.lua')
local bytes={}
local function put(at,s)for i=1,#s do bytes[at+i-1]=s:byte(i)end end
local function raw(n,size)local out={};for i=1,size do out[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(out)end
local function pointer(at,value)put(at,raw(value,8))end
local game,exe,ctx,engine,pl,members,name=0x1000,0x100000,0x200000,0x300000,0x310000,0x320000,0x330000
local profile={key='sda_spawn',pins={{module='game',rva=0x30,bytes='PROOF',label='test pin'}},
    context={global=0x10,localPeer=0x20,hostPeer=0x28,wrapper=0x100},
    wrapper={engineLobby=0,active=0x10,platformPosted=0x11},
    playfab={lobby=0x10,memberCount=0x100,members=0x108,state=0x118,joined=3,handle=0x120},
    api={registryGlobal=0x18,registry=0x1000,table=0xf8,tableRva=0x2000,memberData=0x118,setMemberData=0x120,
        memberDataRva=0x3000,setMemberDataRva=0x4000}}
put(game+0x30,'PROOF');pointer(game+0x10,ctx);put(ctx,string.rep('\0',0x200))
pointer(ctx+0x20,1);pointer(ctx+0x28,2);pointer(ctx+0x100,engine);put(ctx+0x110,'\1\0')
pointer(engine+0x10,pl);put(pl,string.rep('\0',0x200));pointer(pl,name);put(name,'lobby-1\0'..string.rep('\0',128))
put(pl+0x100,raw(2,4));pointer(pl+0x108,members);pointer(members,1);pointer(members+8,2)
put(pl+0x118,raw(3,4));pointer(pl+0x120,123)
pointer(game+0x18,exe+0x1000);pointer(exe+0x10f8,exe+0x2000)
pointer(exe+0x2118,exe+0x3000);pointer(exe+0x2120,exe+0x4000)
local value_at=0x340fff;put(value_at,'SDAES1 H 0000000000000001\0'..string.rep('\0',512))
local mem={module=function(n)return n and game or exe end,address=function(n)return tonumber(n)end,
    read=function(at,n)
        local out={};for i=0,n-1 do if not bytes[at+i]then return nil end;out[#out+1]=string.char(bytes[at+i])end;return table.concat(out)
    end,pointer=function(s,o)
        local n=0;for i=8,1,-1 do n=n*256+s:byte((o or 0)+i)end;if n>0 then return n end
    end}
local gets,sets,code=0,0,0
local calls={get=function(entry,lobby,lo,hi,key)
    assert(entry==exe+0x3000 and lobby==engine and lo==2 and hi==0 and key=='sda_spawn');gets=gets+1;return value_at
end,set=function(entry,lobby,key,v)
    assert(entry==exe+0x4000 and lobby==engine and key=='sda_spawn'and v:match('^SDAES1'))
    sets=sets+1;return code
end}
local channel=module.new(mem,profile,function()end,calls)
local context=assert(channel:snapshot(0));assert(not context.is_host and context.values['0000000000000002']:find('SDAES1',1,true))
assert(channel:publish('SDAES1 W',0,context)==false and sets==0)
assert(channel:publish('SDAES1 W',10,context)==false and sets==0,'wait for game platform post up to 20 seconds')
put(ctx+0x111,'\1')
assert(channel:publish('SDAES1 W',10,context)and sets==1)
assert(channel:publish('SDAES1 W',11,context)and sets==1,'unchanged value is not reposted')
assert(channel:publish('SDAES1 H 0000000000000001',11,context)==false and sets==1)
code=-1
for t=15,25,5 do assert(channel:publish('SDAES1 H 0000000000000001',t,context)==false)end
assert(channel:publish('SDAES1 H 0000000000000001',30,context)==nil and sets==4,'three failures stop posts for this lobby')
put(name,'lobby-2\0');context=assert(channel:snapshot(35));code=0
assert(channel:publish('SDAES1 W',45,context)and sets==5,'a new actual lobby identity resets join/post state')
pointer(exe+0x2118,exe+0x3001);local before=gets
assert(not pcall(channel.snapshot,channel,46)and gets==before,'wrong function slots never get called')
pointer(exe+0x2118,exe+0x3000);put(game+0x30,'WRONG')
assert(not pcall(channel.snapshot,channel,47)and gets==before,'wrong build pins never get called')
put(game+0x30,'PROOF');put(ctx+0x110,'\0')
assert(not channel:snapshot(48)and gets==before,'not joined never calls the SDK')
put(ctx+0x110,'\1');put(value_at,'nonascii\1\0')
assert(next(channel:snapshot(49).values)==nil,'untrusted non-ASCII values are discarded')
-- Exercise the actual two FFI wrapper ABIs against harmless in-process callbacks.
local native=module.calls();local text=ffi.new('char[8]','SDAES1')
local get_callback=ffi.cast('const char *(*)(void *, uint64_t, const char *)',function(lobby,id,key)
    assert(tonumber(ffi.cast('uintptr_t',lobby))==123 and ffi.string(key)=='sda_spawn')
    assert(id==ffi.new('uint64_t',0xfedcba98)*4294967296+0x87654321)
    return ffi.cast('const char *',text)
end)
assert(native.get(get_callback,123,0x87654321,0xfedcba98,'sda_spawn')==tonumber(ffi.cast('uintptr_t',text)))
local set_callback=ffi.cast('int32_t (*)(void *, uint32_t, const char **, const char **)',function(lobby,count,keys,values)
    assert(tonumber(ffi.cast('uintptr_t',lobby))==123 and count==1 and ffi.string(keys[0])=='sda_spawn'and ffi.string(values[0])=='SDAES1 W')
    return 0
end)
assert(native.set(set_callback,123,'sda_spawn','SDAES1 W')==0)
get_callback:free();set_callback:free()
-- Match Bingus memory's actual uint8_t* boundary, not only numeric test addresses.
local function address(at)return tonumber(ffi.cast('uintptr_t',at))end
local pointer_mem={module=function(n)return ffi.cast('uint8_t *',n and game or exe)end,address=address,
    read=function(at,n)return mem.read(address(at),n)end,
    pointer=function(s,o)local n=mem.pointer(s,o);if n then return ffi.cast('uint8_t *',n)end end}
local pointer_calls={get=function(entry,lobby,lo,hi,key)return calls.get(address(entry),address(lobby),lo,hi,key)end,
    set=function(entry,lobby,key,v)return calls.set(address(entry),address(lobby),key,v)end}
put(value_at,'SDAES1 W\0')
local pointers=module.new(pointer_mem,profile,function()end,pointer_calls)
local pointer_context=assert(pointers:snapshot(0))
assert(pointer_context.values['0000000000000002']=='SDAES1 W')
assert(pointers:publish('SDAES1 W',10,pointer_context),'the real pointer type must work through both calls')
print('PASS peer channel: exact ABI/64-bit IDs, joined-member/slot/pin checks, join delay, 5s post ceiling, failure limit, page-bounded text and independent own key')
