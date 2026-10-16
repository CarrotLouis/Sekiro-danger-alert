-- Resource-specific attack windows plus a coherent local-player entity target.
-- Owners use authoritative AI; peers use verified, processed network target IDs.
local M={}
function M.new(native,profile,log,trigger,enabled,delay,details)
    enabled=enabled or function()return true end
    delay=delay or function()return 0 end
    local self={previous={},fired={},peer_factory={},errors=0,cursor=0}
    function self:reset()
        self.previous={};self.fired={};self.peer_factory={};self.peer_sequence=0
        self.snapshot=nil;self.cursor=0;self.factory_cursor=0;self.next_report=nil
    end
    function self:observe(items,targets,t,avatar)
        local decisions=details~=false and {} or nil
        for _,a in ipairs(items) do
            local e=targets[a.entity]
            if e then
                local source=a.source or 'ability'
                local key=source..':'..a.entity..':'..e.unit..':'..a.slot
                local old=self.previous[key]
                if not old or old.id~=a.id or old.token~=a.token or a.time<old.time-0.1 or t-old.seen>2 then
                    old={id=a.id,token=a.token,warned={},pending={}}
                end
                if old.seen and t-old.seen>.35 then
                    for shot in pairs(old.pending)do old.warned[shot]=true;old.pending[shot]=nil end
                end
                if old.time and t>old.seen and a.time>old.time+.00001
                    and a.time-old.time<=(t-old.seen)*math.max(a.speed or 0,1)*4+.1 then
                    old.progress_at=t
                end
                old.time=a.time;old.seen=t;self.previous[key]=old
                local crusher=e.resource==profile.crusher_resource
                local cannon=e.resource==profile.cannon.resource and a.id==profile.cannon.ability
                local expanded=profile.expanded and profile.expanded.resources[e.resource]
                local rule=expanded and expanded.abilities[a.id]
                local excluded=expanded and expanded.excluded[a.id]
                local peer_factory=source=='factory_replica'
                local factory=profile.expanded and (source=='factory_stage' or peer_factory)
                    and e.resource==profile.expanded.factory.resource
                local F=factory and profile.expanded.factory
                local move=factory and F.move or rule and rule.move or crusher and 'crusher_'..a.id or cannon and 'cannon_preparation' or nil
                local cues=rule and rule.cues or {{time=factory and F.cue_time or cannon and profile.cannon.cue_time or 0,
                    last=factory and F.last_warning_time or cannon and profile.cannon.last_warning_time or .35,
                    fire=factory and F.earliest_fire_time or cannon and profile.cannon.fire_time or nil}}
                if peer_factory then cues={{time=0,last=.2}}end
                local shot=1
                for index,c in ipairs(cues)do if a.time>=c.time then shot=index end end
                local window=cues[shot]
                local pending=old.pending[shot]
                local ai=e.ai
                local target=ai;if not e.owned then target=e.peer_target end
                local peer=not e.owned and target and target.verified and target.source=='replicated_aim'
                local behavior=ai;if peer_factory then behavior=e.peer_behavior end
                local identity=a.entity..':'..e.unit
                local reason
                if crusher and (profile.ignored_stomps or {})[a.id] then reason='stomp'
                elseif excluded then reason=excluded
                elseif not (factory or rule or cannon or crusher and profile.attack_states[a.id]) then reason='unmapped'
                elseif not enabled(move) then reason='move_disabled'
                elseif a.paused or not a.speed or a.speed<=0 or a.time~=a.time or a.time<0 then reason='inactive_clock'
                elseif old.warned[shot] then reason='already_warned'
                elseif not pending and a.time<window.time then reason='before_cue'
                elseif not pending and a.time>window.last then reason='late_sample'
                elseif not pending and window.fire and (window.fire-a.time)/a.speed<0.2 then reason='insufficient_lead'
                elseif e.alive==false then reason='dead_or_replaced'
                elseif not e.owned and not peer then reason='unverified_peer_target'
                elseif not e.owned and source=='factory_stage' then reason='unverified_peer_preparation'
                elseif not target then reason='no_ai_target'
                elseif not target.has_target or not target.tracks_entity or target.target==0 then reason='no_entity_target'
                elseif not avatar or target.target~=avatar.id then reason='other_target'
                elseif peer and (not avatar.network_id or avatar.network_id==0x7fff
                    or target.network_target~=avatar.network_id)then reason='unverified_peer_target'
                elseif peer and source=='ability' and (not old.progress_at or t-old.progress_at>.15) then reason='peer_clock_unconfirmed'
                elseif peer_factory and (not peer or not behavior or not behavior.verified)then reason='unverified_peer_preparation'
                elseif (e.owned and (expanded or factory) or peer_factory)
                    and behavior.behavior~=(factory and F.behavior or expanded.behavior)then reason='other_behavior'
                elseif factory and (behavior.stage~=F.stage or not behavior.preparation_ready)then reason='not_preparing'
                elseif peer_factory and a.target_network~=avatar.network_id then reason='other_target'
                elseif t-(self.fired[identity] or -math.huge)<=0.7 then reason='cooldown'
                else reason='trigger' end
                -- Only an originally eligible Harvester attack can arm a delay.
                -- Every subsequent sample must still prove that same living actor,
                -- advancing ability and local target. No detached wall-clock timer.
                if pending and reason~='trigger' then
                    old.pending[shot]=nil;old.warned[shot]=true
                elseif reason=='trigger' then
                    if not pending and (move=='harvester_tesla_ripper' or move=='harvester_disintegration_beamer')then
                        local seconds=tonumber(delay(move))or 0
                        if seconds~=seconds then seconds=0 end
                        seconds=math.floor(math.max(0,math.min(2,seconds))*10+.5)/10
                        if seconds>0 then
                            pending={due=t+seconds,at=t,seconds=seconds,avatar=avatar.id,avatar_unit=avatar.unit,
                                avatar_network=avatar.network_id,owned=e.owned}
                            old.pending[shot]=pending
                        end
                    end
                    if pending then
                        if pending.avatar~=avatar.id or pending.avatar_unit~=avatar.unit
                            or pending.avatar_network~=avatar.network_id or pending.owned~=e.owned then
                            reason='delay_cancelled';old.pending[shot]=nil;old.warned[shot]=true
                        elseif t-pending.at>.15 and (not old.progress_at or t-old.progress_at>.15)then
                            reason='delay_clock_stalled';old.pending[shot]=nil;old.warned[shot]=true
                        elseif t<pending.due then reason='delayed' end
                    end
                end
                local decision
                if decisions or reason=='trigger' then decision={entity=a.entity,unit=e.unit,class_name=e.class_name,move=move,ability=a.id,
                    ability_time=a.time,ability_speed=a.speed,sample_time=t,reason=reason,owned=e.owned,
                    target_entity=target and target.target,has_target=target and target.has_target,
                    tracks_entity=target and target.tracks_entity,behavior=behavior and behavior.behavior,
                    stage=behavior and behavior.stage,target_source=target and (e.owned and 'behavior' or target.source),avatar_entity=avatar and avatar.id,
                    attack_source=source,shot_index=shot,attack_token=a.token,
                    warning_delay=pending and pending.seconds or 0,detected_at=pending and pending.at or t}end
                if decisions then decisions[#decisions+1]=decision end
                if reason=='trigger' then
                    old.pending[shot]=nil;old.warned[shot]=true;self.fired[identity]=t;trigger(decision)
                end
            end
        end
        -- Keep deduplication across partial table scans and short missing-row gaps.
        for key,state in pairs(self.previous) do if t-state.seen>2 then self.previous[key]=nil end end
        for key,when in pairs(self.fired) do if t-when>2 then self.fired[key]=nil end end
        return decisions
    end
    -- Peers receive the Factory preparation light/ready bit but do not own its
    -- microsecond AI clock. Warn on a freshly observed clear -> ready transition.
    -- Joining mid-preparation, missing scans, and later retargeting never invent a cue.
    function self:peer_preparation(e,t)
        local key=e.id..':'..e.unit
        local state=e.peer_behavior
        if e.alive==false or not state or not state.verified then self.peer_factory[key]=nil;return end
        local F=profile.expanded.factory
        local ready=state.behavior==F.behavior and state.stage==F.stage and state.preparation_ready
        local previous=self.peer_factory[key]
        if not previous or t-previous.seen>.35 then previous={ready=ready}end
        if ready and not previous.ready then
            self.peer_sequence=(self.peer_sequence or 0)+1
            previous.edge={at=t,token=self.peer_sequence}
        elseif not ready then previous.edge=nil end
        previous.ready=ready;previous.seen=t;self.peer_factory[key]=previous
        local edge=previous.edge;local target=e.peer_target
        if edge and ready and t-edge.at<=.2 then
            if not edge.target and target and target.verified then edge.target=target.network_target end
            return {entity=e.id,id=0,source='factory_replica',slot='factory',time=t-edge.at,speed=1,
                token=edge.token,target_network=edge.target}
        end
    end
    function self:step(t)
        if self.disabled or t<(self.retry_at or 0) then return end
        self.snapshot=nil
        local ok,why=pcall(function()
            native:begin()
            local scene=native:scene()
            if not scene.mission or not scene.avatar then self:reset();self.context=nil;return end
            local context=scene.key..':'..scene.avatar.id..':'..scene.avatar.unit..':'..tostring(scene.avatar.network_id)
            if self.context~=context then self:reset();self.context=context end
            local active,selected,stats=native:attack_candidates(self.cursor)
            self.cursor=stats.cursor
            if native.factory_candidates then
                local factory,scan=native:factory_candidates(self.factory_cursor)
                self.factory_cursor=scan.cursor;stats.factory=scan
                for _,e in ipairs(factory)do selected[#selected+1]=e end
            end
            local targets={};local health
            for _,e in ipairs(selected) do
                local crusher=e.resource==profile.crusher_resource
                if crusher or profile.health_resources and profile.health_resources[e.resource] then
                    health=health or native:health_header()
                    local current=native:resolve(health,e.id,not crusher and profile.health_resources or nil)
                    e.alive=current~=nil and current.pointer==e.pointer and current.identity==e.identity
                end
                -- Cached peer AI is deliberately never used, even if it still
                -- names this player. Read the current synchronized target instead.
                if e.owned then e.ai=native:behavior_target(e,scene.avatar);e.peer_target=nil;e.peer_behavior=nil
                else
                    e.ai=nil;e.peer_target=native:replicated_target(e,scene.avatar)
                    e.peer_behavior=profile.expanded and e.resource==profile.expanded.factory.resource
                        and native:replicated_behavior(e)or nil
                end
                targets[e.id]=e
                if profile.expanded and e.resource==profile.expanded.factory.resource and e.ai then
                    local ai=e.ai
                    if ai.native_time and ai.preparation_started and ai.preparation_started>0 then
                        active[#active+1]={entity=e.id,id=0,slot='factory',source='factory_stage',
                            time=(ai.native_time-ai.preparation_started)/1000000,speed=1,token=ai.preparation_started}
                    end
                elseif profile.expanded and e.resource==profile.expanded.factory.resource and not e.owned then
                    local preparation=self:peer_preparation(e,t)
                    if preparation then active[#active+1]=preparation end
                end
            end
            -- Reject an avatar/world change before emitting any event from this batch.
            local latest=native:scene()
            assert(latest.mission and latest.avatar and latest.key==scene.key
                and latest.avatar.id==scene.avatar.id and latest.avatar.unit==scene.avatar.unit
                and latest.avatar.network_id==scene.avatar.network_id,'warning scene changed')
            local decisions=self:observe(active,targets,t,scene.avatar)
            if details~=false then self.snapshot={t=t,scene=scene,selected=selected,abilities=active,decisions=decisions,
                tracking=stats,health_records=health and health.count or 0}end
            for key,state in pairs(self.peer_factory)do if t-state.seen>2 then self.peer_factory[key]=nil end end
            -- Compact operational diagnostics, not per-attack captures or raw memory.
            if details~=false and t>=(self.next_report or 0)then
                self.next_report=t+30
                local peers=0;local reasons={}
                for _,e in ipairs(selected)do if not e.owned then peers=peers+1 end end
                for _,decision in ipairs(decisions)do
                    if not decision.owned then reasons[decision.reason]=(reasons[decision.reason]or 0)+1 end
                end
                local detail={};for reason,count in pairs(reasons)do detail[#detail+1]=reason..'='..count end
                table.sort(detail)
                log(string.format('observation: abilities=%d update_prefix=%d selected_peers=%d peer_decisions=%s',
                    stats.ability_records or 0,stats.local_ability_records or 0,peers,table.concat(detail,',')))
            end
        end)
        if ok then self.errors=0
        else
            self.errors=self.errors+1;self.retry_at=t+1
            log('attack observation unavailable: '..tostring(why))
            if self.errors>=8 then self.disabled=true;log('automatic warning stopped after eight consecutive read failures') end
        end
    end
    return self
end
return M
