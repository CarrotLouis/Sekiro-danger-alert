-- No native calls at registration or from a menu callback.
local M={}
function M.new(native,log,status,complete)
    complete=complete or function()end
    local self={pending=nil,epoch=nil,count=0,blocked=false,next_request=0}
    local function cancel(why)
        if self.pending then log('cancelled '..self.pending.enemy.id..': '..why)end
        local pending=self.pending
        self.pending=nil;status(why)
        if pending then complete(pending.requester,false,why)end
    end
    function self:request(enemy,now,requester)
        if self.pending then status('已有生成请求，请等待 / Request already pending');return false end
        if now<self.next_request then status('请稍候再生成 / Please wait');return false end
        native:begin()
        local scene,why=native:scene(requester)
        if not scene then status(tostring(why));return false end
        if scene.key~=self.epoch then self.epoch=scene.key;self.count=0;self.blocked=false end
        if self.blocked or self.count>=32 then
            status('本次任务生成已停止 / Spawning stopped for this mission');return false
        end
        if scene.faction~=enemy.faction then
            status('请进入对应阵营任务 / Enter a mission for this enemy faction');return false
        end
        self.pending={enemy=enemy,scene=scene,requester=requester,start=now,poll=now,phase='loading'}
        self.next_request=now+3
        log('requested '..enemy.id..' entity='..enemy.hash)
        status('正在准备 '..enemy.label..' / Preparing resources')
        return true
    end
    function self:step(now)
        local p=self.pending
        if not p or (now<p.poll and not(p.phase=='countdown'and now>=p.due))then return end
        p.poll=now+0.25;native:begin()
        local scene,why=native:scene(p.requester)
        if not scene or scene.key~=p.scene.key or scene.avatar.id~=p.scene.avatar.id then
            cancel('场景或潜兵已变化 / Scene or avatar changed: '..tostring(why or''));return
        end
        if p.phase=='loading'then
            if now-p.start>=90 then cancel('资源准备超时 / Resource preparation timed out');return end
            local ready,detail=native:prepare(p.enemy,scene)
            if ready==nil then cancel(tostring(detail));return end
            if not ready then return end
            p.phase='countdown';p.due=now+3
            status('3 秒后生成 '..p.enemy.label..' / Spawning in 3 seconds');return
        end
        if now<p.due then return end
        -- Clear intent BEFORE the call: a failure or re-entrant update can never duplicate it.
        self.pending=nil;self.next_request=now+3
        local result,reason=native:spawn(p.enemy,scene)
        if not result then status(tostring(reason));complete(p.requester,false,tostring(reason));return end
        self.count=self.count+1
        if not result.verified then
            self.blocked=true
            status('已创建但状态校验未通过；本任务停止继续生成 / Created, verification failed; further spawns stopped')
            complete(p.requester,false,'verification failed')
            return
        end
        log(('created %s entity=%d unit=%d behavior=%d target_local=%s at=(%.2f,%.2f,%.2f)'):format(
            p.enemy.id,result.entity,result.unit,result.behavior,tostring(result.target_local),
            result.position.x,result.position.y,result.position.z))
        complete(p.requester,true,'created')
        status('已生成 '..p.enemy.label..' / Created')
    end
    function self:stop(reason)cancel(reason or'stopped')end
    return self
end
return M
