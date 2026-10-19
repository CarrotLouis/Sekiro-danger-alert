-- Keys are read only during manual capture and while this process has focus.
local M={}
-- The first focused poll establishes a baseline. Holding a key across capture
-- start or Alt-Tab cannot create a false marker; simultaneous edges stay distinct.
function M.edges()
    local held,armed={},false
    return function(focused,down)
        local edges={}
        if not focused then held={};armed=false;return edges end
        if armed then
            for i,value in ipairs(down)do if value and not held[i]then edges[#edges+1]=i end end
        end
        held=down;armed=true;return edges
    end
end
function M.new(bindings)
    local ffi=require('ffi')
    if not pcall(ffi.typeof,'pw01_hwnd') then ffi.cdef[[
        typedef void *pw01_hwnd;
        short pw01_key(int) __asm__("GetAsyncKeyState");
        pw01_hwnd pw01_foreground(void) __asm__("GetForegroundWindow");
        unsigned int pw01_window_pid(pw01_hwnd,unsigned int *) __asm__("GetWindowThreadProcessId");
        unsigned int pw01_pid(void) __asm__("GetCurrentProcessId");
    ]] end
    local user=ffi.load('user32');local kernel=ffi.load('kernel32')
    local single=bindings==nil
    bindings=bindings or {{key='F8',vk=0x77}}
    assert(#bindings>=1 and #bindings<=4,'marker key count')
    local pid=kernel.pw01_pid();local out=ffi.new('unsigned int[1]');local poll=M.edges()
    return function()
        local window=user.pw01_foreground();local focused=false
        if window~=nil then user.pw01_window_pid(window,out);focused=out[0]==pid end
        local down={}
        if focused then for i,b in ipairs(bindings)do down[i]=user.pw01_key(b.vk)<0 end end
        local edges=poll(focused,down)
        if single then return #edges>0 end
        local result={};for _,i in ipairs(edges)do result[#result+1]=bindings[i].key end
        return result
    end
end
return M
