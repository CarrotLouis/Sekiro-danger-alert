-- Current ModOptionsMenu API v3. Actions are consumed after Apply completes.
local M={}
function M.new(log,catalog,profile)
    local self={ready=false,pending=nil,defaults={}}
    local prefix='peril_warning.crusher.'
    local menu
    function self:register()
        if self.ready then return true end
        menu=rawget(_G,'ModOptionsMenu')
        if type(menu)~='table' or menu.api~=1 or (menu.version or 0)<3 then return false end
        local specs={
            {'offset_x',{type='slider',label='左右位置 / Horizontal',min=-100,max=100,step=1,default=0,
                description='0 保持原头顶锚点；负数向左，正数向右。范围约左右各一个身位。APPLY 后生效。'}},
            {'offset_y',{type='slider',label='上下位置 / Vertical',min=-100,max=100,step=1,default=0,
                description='0 保持原头顶锚点；负数向下，正数向上。范围约上下各两个头高。APPLY 后生效。'}},
            {'size',{type='slider',label='大小 % / Size %',min=50,max=300,step=5,default=100,
                description='100% 约为原效果字形大小；50% 至 300%。以头顶锚点为中心缩放，保持跟随。'}},
            {'automatic',{type='choice',label='自动预警 / Automatic warning',default=1,
                choices={'开启 / On','关闭 / Off'},
                description='Crusher、普通重炮塔及 16 个新增招式锁定本人并进入预警窗口时生效，不限距离。仅采用本机拥有的 AI；蟑龙仅俯冲吐息，铁幕坦克仅直射。'}},
            {'volume',{type='slider',label='音量 / Volume',min=0,max=100,step=1,default=60,
                description='只调整危提示音。0 为静音。按 APPLY 应用。 / Only this warning sound; 0 mutes it. Apply to save.'}},
            {'preview',{type='choice',label='立即试听 / Preview',default=1,
                choices={'待命 / Ready','播放一次 / Play once'},
                description='选择播放一次，然后按 APPLY；立即按已应用的音量播放。可重复使用。 / Play once, then Apply.'}},
            {'visual',{type='choice',label='动画预览 / Animation preview',default=1,
                choices={'待命 / Ready','三秒后播放 / Play in 3 seconds'},
                description='按 APPLY 后关闭菜单，三秒后在本机潜兵头顶显示动画并播放音效。'}},
            {'capture',{type='choice',label='Crusher 采集 / Capture',default=1,
                choices={'待命 / Ready','开始两分钟采集 / Start 2 minutes','结束采集 / Stop'},
                description='在任务内、Crusher 附近开启。记录动作、目标和预警决策；看到出招时按 F8 标记。'}},
            {'target_capture',{type='choice',label='炮塔索敌采集 / Turret targeting capture',default=1,
                choices={'待命 / Ready','开始两分钟采集 / Start 2 minutes','结束采集 / Stop'},
                description='记录炮塔目标、攻击计时与自动预警决策。看到闪光时按 F8 标记；与 Crusher 采集互斥。'}},
            {'research_move',{type='choice',label='新招式采集目标 / Capture target',default=1,
                choices=(function()local out={};for _,m in ipairs(catalog.moves)do out[#out+1]=m.label end;return out end)(),
                description='选择本次要采集的招式；采集启动后目标固定。它不改变招式开关。'}},
            {'research_context',{type='choice',label='采集类型 / Capture condition',default=1,
                choices={'目标招式 / Requested','对照动作 / Comparison'},
                description='铁幕坦克：目标招式记录直射，对照动作记录抛射。其他敌人可采集容易混淆的动作。'}},
            {'research_capture',{type='choice',label='新招式采集 / Combat capture',default=1,
                choices={'待命 / Ready','开始两分钟采集 / Start 2 minutes','结束采集 / Stop'},
                description='选择采集目标后开始并 APPLY；看到指定招式起手后按 F8。与另外两种采集互斥。'}},
            {'reset',{type='choice',label='恢复全部默认值 / Restore defaults',default=1,
                choices={'待命 / Ready','恢复全部默认值 / Restore all'},
                description='APPLY 后恢复本模组各设置页的全部默认值，所有招式开启，停止采集并取消待执行预览。'}},
        }
        for _,row in ipairs(specs) do
            row[2].mod='Sekiro danger alert';row[2].mod_id='peril_warning.crusher'
            local ok,why=menu.register_option(prefix..row[1],row[2])
            if not ok then log('menu refused '..row[1]..': '..tostring(why));return false end
            self.defaults[prefix..row[1]]=row[2].default
        end
        local moves={};local ids={}
        for id in pairs(profile.attack_states)do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids)do moves[#moves+1]={id='crusher_'..id,label='Crusher · 近战分支 '..id,
            description='控制已识别的能力分支 '..id..'。具体动作名称尚未逐一对应；保留已实测的目标与攻击起点判断。'}end
        moves[#moves+1]={id='cannon_preparation',label='普通重炮塔 · 开火准备',description='控制普通重炮塔锁定本人后的准备阶段预警。'}
        for _,move in ipairs(catalog.moves)do moves[#moves+1]={id=move.id,label=move.label,
            description=move.attack_name..'。默认开启；锁定本人并进入已映射的预警窗口时生效。'}end
        for _,move in ipairs(moves)do
            local id=prefix..'move.'..move.id
            local ok,why=menu.register_option(id,{type='toggle',mod='Sekiro danger alert - Attacks',
                mod_id='peril_warning.crusher.moves',label=move.label,description=move.description,default=true})
            if not ok then log('menu refused '..id..': '..tostring(why));return false end
            self.defaults[id]=true
        end
        -- A saved action is never replayed on startup. Reset has no callback.
        for _,key in ipairs({'preview','visual','capture','target_capture','research_capture','reset'}) do
            menu.set(prefix..key,1)
            menu.on_change(prefix..key,function(value)
                if value~=1 then
                    self.pending=self.pending or {}
                    self.pending[key]=value
                end
            end)
        end
        self.ready=true
        log('menu registered: '..#specs..' general options, '..#moves..' move toggles')
        return true
    end
    function self:volume()
        local v=self.ready and menu.get(prefix..'volume') or 60
        return math.max(0,math.min(100,tonumber(v) or 60))
    end
    function self:automatic()return self.ready and menu.get(prefix..'automatic')==1 end
    function self:enabled(move)return self.ready and menu.get(prefix..'move.'..move)==true end
    function self:research_move()return catalog.moves[menu.get(prefix..'research_move') or 1].id end
    function self:research_context()return menu.get(prefix..'research_context')==2 and 'comparison' or 'requested' end
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
        for key in pairs(actions) do menu.set(prefix..key,1) end
        return actions
    end
    return self
end
return M
