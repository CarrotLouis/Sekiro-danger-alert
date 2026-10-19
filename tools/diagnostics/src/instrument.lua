-- Installed only by --diagnostics; normal packages have no collector or F8 reader.
local M={}
function M.new(extension,capture_module,tracking_module,marker_module,catalog,profile,version)
    local self={native_extension=extension,ready=false,next_sample=0}
    local prefix='peril_warning.diagnostics.'
    local groups={{name='虫族',id=2,key='bugs'},{name='机器人',id=8,key='bots'},
        {name='光能族',id=4,key='illuminate'}}
    for _,move in ipairs(catalog.moves)do if move.capture_group=='bugs_new'then
        groups[#groups+1]={name='虫族新增',id=2,key='bugs_new'};break
    end end
    for _,move in ipairs(catalog.moves)do if move.faction==1 then groups[3].name='光能及友军';break end end
    -- Extend the collection catalog only; production IDs and saved options stay intact.
    local moves={};for _,move in ipairs(catalog.moves)do moves[#moves+1]=move end
    moves[#moves+1]={id='crusher_melee',label='粉碎者 · 锤击',attack_name='Heavy Cudgel',
        faction=4,resources={profile.crusher_resource}}
    moves[#moves+1]={id='cannon_preparation',label='加农炮台 · 炮击准备',attack_name='Heavy cannon preparation',
        faction=8,resources={profile.cannon.resource}}
    local resources={};for _,r in ipairs(catalog.resources)do resources[#resources+1]=r end
    resources[#resources+1]={hash=profile.cannon.resource,class_name='turret_heavycannon'}
    self.catalog={moves=moves,resources=resources}
    for _,group in ipairs(groups)do
        group.moves={};for _,move in ipairs(moves)do
            if move.capture_group==group.key or not move.capture_group and move.faction==group.id and group.key~='bugs_new'then
                group.moves[#group.moves+1]=move
            end
        end
        assert(#group.moves>=2 and #group.moves<=16,'diagnostic choice limit')
    end
    local menu,clock,log
    function self:register()
        if self.ready then return true end
        menu=rawget(_G,'ModOptionsMenu')
        if not(menu and menu.api==1 and (menu.version or 0)>=3)then return false end
        local names={};for _,group in ipairs(groups)do names[#names+1]=group.name end
        local specs={{'group',{type='choice',label='采集分组 / Group',default=3,
            choices=names,
            description='只采集所选阵营下对应招式。客机问题必须在客机电脑上记录本人被攻击。'}}}
        for _,group in ipairs(groups)do
            local names={};for _,move in ipairs(group.moves)do names[#names+1]=move.label end
            specs[#specs+1]={group.key,{type='choice',label=group.name..'采集招式',default=1,choices=names,
                description='仅当“采集阵营”选中'..group.name..'时使用；切换选择本身不会开始采集。'}}
        end
        specs[#specs+1]={'context',{type='choice',label='采集场景 / Context',default=1,
            choices={'攻击本人 / Attacking me','攻击队友等对照 / Comparison'},
            description='优先记录本人。普通范围按 F8；霸王虫任一范围均联合采四招：- 出土后下压，= 破土拍击，[ 扫射吐酸，] 直线吐酸。'}}
        specs[#specs+1]={'action',{type='choice',label='开始或停止采集 / Record',default=1,
            choices={'待命 / Ready','开始采集 / Start','停止采集 / Stop'},
            description=function()
                local c=self.collector;local state='未采集'
                if c then
                    state=(c.active and '正在采集' or '已停止：'..tostring(c.stop_reason or '待命'))
                        ..'；有效样本 '..tostring(c.successful_samples or 0)
                    if c.long_capture then
                        for _,key in ipairs({'-','=','[',']'})do state=state..'；'..key..' '..tostring((c.marker_counts or {})[key]or 0)end
                        state=state..'；分段 '..tostring(c.part_index or 0)
                    else state=state..'；F8 '..tostring(c.marker_count or 0)end
                    if c.channel_warning then state=state..'；部分通道不可用，仍保留其他状态'end
                end
                return '开始后 APPLY 并关闭菜单。霸王虫用 - = [ ] 四键，最长60分钟，每5分钟或8 MiB分段；其他范围用F8、两分钟。状态：'..(self.failure or state)
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
                if move then
                    local selected=move.id
                    for _,combined in ipairs(moves)do if combined.id=='hive_lord_all'then
                        for _,binding in ipairs(combined.manual_markers or {})do
                            if binding.move==selected then selected=combined.id;break end
                        end
                    end end
                    self.pending={move=selected,context=menu.get(prefix..'context')==2 and 'comparison'or'requested'}
                end
            elseif value==3 then self.pending={stop=true}end
        end))
        self.ready=true;log('diagnostic menu registered: '..#specs..' options; marker keys enabled only during capture')
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
        self.pending=nil;self.marker=nil
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
            self.marker=nil
            assert(menu.set(prefix..'action',1))
            if pending.stop then self.collector:stop('user stopped')
            else self.collector:start('combat',pending.move,pending.context);self.next_sample=0 end
        end
        if not self.collector.active then return end
        self.collector:record_detection(self.detector.snapshot)
        if t>=self.next_sample then
            self.collector:step()
            self.next_sample=t+((self.collector.cost or 0)>.010 and .2 or(self.collector.sample_interval or .1))
        end
        if self.collector.active then
            self.marker=self.marker or marker_module.new(self.collector.marker_bindings)
            local edges=self.marker()
            if type(edges)=='table'then
                for _,key in ipairs(edges)do self.collector:mark(key)end
            elseif edges then self.collector:mark()end
        end
    end
    function self:stop(reason)
        if reason=='diagnostic failure'then self.failure='诊断已停止，请查看日志并重启游戏'end
        if self.collector then self.collector:stop(reason)end
    end
    return self
end
return M
