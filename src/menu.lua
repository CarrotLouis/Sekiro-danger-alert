-- Current ModOptionsMenu API v3. Actions are consumed after Apply completes.
local M={}
function M.new(log)
    local self={ready=false,pending=nil}
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
                description='Crusher 或普通重炮塔锁定本人并进入已识别的攻击前摇时预警，不限距离。暂只采用本机拥有的敌人 AI 目标。'}},
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
        }
        for _,row in ipairs(specs) do
            row[2].mod='Sekiro danger alert';row[2].mod_id='peril_warning.crusher'
            local ok,why=menu.register_option(prefix..row[1],row[2])
            if not ok then log('menu refused '..row[1]..': '..tostring(why));return false end
        end
        -- A saved action is never replayed on startup. Reset has no callback.
        for _,key in ipairs({'preview','visual','capture','target_capture'}) do
            menu.set(prefix..key,1)
            menu.on_change(prefix..key,function(value)
                if value~=1 then
                    self.pending=self.pending or {}
                    self.pending[key]=value
                end
            end)
        end
        self.ready=true
        log('menu registered: slider 0..100, audio preview, visual preview, capture')
        return true
    end
    function self:volume()
        local v=self.ready and menu.get(prefix..'volume') or 60
        return math.max(0,math.min(100,tonumber(v) or 60))
    end
    function self:automatic()return self.ready and menu.get(prefix..'automatic')==1 end
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
        for key in pairs(actions) do menu.set(prefix..key,1) end
        return actions
    end
    return self
end
return M
