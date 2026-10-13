-- Bounded, distance-prioritized observation. Discovery order must not reserve slots forever.
local M={}
function M.new(native,range,limit)
    local self={tracked={},queue={},queued={},first=1,last=0,cursor=0,next_discover=0}
    range=range or 50;limit=limit or 16
    function self:reset()
        self.tracked={};self.queue={};self.queued={};self.first=1;self.last=0
        self.cursor=0;self.next_discover=0
    end
    function self:step(h,scene,t)
        if t>=self.next_discover then
            local found;found,self.cursor=native:discover(h,self.cursor,128)
            for _,e in ipairs(found) do
                if not self.tracked[e.id] and not self.queued[e.id] then
                    assert(self.last-self.first+1<4096,'candidate queue limit')
                    self.last=self.last+1;self.queue[self.last]=e.id;self.queued[e.id]=true
                end
            end
            self.next_discover=t+0.15
        end
        local candidates,seen={},{}
        local stats={examined=0,unavailable=0,outside_range=0,selection_limit=limit,range_m=range}
        local function inspect(id)
            if seen[id] then return end
            seen[id]=true;stats.examined=stats.examined+1
            local e=native:resolve(h,id)
            if not e then return end
            local ok,p=pcall(native.position,native,e.unit)
            if not ok then stats.unavailable=stats.unavailable+1;return end
            local q=scene.position
            e.distance=math.sqrt((p.x-q.x)^2+(p.y-q.y)^2+(p.z-q.z)^2)
            if e.distance<=range then candidates[#candidates+1]=e
            else stats.outside_range=stats.outside_range+1 end
        end
        for id in pairs(self.tracked) do inspect(id) end
        -- At most 16 new positions plus the selected positions per sample.
        for _=1,16 do
            if self.first>self.last then break end
            local id=self.queue[self.first];self.queue[self.first]=nil;self.first=self.first+1
            self.queued[id]=nil;inspect(id)
        end
        if self.first>self.last then self.queue={};self.first=1;self.last=0 end
        table.sort(candidates,function(a,b)
            if a.distance==b.distance then return a.id<b.id end
            return a.distance<b.distance
        end)
        self.tracked={};local selected={}
        for i=1,math.min(limit,#candidates) do
            local e=candidates[i];self.tracked[e.id]=e;selected[#selected+1]=e
        end
        stats.capacity_excluded=math.max(0,#candidates-limit)
        stats.pending=self.last-self.first+1;stats.selected=#selected;stats.cursor=self.cursor
        return selected,stats
    end
    return self
end
return M
