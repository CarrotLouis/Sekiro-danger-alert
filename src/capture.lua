local M={}
local function quote(s)
    return '"'..tostring(s):gsub('[%z\1-\31\\"]',function(c)
        if c=='"' or c=='\\' then return '\\'..c end
        return string.format('\\u%04x',c:byte())
    end)..'"'
end
local function json(v)
    local t=type(v)
    if t=='string' then return quote(v) end
    if t=='boolean' then return v and 'true' or 'false' end
    if t=='number' then return (v==v and math.abs(v)<1e300) and string.format('%.6f',v) or 'null' end
    if t~='table' then return 'null' end
    local out={}
    if #v>0 then for _,x in ipairs(v) do out[#out+1]=json(x) end;return '['..table.concat(out,',')..']' end
    local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys)
    for _,k in ipairs(keys) do out[#out+1]=quote(k)..':'..json(v[k]) end
    return '{'..table.concat(out,',')..'}'
end
M.json=json
function M.new(native,path,log,clock)
    local self={active=false,tracked={},cursor=0,last={},errors=0,samples=0}
    local began,deadline,context,next_discover,next_heartbeat
    local file,bytes_written
    local function emit(kind,data)
        if not file then return end
        data=data or {};data.event=kind;data.t=clock()-began
        local line=json(data)..'\n'
        if bytes_written+#line>8388608 then self:stop('8 MiB log limit');return end
        file:write(line);file:flush();bytes_written=bytes_written+#line
    end
    function self:start()
        if self.active then self:stop('restarted') end
        self.serial=(self.serial or 0)+1
        local timestamp=os.date('%Y%m%d-%H%M%S')..'-'..math.floor(clock()*1000)..'-'..self.serial
        self.path=path..'/PerilWarning-Crusher-'..timestamp..'.jsonl'
        file=assert(io.open(self.path,'wb'),'cannot create capture log')
        began=clock();deadline=began+120;next_discover=0;next_heartbeat=0;context=nil
        bytes_written=0;self.active=true;self.tracked={};self.last={};self.cursor=0;self.errors=0;self.samples=0
        emit('capture_start',{build='25480438',sample_hz=20,range_m=50,
            warning_range_m=10,automatic_warning=false,manual_marker='F8',version='0.1.0'})
        log('capture started: '..self.path)
    end
    function self:stop(reason)
        if not self.active then return end
        -- Reserve room for a stop record without going through the cap again.
        if file then file:write(json({event='capture_stop',t=clock()-began,reason=reason,samples=self.samples})..'\n');file:close() end
        file=nil;self.active=false;self.tracked={};self.last={};log('capture stopped: '..reason)
    end
    function self:mark()
        if self.active then emit('user_attack_mark',{key='F8'}) end
    end
    function self:step()
        if not self.active then return end
        local now=clock()
        if now>=deadline then return self:stop('two minutes complete') end
        self.samples=self.samples+1
        local started=now
        local ok,why=pcall(function()
            native:begin();local scene=native:scene()
            if not scene.mission or not scene.avatar or not scene.position then
                if context then self:stop('left mission or local avatar unavailable');return end
                if now>=next_heartbeat then emit('waiting_for_mission');next_heartbeat=now+5 end
                return
            end
            if context and context~=scene.key then self:stop('mission context changed');return end
            context=scene.key
            local h=native:health_header()
            if now>=next_discover then
                local found;found,self.cursor=native:discover(h,self.cursor,128)
                local n=0;for _ in pairs(self.tracked) do n=n+1 end
                for _,e in ipairs(found) do
                    if self.tracked[e.id] or n<16 then
                        if not self.tracked[e.id] then n=n+1;emit('crusher_found',{entity=e.id,unit=e.unit,owned=e.owned}) end
                        self.tracked[e.id]=true
                    end
                end
                next_discover=now+0.15
            end
            local targets,nearby={},{}
            for id in pairs(self.tracked) do
                local e=native:resolve(h,id)
                if not e then self.tracked[id]=nil;self.last[id]=nil;emit('crusher_gone',{entity=id})
                else
                    local good,pos=pcall(native.position,native,e.unit)
                    if good then
                        local p=scene.position
                        local d=math.sqrt((pos.x-p.x)^2+(pos.y-p.y)^2+(pos.z-p.z)^2)
                        if d<=50 then
                            nearby[#nearby+1]={entity=id,distance=d,owned=e.owned,health=e.health}
                            targets[native.memory.address(e.pointer)]=e
                            local anim_ok,states=pcall(native.animation,native,e.unit)
                            local stamp=anim_ok and json(states) or tostring(states)
                            if self.last[id]~=stamp then
                                emit(anim_ok and 'animation_change' or 'animation_unavailable',
                                    {entity=id,unit=e.unit,distance=d,owned=e.owned,states=anim_ok and states or nil,
                                     reason=not anim_ok and stamp or nil})
                                self.last[id]=stamp
                            end
                        end
                    else
                        local stamp='position unavailable: '..tostring(pos)
                        if self.last[id]~=stamp then emit('unit_unavailable',{entity=id,reason=stamp});self.last[id]=stamp end
                    end
                end
            end
            local active=native:abilities(targets)
            local stamp={}
            for _,a in ipairs(active) do stamp[#stamp+1]=a.entity..':'..a.id..':'..a.slot end
            table.sort(stamp);stamp=table.concat(stamp,'|')
            -- Log running times at 20 Hz only while a nearby Crusher has an active ability.
            if #active>0 or self.ability_stamp~=stamp then emit('abilities',{items=active});self.ability_stamp=stamp end
            if now>=next_heartbeat then
                emit('heartbeat',{nearby=nearby,health_records=h.count,reads=native.reads,
                    bytes=native.bytes,avatar_unit=scene.avatar.unit,local_position=scene.position})
                next_heartbeat=now+1
            end
        end)
        if not ok then
            self.errors=self.errors+1;emit('read_error',{reason=tostring(why),count=self.errors})
            if self.errors>=8 then self:stop('eight read failures') end
        end
        local cost=clock()-started
        if cost>0.020 then self:stop('sample exceeded 20 ms budget') end
        self.cost=cost
    end
    return self
end
return M
