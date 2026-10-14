-- Read-only layouts researched in HD2Runtime by SkyeShade (see README credit).
-- Animation layer reader independently checked against the retained 25480438 capture.
-- No engine function pointer calls and no game-memory writes.
local ffi=require('ffi')
local bit=require('bit')
local M={}
local function u32(s,o)
    local a,b,c,d=s:byte(o+1,o+4);assert(d,'short read')
    return a+b*256+c*65536+d*16777216
end
local function hex(s)return (s:reverse():gsub('.',function(c)return string.format('%02x',c:byte())end)) end
M.u32=u32
-- The camera uses X=right, Y=forward, Z=up. GUI coordinates start at bottom left.
function M.project(point,camera,w,h)
    local dx,dy,dz=point.x-camera.x,point.y-camera.y,point.z-camera.z
    local function dot(v)return dx*v[1]+dy*v[2]+dz*v[3] end
    local depth=dot(camera.forward)
    if depth<=0.05 then return nil,'head behind camera' end
    local scale=math.tan(camera.fov*0.5)
    local x=dot(camera.right)/(depth*scale*(w/h))
    local y=dot(camera.up)/(depth*scale)
    if x~=x or y~=y or math.abs(x)>1 or math.abs(y)>1 then return nil,'head outside view' end
    return {x=(x+1)*w*0.5,y=(y+1)*h*0.5,depth=depth}
end
function M.new(memory,profile)
    local self={memory=memory,reads=0,bytes=0}
    local game=assert(memory.module('game.dll'));local exe=assert(memory.module(nil))
    self.game,self.exe=game,exe
    local float=ffi.new('float[1]')
    local function f32(s,o) ffi.copy(float,s:sub(o+1,o+4),4);local n=tonumber(float[0]);assert(n==n and math.abs(n)<1e8,'invalid float');return n end
    function self:begin() self.reads,self.bytes=0,0 end
    local function read(at,n)
        self.reads=self.reads+1;self.bytes=self.bytes+n
        assert(self.reads<=2500 and self.bytes<=1048576,'read budget exceeded')
        assert(at~=nil and n>0 and n<=1048576,'invalid read')
        local s=memory.read(at,n);assert(s,'unreadable state');return s
    end
    local function ptr(at)local p=memory.pointer(read(at,8));assert(p,'missing pointer');return p end
    local function nullable(at)return memory.pointer(read(at,8)) end
    local function numptr(s,o)return u32(s,o)+u32(s,o+4)*4294967296 end
    local function entity(s,p)
        return {resource=hex(s:sub(1,8)),id=u32(s,8),unit=u32(s,12),owned=bit.band(u32(s,20),1)~=0,
            identity=s:sub(1,20),pointer=p}
    end
    local function map_index(at,id,limit)
        local h=read(at,20);local cap,empty,mult=u32(h,8),u32(h,12),u32(h,16)
        if cap==0 then return nil end
        assert(cap<=limit and bit.band(cap,cap-1)==0,'bad entity map')
        local rows=assert(memory.pointer(h))
        local start=(id*(mult%65536)+((id*math.floor(mult/65536))%65536)*65536)%4294967296
        for k=0,63 do
            local b=read(rows+bit.band(start+k,cap-1)*8,8)
            if u32(b,0)==id then return u32(b,4) end
            if u32(b,0)==empty then return nil end
        end
        error('entity map probe limit')
    end
    function self:scene()
        local context=ptr(game+53633856)
        local mode=u32(read(context+705052,4),0)
        local result={mode=mode,mission=mode==4,key=tostring(context)}
        if mode~=4 and mode~=3 then return result end
        local players=ptr(game+53634152);local c=read(players+0x84,8)
        assert(u32(c,0)<=4 and u32(c,4)<=1,'player count invalid')
        if u32(c,4)==0 then return result end
        local handle=u32(read(players+0x3a8,4),0)
        if handle==0x7fff then return result end
        local entities=ptr(game+54968216)
        local index=map_index(entities+0xf22ec8,handle,1048576)
        if index and index<262144 then
            local at=entities+0xf32f18+index*24
            local e=entity(read(at,24),at)
            if e.resource==profile.avatar_resource and e.owned then
                result.avatar=e;result.position=self:position(e.unit)
            end
        end
        result.key=result.key..'/'..tostring(entities)
        return result
    end
    function self:ui_world()
        local context=ptr(game+53633856);local target=memory.address(ptr(context+4376))
        local app=ptr(exe+27329032);local count=u32(read(app+1424,4),0)
        assert(count>0 and count<=64,'world list invalid')
        local rows=read(ptr(app+1432),count*8)
        local S=assert(rawget(_G,'stingray'));local list=S.Application.worlds()
        assert(type(list)=='table' and #list==count,'world list changed')
        for i=0,count-1 do if numptr(rows,i*8)==target then return list[i+1] end end
        error('UI world unavailable')
    end
    local function unit_object(unit)
        assert(unit>0 and unit<4294967296,'invalid unit')
        local index,generation=unit%4194304,math.floor(unit/4194304)%256
        local registry=ptr(exe+27328752);local count=u32(read(registry+152,4),0)
        assert(count<=4194304 and index<count,'unit index invalid')
        local generations=ptr(registry+160)
        assert(read(generations+index,1):byte()==generation,'unit expired')
        local object=ptr(ptr(registry+136)+index*8)
        assert(u32(read(object+8,4),0)==unit,'unit identity changed')
        return object
    end
    function self:position(unit)
        local object=unit_object(unit);local vt=ptr(object);local accessor=ptr(vt+0xe8)
        assert(accessor==exe+2873456 and read(accessor,5)=='\072\141\065\096\195','position accessor mismatch')
        local s=read(ptr(object+136)+48,12)
        return {x=f32(s,0),y=f32(s,4),z=f32(s,8)}
    end
    function self:head_position(unit)
        local object=unit_object(unit);local accessor=ptr(ptr(object)+0xe8)
        assert(accessor==exe+2873456 and read(accessor,5)=='\072\141\065\096\195','head scene graph mismatch')
        -- unit_node reads the count at SceneGraph+0x10 and name IDs at +0x40.
        -- SceneGraph is object+0x60; world poses are at SceneGraph+0x28.
        local count=u32(read(object+0x70,4),0)
        assert(count>0 and count<=2048,'head node count invalid')
        local names=read(ptr(object+0xa0),count*4)
        for index=0,count-1 do
            if u32(names,index*4)==0x8c5570c9 then -- StringId32("head")
                local s=read(ptr(object+0x88)+index*64+48,12)
                return {x=f32(s,0),y=f32(s,4),z=f32(s,8),node=index}
            end
        end
        return nil,'local avatar has no head node'
    end
    function self:camera()
        local manager=ptr(game+54973792);local eye=ptr(manager)
        local pose=read(manager+12,64)
        local fov=f32(read(eye+0x34,4),0)
        assert(fov>0.05 and fov<3.10,'camera field of view invalid')
        local function axis(offset)
            local v={f32(pose,offset),f32(pose,offset+4),f32(pose,offset+8)}
            local length=math.sqrt(v[1]^2+v[2]^2+v[3]^2)
            assert(length>0.95 and length<1.05,'camera basis invalid')
            for i=1,3 do v[i]=v[i]/length end
            return v
        end
        local result={right=axis(0),forward=axis(16),up=axis(32),
            x=f32(pose,48),y=f32(pose,52),z=f32(pose,56),fov=fov}
        assert(ptr(manager)==eye,'camera changed during read')
        return result
    end
    function self:head_anchor(w,h)
        -- Avatar/camera transitions are normal: hide the frame instead of guessing a location.
        local ok,anchor,why=pcall(function()
            local scene=self:scene()
            if not scene.avatar then return nil,'local avatar unavailable' end
            local head,reason=self:head_position(scene.avatar.unit)
            if not head then return nil,reason end
            local projected,message=M.project(head,self:camera(),w,h)
            if projected then projected.node=head.node;projected.unit=scene.avatar.unit end
            return projected,message
        end)
        if not ok then return nil,'head read unavailable: '..tostring(anchor) end
        return anchor,why
    end
    function self:animation(unit)
        local object=unit_object(unit);local accessor=ptr(ptr(object)+0x1b0)
        local rva=memory.distance(accessor,exe)
        assert(rva>=4096 and rva<0x2000000,'animation accessor outside image')
        assert(read(accessor,8)=='\072\139\129\120\001\000\000\195','animation accessor mismatch')
        local machine=ptr(object+0x178);local resource=ptr(machine+0x28)
        local h=read(resource,12);local layers=u32(h,4);local group_offset=u32(h,8)
        assert(layers>0 and layers<=32 and group_offset<0x2000000,'animation header invalid')
        local current=read(ptr(machine+0x50),layers*8)
        local groups=resource+group_offset;local tablebytes=read(groups,4+layers*4)
        assert(u32(tablebytes,0)==layers,'animation groups invalid')
        local out={}
        for i=0,layers-1 do
            local state=memory.pointer(current,i*8)
            if state then
                local relative=memory.distance(state,resource)
                assert(relative>=0 and relative<0x2000000,'animation state outside resource')
                local off=u32(tablebytes,4+i*4);assert(off<0x2000000,'animation group offset invalid')
                local group=groups+off;local states=u32(read(group+8,4),0)
                assert(states<=2048,'too many animation states')
                local indices=states>0 and read(group+12,states*4) or ''
                local index=-1;local delta=memory.distance(state,group)
                for j=0,states-1 do if u32(indices,j*4)==delta then index=j;break end end
                assert(index>=0,'animation state not in its group')
                out[#out+1]={layer=i,index=index,hash=hex(read(state,8))}
            else out[#out+1]={layer=i,index=-1,hash='none'} end
        end
        assert(read(ptr(machine+0x50),layers*8)==current,'animation changed during read')
        return out
    end
    function self:health_header()
        local manager=ptr(game+53634696);local h=read(manager+4112,88)
        local cap,live=u32(h,0),u32(h,16)
        assert(cap>0 and cap<=4096 and live<=cap,'health counts invalid')
        return {manager=manager,count=live,descriptors=assert(memory.pointer(h,56)),records=assert(memory.pointer(h,72))}
    end
    function self:discover(header,start,limit,resources)
        local out={};local last=math.min(header.count,start+limit)
        if last<=start then return out,0 end
        local rows=read(header.descriptors+start*8,(last-start)*8)
        for i=0,last-start-1 do
            local at=memory.pointer(rows,i*8)
            if at then
                local s=read(at,24)
                local hash=hex(s:sub(1,8));local named=resources and resources[hash]
                if named or not resources and hash==profile.crusher_resource then
                    local e=entity(s,at);e.class_name=named and named.class_name;out[#out+1]=e
                end
            end
        end
        return out,last>=header.count and 0 or last
    end
    function self:resolve(header,id,resources)
        local index=map_index(header.manager+4144,id,65536)
        if not index or index>=header.count then return nil end
        local at=nullable(header.descriptors+index*8);if not at then return nil end
        local e=entity(read(at,24),at)
        local named=resources and resources[e.resource]
        if e.id~=id or (resources and not named) or (not resources and e.resource~=profile.crusher_resource) then return nil end
        e.class_name=named and named.class_name
        local health=read(header.records+index*440,440)
        e.health=u32(health,20);e.life=u32(health,412)
        if e.health==0 or e.health>=2147483648 then return nil end
        return e
    end
    function self:abilities(targets)
        local manager=ptr(game+53634624);local h=read(manager+8,56)
        local cap,count=u32(h,0),u32(h,4)
        assert(cap<=8192 and count<=cap,'ability counts invalid')
        if count==0 then return {} end
        local owners=read(assert(memory.pointer(h,40)),count*8)
        local rows=assert(memory.pointer(h,48));local out={}
        for i=0,count-1 do
            local e=targets[numptr(owners,i*8)]
            if e then
                assert(read(e.pointer,20)==e.identity,'ability owner changed')
                local row=read(rows+i*224,224)
                if row:byte(17)~=0 then
                    local item={entity=e.id,id=u32(row,0),time=f32(row,8),speed=f32(row,12),slot=i}
                    out[#out+1]=item
                end
            end
        end
        assert(read(manager+8,56)==h,'ability table changed')
        return out
    end
    -- AI interest and aiming are NOT proof of a committed attack; the detector
    -- also requires a resource-specific active ability inside its warning window.
    -- Targeting/Behavior offsets and instruction pins: HD2Runtime by SkyeShade,
    -- independently re-decoded from the retained 25480438 module sections.
    function self:verify_targeting()
        if not self.targeting_proven then
            assert(profile.targeting_pins and #profile.targeting_pins>0,'targeting pins missing')
            for _,pin in ipairs(profile.targeting_pins) do
                assert(read(game+pin.rva,#pin.bytes)==pin.bytes,'targeting layout mismatch: '..pin.label)
            end
            self.targeting_proven=true
        end
    end
    function self:targeting_header()
        self:verify_targeting()
        local manager=ptr(game+0x3326d30);local h=read(manager+0x140,72)
        local count=u32(h,0);assert(count<=4096,'targeting count invalid')
        return {manager=manager,count=count,raw=h,descriptors=memory.pointer(h,0x28),
            records=memory.pointer(h,0x38),network=memory.pointer(h,0x40)}
    end
    function self:targeting_discover(h,start,limit)
        local out={};local last=math.min(h.count,start+limit)
        if last<=start then return out,0 end
        local rows=read(assert(h.descriptors)+start*8,(last-start)*8)
        for i=0,last-start-1 do
            local at=memory.pointer(rows,i*8)
            if at then
                local s=read(at,24);local name=profile.targeting_resources[hex(s:sub(1,8))]
                if name and bit.band(u32(s,20),2)==0 then
                    local e=entity(s,at);e.class_name=name;out[#out+1]=e
                end
            end
        end
        assert(read(h.manager+0x140,72)==h.raw,'targeting table changed')
        return out,last>=h.count and 0 or last
    end
    function self:targeting_resolve(h,id)
        local index=map_index(h.manager+0x150,id,65536)
        if not index or index>=h.count then return nil end
        local at=nullable(assert(h.descriptors)+index*8);if not at then return nil end
        local s=read(at,24);local e=entity(s,at)
        e.class_name=profile.targeting_resources[e.resource]
        if e.id~=id or not e.class_name or bit.band(u32(s,20),2)~=0 then return nil end
        e.targeting_index=index
        return e
    end
    function self:targeting_state(h,e,avatar)
        local i=e.targeting_index;assert(i and i<h.count,'targeting index invalid')
        assert(nullable(h.descriptors+i*8)==e.pointer and read(e.pointer,20)==e.identity,'targeting owner changed')
        local row=read(assert(h.records)+i*0xd0,0x20)
        local net=read(assert(h.network)+i*0x18,0x18)
        local target=u32(row,0);local network_target=u32(net,0);local resolved_network_target=u32(row,4)
        local position_only=net:byte(0x15)~=0
        local result={entity=e.id,unit=e.unit,class_name=e.class_name,distance=e.distance,owned=e.owned,
            aim_target=target,network_target=network_target,network_flags=u32(net,0x10),
            resolved_network_target=resolved_network_target,network_target_consistent=resolved_network_target==network_target,
            target_point={x=f32(row,8),y=f32(row,12),z=f32(row,16)},
            position_only=position_only,aim_point={x=f32(row,0x14),y=f32(row,0x18),z=f32(row,0x1c)},
            aim_target_is_local=target==avatar.id,
            entity_target_valid=not position_only and network_target~=0x7fff and target~=0,ai_available=false}
        result.ai=self:behavior_target(e,avatar)
        result.ai_available=result.ai~=nil
        assert(read(h.manager+0x140,72)==h.raw and nullable(h.descriptors+i*8)==e.pointer
            and read(e.pointer,20)==e.identity,'targeting identity changed')
        return result
    end
    function self:behavior_target(e,avatar,include_raw)
        self:verify_targeting()
        assert(read(e.pointer,24):sub(1,20)==e.identity,'AI owner changed')
        -- A peer's cached AI is not authoritative. Return observations for diagnosis;
        -- the detector requires the fresh descriptor's ownership flag as well.
        local mgr=ptr(game+0x3326740);local bh=read(mgr+0x40,40)
        local index=map_index(mgr+0x40,e.id,65536)
        local result
        if index and index<4096 then
            local handles=assert(memory.pointer(bh,0x18));local records=assert(memory.pointer(bh,0x20))
            if nullable(handles+index*8)==e.pointer then
                local factory=profile.expanded and e.resource==profile.expanded.factory.resource
                local ai=read(records+index*0x1f8,(include_raw or factory) and 0x1f8 or 0x80)
                result={behavior=u32(ai,0),stage=u32(ai,8),pending_stage=u32(ai,12),
                    target=u32(ai,0x18),has_target=ai:byte(0x79)~=0,flags=u32(ai,0x60)}
                result.target_is_local=result.target==avatar.id and result.has_target
                result.tracks_entity=bit.band(result.flags,1)~=0
                if factory then
                    self:verify_expanded()
                    local F=profile.expanded.factory
                    result.preparation_started=numptr(ai,F.stage_start_offset)
                    result.preparation_ready=bit.band(u32(ai,F.ready_offset),F.ready_mask)~=0
                    local clock=read(ptr(game+F.clock_global)+F.clock_offset,8)
                    result.native_time=numptr(clock,0)
                    assert(result.native_time<9007199254740992 and result.preparation_started<9007199254740992,
                        'factory clock exceeds exact integer range')
                end
                if include_raw then result.raw_hex=(ai:gsub('.',function(c)return string.format('%02x',c:byte())end)) end
                assert(read(mgr+0x40,40)==bh and nullable(handles+index*8)==e.pointer,'AI table changed')
            end
        end
        local descriptor=read(e.pointer,24)
        assert(descriptor:sub(1,20)==e.identity and (bit.band(u32(descriptor,20),1)~=0)==e.owned
            and bit.band(u32(descriptor,20),2)==0,'AI identity or ownership changed')
        return result
    end
    -- Read-only weapon input observations for diagnostics; never call a trigger.
    function self:weapon_inputs(e,include_raw)
        if not self.combat_proven then
            assert(profile.combat_pins and #profile.combat_pins>0,'combat pins missing')
            for _,pin in ipairs(profile.combat_pins) do
                assert(read(game+pin.rva,#pin.bytes)==pin.bytes,'combat layout mismatch: '..pin.label)
            end
            self.combat_proven=true
        end
        local mgr=ptr(game+0x3326420);local header=read(mgr+0x30,24)
        local index=map_index(mgr+0x30,e.id,65536)
        if not index or index>=4096 then return nil end
        local handles=ptr(mgr+0x48)
        if nullable(handles+index*8)~=e.pointer then return nil end
        assert(read(e.pointer,20)==e.identity,'weapon input owner changed')
        local row=read(ptr(mgr+0x60)+index*0x1d0,0x1d0)
        local inputs=read(ptr(mgr+0x58)+index*32,32)
        local mask=u32(read(ptr(mgr+0x68)+index*4,4),0)
        local result={replicated_input_bits=mask,local_input_bytes={},slot_head_words={}}
        for i=0,4 do
            result.local_input_bytes[i+1]=inputs:byte(i+1)
            result.slot_head_words[i+1]={u32(row,i*0x50),u32(row,i*0x50+4)}
        end
        if include_raw then result.raw_hex=(row:gsub('.',function(c)return string.format('%02x',c:byte())end)) end
        assert(read(mgr+0x30,24)==header and nullable(handles+index*8)==e.pointer
            and read(e.pointer,20)==e.identity,'weapon input identity changed')
        return result
    end
    function self:combat_state(h,e,avatar,include_raw)
        local result={entity=e.id,unit=e.unit,resource=e.resource,class_name=e.class_name,
            distance=e.distance,owned=e.owned,ai=self:behavior_target(e,avatar,true),
            weapon_inputs=self:weapon_inputs(e,include_raw)}
        local index=map_index(h.manager+0x150,e.id,65536)
        if index and index<h.count and nullable(assert(h.descriptors)+index*8)==e.pointer then
            e.targeting_index=index
            result.aim=self:targeting_state(h,e,avatar)
        end
        -- Root facing is diagnostic only: it may differ from an animated barrel.
        local object=unit_object(e.unit);local pose=read(ptr(object+136),64)
        result.root_forward={x=f32(pose,16),y=f32(pose,20),z=f32(pose,24)}
        return result
    end
    -- Scan the active ability table first, without reserving permanent enemy slots
    -- or reading positions. Limits bound work per poll; the cursor resumes at the
    -- next unprocessed row, including when many attacks start simultaneously.
    function self:attack_candidates(cursor)
        self:verify_targeting()
        self:verify_expanded()
        if not self.attack_proven then
            assert(profile.attack_pins and #profile.attack_pins>0,'attack pins missing')
            for _,pin in ipairs(profile.attack_pins) do
                assert(read(game+pin.rva,#pin.bytes)==pin.bytes,'attack layout mismatch: '..pin.label)
            end
            self.attack_proven=true
        end
        local manager=ptr(game+53634624);local h=read(manager+8,56)
        local cap,count=u32(h,0),u32(h,4)
        assert(cap<=8192 and count<=cap,'ability counts invalid')
        local stats={ability_records=count,scan_limit=2048,match_limit=32,scanned=0,matched=0}
        if count==0 then stats.cursor=0;return {},{},stats end
        cursor=cursor or 0;if cursor>=count then cursor=0 end
        local last=math.min(count,cursor+stats.scan_limit)
        local owners_at=assert(memory.pointer(h,40));local rows_at=assert(memory.pointer(h,48))
        local owners=read(owners_at+cursor*8,(last-cursor)*8)
        local rows=read(rows_at+cursor*224,(last-cursor)*224)
        local active,selected,seen={},{},{}
        local next_row=last
        for i=0,last-cursor-1 do
            stats.scanned=stats.scanned+1
            local offset=i*224;local id=u32(rows,offset)
            if rows:byte(offset+17)~=0 and (profile.attack_states[id] or profile.ignored_stomps[id]
                or id==profile.cannon.ability or profile.expanded and profile.expanded.ids[id]) then
                local at=memory.pointer(owners,i*8)
                if at then
                    local descriptor=read(at,24);local e=entity(descriptor,at)
                    local crusher=e.resource==profile.crusher_resource
                    local cannon=e.resource==profile.cannon.resource and id==profile.cannon.ability
                    local rule=profile.expanded and profile.expanded.resources[e.resource]
                    local expanded=rule and (rule.abilities[id] or rule.excluded[id])
                    if bit.band(u32(descriptor,20),2)==0 and ((crusher and id~=profile.cannon.ability) or cannon or expanded) then
                        assert(nullable(owners_at+(cursor+i)*8)==at and read(rows_at+(cursor+i)*224,20)
                            ==rows:sub(offset+1,offset+20),'attack row changed')
                        e.class_name=crusher and 'crusher' or cannon and 'turret_heavycannon' or profile.health_resources[e.resource].class_name
                        if not seen[e.id] then selected[#selected+1]=e;seen[e.id]=true end
                        active[#active+1]={entity=e.id,id=id,time=f32(rows,offset+8),speed=f32(rows,offset+12),
                            paused=rows:byte(offset+18)~=0,slot=cursor+i}
                        stats.matched=stats.matched+1
                        if stats.matched>=stats.match_limit then next_row=cursor+i+1;break end
                    end
                end
            end
        end
        assert(read(manager+8,56)==h,'ability table changed')
        stats.cursor=next_row>=count and 0 or next_row
        stats.remaining=count-next_row;stats.selected=#selected
        return active,selected,stats
    end
    function self:verify_expanded()
        if not profile.expanded or self.expanded_proven then return end
        assert(#profile.expanded.pins>0,'expanded attack pins missing')
        for _,pin in ipairs(profile.expanded.pins)do
            assert(read(game+pin.rva,#pin.bytes)==pin.bytes,'expanded attack layout mismatch: '..pin.label)
        end
        self.expanded_proven=true
    end
    -- Factory cannons have no active Ability. Scan the proven contiguous world
    -- descriptors without positions, distance tests or permanent observation slots.
    -- A per-batch match limit resumes on the next descriptor, preserving fairness.
    function self:factory_candidates(cursor)
        if not profile.expanded then return {},{cursor=0,scanned=0,matched=0} end
        self:verify_expanded()
        local F=profile.expanded.factory;local world=ptr(game+F.world_global)
        local invalid=u32(read(game+F.invalid_entity_global,4),0)
        assert(F.slots==2048 and F.stride==24,'factory descriptor scan layout differs')
        if not self.factory_resource_bytes then
            local bytes={};for index=15,1,-2 do bytes[#bytes+1]=string.char(tonumber(F.resource:sub(index,index+1),16))end
            self.factory_resource_bytes=table.concat(bytes)
        end
        local rows=read(world+F.descriptors_offset,F.slots*F.stride)
        cursor=cursor or 0;if cursor>=F.slots then cursor=0 end
        assert(cursor>=0 and cursor%1==0,'factory descriptor cursor invalid')
        local out={};local stats={scanned=0,matched=0,match_limit=8};local next_row=F.slots
        for index=cursor,F.slots-1 do
            stats.scanned=stats.scanned+1
            local offset=index*F.stride
            if rows:sub(offset+1,offset+8)==self.factory_resource_bytes and u32(rows,offset+8)~=invalid and bit.band(u32(rows,offset+20),2)==0 then
                local at=world+F.descriptors_offset+offset
                local e=entity(rows:sub(offset+1,offset+24),at)
                assert(read(at,24)==rows:sub(offset+1,offset+24),'factory descriptor changed')
                e.class_name=profile.health_resources[e.resource].class_name
                out[#out+1]=e;stats.matched=stats.matched+1
                if #out>=stats.match_limit then next_row=index+1;break end
            end
        end
        assert(ptr(game+F.world_global)==world,'factory descriptor world changed')
        stats.cursor=next_row>=F.slots and 0 or next_row;stats.remaining=F.slots-next_row
        return out,stats
    end
    local function resource(kind,name)
        local app=ptr(exe+27328968);local manager=ptr(app+1016)
        local function find(entries,capacity,buckets,stride,nextoff,key)
            assert(buckets>0 and buckets<=capacity and capacity<=1048576,'resource map invalid')
            local index=tonumber(key:sub(1,8),16)%buckets
            for _=1,128 do
                assert(index<capacity,'resource chain invalid')
                local at=entries+index*stride;local row=read(at,stride);local nxt=u32(row,nextoff)
                if nxt==4294967294 then return nil end
                if hex(row:sub(1,8))==key then return at,row end
                if nxt==2147483647 then return nil end
                index=nxt
            end
            error('resource chain budget')
        end
        local cap=u32(read(manager+744,4),0);local buckets=u32(read(manager+772,4),0)
        assert(cap<=4096,'resource type capacity invalid')
        local at,row=find(ptr(manager+752),cap,buckets,208,200,kind)
        if not at then return nil end
        local entry,n=find(assert(memory.pointer(row,40)),u32(row,32),u32(row,60),24,16,name)
        if not entry then return nil end
        local slot=u32(n,8);if slot==4211011825 then return nil end
        assert(slot<1048576,'resource slot invalid')
        return nullable(assert(memory.pointer(row,16))+slot*160)
    end
    function self:image_ready(hash)
        local texture=resource('cd4238c6a0c69e32',hash)
        local at=resource('eac0b497876adedf',hash)
        if not texture or not at then return false end
        local m=read(at,160);local object=assert(memory.pointer(m,32),'material not online')
        assert(u32(m,0)==0x120 and u32(m,4)==1 and u32(m,64)==1 and u32(m,128)==0x3461ff0d,
            'material format differs')
        assert(hex(m:sub(141,148))==hash,'material texture name differs')
        assert(memory.pointer(m,48)==at+136 and memory.pointer(m,56)==at+140,'material fixup differs')
        local o=read(object,72)
        assert(u32(o,0)==3643441971 and memory.pointer(o,16)==at+24 and u32(o,48)==0x3461ff0d
            and hex(o:sub(57,64))==hash,'material object differs')
        return true
    end
    -- Read-only seam used by the separate Enemy Spawner after complete package residency.
    -- MurmurHash64A("unit"); this does not spawn or load anything.
    function self:unit_ready(hash)
        return resource('e0a48d0be9a7453f',hash)~=nil
    end
    return self
end
return M
