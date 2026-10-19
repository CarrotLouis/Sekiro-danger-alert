-- Read-only checks plus TWO proven engine requests. No game-memory writes, patches or hooks.
-- Uses research from HD2Runtime by SkyeShade; native code re-decoded from build 25480438.
local ffi=require('ffi')
local bit=require('bit')
local M={}
local ZERO8=string.rep('\0',8)
local function u32(s,o)
    local a,b,c,d=s:byte(o+1,o+4);assert(d,'short native read')
    return a+b*256+c*65536+d*16777216
end
local function hex(s)return (s:reverse():gsub('.',function(c)return string.format('%02x',c:byte())end))end
local function rawhex(s)return (s:gsub('.',function(c)return string.format('%02x',c:byte())end))end
local function f32(s,o)
    local value=ffi.new('float[1]');ffi.copy(value,s:sub(o+1,o+4),4)
    return tonumber(value[0])
end
local function unhex(s)
    assert(type(s)=='string'and #s==16 and s:match('^%x+$'),'invalid reviewed hash')
    local out={};for i=15,1,-2 do out[#out+1]=string.char(tonumber(s:sub(i,i+1),16))end
    return table.concat(out)
end
local function coordinate(v)return type(v)=='number'and v==v and math.abs(v)<=100000 end
function M.descriptor(enemy,avatar,position,forward)
    assert(coordinate(position.x)and coordinate(position.y)and coordinate(position.z),'invalid position')
    local fx,fy=forward.x,forward.y
    assert(coordinate(fx)and coordinate(fy)and math.abs(fx*fx+fy*fy-1)<0.001,'invalid facing')
    assert(type(avatar.id)=='number'and avatar.id>0 and avatar.id<4294967296 and avatar.id%1==0,'invalid avatar')
    assert(coordinate(avatar.position.x)and coordinate(avatar.position.y)and coordinate(avatar.position.z),'invalid target position')
    local context=ffi.new('uint8_t[?]',0x8A0+16)
    local cb=tonumber(ffi.cast('uintptr_t',context));local ca=context+(16-cb%16)%16
    -- Only fields read by the proven Behavior creation path are initialized.
    ffi.cast('uint32_t *',ca+0x66C)[0]=avatar.id
    local target=ffi.cast('float *',ca+0x670)
    target[0],target[1],target[2]=avatar.position.x,avatar.position.y,avatar.position.z
    local descriptor=ffi.new('uint8_t[?]',0x58+8)
    local db=tonumber(ffi.cast('uintptr_t',descriptor));local at=descriptor+(8-db%8)%8
    at[0]=1;ffi.cast('uint32_t *',at+4)[0]=0x7FFF
    local pose=ffi.cast('float *',at+8)
    local values={fy,-fx,0,0, fx,fy,0,0, 0,0,1,0, position.x,position.y,position.z,1}
    for i=1,16 do pose[i-1]=values[i]end
    ffi.cast('void **',at+0x48)[0]=ca
    local entity=ffi.new('uint64_t[1]');ffi.copy(entity,unhex(enemy.hash),8)
    local out=ffi.new('uint32_t[1]')
    return {storage=descriptor,context_storage=context,context=ca,at=at,entity=entity,out=out}
end
function M.calls()
    return {
        request=function(entry,instance,bytes)
            local ids=ffi.new('uint64_t[1]');ffi.copy(ids,bytes,8)
            local fn=ffi.cast('void (*)(void *, const uint64_t *, uint32_t)',entry)
            fn(ffi.cast('void *',instance),ids,1)
            assert(ids~=nil)
        end,
        spawn=function(entry,args)
            local fn=ffi.cast('uint32_t *(*)(uint32_t *, uint64_t, void *)',entry)
            fn(args.out,args.entity[0],args.at)
            assert(args.storage~=nil and args.context_storage~=nil and args.entity~=nil)
            return tonumber(args.out[0])
        end,
    }
end
function M.new(memory,profile,catalog,core,log,calls)
    local self={reads=0,bytes=0,held={},held_count=0,package_cache={},contexts={}}
    local game=assert(memory.module('game.dll'));local exe=assert(memory.module(nil))
    calls=calls or M.calls()
    local function read(at,n)
        self.reads=self.reads+1;self.bytes=self.bytes+n
        assert(self.reads<=4000 and self.bytes<=1048576,'spawner read budget exceeded')
        local s=memory.read(at,n);assert(s and #s==n,'spawner state unreadable');return s
    end
    local function ptr(at)return assert(memory.pointer(read(at,8)),'missing native pointer')end
    function self:begin()self.reads,self.bytes=0,0;core:begin()end
    function self:prove()
        for _,pin in ipairs(profile.pins)do
            local base=pin.module=='exe'and exe or game
            assert(read(base+pin.rva,#pin.bytes)==pin.bytes,'spawner pin mismatch: '..pin.label)
        end
    end
    local function record(world,name,hash)
        local t=assert(catalog.tables[name]);local tab=ptr(world+profile.component_slot_base+t.index*8)
        local lo,hi=tonumber(hash:sub(9,16),16),tonumber(hash:sub(1,8),16)
        local start=((hi%t.slots)*(4294967296%t.slots)+lo%t.slots)%t.slots
        for i=0,math.min(t.slots,128)-1 do
            local row=read(tab+((start+i)%t.slots)*16,16)
            if hex(row:sub(1,8))==hash then
                local index=u32(row,8);assert(index<t.records,'entity record out of bounds')
                return read(tab+t.offset+index*t.stride,t.stride)
            end
            if row:sub(1,8)==ZERO8 then return nil end
        end
        error('entity settings probe limit')
    end
    local function remote_avatar(peer,network,resource)
        local R=assert(profile.remote_players,'missing player layout');local P,A=R.players,R.avatars
        assert(type(peer)=='string'and #peer==16 and peer:match('^%x+$'),'invalid requester peer')
        assert(type(network)=='number'and network>=1 and network<A.noNetworkId and network%1==0,'invalid requester avatar')
        local players=ptr(game+P.global);local count=u32(read(players+P.count,4),0)
        assert(count>=1 and count<=P.maxPlayers,'player roster bounds')
        local found
        for slot=0,count-1 do
            local id=hex(read(players+P.peers+slot*P.peerStride,8))
            if id==peer:lower() then
                if u32(read(players+A.lifecycle+slot*A.lifecycleStride,4),0)~=3
                    or u32(read(players+A.avatarId+slot*A.avatarIdStride,4),0)~=network then return nil end
                found=slot;break
            end
        end
        if not found then return nil end
        local manager=ptr(game+A.entities);local h=read(manager+A.mapSlots,20)
        local cap,empty,mult=u32(h,8),u32(h,12),u32(h,16)
        assert(cap>=1 and cap<=1048576 and bit.band(cap,cap-1)==0,'network map bounds')
        local rows=assert(memory.pointer(h));local start=(network*(mult%65536)+((network*math.floor(mult/65536))%65536)*65536)%4294967296
        for i=0,63 do
            local row=read(rows+bit.band(start+i,cap-1)*8,8);local key=u32(row,0)
            if key==empty then return nil end
            if key==network then
                local index=u32(row,4);assert(index<262144,'network entity index')
                local descriptor=read(manager+A.entityBase+index*A.entityStride-8,24)
                if hex(descriptor:sub(1,8))~=resource or u32(descriptor,16)~=network then return nil end
                local avatar=core:resolve(core:health_header(),u32(descriptor,8),{[resource]={class_name='avatar'}})
                if not avatar or avatar.unit~=u32(descriptor,12)or avatar.network_id~=network then return nil end
                if ptr(game+P.global)~=players or u32(read(players+P.count,4),0)~=count
                    or hex(read(players+P.peers+found*P.peerStride,8))~=peer:lower()
                    or u32(read(players+A.avatarId+found*A.avatarIdStride,4),0)~=network then return nil end
                avatar.position=core:position(avatar.unit)
                return avatar
            end
        end
        error('network map probe limit')
    end
    local function scene_context(requester,allow_peer)
        local scene=core:scene()
        if not(scene and scene.mission and scene.avatar and scene.position)then
            return nil,'需要存活潜兵和地面任务 / Need a living avatar in a mission'
        end
        local players=ptr(game+53634152)
        local count=u32(read(players+132,4),0)
        if count<1 or count>4 then return nil,'玩家列表尚未就绪 / Player roster not ready'end
        local mode=ptr(game+53634720)
        if u32(read(mode+8,4),0)~=1 then return nil,'游戏模式尚未就绪 / Mission not ready'end
        local descriptor=read(ptr(mode+56),24)
        scene.host=u32(descriptor,20)%2==1
        if not scene.host and not allow_peer then return nil,'由房主执行生成请求 / Host creation required'end
        local avatar=core:resolve(core:health_header(),scene.avatar.id,{[scene.avatar.resource]={class_name='avatar'}})
        if not avatar or avatar.unit~=scene.avatar.unit then return nil,'潜兵已死亡 / Avatar unavailable'end
        scene.faction=u32(read(ptr(game+profile.ai_global)+profile.ai_faction,4),0)
        scene.world=ptr(game+profile.world_global)
        scene.key=scene.key..'/'..tostring(scene.world)..'/'..u32(descriptor,8)
        scene.avatar.position=scene.position
        scene.player_count=count
        if requester then
            assert(scene.host,'remote creation requires host')
            local avatar=remote_avatar(requester.peer,requester.network,scene.avatar.resource)
            if not avatar then return nil,'请求者已离开、死亡或换潜兵 / Requester unavailable'end
            scene.avatar=avatar;scene.position=avatar.position;scene.requester=requester
        end
        return scene
    end
    function self:scene(requester)return scene_context(requester,false)end
    function self:peer_scene()return scene_context(nil,true)end
    function self:direction()
        local camera=core:camera();local fx,fy=camera.forward[1],camera.forward[2]
        local length=math.sqrt(fx*fx+fy*fy)
        if length<0.1 then return nil,'请平视空地 / Look toward open ground'end
        return {x=fx/length,y=fy/length}
    end
    local function identities(enemy,scene)
        local ep=record(scene.world,'EnemyPackageComponentData',enemy.hash)
        if enemy.package_source=='world_package' then
            -- Fixed defenses use a curated vanilla world package, not an EnemyPackage
            -- record. Re-prove their weapon, turret and sensor definitions before the
            -- already reviewed generic creation request. Never infer packages from paths.
            assert(ep==nil and enemy.single_player_only==true,'building package definitions changed')
            assert(#enemy.component_guards==3,'building component guard count')
            for _,guard in ipairs(enemy.component_guards)do
                local definition=record(scene.world,guard.table,enemy.hash)
                assert(definition and rawhex(definition)==guard.hex,'building definition changed: '..guard.table)
            end
        else
            assert(enemy.package_source==nil and ep and rawhex(ep)==enemy.package_record,'enemy package definitions changed')
        end
        local behavior=record(scene.world,'BehaviorComponentData',enemy.hash)
        assert(behavior and u32(behavior,0)==enemy.behavior,'enemy behavior definition changed')
        for _,unit in ipairs(enemy.required_units)do
            local r=record(scene.world,'UnitComponentData',unit.entity)
            assert(r and hex(r:sub(1,8))==unit.unit,'enemy unit definition changed')
            if unit.mount_record then
                local mount=record(scene.world,'MountComponentData',unit.entity)
                assert(mount and rawhex(mount)==unit.mount_record,'enemy mounted entities changed')
            end
        end
    end
    local function summons_ready(enemy)
        if not enemy.summons then return true end
        -- Native summon calls PickEnemy before creating its child. Loading the child's
        -- package cannot make a zero-weight roster entry eligible (Impaler crashes at
        -- game+0x9530F5 when PickEnemy returns no entry on difficulty 1..4).
        local G=assert(profile.summon_gate,'missing summon gate')
        local ai=ptr(game+profile.ai_global)
        local difficulty=u32(read(ai+G.difficulty,4),0)
        if difficulty<enemy.min_difficulty or difficulty>10 then
            return nil,('穿刺虫需 5–10 难度；当前 %d / Impaler requires difficulty 5–10; current %d'):format(difficulty,difficulty)
        end
        local descriptor=ptr(ai+G.roster)
        assert(descriptor==game+G.descriptor,'summon roster descriptor differs')
        local header=read(descriptor,12)
        assert(memory.pointer(header)==game+G.rows and u32(header,8)==G.count,'summon roster layout differs')
        assert(#enemy.summons>0 and #enemy.summons<=4,'summon dependency limit')
        for _,child in ipairs(enemy.summons)do
            assert(child.row>=0 and child.row<G.count and child.row%1==0,'summon row bounds')
            local row=read(game+G.rows+child.row*G.stride,G.stride)
            assert(u32(row,0)==tonumber(child.group,16) and hex(row:sub(9,16))==child.entity,'summon roster identity differs')
            -- This reviewed child is untagged. Refuse modified tag restrictions rather
            -- than guessing which candidates the native picker will accept.
            assert(row:sub(G.tags+1,G.tags+G.tag_bytes)==string.rep('\0',G.tag_bytes),'summon roster tags differ')
            local weight=f32(row,G.weights+4*(difficulty-1))
            if weight~=weight or weight<=0 or weight>1000 then
                return nil,'当前任务未启用穿刺虫触手 / Impaler tentacles disabled in this mission'
            end
        end
        assert(ptr(game+profile.ai_global)==ai and u32(read(ai+G.difficulty,4),0)==difficulty and ptr(ai+G.roster)==descriptor,
            'summon mission changed during check')
        local checked=enemy.id..'/'..difficulty
        if self.summon_checked~=checked then
            self.summon_checked=checked;log('summon gate ready '..enemy.id..' difficulty='..difficulty)
        end
        return true
    end
    local function package_system()
        local L=profile.loader;local instance=ptr(game+L.instanceGlobalRva)
        local h=read(instance,32);local cap=u32(h,L.refcountMap.capacity)
        assert(cap>=16 and cap<=32768 and cap%2==0,'package reference map exceeds bounded scan')
        local entries=assert(memory.pointer(h,L.refcountMap.entries),'package map missing')
        return instance,entries,cap,h
    end
    local function request(package)
        if self.held[package]then return end
        assert(self.held_count<32,'package hold limit')
        local instance,entries,cap=package_system();local used=0
        -- Bound large maps by counting one contiguous chunk at a time.
        for first=0,cap-1,1024 do
            local n=math.min(1024,cap-first);local rows=read(entries+first*16,n*16)
            for i=0,n-1 do if rows:sub(i*16+1,i*16+8)~=ZERO8 then used=used+1 end end
        end
        assert(used+1<cap*0.75,'package reference map has insufficient headroom')
        local E=profile.loader.engine
        if E.queue then
            local manager=ptr(ptr(exe+E.managerGlobalRva)+E.packageManager)
            local q=E.queue
            local head=u32(read(manager+q.head,4),0);local tail=u32(read(manager+q.tail,4),0)
            assert(head<q.capacity and tail<q.capacity,'package queue bounds')
            assert((tail-head)%q.capacity<q.capacity-4,'package load queue has insufficient headroom')
        end
        log('package request '..package)
        calls.request(game+profile.loader.requestRva,instance,unhex(package))
        self.held[package]=true;self.held_count=self.held_count+1
    end
    local function resident_packages(wanted)
        local E=profile.loader.engine
        local manager=ptr(ptr(exe+E.managerGlobalRva)+E.packageManager)
        local resources=ptr(manager+E.resourceManager)
        local count=u32(read(resources+E.listCount,4),0)
        assert(count<=2048,'engine package list exceeds spawner budget')
        if count==0 then return false end
        local list=read(ptr(resources+E.list),count*8);local found={}
        for i=0,count-1 do
            local p=assert(memory.pointer(list,i*8),'engine package missing')
            local hash=hex(read(p+E.packageId,8))
            if wanted[hash]then
                local n=u32(read(p+E.partCount,4),0)
                if n==0 or n>64 then return false end
                local parts=read(ptr(p+E.parts),n*8)
                for j=0,n-1 do
                    local part=assert(memory.pointer(parts,j*8),'package part missing')
                    if u32(read(part+E.partState,4),0)~=E.loadedState then return false end
                end
                found[hash]=true
            end
        end
        assert(u32(read(resources+E.listCount,4),0)==count,'engine package list changed')
        for hash in pairs(wanted)do if not found[hash]then return false end end
        return true
    end
    function self:prepare(enemy,scene)
        if enemy.single_player_only and (scene.player_count~=1 or scene.requester or scene.host~=true)then
            return nil,'炮台核心目前仅支持单人任务 / Turret cores currently require a solo mission'
        end
        self:prove();identities(enemy,scene)
        if enemy.min_difficulty and not enemy.summons then
            local G=assert(profile.summon_gate,'missing reviewed difficulty layout')
            local difficulty=u32(read(ptr(game+profile.ai_global)+G.difficulty,4),0)
            if difficulty<enemy.min_difficulty or difficulty>10 then
                return nil,('该单位需 %d–10 难度，当前 %d / Required difficulty %d–10; current %d'):format(
                    enemy.min_difficulty,difficulty,enemy.min_difficulty,difficulty)
            end
        end
        if enemy.single_instance then
            local invalid=u32(read(game+profile.invalid_entity,4),0)
            local world=ptr(game+profile.world_global)
            local rows=read(world+profile.entity_handles,profile.entity_slots*24)
            local wanted=unhex(enemy.hash)
            for index=0,profile.entity_slots-1 do
                local at=index*24
                if rows:sub(at+1,at+8)==wanted and u32(rows,at+8)~=invalid and bit.band(u32(rows,at+20),2)==0 then
                    return nil,'任务内已存在该单位 / An instance already exists in this mission'
                end
            end
            assert(ptr(game+profile.world_global)==world,'singleton world changed')
        end
        local allowed,why=summons_ready(enemy)
        if not allowed then return nil,why end
        local wanted={}
        for _,package in ipairs(enemy.packages)do request(package);wanted[package]=true end
        if not resident_packages(wanted)then return false,'packages loading'end
        for _,unit in ipairs(enemy.required_units)do
            if not core:unit_ready(unit.unit)then return false,'unit not resident '..unit.unit end
        end
        return true
    end
    function self:spawn(enemy,scene)
        self:prove()
        local latest,why=self:scene(scene.requester)
        if not latest then return nil,why end
        local function same(a,b)
            return a.key==b.key and a.world==b.world and a.avatar.id==b.avatar.id and a.avatar.unit==b.avatar.unit
                and a.avatar.network_id==b.avatar.network_id and a.faction==enemy.faction
                and (not enemy.single_player_only or a.host==true and a.player_count==1 and not a.requester)
        end
        if not same(latest,scene) then
            return nil,'场景已变化 / Scene changed'
        end
        local ready,detail=self:prepare(enemy,latest)
        if not ready then return nil,'资源尚未就绪 / Resources not ready: '..tostring(detail)end
        local checked,why=self:scene(scene.requester)
        if not checked or not same(checked,latest)then return nil,why or'场景已变化 / Scene changed'end
        latest=checked
        assert(read(latest.world+profile.default_context,profile.context_size)==string.rep('\0',profile.context_size),
            'world default spawn context differs')
        -- The engine's insert assumes a free descriptor. Leave ample room for mounts and future tentacles.
        local invalid=u32(read(game+profile.invalid_entity,4),0)
        local handles=read(latest.world+profile.entity_handles,profile.entity_slots*24);local free=0
        for i=0,profile.entity_slots-1 do if u32(handles,i*24+8)==invalid then free=free+1 end end
        if free<64 then return nil,'实体容量不足 / Entity capacity too low'end
        local direction,why
        if latest.requester then direction=latest.requester.direction else direction,why=self:direction()end
        if not direction then return nil,why end
        local fx,fy=direction.x,direction.y
        assert(coordinate(fx)and coordinate(fy)and math.abs(fx*fx+fy*fy-1)<.001,'invalid requested direction')
        local position={x=latest.position.x+20*fx,y=latest.position.y+20*fy,z=latest.position.z+0.2}
        -- Enemy faces the caller. Position is taken at execution, so moving during countdown is supported.
        local args=M.descriptor(enemy,latest.avatar,position,{x=-fx,y=-fy})
        assert(#self.contexts<256,'session spawn context limit')
        self.contexts[#self.contexts+1]=args.context_storage
        assert(ptr(game+profile.world_global)==latest.world,'component world changed before spawn')
        log(('native spawn begin %s target=%d requester=%s at=(%.2f,%.2f,%.2f) free_slots=%d'):format(
            enemy.id,latest.avatar.id,latest.requester and latest.requester.peer or 'local',position.x,position.y,position.z,free))
        local id=calls.spawn(game+profile.spawn_rva,args)
        log('native spawn returned '..tostring(id))
        local result={entity=id,position=position,verified=false}
        if type(id)~='number'or id<=0 or id==invalid or id>=4294967296 then return result end
        core:begin()
        local e=core:resolve(core:health_header(),id,{[enemy.hash]={class_name=enemy.id}})
        if not e or not e.owned or e.unit==0 then return result end
        local b=core:behavior_target(e,latest.avatar)
        result.unit=e.unit;result.behavior=b and b.behavior
        result.target_local=b and b.target_is_local
        result.verified=b~=nil and b.behavior==enemy.behavior and result.target_local==true
        return result
    end
    return self
end
return M
