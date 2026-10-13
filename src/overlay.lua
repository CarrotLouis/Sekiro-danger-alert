-- Uses the game's screen GUI and compiled materials; no desktop overlay.
local M={}
function M.new(native,assets,log)
    local self={ready=false,world=nil,gui=nil,id=nil,until_time=nil,checked=0,coloured={}}
    local S=assert(rawget(_G,'stingray'),'stingray API missing')
    local function scope(fn)
        local mark=S.Script.temp_count()
        assert(type(mark)=='number' and mark>=0 and mark<1048576,'invalid temporary arena mark')
        local ok,why=pcall(fn)
        S.Script.set_temp_count(mark)
        if not ok then error(why,0) end
    end
    local function alive(world)
        for _,w in ipairs(S.Application.worlds()) do if w==world then return true end end
        return false
    end
    function self:close()
        if self.gui and alive(self.world) then S.World.destroy_gui(self.world,self.gui) end
        self.gui,self.world,self.id=nil,nil,nil;self.coloured={}
    end
    function self:warmup()
        if self.ready then return true end
        local index=self.checked+1
        if not native:image_ready(assets.frames[index].hash) then return false end
        self.checked=index
        if index==#assets.frames then self.ready=true;log('all '..index..' image families resident') end
        return self.ready
    end
    function self:play(now)
        if not self.ready then log('visual waiting for compiled resources');return false end
        self.start=now;self.until_time=now+#assets.frames/assets.fps;return true
    end
    function self:step(now)
        if not self.until_time then return end
        if now>=self.until_time then self.until_time=nil;self:close();return end
        local world=native:ui_world()
        if self.world and world~=self.world then self:close() end
        scope(function()
            if not self.gui then
                self.world=world;self.gui=assert(S.World.create_screen_gui(world,'scale',1,1),'GUI creation failed')
            end
            local w,h=S.Gui.resolution()
            assert(type(w)=='number' and type(h)=='number' and w>=320 and w<=16384 and h>=240 and h<=16384,'resolution invalid')
            local index=math.min(#assets.frames,math.floor((now-self.start)*assets.fps)+1)
            local frame=assets.frames[index]
            -- Prototype preview anchor; exact avatar-head projection follows attack identification.
            local size=math.min(h*0.48,512)
            local position=S.Vector3(w*0.5-size*0.5,h*0.65-size*0.5,950)
            local dimensions=S.Vector2(size,size);local tint=S.Color(255,255,255,255)
            if self.id==nil then self.id=assert(S.Gui.bitmap(self.gui,frame.name,position,dimensions,tint),'bitmap creation failed')
            else S.Gui.update_bitmap(self.gui,self.id,frame.name,position,dimensions,tint) end
            if not self.coloured[index] then
                local material=assert(S.Gui.material(self.gui,frame.name),'material instance missing')
                assert(not tostring(material):match('NULL$') and not tostring(material):match(':%s*0x0+$'),'null material')
                for j,c in ipairs(assets.colours) do
                    S.Material.set_vector4(material,'c'..(j-1),S.Quaternion.from_elements(c[1],c[2],c[3],c[4]))
                end
                self.coloured[index]=true
            end
        end)
    end
    return self
end
return M
