-- Resource-specific attack windows plus a currently authoritative entity target.
-- No range predicate. AI selection alone and stale/replicated aim IDs cannot warn.
local M={}
function M.new(native,profile,log,trigger,enabled)
    enabled=enabled or function()return true end
    local self={previous={},fired={},errors=0,cursor=0}
    function self:reset()
        self.previous={};self.fired={};self.snapshot=nil;self.cursor=0;self.factory_cursor=0
    end
    function self:observe(items,targets,t,avatar)
        local decisions={}
        for _,a in ipairs(items) do
            local e=targets[a.entity]
            if e then
                local source=a.source or 'ability'
                local key=source..':'..a.entity..':'..e.unit..':'..a.slot
                local old=self.previous[key]
                if not old or old.id~=a.id or old.token~=a.token or a.time<old.time-0.1 or t-old.seen>2 then
                    old={id=a.id,token=a.token,warned={}}
                end
                old.time=a.time;old.seen=t;self.previous[key]=old
                local crusher=e.resource==profile.crusher_resource
                local cannon=e.resource==profile.cannon.resource and a.id==profile.cannon.ability
                local expanded=profile.expanded and profile.expanded.resources[e.resource]
                local rule=expanded and expanded.abilities[a.id]
                local excluded=expanded and expanded.excluded[a.id]
                local factory=profile.expanded and source=='factory_stage' and e.resource==profile.expanded.factory.resource
                local F=factory and profile.expanded.factory
                local move=factory and F.move or rule and rule.move or crusher and 'crusher_'..a.id or cannon and 'cannon_preparation' or nil
                local cues=rule and rule.cues or {{time=factory and F.cue_time or cannon and profile.cannon.cue_time or 0,
                    last=factory and F.last_warning_time or cannon and profile.cannon.last_warning_time or .35,
                    fire=factory and F.earliest_fire_time or cannon and profile.cannon.fire_time or nil}}
                local shot=1
                for index,c in ipairs(cues)do if a.time>=c.time then shot=index end end
                local window=cues[shot]
                local ai=e.ai
                local identity=a.entity..':'..e.unit
                local reason
                if crusher and (profile.ignored_stomps or {})[a.id] then reason='stomp'
                elseif excluded then reason=excluded
                elseif not (factory or rule or cannon or crusher and profile.attack_states[a.id]) then reason='unmapped'
                elseif not enabled(move) then reason='move_disabled'
                elseif a.paused or not a.speed or a.speed<=0 or a.time~=a.time or a.time<0 then reason='inactive_clock'
                elseif old.warned[shot] then reason='already_warned'
                elseif a.time<window.time then reason='before_cue'
                elseif a.time>window.last then reason='late_sample'
                elseif window.fire and (window.fire-a.time)/a.speed<0.2 then reason='insufficient_lead'
                elseif e.alive==false then reason='dead_or_replaced'
                elseif not e.owned then reason='unverified_peer_target'
                elseif not ai then reason='no_ai_target'
                elseif not ai.has_target or not ai.tracks_entity or ai.target==0 then reason='no_entity_target'
                elseif not avatar or ai.target~=avatar.id then reason='other_target'
                elseif (expanded or factory) and ai.behavior~=(factory and F.behavior or expanded.behavior) then reason='other_behavior'
                elseif factory and (ai.stage~=F.stage or not ai.preparation_ready) then reason='not_preparing'
                elseif t-(self.fired[identity] or -math.huge)<=0.7 then reason='cooldown'
                else reason='trigger' end
                local decision={entity=a.entity,unit=e.unit,class_name=e.class_name,move=move,ability=a.id,
                    ability_time=a.time,ability_speed=a.speed,sample_time=t,reason=reason,owned=e.owned,
                    target_entity=ai and ai.target,has_target=ai and ai.has_target,
                    tracks_entity=ai and ai.tracks_entity,behavior=ai and ai.behavior,
                    stage=ai and ai.stage,target_source=ai and 'behavior',avatar_entity=avatar and avatar.id,
                    attack_source=source,shot_index=shot,attack_token=a.token}
                decisions[#decisions+1]=decision
                if reason=='trigger' then
                    old.warned[shot]=true;self.fired[identity]=t;trigger(decision)
                end
            end
        end
        -- Keep deduplication across partial table scans and short missing-row gaps.
        for key,state in pairs(self.previous) do if t-state.seen>2 then self.previous[key]=nil end end
        for key,when in pairs(self.fired) do if t-when>2 then self.fired[key]=nil end end
        return decisions
    end
    function self:step(t)
        if self.disabled or t<(self.retry_at or 0) then return end
        self.snapshot=nil
        local ok,why=pcall(function()
            native:begin()
            local scene=native:scene()
            if not scene.mission or not scene.avatar then self:reset();self.context=nil;return end
            local context=scene.key..':'..scene.avatar.id..':'..scene.avatar.unit
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
                e.ai=native:behavior_target(e,scene.avatar)
                targets[e.id]=e
                if profile.expanded and e.resource==profile.expanded.factory.resource and e.ai then
                    local ai=e.ai
                    if ai.native_time and ai.preparation_started and ai.preparation_started>0 then
                        active[#active+1]={entity=e.id,id=0,slot='factory',source='factory_stage',
                            time=(ai.native_time-ai.preparation_started)/1000000,speed=1,token=ai.preparation_started}
                    end
                end
            end
            -- Reject an avatar/world change before emitting any event from this batch.
            local latest=native:scene()
            assert(latest.mission and latest.avatar and latest.key==scene.key
                and latest.avatar.id==scene.avatar.id and latest.avatar.unit==scene.avatar.unit,'warning scene changed')
            local decisions=self:observe(active,targets,t,scene.avatar)
            self.snapshot={t=t,scene=scene,selected=selected,abilities=active,decisions=decisions,
                tracking=stats,health_records=health and health.count or 0}
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
