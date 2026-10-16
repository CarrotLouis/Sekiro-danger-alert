-- Release settings: one ModOptionsMenu category; actions run after Apply.
local M={}
function M.new(log,catalog,profile,text)
    assert(text,'localized menu text missing')
    local self={ready=false,pending=nil,defaults={}}
    local prefix='peril_warning.crusher.'
    local menu
    function self:register()
        if self.ready then return true end
        menu=rawget(_G,'ModOptionsMenu')
        if type(menu)~='table' or menu.api~=1 or (menu.version or 0)<3 then return false end
        local function register(key,spec)
            spec.mod='Sekiro danger alert';spec.mod_id='peril_warning.crusher'
            local ok,why=menu.register_option(prefix..key,spec)
            if not ok then log('menu refused '..key..': '..tostring(why));return false end
            self.defaults[prefix..key]=spec.default
            return true
        end
        local specs={
            {'offset_x',{type='slider',label=text:source('horizontal'),min=-100,max=100,step=1,default=0,
                description=text:source('h_desc')}},
            {'offset_y',{type='slider',label=text:source('vertical'),min=-100,max=100,step=1,default=0,
                description=text:source('v_desc')}},
            {'size',{type='slider',label=text:source('size'),min=50,max=300,step=5,default=100,
                description=text:source('size_desc')}},
            {'volume',{type='slider',label=text:source('volume'),min=0,max=100,step=1,default=60,gap=true,
                description=text:source('vol_desc')}},
            {'preview',{type='choice',label=text:source('sound'),default=1,
                choices={text:source('ready'),text:source('play')},description=text:source('sound_desc')}},
            {'visual',{type='choice',label=text:source('animation'),default=1,
                choices={text:source('ready'),text:source('later')},description=text:source('anim_desc')}},
        }
        for _,row in ipairs(specs)do if not register(row[1],row[2])then return false end end
        local moves={}
        for _,group in ipairs({{id=2,name='bugs'},{id=8,name='bots'},{id=4,name='illuminate'}})do
            local first=#moves+1
            if group.id==8 then moves[#moves+1]={id='cannon_preparation'}end
            if group.id==4 then moves[#moves+1]={id='crusher_melee'}end
            for _,move in ipairs(catalog.moves)do if move.faction==group.id then
                moves[#moves+1]={id=move.id}
            end end
            for index=first,#moves do moves[index].faction=group.name end
            if moves[first]then moves[first].gap=true end
        end
        for index,move in ipairs(moves)do
            local faction=move.faction
            local desc=move.id=='crusher_melee'and'crusher_desc'or move.id=='dragon_alchemical_pyrosis'and'dragon_desc'
                or move.id=='barrager_direct_mlrs'and'barrager_desc'or'attack_desc'
            if not register('move.'..move.id,{type='toggle',label=text:source('move.'..move.id),
                description=function()return text:text(faction)..' · '..text:text(desc)end,
                default=true,gap=move.gap})then return false end
            if move.id=='harvester_tesla_ripper' or move.id=='harvester_disintegration_beamer' then
                local key=move.id=='harvester_tesla_ripper'and'tesla_delay'or'beam_delay'
                if not register('delay.'..move.id,{type='slider',label=text:source(key),
                    min=0,max=.5,step=.01,default=.30,
                    description=text:source('delay_desc')})then return false end
            end
        end
        if not register('reset',{type='choice',label=text:source('reset'),default=1,gap=true,
            choices={text:source('ready'),text:source('restore')},description=text:source('reset_desc')})then return false end
        -- Saved actions never replay on startup; set() does not run callbacks.
        for _,key in ipairs({'preview','visual','reset'})do
            menu.set(prefix..key,1)
            menu.on_change(prefix..key,function(value)
                if value~=1 then self.pending=self.pending or {};self.pending[key]=value end
            end)
        end
        self.ready=true
        log('menu registered: '..(#moves+9)..' options on one page; '..#moves..' attack toggles grouped by faction')
        return true
    end
    function self:volume()
        local v=self.ready and menu.get(prefix..'volume') or 60
        return math.max(0,math.min(100,tonumber(v) or 60))
    end
    function self:enabled(move)
        local branch=type(move)=='string' and move:match('^crusher_(%d+)$')
        if branch then
            if not profile.attack_states[tonumber(branch)]then return false end
            move='crusher_melee'
        end
        return self.ready and menu.get(prefix..'move.'..tostring(move))==true
    end
    function self:delay(move)
        if move~='harvester_tesla_ripper' and move~='harvester_disintegration_beamer' then return 0 end
        local value=self.ready and tonumber(menu.get(prefix..'delay.'..move)) or .30
        if not value or value~=value then return .30 end
        return math.floor(math.max(0,math.min(.5,value))*100+.5)/100
    end
    function self:appearance()
        local function value(key,default,lo,hi)
            local v=self.ready and tonumber(menu.get(prefix..key)) or default
            if not v or v~=v then v=default end
            return math.max(lo,math.min(hi,v))
        end
        return {x=value('offset_x',0,-100,100)/100,y=value('offset_y',0,-100,100)/100,
                scale=value('size',100,50,300)/100}
    end
    function self:consume()
        local actions=self.pending or {};self.pending=nil
        if actions.reset==2 then
            for id,value in pairs(self.defaults)do assert(menu.set(id,value),'could not restore '..id)end
            log('all Sekiro danger alert options restored to defaults')
            return {reset=2}
        end
        for key in pairs(actions)do menu.set(prefix..key,1)end
        return actions
    end
    return self
end
return M
