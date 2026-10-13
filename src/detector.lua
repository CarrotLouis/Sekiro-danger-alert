-- Read-only Crusher observation: captured slams plus build-pinned non-stomp melee branches.
local M={}
function M.new(native,profile,log,trigger,tracking)
    local tracker=tracking.new(native)
    local self={tracked={},previous={},fired={},errors=0}
    function self:reset()
        tracker:reset();self.tracked={};self.previous={};self.fired={};self.snapshot=nil
    end
    function self:observe(items,targets,t)
        local current,decisions={},{}
        for _,a in ipairs(items) do
            local target=targets[a.entity]
            if target then
                local key=a.entity..':'..target.unit..':'..a.slot
                local old=self.previous[key]
                current[key]={id=a.id,time=a.time}
                local fresh=a.time>=0 and a.time<=0.35
                local start=fresh and (not old or old.id~=a.id or a.time<old.time-0.1)
                local identity=a.entity..':'..target.unit
                local reason=not fresh and 'late_sample' or not start and 'already_observed'
                    or (profile.ignored_stomps or {})[a.id] and 'stomp'
                    or not profile.attack_states[a.id] and 'unmapped'
                    or target.distance>10 and 'outside_10m'
                    or t-(self.fired[identity] or -math.huge)<=0.7 and 'cooldown' or 'trigger'
                decisions[#decisions+1]={entity=a.entity,unit=target.unit,ability=a.id,
                    ability_time=a.time,distance=target.distance,reason=reason}
                if start and target.distance<=10 and not profile.attack_states[a.id]
                    and not (profile.ignored_stomps or {})[a.id] then
                    log('unmapped_action entity='..a.entity..' ability='..a.id)
                end
                if start and profile.attack_states[a.id] and not (profile.ignored_stomps or {})[a.id] and target.distance<=10
                    and t-(self.fired[identity] or -math.huge)>0.7 then
                    self.fired[identity]=t
                    trigger({entity=a.entity,unit=target.unit,ability=a.id,ability_time=a.time,distance=target.distance})
                end
            end
        end
        self.previous=current
        return decisions
    end
    function self:step(t)
        if self.disabled or t<(self.retry_at or 0) then return end
        self.snapshot=nil
        local ok,why=pcall(function()
            native:begin()
            local scene=native:scene()
            if not scene.mission or not scene.avatar or not scene.position then self:reset();self.context=nil;return end
            local context=scene.key..':'..scene.avatar.unit
            if self.context~=context then self:reset();self.context=context end
            local h=native:health_header()
            local selected,stats=tracker:step(h,scene,t);self.tracked=tracker.tracked
            local owners,targets={},{}
            for _,e in ipairs(selected) do
                owners[native.memory.address(e.pointer)]=e
                targets[e.id]={unit=e.unit,distance=e.distance}
            end
            local active=native:abilities(owners)
            local decisions=self:observe(active,targets,t)
            self.snapshot={t=t,scene=scene,selected=selected,abilities=active,decisions=decisions,
                tracking=stats,health_records=h.count}
            -- Despawned/replaced unit identities must not accumulate for the whole mission.
            local kept={}
            for key,when in pairs(self.fired) do if t-when<2 then kept[key]=when end end
            self.fired=kept
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
