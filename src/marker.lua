-- F8 is read only during capture and only while this game's window has focus.
local M={}
function M.new()
    local ffi=require('ffi')
    if not pcall(ffi.typeof,'pw01_hwnd') then ffi.cdef[[
        typedef void *pw01_hwnd;
        short pw01_key(int) __asm__("GetAsyncKeyState");
        pw01_hwnd pw01_foreground(void) __asm__("GetForegroundWindow");
        unsigned int pw01_window_pid(pw01_hwnd,unsigned int *) __asm__("GetWindowThreadProcessId");
        unsigned int pw01_pid(void) __asm__("GetCurrentProcessId");
    ]] end
    local user=ffi.load('user32');local kernel=ffi.load('kernel32')
    local pid=kernel.pw01_pid();local out=ffi.new('unsigned int[1]');local held=false
    return function()
        local window=user.pw01_foreground();if window==nil then held=false;return false end
        user.pw01_window_pid(window,out)
        if out[0]~=pid then held=false;return false end
        local down=user.pw01_key(0x77)<0;local edge=down and not held;held=down;return edge
    end
end
return M
