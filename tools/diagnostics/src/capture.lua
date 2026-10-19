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
function M.new(native,path,log,clock,tracking,catalog,version)
    local self={active=false,last={},errors=0,samples=0}
    local expanded=false
    for _,move in ipairs(catalog and catalog.moves or {})do
        if move.status=='enabled_from_capture' then expanded=true;break end
    end
    local began,deadline,context,next_heartbeat,tracker,file,bytes_written,base_path,header,limits
    local last_detector_emit,world_context
    local function line_for(kind,data,at)
        data=data or {};data.event=kind;data.t=at or clock()-began
        return json(data)..'\n'
    end
    local function write(line)
        local handle=file
        local ok,result,why=pcall(handle.write,handle,line)
        if ok and result then ok,result,why=pcall(handle.flush,handle)end
        if not ok or not result then
            self.stop_reason='capture log write failed: '..tostring(ok and why or result)
            file=nil;self.active=false;pcall(handle.close,handle)
            log('capture stopped: '..self.stop_reason);return false
        end
        bytes_written=bytes_written+#line;self.total_bytes=self.total_bytes+#line
        return true
    end
    local function close_part(reason,continues,at)
        if not file then return end
        local continuation;if self.long_capture then continuation=continues end
        if not write(line_for('capture_stop',{reason=reason,samples=self.samples,
            successful_samples=self.successful_samples,read_errors=self.errors,marker_count=self.marker_count,
            marker_counts=self.marker_bindings and self.marker_counts,
            session_id=self.session_id,part_index=self.long_capture and self.part_index or nil,
            session_continues=continuation,
            part_research_samples=self.long_capture and self.part_samples or nil,
            part_marker_count=self.long_capture and self.part_markers or nil},at))then return end
        file:close();file=nil
    end
    local function open_part(at)
        self.part_index=self.part_index+1
        self.path=base_path..(self.long_capture and ('-part%03d'):format(self.part_index)or'')..'.jsonl'
        local why;file,why=io.open(self.path,'wb')
        if not file then
            self.active=false;self.stop_reason='cannot create capture log: '..tostring(why)
            log('capture stopped: '..self.stop_reason);return false
        end
        self.paths[#self.paths+1]=self.path;bytes_written=0
        self.part_started=at or clock()-began;self.part_samples=0;self.part_markers=0
        header.session_id=self.session_id;header.part_index=self.long_capture and self.part_index or nil
        header.part_started_t=self.long_capture and self.part_started or nil
        if not write(line_for('capture_start',header,at))then return false end
        if self.long_capture then log('capture part opened: '..self.path)end
        return true
    end
    local function emit(kind,data)
        if not file or not self.active then return false end
        data=data or {}
        local line=line_for(kind,data)
        -- Reserve footer space. Rotation never resets the mission, tracker,
        -- ability clock, marker counters or session-relative timestamps.
        if self.total_bytes+#line>limits.total_bytes-4096 then
            self:stop(self.long_capture and '256 MiB session limit'or'8 MiB log limit');return false
        end
        if #line>limits.part_bytes-65536 then self:stop('capture record exceeds part limit');return false end
        if self.long_capture and (clock()-began-self.part_started>=limits.part_seconds
            or bytes_written+#line>limits.part_bytes-4096)then
            if self.part_index>=limits.parts then self:stop('capture part count limit');return false end
            -- IO takes time. Both boundaries use the pending event's logical
            -- timestamp so the following record cannot predate its new header.
            close_part('part rotated',true,data.t)
            if not self.active or not open_part(data.t)then return false end
        elseif bytes_written+#line>limits.part_bytes-4096 then self:stop('8 MiB log limit');return false end
        if self.total_bytes+#line>limits.total_bytes-4096 then self:stop('256 MiB session limit');return false end
        if not write(line)then return false end
        if kind=='research_sample'then self.part_samples=self.part_samples+1 end
        if kind=='user_attack_mark'then self.part_markers=self.part_markers+1 end
        return true
    end
    local function budget(channel,cost)
        local streak=cost>.020 and (self.overruns[channel]or 0)+1 or 0
        self.overruns[channel]=streak
        if streak>0 then
            emit('sample_overrun',{channel=channel,cost_ms=cost*1000,consecutive=streak,
                action=(cost>=.050 or streak>=3)and 'stop'or'backoff'})
            self.backoff_until=clock()+1
            if cost>=.050 or streak>=3 then self:stop(channel..' sampling budget exceeded')end
        end
    end
    local function accept_scene(scene)
        if not scene.mission then
            if context then self:stop('left mission or local avatar unavailable')end
            return false
        end
        if not scene.avatar or not scene.position then
            if context and not self.long_capture then self:stop('left mission or local avatar unavailable')
            elseif self.long_capture and not self.waiting_avatar then
                self.waiting_avatar=true;self.observation=nil;self.detector_observation=nil
                emit('waiting_for_local_avatar',{avatar_epoch=self.avatar_epoch})
            end
            return false
        end
        local key=scene.key..':'..scene.avatar.unit
        if context and (not self.long_capture and context~=key
            or self.long_capture and world_context~=scene.key)then
            self:stop('mission or local avatar changed');return false
        end
        if self.long_capture and (context~=key or self.waiting_avatar)then
            self.avatar_epoch=self.avatar_epoch+1
            if context then self.epoch_changed_at=clock()end
            self.last={};self.observation=nil;self.detector_observation=nil;self.ability_stamp=nil
            if tracker and tracker.reset then tracker:reset()end
            emit('local_avatar_epoch',{avatar_epoch=self.avatar_epoch,
                avatar_entity=scene.avatar.id,avatar_unit=scene.avatar.unit})
        end
        context=key;world_context=scene.key;self.waiting_avatar=false
        return self.active
    end
    local function nearby(selected)
        local out={}
        for _,e in ipairs(selected) do
            out[#out+1]={entity=e.id,unit=e.unit,network_id=e.network_id,resource=e.resource,distance=e.distance,owned=e.owned,health=e.health,class_name=e.class_name}
        end
        return out
    end
    local function animations(selected)
        -- Animation reads are optional and rotated; inability to read one is diagnostic.
        for _=1,math.min(4,#selected) do
            if not self.active then return end
            self.animation_cursor=self.animation_cursor%#selected+1
            local e=selected[self.animation_cursor]
            local good,states=pcall(native.animation,native,e.unit)
            local stamp=good and json(states) or tostring(states)
            if self.last[e.id].stamp~=stamp then
                local written=emit(good and 'animation_change' or 'animation_unavailable',
                    {entity=e.id,unit=e.unit,resource=e.resource,distance=e.distance,owned=e.owned,
                    states=good and states or nil,reason=not good and stamp or nil})
                if not written then return end
                self.last[e.id].stamp=stamp
            end
        end
    end
    function self:start(mode,move_id,capture_context,vehicle_scenario)
        if self.active then self:stop('restarted') end
        self.mode=mode=='combat' and 'combat' or mode=='targeting' and 'targeting' or 'crusher'
        self.sample_interval=self.mode=='combat' and
            (move_id=='factory_fusion_repeater' or move_id=='dragon_alchemical_pyrosis')and .05 or .1
        self.requested_move=nil;self.resources=nil;self.long_capture=false;self.marker_bindings=nil
        self.marker_counts={};self.key_moves={};self.selected_move=move_id
        self.capture_context=capture_context=='comparison' and 'comparison' or 'requested'
        local scenarios={on_foot=true,bastion_driver=true,bastion_gunner=true,frv_driver=true,empty_vehicle=true}
        assert(vehicle_scenario==nil or scenarios[vehicle_scenario],'unknown vehicle capture scenario')
        self.vehicle_scenario=vehicle_scenario
        if self.mode=='combat' then
            for _,move in ipairs(catalog.moves)do if move.id==move_id then self.requested_move=move end end
            assert(self.requested_move,'unknown capture move')
            -- The four legacy Hive selections all enter the same continuous
            -- scope; the key on each marker identifies the observed variant.
            for _,move in ipairs(catalog.moves)do if move.id=='hive_lord_all'then
                for _,binding in ipairs(move.manual_markers or {})do
                    if binding.move==move_id then self.requested_move=move end
                end
            end end
            local chosen=self.requested_move;move_id=chosen.id
            if chosen.capture_profile=='hive_lord_long'then
                assert(chosen.id=='hive_lord_all'and #chosen.resources==1
                    and chosen.resources[1]=='d465d9c7f77a07cb','long capture scope mismatch')
                local keys={['-']=0xbd,['=']=0xbb,['[']=0xdb,[']']=0xdd}
                assert(#chosen.manual_markers==4,'long capture marker count')
                for _,binding in ipairs(chosen.manual_markers)do
                    assert(keys[binding.key]==binding.vk and not self.key_moves[binding.key],'long capture key mismatch')
                    local member
                    for _,move in ipairs(catalog.moves)do if move.id==binding.move then member=move end end
                    assert(member and member.control==binding.control and #member.resources==1
                        and member.resources[1]==chosen.resources[1],'long capture variant mismatch')
                    self.key_moves[binding.key]=binding;self.marker_counts[binding.key]=0
                end
                self.long_capture=true;self.marker_bindings=chosen.manual_markers
            end
            local allowed={};for _,hash in ipairs(self.requested_move.resources)do allowed[hash]=true end
            self.resources={};for _,resource in ipairs(catalog.resources)do
                if allowed[resource.hash] then self.resources[resource.hash]=resource end
            end
        end
        self.serial=(self.serial or 0)+1
        local timestamp=os.date('%Y%m%d-%H%M%S')..'-'..math.floor(clock()*1000)..'-'..self.serial
        local label=self.mode=='combat' and 'Combat-'..move_id..'-'..self.capture_context..'-' or self.mode=='targeting' and 'Targeting-' or 'Crusher-'
        if vehicle_scenario and not self.long_capture then label=label..'vehicle_'..vehicle_scenario..'-'end
        base_path=path..'/Sekiro danger alert-'..label..timestamp
        limits=self.long_capture and {seconds=3600,part_seconds=300,part_bytes=8388608,total_bytes=268435456,parts=64}
            or {seconds=120,part_seconds=120,part_bytes=8388608,total_bytes=8388608,parts=1}
        self.duration_limit=limits.seconds;self.part_limit=limits.part_bytes
        self.total_limit=limits.total_bytes;self.part_seconds=limits.part_seconds
        began=clock();deadline=began+limits.seconds;next_heartbeat=0;context=nil;world_context=nil;last_detector_emit=nil
        self.avatar_epoch=0;self.waiting_avatar=false;self.epoch_changed_at=nil
        self.session_id=self.long_capture and ('hive_lord_all-'..self.capture_context..'-'..timestamp)or nil
        self.paths={};self.part_index=0;self.total_bytes=0
        bytes_written=0;self.active=true;self.last={};self.errors=0;self.samples=0;self.cost=0
        self.successful_samples=0;self.marker_count=0;self.stop_reason=nil;self.channel_warning=nil
        self.ability_stamp=nil;self.observation=nil;self.detector_observation=nil;self.detector_t=nil;self.animation_cursor=0
        self.overruns={};self.presentation_stamp=nil;self.backoff_until=nil;self.local_control=nil
        local source=native
        if self.mode=='targeting' then
            source={discover=function(_,h,c,n)return native:targeting_discover(h,c,n)end,
                resolve=function(_,h,id)return native:targeting_resolve(h,id)end,
                position=function(_,unit)return native:position(unit)end}
        elseif self.mode=='combat' then
            source={discover=function(_,h,c,n)return native:discover(h,c,n,self.resources)end,
                resolve=function(_,h,id)return native:resolve(h,id,self.resources)end,
                position=function(_,unit)return native:position(unit)end}
        end
        tracker=tracking.new(source,self.mode~='crusher' and 2000 or 50,self.mode~='crusher' and 8 or 16)
        header={build='25480438',nominal_sample_hz=1/self.sample_interval,adaptive_sampling=true,
            utc_started=os.date('!%Y-%m-%dT%H:%M:%SZ'),clock_anchor=began,
            research_schema=self.long_capture and 3 or 2,warning_logic='unchanged_from_0.8.2',
            diagnostic_range_m=self.mode~='crusher' and 2000 or 50,warning_rule='local_entity_target_and_attack',mode=self.mode,
            requested_move=self.requested_move and self.requested_move.id,
            requested_attack=self.requested_move and self.requested_move.attack_name,
            requested_control=self.requested_move and self.requested_move.control,
            requested_controls=self.requested_move and self.requested_move.controls,
            selected_move=self.selected_move,
            requested_status=self.requested_move and self.requested_move.status,
            requested_warning_enabled=self.requested_move and self.requested_move.status=='enabled_from_capture' or false,
            capture_context=self.mode=='combat' and self.capture_context,
            vehicle_scenario=vehicle_scenario,vehicle_observation_only=vehicle_scenario and true or nil,
            overrun_policy={backoff_above_ms=20,stop_consecutive=3,stop_immediate_ms=50},
            requested_resources=self.requested_move and self.requested_move.resources,
            new_moves_automatic_warning=expanded,automatic_warning_supported=true,
            manual_marker=self.long_capture and '- = [ ]'or'F8',manual_markers=self.marker_bindings,
            duration_limit_s=limits.seconds,part_limit_bytes=limits.part_bytes,total_limit_bytes=limits.total_bytes,
            part_limit_s=self.long_capture and limits.part_seconds or nil,
            timestamp_basis=self.long_capture and 'seconds_since_session_start'or nil,
            avatar_changes=self.long_capture and 'pause_then_continue_with_epoch_records'or'stop',
            version=version or 'unknown',mod='Sekiro danger alert'}
        assert(open_part(),self.stop_reason)
        log('capture started: '..self.path)
    end
    function self:stop(reason)
        if not self.active then return end
        self.stop_reason=reason
        close_part(reason,false)
        file=nil;self.active=false;self.last={};self.observation=nil;self.detector_observation=nil;log('capture stopped: '..reason)
    end
    function self:mark(key)
        if not self.active then return false end
        if clock()>=deadline then self:stop(self.long_capture and '60 minutes complete'or'two minutes complete');return false end
        key=key or'F8';local binding=self.key_moves[key]
        if self.long_capture and not binding or not self.long_capture and key~='F8' then return false end
        local available;if self.long_capture then available=not self.waiting_avatar end
        local written=emit('user_attack_mark',{key=key,
            marked_move=binding and binding.move or self.requested_move and self.requested_move.id,
            marked_control=binding and binding.control or self.requested_move and self.requested_move.control,
            marked_label=binding and binding.label,last_observation=self.observation,
            avatar_epoch=self.long_capture and self.avatar_epoch or nil,
            local_avatar_available=available,
            observation_age=self.observation and clock()-began-self.observation.sample_t or nil,
            last_detection=self.detector_observation,
            detection_age=self.detector_observation and clock()-began-self.detector_observation.sample_t or nil})
        if written then
            self.marker_count=self.marker_count+1
            if binding then self.marker_counts[key]=self.marker_counts[key]+1 end
        end
        return written
    end
    function self:record_detection(snapshot)
        if not self.active or not snapshot or snapshot.t<began or self.detector_t and snapshot.t<=self.detector_t
            or self.long_capture and self.epoch_changed_at and snapshot.t<self.epoch_changed_at then return end
        if clock()>=deadline then self:stop(self.long_capture and '60 minutes complete'or'two minutes complete');return end
        if not accept_scene(snapshot.scene)then return end
        local started=clock()
        self.detector_t=snapshot.t
        local observation={sample_t=snapshot.t-began,source='automatic_detector',nearby=nearby(snapshot.selected),
            decisions=snapshot.decisions,tracking=snapshot.tracking}
        self.detector_observation=observation
        if self.mode=='crusher' then self.observation=observation end
        if self.long_capture and last_detector_emit and snapshot.t-last_detector_emit<.2 then return end
        last_detector_emit=snapshot.t
        -- Preserve every detector decision even when animation capture has backed off.
        emit('detector_sample',{sample_t=snapshot.t-began,nearby=observation.nearby,
            items=snapshot.abilities,decisions=snapshot.decisions,tracking=snapshot.tracking,
            avatar_entity=snapshot.scene.avatar.id,avatar_unit=snapshot.scene.avatar.unit})
        budget('detector_recording',clock()-started)
    end
    function self:record_warning(event,visual,audio,why,volume)
        if not self.active or not self.vehicle_scenario then return end
        emit('warning_output',{source=event.source or 'automatic',decision=event,
            visual_started=visual==true,audio_request_succeeded=audio==true,audio_reason=why,
            volume=volume,audio_muted=volume==0})
    end
    function self:record_presentation(overlay,t)
        if not self.active or not self.vehicle_scenario then return end
        local result={ready=overlay.ready==true,playing=overlay.until_time~=nil and t<overlay.until_time,
            bitmap_present=overlay.id~=nil,anchor_status=overlay.anchor_status}
        local stamp=json(result)
        if stamp~=self.presentation_stamp then
            self.presentation_stamp=stamp;emit('presentation_state',result)
        end
    end
    function self:step()
        if not self.active then return end
        local now=clock()
        if now>=deadline then return self:stop(self.long_capture and '60 minutes complete'or'two minutes complete') end
        self.samples=self.samples+1
        local started=now
        local ok,why=pcall(function()
            native:begin();local scene=native:scene()
            if self.vehicle_scenario and scene.mission and (scene.avatar or now>=next_heartbeat)then
                local good,result=pcall(native.local_control_state,native,scene)
                self.local_control=good and result or {error=tostring(result)}
                if not scene.avatar and now>=next_heartbeat then
                    emit('vehicle_local_state',{local_control=self.local_control,avatar_available=false,
                        vehicle_scenario=self.vehicle_scenario})
                end
            end
            if not accept_scene(scene)then
                if self.active and now>=next_heartbeat then
                    emit(self.waiting_avatar and 'waiting_for_local_avatar'or'waiting_for_mission');next_heartbeat=now+5
                end
                return
            end
            -- The automatic detector now scans active abilities without positions.
            -- Keep the bounded, proximity-based animation/aim diagnostics separate.
            local h=self.mode=='targeting' and native:targeting_header() or native:health_header()
            local selected,stats=tracker:step(h,scene,now)
            local owners={}
            for _,e in ipairs(selected) do owners[native.memory.address(e.pointer)]=e end
            local active,ability_stats=native:abilities(owners,true)
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
            if self.mode=='combat' then
                -- A broken optional aiming channel must not discard usable
                -- ability/weapon/network observations or disable the F8 marker.
                local states={};local aim_ok,aim_header=pcall(native.targeting_header,native)
                local aim_table
                if aim_ok then
                    aim_table={total=aim_header.count,owned_prefix=aim_header.owned_prefix}
                    self.channel_warning=nil
                else
                    self.channel_warning=tostring(aim_header);aim_table={error=self.channel_warning};aim_header=nil
                end
                for _,e in ipairs(selected) do
                    states[#states+1]=native:combat_state(aim_header,e,scene.avatar,now>=next_heartbeat)
                end
                local vehicle,vehicle_error,targets,geometry
                if self.vehicle_scenario then
                    local good,result=pcall(native.vehicle_state,native,scene,now>=next_heartbeat)
                    if good then vehicle=result else vehicle_error=tostring(result)end
                    local described,value=pcall(native.target_descriptions,native,h,states,scene,vehicle)
                    if described then targets=value else vehicle_error=(vehicle_error or '')..'; targets: '..tostring(value)end
                    local projected,value=pcall(native.presentation_geometry,native)
                    geometry=projected and value or {available=false,reason=tostring(value)}
                end
                self.observation={sample_t=now-began,source='combat_probe',states=states,
                    requested_move=self.requested_move.id,capture_context=self.capture_context,tracking=stats,
                    vehicle=vehicle,vehicle_error=vehicle_error,target_descriptions=targets,presentation_geometry=geometry}
                emit('research_sample',{sample_t=now-began,states=states,abilities=active,tracking=stats,
                    requested_move=self.requested_move.id,avatar_entity=scene.avatar.id,
                    avatar_epoch=self.long_capture and self.avatar_epoch or nil,
                    avatar_unit=scene.avatar.unit,avatar_network=scene.avatar.network_id,
                    ability_table=ability_stats,targeting_table=aim_table,local_position=scene.position,
                    vehicle=vehicle,vehicle_error=vehicle_error,target_descriptions=targets,presentation_geometry=geometry,
                    local_control=self.vehicle_scenario and self.local_control or nil})
            elseif self.mode=='targeting' then
                local states={}
                for _,e in ipairs(selected) do states[#states+1]=native:targeting_state(h,e,scene.avatar) end
                self.observation={sample_t=now-began,source='targeting_probe',states=states,tracking=stats}
                emit('targeting_sample',{sample_t=now-began,states=states,abilities=active,tracking=stats,
                    avatar_entity=scene.avatar.id,avatar_unit=scene.avatar.unit,local_position=scene.position})
            else
                self.observation={sample_t=now-began,source='capture_only',nearby=near,tracking=stats}
                emit('abilities',{items=active,nearby=near,source='capture_only'})
            end
            if self.active then self.successful_samples=self.successful_samples+1 end
            if self.active and self.mode~='targeting' then animations(selected) end
            if self.active and now>=next_heartbeat then
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
        budget('capture',cost)
        self.cost=cost
    end
    return self
end
return M
