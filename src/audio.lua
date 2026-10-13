-- A private asynchronous PCM voice. No device-wide/session-wide volume change.
local M={}
local bit=require('bit')
function M.new(pcm,rate,channels,log)
    local ffi=require('ffi')
    if not pcall(ffi.typeof,'pw01_wavehdr') then ffi.cdef[[
        typedef struct { unsigned short format,channels; unsigned int rate,bytes_sec;
            unsigned short align,bits,extra; } pw01_waveformat;
        typedef struct pw01_wavehdr { char *data; unsigned int length,recorded;
            uintptr_t user; unsigned int flags,loops; struct pw01_wavehdr *next;
            uintptr_t reserved; } pw01_wavehdr;
        unsigned int pw01_open(void **,unsigned int,const pw01_waveformat *,uintptr_t,uintptr_t,unsigned int) __asm__("waveOutOpen");
        unsigned int pw01_prepare(void *,pw01_wavehdr *,unsigned int) __asm__("waveOutPrepareHeader");
        unsigned int pw01_write(void *,pw01_wavehdr *,unsigned int) __asm__("waveOutWrite");
        unsigned int pw01_reset(void *) __asm__("waveOutReset");
        unsigned int pw01_unprepare(void *,pw01_wavehdr *,unsigned int) __asm__("waveOutUnprepareHeader");
        unsigned int pw01_close(void *) __asm__("waveOutClose");
    ]] end
    local winmm=ffi.load('winmm')
    assert(ffi.sizeof('pw01_wavehdr')==48,'unexpected wave header layout')
    assert(#pcm%2==0 and channels==2 and rate==48000,'unexpected audio format')
    local self={handle=nil,prepared=false,failed=false}
    local count=#pcm/2
    local original=ffi.new('int16_t[?]',count);ffi.copy(original,pcm,#pcm)
    local buffer=ffi.new('int16_t[?]',count)
    local header=ffi.new('pw01_wavehdr[1]');local size=ffi.sizeof(header[0])
    local last_volume
    local function fail(call,result) log('audio '..call..' failed: '..result);self.failed=true;return false end
    function self:release()
        if not self.handle then return true end
        local rc=winmm.pw01_reset(self.handle)
        if rc~=0 then return fail('reset',rc) end
        if self.prepared then
            rc=winmm.pw01_unprepare(self.handle,header,size)
            if rc~=0 then return fail('unprepare',rc) end
            self.prepared=false
        end
        rc=winmm.pw01_close(self.handle)
        if rc~=0 then return fail('close',rc) end
        self.handle=nil;return true
    end
    function self:poll()
        if self.handle and self.prepared and bit.band(header[0].flags,1)~=0 then self:release() end
    end
    function self:play(volume)
        if self.failed then return false end
        if not self:release() then return false end
        volume=math.max(0,math.min(100,tonumber(volume) or 0))
        if volume==0 then log('audio preview muted (0%)');return true end
        if last_volume~=volume then
            local gain=volume/100
            for i=0,count-1 do buffer[i]=original[i]*gain end
            last_volume=volume
        end
        local fmt=ffi.new('pw01_waveformat[1]')
        fmt[0].format=1;fmt[0].channels=channels;fmt[0].rate=rate
        fmt[0].align=channels*2;fmt[0].bytes_sec=rate*channels*2;fmt[0].bits=16
        local output=ffi.new('void *[1]')
        local rc=winmm.pw01_open(output,0xffffffff,fmt,0,0,0)
        if rc~=0 then return fail('open',rc) end
        self.handle=output[0]
        ffi.fill(header,ffi.sizeof(header));header[0].data=ffi.cast('char *',buffer);header[0].length=#pcm
        rc=winmm.pw01_prepare(self.handle,header,size)
        if rc~=0 then self:release();return fail('prepare',rc) end
        self.prepared=true;rc=winmm.pw01_write(self.handle,header,size)
        if rc~=0 then self:release();return fail('write',rc) end
        log('audio played at '..volume..'%');return true
    end
    -- Retain buffers for the full lifetime of any driver-owned header, even on failure.
    self.buffers={buffer,header,original}
    return self
end
return M
