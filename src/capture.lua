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
function M.new(native,path,log,clock,tracking)
    local self={active=false,last={},errors=0,samples=0}
    local began,deadline,context,next_heartbeat,tracker,file,bytes_written
    local function emit(kind,data)
        if not file then return end
        data=data or {};data.event=kind;data.t=clock()-began
        local line=json(data)..'\n'
        if bytes_written+#line>8388608 then self:stop('8 MiB log limit');return end
        file:write(line);file:flush();bytes_written=bytes_written+#line
    end
    local function nearby(selected)
        local out={}
        for _,e in ipairs(selected) do
            out[#out+1]={entity=e.id,unit=e.unit,distance=e.distance,owned=e.owned,health=e.health,class_name=e.class_name}
        end
        return out
    end
    function self:start(mode)
        if self.active then self:stop('restarted') end
        self.mode=mode=='targeting' and 'targeting' or 'crusher'
        self.serial=(self.serial or 0)+1
        local timestamp=os.date('%Y%m%d-%H%M%S')..'-'..math.floor(clock()*1000)..'-'..self.serial
        self.path=path..'/Sekiro danger alert-'..(self.mode=='targeting' and 'Targeting-' or 'Crusher-')..timestamp..'.jsonl'
        file=assert(io.open(self.path,'wb'),'cannot create capture log')
        began=clock();deadline=began+120;next_heartbeat=0;context=nil
        bytes_written=0;self.active=true;self.last={};self.errors=0;self.samples=0;self.cost=0
        self.ability_stamp=nil;self.observation=nil;self.detector_observation=nil;self.detector_t=nil;self.animation_cursor=0
        local source=native
        if self.mode=='targeting' then
            source={discover=function(_,h,c,n)return native:targeting_discover(h,c,n)end,
                resolve=function(_,h,id)return native:targeting_resolve(h,id)end,
                position=function(_,unit)return native:position(unit)end}
        end
        tracker=tracking.new(source,self.mode=='targeting' and 2000 or 50,self.mode=='targeting' and 8 or 16)
        emit('capture_start',{build='25480438',nominal_sample_hz=20,adaptive_sampling=true,
            diagnostic_range_m=self.mode=='targeting' and 2000 or 50,warning_rule='local_entity_target_and_attack',mode=self.mode,
            automatic_warning_supported=true,manual_marker='F8',version='0.4.0',mod='Sekiro danger alert'})
        log('capture started: '..self.path)
    end
    function self:stop(reason)
        if not self.active then return end
        if file then file:write(json({event='capture_stop',t=clock()-began,reason=reason,samples=self.samples})..'\n');file:close() end
        file=nil;self.active=false;self.last={};self.observation=nil;self.detector_observation=nil;log('capture stopped: '..reason)
    end
    function self:mark()
        if self.active then emit('user_attack_mark',{key='F8',last_observation=self.observation,
            observation_age=self.observation and clock()-began-self.observation.sample_t or nil,
            last_detection=self.detector_observation,
            detection_age=self.detector_observation and clock()-began-self.detector_observation.sample_t or nil}) end
    end
    function self:record_detection(snapshot)
        if not self.active or not snapshot or snapshot.t<began or snapshot.t==self.detector_t then return end
        if clock()>=deadline then self:stop('two minutes complete');return end
        local key=snapshot.scene.key..':'..snapshot.scene.avatar.unit
        if context and context~=key then self:stop('mission or local avatar changed');return end
        context=key
        local started=clock()
        self.detector_t=snapshot.t
        local observation={sample_t=snapshot.t-began,source='automatic_detector',nearby=nearby(snapshot.selected),
            decisions=snapshot.decisions,tracking=snapshot.tracking}
        self.detector_observation=observation
        if self.mode=='crusher' then self.observation=observation end
        -- Preserve every detector decision even when animation capture has backed off.
        emit('detector_sample',{sample_t=snapshot.t-began,nearby=observation.nearby,
            items=snapshot.abilities,decisions=snapshot.decisions,tracking=snapshot.tracking,
            avatar_entity=snapshot.scene.avatar.id,avatar_unit=snapshot.scene.avatar.unit})
        if clock()-started>0.020 then self:stop('detector recording exceeded 20 ms budget') end
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
            local key=scene.key..':'..scene.avatar.unit
            if context and context~=key then self:stop('mission or local avatar changed');return end
            context=key
            -- The automatic detector now scans active abilities without positions.
            -- Keep the bounded, proximity-based animation/aim diagnostics separate.
            local h=self.mode=='targeting' and native:targeting_header() or native:health_header()
            local selected,stats=tracker:step(h,scene,now)
            local owners={}
            for _,e in ipairs(selected) do owners[native.memory.address(e.pointer)]=e end
            local active=native:abilities(owners)
            local near=nearby(selected);local selected_ids={}
            for _,e in ipairs(selected) do
                selected_ids[e.id]=true
                if not self.last[e.id] or self.last[e.id].unit~=e.unit then
                    emit('observation_selected',{entity=e.id,unit=e.unit,distance=e.distance,class_name=e.class_name})
                    self.last[e.id]={unit=e.unit}
                end
            end
            for id in pairs(self.last) do
                if not selected_ids[id] then emit('observation_removed',{entity=id});self.last[id]=nil end
            end
            if self.mode=='targeting' then
                local states={}
                for _,e in ipairs(selected) do states[#states+1]=native:targeting_state(h,e,scene.avatar) end
                self.observation={sample_t=now-began,source='targeting_probe',states=states,tracking=stats}
                emit('targeting_sample',{sample_t=now-began,states=states,abilities=active,tracking=stats,
                    avatar_entity=scene.avatar.id,avatar_unit=scene.avatar.unit,local_position=scene.position})
            else
                -- Animation layers are expensive; abilities and automatic decisions stay at their own rate.
                for _=1,math.min(4,#selected) do
                    self.animation_cursor=self.animation_cursor%#selected+1
                    local e=selected[self.animation_cursor]
                    local good,states=pcall(native.animation,native,e.unit)
                    local stamp=good and json(states) or tostring(states)
                    if self.last[e.id].stamp~=stamp then
                        emit(good and 'animation_change' or 'animation_unavailable',
                            {entity=e.id,unit=e.unit,distance=e.distance,owned=e.owned,states=good and states or nil,
                             reason=not good and stamp or nil})
                        self.last[e.id].stamp=stamp
                    end
                end
                self.observation={sample_t=now-began,source='capture_only',nearby=near,tracking=stats}
                emit('abilities',{items=active,nearby=near,source='capture_only'})
            end
            if now>=next_heartbeat then
                emit('heartbeat',{nearby=near,component_records=h.count,tracking=stats,reads=native.reads,
                    bytes=native.bytes,avatar_entity=scene.avatar.id,avatar_unit=scene.avatar.unit,
                    local_position=scene.position,previous_sample_cost_ms=(self.cost or 0)*1000,
                    source='capture_only'})
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
