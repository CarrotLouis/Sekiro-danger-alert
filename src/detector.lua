-- Resource-specific attack windows plus a currently authoritative entity target.
-- No range predicate. AI selection alone and stale/replicated aim IDs cannot warn.
local M={}
function M.new(native,profile,log,trigger)
    local self={previous={},fired={},errors=0,cursor=0}
    function self:reset()
        self.previous={};self.fired={};self.snapshot=nil;self.cursor=0
    end
    function self:observe(items,targets,t,avatar)
        local decisions={}
        for _,a in ipairs(items) do
            local e=targets[a.entity]
            if e then
                local key=a.entity..':'..e.unit..':'..a.slot
                local old=self.previous[key]
                if not old or old.id~=a.id or a.time<old.time-0.1 or t-old.seen>2 then
                    old={id=a.id,warned=false}
                end
                old.time=a.time;old.seen=t;self.previous[key]=old
                local crusher=e.resource==profile.crusher_resource
                local cannon=e.resource==profile.cannon.resource and a.id==profile.cannon.ability
                local cue=cannon and profile.cannon.cue_time or 0
                local last=cannon and profile.cannon.last_warning_time or 0.35
                local ai=e.ai
                local identity=a.entity..':'..e.unit
                local reason
                if crusher and (profile.ignored_stomps or {})[a.id] then reason='stomp'
                elseif not (cannon or crusher and profile.attack_states[a.id]) then reason='unmapped'
                elseif a.paused or not a.speed or a.speed<=0 then reason='inactive_clock'
                elseif old.warned then reason='already_warned'
                elseif a.time<cue then reason='before_cue'
                elseif a.time>last then reason='late_sample'
                elseif cannon and (profile.cannon.fire_time-a.time)/a.speed<0.2 then reason='insufficient_lead'
                elseif e.alive==false then reason='dead_or_replaced'
                elseif not e.owned then reason='unverified_peer_target'
                elseif not ai then reason='no_ai_target'
                elseif not ai.has_target or not ai.tracks_entity or ai.target==0 then reason='no_entity_target'
                elseif not avatar or ai.target~=avatar.id then reason='other_target'
                elseif t-(self.fired[identity] or -math.huge)<=0.7 then reason='cooldown'
                else reason='trigger' end
                local decision={entity=a.entity,unit=e.unit,class_name=e.class_name,ability=a.id,
                    ability_time=a.time,ability_speed=a.speed,sample_time=t,reason=reason,owned=e.owned,
                    target_entity=ai and ai.target,has_target=ai and ai.has_target,
                    tracks_entity=ai and ai.tracks_entity,behavior=ai and ai.behavior,
                    stage=ai and ai.stage,target_source=ai and 'behavior',avatar_entity=avatar and avatar.id}
                decisions[#decisions+1]=decision
                if reason=='trigger' then
                    old.warned=true;self.fired[identity]=t;trigger(decision)
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
            local targets={};local health
            for _,e in ipairs(selected) do
                if e.resource==profile.crusher_resource then
                    health=health or native:health_header()
                    local current=native:resolve(health,e.id)
                    e.alive=current~=nil and current.pointer==e.pointer and current.identity==e.identity
                end
                e.ai=native:behavior_target(e,scene.avatar)
                targets[e.id]=e
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
