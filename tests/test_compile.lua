local root=arg[1]
local fn=assert(loadfile(root..'/build/peril_warning.lua'))
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
