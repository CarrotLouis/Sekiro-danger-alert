local root=arg[1];local ffi=require('ffi')
-- Deliberately incompatible common Windows names: our FFI must remain private.
ffi.cdef[[typedef int HWAVEOUT; typedef struct { int wrong; } WAVEHDR;]]
local load=ffi.load;local calls={};local captured;local queue=false
local mock={
 pw01_open=function(out,id,fmt,cb,inst,flags)
    assert(fmt[0].channels==2 and fmt[0].rate==48000 and fmt[0].bits==16)
    assert(cb==0 and inst==0 and flags==0);out[0]=ffi.cast('void *',0x12345);calls.open=(calls.open or 0)+1;return 0
 end,
 pw01_prepare=function(handle,h,size) assert(size==48);h[0].flags=2;calls.prepare=(calls.prepare or 0)+1;return 0 end,
 pw01_write=function(handle,h)captured=ffi.string(h[0].data,h[0].length);queue=true;return 0 end,
 pw01_reset=function()queue=false;calls.reset=(calls.reset or 0)+1;return 0 end,
 pw01_unprepare=function()assert(not queue);return 0 end,
 pw01_close=function()assert(not queue);return 0 end,
}
ffi.load=function(name)if name=='winmm' then return mock end;return load(name)end
local pcm=ffi.new('int16_t[4]',{10000,-10000,32767,-32768})
local notes={}
local player=dofile(root..'/src/audio.lua').new(ffi.string(pcm,8),48000,2,function(s)notes[#notes+1]=s end)
assert(player:play(25));local out=ffi.new('int16_t[4]');ffi.copy(out,captured,8)
assert(out[0]==2500 and out[1]==-2500 and out[2]==8191 and out[3]==-8192)
assert(player:play(100));assert(captured==ffi.string(pcm,8));assert(calls.reset==1)
assert(player:play(0));assert(not player.handle and not queue and calls.open==2)
assert(#notes==0,'ordinary playback and mute must not write per-alert disk logs')
ffi.load=load
-- Real Windows driver calls, using only digital silence. No game is started.
local real=dofile(root..'/src/audio.lua').new(string.rep('\0',3840),48000,2,function()end)
assert(real:play(60));assert(real:release());assert(not real.handle)
print('PASS PCM gain, mute, restart, private FFI names, and real WinMM silent-buffer lifecycle')
