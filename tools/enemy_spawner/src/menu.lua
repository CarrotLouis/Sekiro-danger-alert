local M={}
local PREFIX='peril_warning.enemy_spawner.'
function M.new(catalog,log)
    local self={ready=false,pending=nil,status='正在初始化 / Initializing'}
    local menu
    function self:register()
        if self.ready then return true end
        menu=rawget(_G,'ModOptionsMenu')
        if not(menu and menu.version and menu.version>=3)then return false end
        local choices={}
        for _,enemy in ipairs(catalog.enemies)do choices[#choices+1]=enemy.label end
        local specs={
            {'enemy',{type='choice',label='选择敌人 / Enemy',default=1,choices=choices,
                description='14 种测试敌人。进入对应阵营的单人任务，在开阔平地选择；穿刺虫会自行召唤触手。'}},
            {'spawn',{type='choice',label='生成一只 / Spawn one',default=1,
                choices={'待命 / Ready','生成一只 / Spawn one'},
                description=function()
                    return '选择生成后 APPLY 并关闭菜单。资源就绪后等待 3 秒，在镜头前方约 20m 生成一只。当前状态 / Status: '..self.status
                end}},
        }
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
                local index=menu.get(PREFIX..'enemy')
                if type(index)=='number'and index%1==0 and catalog.enemies[index]then
                    self.pending=catalog.enemies[index]
                end
            end
        end))
        self.ready=true;log('menu registered: 2 options, 14 enemies')
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
