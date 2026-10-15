-- Release settings: one ModOptionsMenu category; actions run after Apply.
local M={}
function M.new(log,catalog,profile)
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
            {'offset_x',{type='slider',label='左右位置 / Horizontal',min=-100,max=100,step=1,default=0,
                description='0 保持原头顶锚点；负数向左，正数向右。范围约左右各一个身位。APPLY 后生效。'}},
            {'offset_y',{type='slider',label='上下位置 / Vertical',min=-100,max=100,step=1,default=0,
                description='0 保持原头顶锚点；负数向下，正数向上。范围约上下各两个头高。APPLY 后生效。'}},
            {'size',{type='slider',label='大小 % / Size %',min=50,max=300,step=5,default=100,
                description='100% 为默认字形大小；50% 至 300%。以头顶锚点为中心缩放，始终跟随潜兵。'}},
            {'volume',{type='slider',label='音量 / Volume',min=0,max=100,step=1,default=60,gap=true,
                description='只调整危提示音。0 为静音。按 APPLY 应用。 / Only this warning sound; 0 mutes it.'}},
            {'preview',{type='choice',label='立即试听 / Sound preview',default=1,
                choices={'待命 / Ready','播放一次 / Play once'},
                description='选择播放一次，然后按 APPLY；按已应用的音量播放。可重复使用。'}},
            {'visual',{type='choice',label='动画预览 / Animation preview',default=1,
                choices={'待命 / Ready','三秒后播放 / Play in 3 seconds'},
                description='按 APPLY 后关闭菜单，三秒后在本机潜兵头顶显示动画并播放音效。'}},
        }
        for _,row in ipairs(specs)do if not register(row[1],row[2])then return false end end
        local moves={
            {id='crusher_melee',label='Crusher · 危险近战',
                description='统一控制 Crusher 已识别的所有危险近战变体；跺脚不预警。'},
            {id='cannon_preparation',label='普通重炮塔 · 开火准备',
                description='控制普通重炮塔锁定本人后的准备阶段预警。'},
        }
        for _,move in ipairs(catalog.moves)do moves[#moves+1]={id=move.id,label=move.label,
            description=move.attack_name..'。锁定本人并进入招式预警窗口时生效，不限距离。'}end
        for index,move in ipairs(moves)do
            if not register('move.'..move.id,{type='toggle',label=move.label,description=move.description,
                default=true,gap=index==1})then return false end
        end
        if not register('reset',{type='choice',label='恢复全部默认值 / Restore defaults',default=1,gap=true,
            choices={'待命 / Ready','恢复全部默认值 / Restore all'},
            description='APPLY 后恢复本模组全部默认值：所有招式开启、偏移 0、大小 100%、音量 60，并取消待执行预览。'})then return false end
        -- Saved actions never replay on startup; set() does not run callbacks.
        for _,key in ipairs({'preview','visual','reset'})do
            menu.set(prefix..key,1)
            menu.on_change(prefix..key,function(value)
                if value~=1 then self.pending=self.pending or {};self.pending[key]=value end
            end)
        end
        self.ready=true
        log('menu registered: 25 release options on one page; '..#moves..' attack toggles')
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
