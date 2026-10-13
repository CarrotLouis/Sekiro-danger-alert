local root=arg[1]
local fn=assert(loadfile(root..'/build/Sekiro danger alert.lua'))
local util=require('jit.util');local seen={};local count,maxbc=0,0
local function walk(f)
    if seen[f] then return end;seen[f]=true
    local info=util.funcinfo(f);assert(info.bytecodes<65535,'function too large')
    count=count+1;maxbc=math.max(maxbc,info.bytecodes)
    for i=1,info.gcconsts do
        local v=util.funck(f,-i)
        if type(v)~='string' and v~=nil then
            local ok,child=pcall(util.funcinfo,v)
            if ok and type(child)=='table' and child.bytecodes then walk(v) end
        end
    end
end
walk(fn)
print('PASS exact game LuaJIT compile; prototypes',count,'max bytecodes',maxbc)
local assets=dofile(root..'/build/assets.lua')
assert(#assets.frames==50 and #assets.colours==4)
assert(assets.frames[50].name:match('peril_049$'))
assert(math.abs(50/assets.fps-0.8341666667)<1e-8)
assert(assets.colours[1][2]==1 and assets.colours[1][3]==1 and assets.colours[1][4]==1)
assert(assets.colours[2][2]==1 and assets.colours[2][3]==0 and assets.colours[2][4]==0)
assert(assets.colours[3][2]==1 and assets.colours[3][3]==1 and assets.colours[3][4]==0)
assert(assets.colours[4][1]==0)
print('PASS packaged R2 frame count, duration and exactly four native colour slots')
