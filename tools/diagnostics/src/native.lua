-- Development-only observations. This module is never included in release ZIPs.
-- Read-only layouts researched in HD2Runtime by SkyeShade (see CREDITS.txt).
local bit=require('bit')
local M={}
function M.install(self,tools)
    local read,ptr,nullable,numptr=tools.read,tools.ptr,tools.nullable,tools.numptr
    local u32,f32,hex,entity=tools.u32,tools.f32,tools.hex,tools.entity
    local map_index,unit_object=tools.map_index,tools.unit_object
    local game,exe,memory,profile=tools.game,tools.exe,tools.memory,tools.profile
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
    function self:abilities(targets,include_inactive)
        local manager=ptr(game+53634624);local h=read(manager+8,56)
        local count,prefix=u32(h,0),u32(h,4)
        assert(count<=8192 and prefix<=count,'ability counts invalid')
        if count==0 then return {} end
        local owners=read(assert(memory.pointer(h,40)),count*8)
        local rows=assert(memory.pointer(h,48));local out={}
        for i=0,count-1 do
            local e=targets[numptr(owners,i*8)]
            if e then
                assert(read(e.pointer,20)==e.identity,'ability owner changed')
                local row=read(rows+i*224,224)
                if include_inactive or row:byte(17)~=0 then
                    local item={entity=e.id,id=u32(row,0),time=f32(row,8),speed=f32(row,12),slot=i,
                        active=row:byte(17)~=0,paused=row:byte(18)~=0}
                    out[#out+1]=item
                end
            end
        end
        assert(read(manager+8,56)==h,'ability table changed')
        return out,{total=count,update_prefix=prefix}
    end
    function self:targeting_header()
        return self:aiming_header()
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
        local ok,ai=pcall(self.behavior_target,self,e,avatar)
        if ok then result.ai=ai else result.ai_unavailable=tostring(ai)end
        result.ai_available=result.ai~=nil
        assert(read(h.manager+0x140,72)==h.raw and nullable(h.descriptors+i*8)==e.pointer
            and read(e.pointer,20)==e.identity,'targeting identity changed')
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
    -- Research channels only. These bytes are not a new attack/target rule:
    -- a projectile timer is not proof that a shot has been committed, and a
    -- flying controller's last network record is not an identified player.
    local function detail_row(e,global,map,handles,records,stride,count_offset)
        self:verify_peer()
        assert(profile.combat_pins and #profile.combat_pins>0,'combat pins missing')
        if not self.details_proven then
            for _,pin in ipairs(profile.combat_pins)do
                assert(read(game+pin.rva,#pin.bytes)==pin.bytes,'research layout mismatch: '..pin.label)
            end
            self.details_proven=true
        end
        local function owner()
            local s=read(e.pointer,24)
            return s:sub(1,20)==e.identity and(bit.band(u32(s,20),1)~=0)==e.owned
                and bit.band(u32(s,20),2)==0
        end
        assert(owner(),'research owner changed')
        local mgr=ptr(game+global);local header=read(mgr+map,records-map+8)
        local index=map_index(mgr+map,e.id,65536)
        if not index or index>=4096 then return end
        if count_offset then
            local count=u32(read(mgr+count_offset,4),0)
            assert(count<=4096,'research count invalid')
            if index>=count then return end
        end
        local owners=ptr(mgr+handles)
        if nullable(owners+index*8)~=e.pointer then return end
        local at=ptr(mgr+records)+index*stride
        local row=read(at,stride)
        assert(read(mgr+map,#header)==header and nullable(owners+index*8)==e.pointer
            and read(at,stride)==row and ptr(game+global)==mgr and owner(),'research record changed')
        return row,index
    end
    local function rawhex(row)return (row:gsub('.',function(c)return string.format('%02x',c:byte())end))end
    function self:projectile_state(e)
        if e.resource~='843d18d4b5512b63'then return end
        local row,index=detail_row(e,0x33266d8,0x50,0x68,0x78,0xa8)
        if not row then return end
        return {index=index,instance_stride=0xa8,fire_gate_timer=f32(row,8),shot_interval=f32(row,12),
            state_bytes={row:byte(1,3)},effect_bytes={row:byte(0x11,0x13)},raw_hex=rawhex(row),
            interpretation='diagnostic_only_not_committed_shot'}
    end
    function self:flight_network_state(e)
        if e.resource~='960b48a421a3faaa'then return end
        local row,index=detail_row(e,0x3326de0,0x20,0x38,0x48,0x1c,8)
        if not row then return end
        local words={};for offset=0,0x18,4 do words[#words+1]=u32(row,offset)end
        return {index=index,record_stride=0x1c,words=words,raw_hex=rawhex(row),
            interpretation='diagnostic_only_not_verified_target'}
    end
    function self:behavior_network_state(e)
        if e.resource~='843d18d4b5512b63'and e.resource~='960b48a421a3faaa'then return end
        local row,index=detail_row(e,0x3326740,0x40,0x58,0x68,0xa0)
        if not row then return end
        return {index=index,stage=u32(row,0),behavior=u32(row,4),raw_hex=rawhex(row),
            interpretation=e.owned and 'last_encoded_network_state' or 'received_network_state'}
    end
    function self:combat_state(h,e,avatar,include_raw)
        local result={entity=e.id,unit=e.unit,resource=e.resource,class_name=e.class_name,
            distance=e.distance,owned=e.owned,network_id=e.network_id,ai_authoritative=e.owned==true,
            observation_errors={}}
        local function optional(key,fn)
            local ok,value=pcall(fn)
            if ok then result[key]=value else result.observation_errors[key]=tostring(value)end
        end
        optional('ai',function()return self:behavior_target(e,avatar,include_raw)end)
        optional('weapon_inputs',function()return self:weapon_inputs(e,include_raw)end)
        if e.resource=='843d18d4b5512b63'then
            optional('projectile_state',function()return self:projectile_state(e)end)
        elseif e.resource=='960b48a421a3faaa'then
            optional('flight_network_state',function()return self:flight_network_state(e)end)
        end
        if e.resource=='843d18d4b5512b63'or e.resource=='960b48a421a3faaa'then
            optional('behavior_network_state',function()return self:behavior_network_state(e)end)
        end
        if not e.owned then
            optional('replicated_target',function()return self:replicated_target(e,avatar)end)
            optional('replicated_behavior',function()return self:replicated_behavior(e)end)
        end
        if h then optional('aim',function()
            local index=map_index(h.manager+0x150,e.id,65536)
            if index and index<h.count and nullable(assert(h.descriptors)+index*8)==e.pointer then
                e.targeting_index=index
                return self:targeting_state(h,e,avatar)
            end
        end)else result.observation_errors.aim='targeting header unavailable'end
        -- Root facing is diagnostic only: it may differ from an animated barrel.
        optional('root_forward',function()
            local object=unit_object(e.unit);local pose=read(ptr(object+136),64)
            return {x=f32(pose,16),y=f32(pose,20),z=f32(pose,24)}
        end)
        assert(self.reads<=2500 and self.bytes<=1048576,'diagnostic read budget exceeded')
        return result
    end
    local behavior_target=self.behavior_target
    function self:behavior_target(e,avatar,include_raw)
        local result=behavior_target(self,e,avatar)
        if include_raw and result then
            local mgr=ptr(game+0x3326740);local bh=read(mgr+0x40,40)
            local index=map_index(mgr+0x40,e.id,65536)
            assert(index and index<4096,'diagnostic AI index changed')
            local handles=assert(memory.pointer(bh,0x18));local records=assert(memory.pointer(bh,0x20))
            assert(nullable(handles+index*8)==e.pointer,'diagnostic AI owner changed')
            local raw=read(records+index*0x1f8,0x1f8)
            assert(u32(raw,0)==result.behavior and u32(raw,8)==result.stage
                and u32(raw,0x18)==result.target and u32(raw,0x60)==result.flags
                and (raw:byte(0x79)~=0)==result.has_target,'diagnostic AI sample changed')
            result.raw_hex=(raw:gsub('.',function(c)return string.format('%02x',c:byte())end))
            assert(read(mgr+0x40,40)==bh and nullable(handles+index*8)==e.pointer
                and read(e.pointer,20)==e.identity,'diagnostic AI identity changed')
        end
        return result
    end
    if M.vehicle then M.vehicle.install(self,tools)end
end
return M
