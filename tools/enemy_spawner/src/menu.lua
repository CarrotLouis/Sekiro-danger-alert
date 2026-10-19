local M={}
local PREFIX='peril_warning.enemy_spawner.'
function M.new(catalog,log)
    local self={ready=false,pending=nil,status='正在初始化 / Initializing'}
    local menu
    function self:register()
        if self.ready then return true end
        menu=rawget(_G,'ModOptionsMenu')
        if not(menu and menu.version and menu.version>=3)then return false end
        assert(#catalog.enemies>=2 and #catalog.enemies<=32,'spawner catalog limit')
        local choices,extra={},{}
        for index,enemy in ipairs(catalog.enemies)do
            local list=index<=16 and choices or extra;list[#list+1]=enemy.label
        end
        local specs={
            {'enemy',{type='choice',label='选择敌人 / Enemy',default=1,choices=choices,
                description='原有 16 项的顺序保持不变。新增单位在“新增敌人”中选择，并将“使用列表”切为新增。联机双方均需 0.4.1；穿刺虫需 5–10 难度，霸王虫需 7–10 难度。'}},
            {'spawn',{type='choice',label='生成一只 / Spawn one',default=1,
                choices={'待命 / Ready','生成一只 / Spawn one'},
                description=function()
                    return '选择生成后 APPLY 并关闭菜单。客机请求通过联机服务传给房主，可能需等待；房主资源就绪后倒计时 3 秒，在请求者前方约 20m 生成并以请求者为初始目标。当前状态 / Status: '..self.status
                end}},
        }
        if #extra>0 then
            assert(#extra>=2,'a choice needs at least two items')
            table.insert(specs,1,{'list',{type='choice',label='使用列表 / List',default=1,
                choices={'原有单位 / Original','新增单位 / Added'},
                description='决定生成时读取哪份敌人列表。切换列表或敌人本身不会生成。'}})
            table.insert(specs,3,{'extra',{type='choice',label='新增敌人 / Added enemy',default=1,choices=extra,
                description='三类喷涌虫、霸王虫、两类指挥官，以及 Gazer 小炮台和激光塔核心。两种炮台核心仅支持单人光能任务，尚需验证；生成其武器实体，不生成任务场地或塔基。'}})
        end
        for _,row in ipairs(specs)do
            row[2].mod='Sekiro danger alert - Enemy Spawner'
            row[2].mod_id='peril_warning.enemy_spawner'
            local ok,why=menu.register_option(PREFIX..row[1],row[2])
            if not ok then log('menu refused '..row[1]..': '..tostring(why));return false end
        end
        assert(menu.set(PREFIX..'spawn',1))
        assert(menu.on_change(PREFIX..'spawn',function(value)
            if value==2 then
                -- Only an Apply callback creates an intent. Saved actions never run on load.
                local added=#extra>0 and menu.get(PREFIX..'list')==2
                local index=menu.get(PREFIX..(added and'extra'or'enemy'))
                if added and type(index)=='number'then index=index+16 end
                if type(index)=='number'and index%1==0 and catalog.enemies[index]then
                    self.pending=catalog.enemies[index]
                end
            end
        end))
        self.ready=true;log('menu registered: '..#specs..' options, '..#catalog.enemies..' enemies')
        return true
    end
    function self:consume()
        local enemy=self.pending;self.pending=nil
        if enemy then assert(menu.set(PREFIX..'spawn',1))end
        return enemy
    end
    function self:set_status(value)self.status=tostring(value)end
    return self
end
return M
