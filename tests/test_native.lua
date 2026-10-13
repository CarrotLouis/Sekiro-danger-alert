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
