-- Read-only Crusher ability observation. Only the two capture-supported attacks are enabled.
local M={}
function M.new(native,profile,log,trigger)
    local self={tracked={},previous={},fired={},cursor=0,next_discover=0,errors=0}
    function self:reset()
        self.tracked={};self.previous={};self.fired={};self.cursor=0;self.next_discover=0
    end
    function self:observe(items,targets,t)
        local current={}
        for _,a in ipairs(items) do
            local target=targets[a.entity]
            if target then
                local key=a.entity..':'..target.unit..':'..a.slot
                local old=self.previous[key]
                current[key]={id=a.id,time=a.time}
                local fresh=a.time>=0 and a.time<=0.35
                local start=fresh and (not old or old.id~=a.id or a.time<old.time-0.1)
                local identity=a.entity..':'..target.unit
                if start and profile.attack_states[a.id] and target.distance<=10
                    and t-(self.fired[identity] or -math.huge)>0.7 then
                    self.fired[identity]=t
                    trigger({entity=a.entity,unit=target.unit,ability=a.id,ability_time=a.time,distance=target.distance})
                end
            end
        end
        self.previous=current
    end
    function self:step(t)
        if self.disabled or t<(self.retry_at or 0) then return end
        local ok,why=pcall(function()
            native:begin()
            local scene=native:scene()
            if not scene.mission or not scene.avatar or not scene.position then self:reset();self.context=nil;return end
            local context=scene.key..':'..scene.avatar.unit
            if self.context~=context then self:reset();self.context=context end
            local h=native:health_header()
            if t>=self.next_discover then
                local found;found,self.cursor=native:discover(h,self.cursor,128)
                local count=0;for _ in pairs(self.tracked) do count=count+1 end
                for _,e in ipairs(found) do
                    if self.tracked[e.id] or count<16 then
                        if not self.tracked[e.id] then count=count+1 end
                        self.tracked[e.id]=true
                    end
                end
                self.next_discover=t+0.15
            end
            local owners,targets={},{}
            for id in pairs(self.tracked) do
                local e=native:resolve(h,id)
                if not e then self.tracked[id]=nil
                else
                    local p=native:position(e.unit);local q=scene.position
                    local distance=math.sqrt((p.x-q.x)^2+(p.y-q.y)^2+(p.z-q.z)^2)
                    owners[native.memory.address(e.pointer)]=e
                    targets[id]={unit=e.unit,distance=distance}
                end
            end
            self:observe(native:abilities(owners),targets,t)
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
