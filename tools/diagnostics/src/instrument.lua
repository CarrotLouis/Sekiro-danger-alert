-- Installed only by --diagnostics; normal packages have no collector or F8 reader.
local M={}
function M.new(extension,capture_module,tracking_module,marker_module,catalog,profile,version)
    local self={native_extension=extension,ready=false,next_sample=0}
    local prefix='peril_warning.diagnostics.'
    local groups={{name='虫族',id=2,key='bugs'},{name='机器人',id=8,key='bots'},
        {name='光能族',id=4,key='illuminate'}}
    -- Extend the collection catalog only; production IDs and saved options stay intact.
    local moves={};for _,move in ipairs(catalog.moves)do moves[#moves+1]=move end
    moves[#moves+1]={id='crusher_melee',label='粉碎者 · 危险近战',attack_name='Crusher dangerous melee',
        faction=4,resources={profile.crusher_resource}}
    moves[#moves+1]={id='cannon_preparation',label='普通重炮塔 · 开火准备',attack_name='Heavy cannon preparation',
        faction=8,resources={profile.cannon.resource}}
    local resources={};for _,r in ipairs(catalog.resources)do resources[#resources+1]=r end
    resources[#resources+1]={hash=profile.cannon.resource,class_name='turret_heavycannon'}
    self.catalog={moves=moves,resources=resources}
    for _,group in ipairs(groups)do
        group.moves={};for _,move in ipairs(moves)do if move.faction==group.id then group.moves[#group.moves+1]=move end end
        assert(#group.moves>=2 and #group.moves<=16,'diagnostic choice limit')
    end
    local menu,clock,log
    function self:register()
        if self.ready then return true end
        menu=rawget(_G,'ModOptionsMenu')
        if not(menu and menu.api==1 and (menu.version or 0)>=3)then return false end
        local specs={{'group',{type='choice',label='采集阵营 / Faction',default=3,
            choices={'虫族 / Terminids','机器人 / Automatons','光能族 / Illuminate'},
            description='只采集所选阵营下对应招式。客机问题必须在客机电脑上记录本人被攻击。'}}}
        for _,group in ipairs(groups)do
            local names={};for _,move in ipairs(group.moves)do names[#names+1]=move.label end
            specs[#specs+1]={group.key,{type='choice',label=group.name..'采集招式',default=1,choices=names,
                description='仅当“采集阵营”选中'..group.name..'时使用；切换选择本身不会开始采集。'}}
        end
        specs[#specs+1]={'context',{type='choice',label='采集场景 / Context',default=1,
            choices={'攻击本人 / Attacking me','攻击队友等对照 / Comparison'},
            description='优先记录敌人攻击本人；再做少量攻击队友的对照。F8 标记看见出招的时刻，延迟按键也保留。'}}
        specs[#specs+1]={'action',{type='choice',label='开始或停止采集 / Record',default=1,
            choices={'待命 / Ready','开始采集 / Start','停止采集 / Stop'},
            description=function()
                local c=self.collector;local state='未采集'
                if c then
                    state=(c.active and '正在采集' or '已停止：'..tostring(c.stop_reason or '待命'))
                        ..'；有效样本 '..tostring(c.successful_samples or 0)..'；F8 '..tostring(c.marker_count or 0)
                    if c.channel_warning then state=state..'；部分通道不可用，仍保留其他状态'end
                end
                return '选择开始后 APPLY，关闭菜单；看见所选招式按 F8。最多两分钟。状态：'..(self.failure or state)
            end}}
        self.defaults={}
        for _,spec in ipairs(specs)do
            spec[2].mod='Sekiro danger alert · 采集 / Diagnostics';spec[2].mod_id='peril_warning.diagnostics'
            local ok,why=menu.register_option(prefix..spec[1],spec[2])
            if not ok then log('diagnostic menu refused '..spec[1]..': '..tostring(why));return false end
            self.defaults[spec[1]]=spec[2].default
        end
        assert(menu.set(prefix..'action',1))
        assert(menu.on_change(prefix..'action',function(value)
            if value==2 then
                local group=groups[menu.get(prefix..'group')]
                local move=group and group.moves[menu.get(prefix..group.key)]
                if move then self.pending={move=move.id,context=menu.get(prefix..'context')==2 and 'comparison'or'requested'}end
            elseif value==3 then self.pending={stop=true}end
        end))
        self.ready=true;log('diagnostic menu registered: 6 options; F8 enabled only during capture')
        return true
    end
    function self:attach_menu(adapter,logger)
        log=logger
        local register,consume=adapter.register,adapter.consume
        -- Bind explicitly; no callback may accidentally resolve a later local as global.
        local instrument=self
        function adapter:register()return register(self)and instrument:register()end
        function adapter:consume()
            local actions=consume(self)
            if actions.reset==2 then instrument:reset()end
            return actions
        end
    end
    function self:reset()
        self.pending=nil
        if self.collector then self.collector:stop('all settings reset')end
        for key,value in pairs(self.defaults or {})do assert(menu.set(prefix..key,value))end
    end
    function self:initialize(native,detector,now,logger,directory)
        log=logger;clock=now;self.detector=detector
        self.collector=capture_module.new(native,directory,log,clock,tracking_module,self.catalog,version)
    end
    function self:step(t,actions)
        if not self.collector then return end
        if actions.reset==2 then self:reset()end
        local pending=self.pending;self.pending=nil
        if pending then
            assert(menu.set(prefix..'action',1))
            if pending.stop then self.collector:stop('user stopped')
            else self.collector:start('combat',pending.move,pending.context);self.next_sample=0 end
        end
        if not self.collector.active then return end
        self.collector:record_detection(self.detector.snapshot)
        if t>=self.next_sample then
            self.collector:step()
            self.next_sample=t+((self.collector.cost or 0)>.010 and .2 or .1)
        end
        if self.collector.active then
            self.marker=self.marker or marker_module.new()
            if self.marker()then self.collector:mark()end
        end
    end
    function self:stop(reason)
        if reason=='diagnostic failure'then self.failure='诊断已停止，请查看日志并重启游戏'end
        if self.collector then self.collector:stop(reason)end
    end
    return self
end
return M
