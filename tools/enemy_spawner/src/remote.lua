-- Client intent -> current host -> existing authoritative spawn controller.
-- Wire data contains only whitelisted indices, IDs and a bounded facing vector.
-- The host chooses the actual position from its current requester avatar.
local M={}
local function hex(value)return type(value)=='string'and #value==16 and value:match('^[0-9a-f]+$')~=nil end
local function number(s,lo,hi)
    if type(s)~='string'or not s:match('^%-?%d+$')or #s>8 then return nil end
    local n=tonumber(s);if n and n>=lo and n<=hi then return n end
end
function M.parse(value)
    if type(value)~='string'or #value>512 or value:find('[^\32-\126]')then return nil end
    local t={};for word in value:gmatch('%S+')do t[#t+1]=word end
    if t[1]~='SDAES1'then return nil end
    if t[2]=='H'and #t>=3 and #t<=12 and (#t-3)%3==0 and hex(t[3])then
        local acks={}
        for i=4,#t,3 do
            if not hex(t[i])or not hex(t[i+1])or not t[i+2]:match('^[QDFB]$')or acks[t[i]]then return nil end
            acks[t[i]]={token=t[i+1],code=t[i+2]}
        end
        return {kind='H',nonce=t[3],acks=acks}
    elseif t[2]=='R'and #t==8 and hex(t[3])and hex(t[4])then
        local enemy,network=number(t[5],1,16),number(t[6],1,32766)
        local x,y=number(t[7],-1000,1000),number(t[8],-1000,1000)
        if not(enemy and network and x and y)then return nil end
        local length=math.sqrt(x*x+y*y);if length<990 or length>1010 then return nil end
        return {kind='R',nonce=t[3],token=t[4],enemy=enemy,network=network,direction={x=x/length,y=y/length}}
    end
end
function M.new(native,controller,channel,catalog,log,status,nonce,clock)
    clock=clock or function()return 0 end
    local self={acks={},seen={},seen_count=0,next_poll=0,next_request=0,errors=0}
    local function client_stop(message)
        self.pending=nil;status(message)
    end
    function self:complete(requester,success,reason)
        if not requester then return end
        local current=self.acks[requester.peer]
        if current and current.token==requester.token then
            current.code=success and'D'or'F'
            log('remote spawn '..requester.peer..' '..requester.token..' '..current.code..': '..tostring(reason))
        end
    end
    function self:request(enemy,now)
        native:begin();local scene,why=native:peer_scene()
        if not scene then status(tostring(why));return false end
        if scene.host then return controller:request(enemy,now)end
        if self.disabled then status('联机请求已停止，请重启 / Remote channel stopped; restart');return false end
        if self.pending or now<self.next_request then status('请等待当前生成请求 / Wait for current request');return false end
        if enemy.faction~=scene.faction then status('请进入对应阵营任务 / Enter the correct faction mission');return false end
        local direction,why=native:direction();if not direction then status(tostring(why));return false end
        local index;for i,e in ipairs(catalog.enemies)do if e==enemy then index=i;break end end
        if not index then return false end
        local net=scene.avatar.network_id
        if not(type(net)=='number'and net>=1 and net<=32766)then status('本人网络 ID 尚未就绪 / Avatar network not ready');return false end
        self.pending={enemy=index,network=net,key=scene.key,unit=scene.avatar.unit,direction=direction,
            token=nonce(),start=now};self.next_request=now+5
        status('等待房主生成工具 / Waiting for host spawner (both need 0.3.1+)')
        return true
    end
    local function host_value()
        local list={'SDAES1 H '..self.nonce};local peers={}
        for id in pairs(self.acks)do peers[#peers+1]=id end;table.sort(peers)
        for _,id in ipairs(peers)do local a=self.acks[id];list[#list+1]=id..' '..a.token..' '..a.code end
        return table.concat(list,' ')
    end
    function self:poll(now)
        native:begin();local scene=native:peer_scene()
        if scene and scene.host and scene.player_count==1 then self.host_key=nil;return end
        local context,why=channel:snapshot(now)
        if not context then
            local message=tostring(why or 'lobby unavailable')
            if self.channel_reason~=message then self.channel_reason=message;log('remote waiting: '..message)end
            if self.pending then status('等待联机通道 / Waiting for lobby: '..message)end
            if self.pending and now-self.pending.start>=180 then client_stop('联机请求超时 / Remote request timed out')end
            return
        end
        if self.channel_reason then self.channel_reason=nil;log('remote lobby available')end
        if not scene then
            self.host_key=nil;self.nonce=nil;self.acks={};self.seen={};self.seen_count=0
            if self.pending then client_stop('场景或潜兵已变化 / Scene or avatar changed')end
            channel:publish('SDAES1 W',now,context);return
        end
        if scene.host~=context.is_host then
            if not self.role_mismatch then self.role_mismatch=true;log('remote waiting: mission authority and lobby host differ')end
            if self.pending then status('任务房主状态尚未同步 / Waiting for host authority')end
            return
        end
        self.role_mismatch=nil
        if scene.host then
            local key=context.key..'/'..scene.key..'/'..scene.avatar.id..'/'..scene.avatar.unit
            if self.host_key~=key then
                self.host_key=key;self.nonce=nonce();self.challenge_at=now;self.acks={};self.seen={};self.seen_count=0
                log('remote host epoch changed; stale requests invalidated')
            end
            -- A delayed service update cannot revive an indefinitely old intent.
            -- Keep a queued request's epoch until its controller completes; ACKs
            -- survive lease renewal so a completed spawn is still reported.
            if now-self.challenge_at>=60 and not controller.pending then self.nonce=nonce();self.challenge_at=now end
            -- Bound the per-peer maps even if lobby members leave and rejoin.
            for id in pairs(self.acks)do if not context.members[id]then self.acks[id]=nil end end
            local peers={};for id in pairs(context.values)do peers[#peers+1]=id end;table.sort(peers)
            for _,id in ipairs(peers)do
                local req=M.parse(context.values[id])
                if id~=context.local_peer and context.members[id]and req and req.kind=='R'and req.nonce==self.nonce
                    and not self.seen[id..':'..req.token]and self.seen_count<128 then
                    -- Consume first, including rejections. The persisted member
                    -- property can never turn into an automatic retry/spawn loop.
                    self.seen[id..':'..req.token]=true;self.seen_count=self.seen_count+1
                    local count=0;for _ in pairs(self.acks)do count=count+1 end
                    if count<3 or self.acks[id]then
                        local requester={peer=id,network=req.network,direction=req.direction,token=req.token}
                        local enemy=catalog.enemies[req.enemy]
                        native:begin();local valid=native:scene(requester)
                        local accepted=valid and enemy and valid.faction==enemy.faction
                            and controller:request(enemy,now,requester)
                        self.acks[id]={token=req.token,code=accepted and'Q'or'B'}
                        log('remote request '..id..' enemy='..req.enemy..' '..self.acks[id].code)
                    end
                end
            end
            channel:publish(host_value(),now,context)
        else
            local p=self.pending;if not p then return end
            if scene.key~=p.key or scene.avatar.network_id~=p.network or scene.avatar.unit~=p.unit then
                client_stop('场景或潜兵已变化 / Scene or avatar changed');return
            end
            if now-p.start>=180 then client_stop('联机请求超时 / Remote request timed out; inspect host status');return end
            local host=M.parse(context.values[context.host_peer])
            if not(host and host.kind=='H')then
                status('等待房主启用新版生成工具 / Waiting for host spawner')
                return
            end
            if p.nonce and (p.host~=context.host_peer or p.lobby~=context.key)then
                client_stop('房主或任务已变化 / Host or mission changed');return
            end
            local ack=host.acks[context.local_peer]
            if ack and ack.token==p.token then
                if ack.code=='D'then client_stop('已在本人前方生成 / Created ahead of you');return
                elseif ack.code=='F'or ack.code=='B'then client_stop('房主拒绝或生成失败，请查看房主状态 / Host busy/refused/failed');return
                elseif ack.code=='Q'then status('房主已接收，正在准备生成 / Host preparing spawn')end
            end
            if p.posted and p.nonce~=host.nonce then client_stop('请求已过期，请重新 APPLY / Request expired; Apply again');return end
            p.nonce=host.nonce;p.host=context.host_peer;p.lobby=context.key
            local function q(n)return math.floor(n*1000+.5)end
            local value=table.concat({'SDAES1','R',p.nonce,p.token,p.enemy,p.network,q(p.direction.x),q(p.direction.y)},' ')
            local posted=channel:publish(value,now,context)
            if posted and not p.posted then p.posted=true;status('已请求房主生成 / Spawn requested from host')end
        end
    end
    function self:step(now)
        if self.disabled or now<self.next_poll then return end
        self.next_poll=now+.5
        local started=clock()
        local ok,why=pcall(self.poll,self,now)
        local cost=clock()-started;self.last_cost=cost
        if cost>.010 then self.next_poll=now+2 end
        if cost>.020 then
            self.slow=(self.slow or 0)+1;log(('remote channel cost %.2f ms; slow polls=%d'):format(cost*1000,self.slow))
            if self.slow>=3 then self.disabled=true;client_stop('联机通道耗时超限已停止 / Remote channel stopped after slow polls')end
        else self.slow=0 end
        if ok then self.errors=0
        else
            self.errors=self.errors+1;log('remote channel unavailable: '..tostring(why))
            if self.errors>=3 then self.disabled=true;client_stop('联机通道已停止，房主本地生成仍可用 / Remote stopped; local host spawning remains')end
        end
    end
    function self:stop()self.pending=nil;self.disabled=true end
    return self
end
return M
