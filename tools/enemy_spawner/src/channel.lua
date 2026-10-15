-- Own PlayFab member property only, following HD2Runtime by SkyeShade's
-- peer_channel/windows_write ABI and lobby guards (MIT; bundled license).
-- Exact wrappers and call sites re-proved against retained build 25480438.
-- No chat messages, arbitrary RPCs, hooks, game-memory writes or Runtime key reuse.
local ffi=require('ffi')
local M={}
local function u32(s,o)local a,b,c,d=s:byte(o+1,o+4);assert(d,'short channel read');return a+b*256+c*65536+d*16777216 end
local function peer(s)return string.format('%08x%08x',u32(s,4),u32(s,0))end
function M.calls()
    return {
        get=function(entry,lobby,lo,hi,key)
            local k=ffi.new('char[?]',#key+1);ffi.copy(k,key)
            local id=ffi.new('uint64_t',hi)*4294967296+lo
            local fn=ffi.cast('const char *(*)(void *, uint64_t, const char *)',entry)
            local value=fn(ffi.cast('void *',lobby),id,k)
            assert(k~=nil)
            if value==nil then return nil end
            return tonumber(ffi.cast('uintptr_t',value))
        end,
        set=function(entry,lobby,key,value)
            local k,v=ffi.new('char[?]',#key+1),ffi.new('char[?]',#value+1)
            ffi.copy(k,key);ffi.copy(v,value)
            local keys,values=ffi.new('const char *[1]'),ffi.new('const char *[1]');keys[0],values[0]=k,v
            local fn=ffi.cast('int32_t (*)(void *, uint32_t, const char **, const char **)',entry)
            local result=fn(ffi.cast('void *',lobby),1,keys,values)
            assert(k~=nil and v~=nil and keys~=nil and values~=nil)
            return tonumber(result)
        end,
    }
end
function M.new(memory,profile,log,calls)
    local self={failures=0};local game=assert(memory.module('game.dll'));local exe=assert(memory.module(nil))
    calls=calls or M.calls()
    assert(profile.key=='sda_spawn','channel key differs')
    local reads,bytes=0,0
    local function read(at,n)
        reads,bytes=reads+1,bytes+n;assert(reads<=1000 and bytes<=65536,'channel read budget')
        -- Bingus passes addresses straight into ReadProcessMemory's const void*.
        -- SDK string results and page cursors are numbers; normalize them here.
        local s=memory.read(ffi.cast('const void *',at),n);assert(s and #s==n,'unreadable peer channel');return s
    end
    local function ptr(at)return memory.pointer(read(at,8))end
    local function prove()
        reads,bytes=0,0
        for _,pin in ipairs(profile.pins)do
            local base=pin.module=='exe'and exe or game
            assert(read(base+pin.rva,#pin.bytes)==pin.bytes,'channel pin mismatch: '..pin.label)
        end
    end
    local text
    local function lobby(now)
        local C,W,P=profile.context,profile.wrapper,profile.playfab
        local ctx=ptr(game+C.global);if not ctx then return nil,'no network context'end
        local wrapper=ctx+C.wrapper
        if read(wrapper+W.active,1):byte()==0 then return nil,'lobby not joined'end
        local engine=ptr(wrapper+W.engineLobby);if not engine then return nil,'no engine lobby'end
        local pl=ptr(engine+P.lobby);if not pl then return nil,'no PlayFab lobby'end
        if u32(read(pl+P.state,4),0)~=P.joined or read(pl+P.handle,8)==string.rep('\0',8)then return nil,'PlayFab lobby not joined'end
        local count=u32(read(pl+P.memberCount,4),0)
        assert(count>=1 and count<=16,'lobby member bounds')
        local array=assert(ptr(pl+P.members));local raw=read(array,count*8)
        local mine=peer(read(ctx+C.localPeer,8));local host=peer(read(ctx+C.hostPeer,8))
        local members,found,host_found={},false,false
        for i=0,count-1 do
            local s=raw:sub(i*8+1,i*8+8);local id=peer(s)
            assert(id~='0000000000000000'and not members[id],'invalid lobby member list')
            members[id]={lo=u32(s,0),hi=u32(s,4)};found=found or id==mine;host_found=host_found or id==host
        end
        if not found or not host_found then return nil,'local/host peer not a lobby member'end
        local name_pointer=ptr(pl);if not name_pointer then return nil,'missing lobby identity'end
        local name_at=memory.address(name_pointer)
        local name=text(name_at,128)
        if not name or #name==0 then return nil,'unreadable lobby identity'end
        local key=name..'/'..tostring(engine)..'/'..tostring(pl)..'/'..host
        if self.key~=key then
            self.key=key;self.since=now;self.last_post=nil;self.posted=nil;self.failures=0
            log('peer channel joined; local='..mine..' host='..host)
        end
        return {key=key,engine=engine,local_peer=mine,host_peer=host,members=members,is_host=mine==host,
            platform_posted=read(wrapper+W.platformPosted,1):byte()~=0}
    end
    local function slots()
        local A=profile.api;local registry=ptr(game+A.registryGlobal)
        assert(registry==exe+A.registry,'peer API registry changed')
        local tab=ptr(registry+A.table);assert(tab==exe+A.tableRva,'peer API table changed')
        local get,set=ptr(tab+A.memberData),ptr(tab+A.setMemberData)
        assert(get==exe+A.memberDataRva and set==exe+A.setMemberDataRva,'peer API functions changed')
        return get,set
    end
    text=function(at,limit)
        limit=limit or 512
        local parts,total={},0
        while total<=limit do
            local n=math.min(limit+1-total,4096-at%4096);local s=read(at,n);local nul=s:find('\0',1,true)
            if nul then
                parts[#parts+1]=s:sub(1,nul-1);local value=table.concat(parts)
                if value:find('[^\32-\126]')then return nil end
                return value
            end
            parts[#parts+1]=s;total=total+n;at=at+n
        end
    end
    function self:snapshot(now)
        prove();local context,why=lobby(now);if not context then return nil,why end
        local get=slots();context.values={}
        for id,m in pairs(context.members)do if id~=context.local_peer then
            local at=calls.get(get,context.engine,m.lo,m.hi,profile.key)
            if at then context.values[id]=text(at)end
        end end
        return context
    end
    function self:publish(value,now,context)
        assert(type(value)=='string'and #value>=1 and #value<=512 and not value:find('[^\32-\126]'),'invalid own member property')
        prove();local latest,why=lobby(now)
        if not latest or not context or latest.key~=context.key then return nil,why or'lobby changed'end
        if value==self.posted then return true end
        if self.failures>=3 then return nil,'three failed lobby posts; disabled for this lobby'end
        if now-self.since<10 or not latest.platform_posted and now-self.since<20 then return false,'waiting for lobby join / game platform post'end
        if self.last_post and now-self.last_post<5 then return false,'lobby post cooldown'end
        local _,set=slots();self.last_post=now
        local code=calls.set(set,latest.engine,profile.key,value)
        if code~=0 then self.failures=self.failures+1;log('peer channel post failed: '..tostring(code));return false,'lobby post failed'end
        self.posted=value;self.failures=0;log('peer channel posted '..#value..' bytes')
        return true
    end
    return self
end
return M
