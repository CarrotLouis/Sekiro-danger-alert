-- Diagnostic-only, current-build read-only seat/target observations. Never
-- expands the production local-target predicate or calls a native helper.
local bit=require('bit')
local M={}
function M.install(self,tools)
    local read,ptr,nullable=tools.read,tools.ptr,tools.nullable
    local u32,entity,map_index=tools.u32,tools.entity,tools.map_index
    local game,memory,profile=tools.game,tools.memory,tools.profile
    local config=assert(profile.vehicle_probe,'vehicle probe configuration missing')
    local function rawhex(s)return(s:gsub('.',function(c)return('%02x'):format(c:byte())end))end
    local function signed(s,o)local v=u32(s,o);return v>=2147483648 and v-4294967296 or v end
    local function describe(e)
        return {entity=e.id,unit=e.unit,network_id=e.network_id,resource=e.resource,owned=e.owned}
    end
    local function valid(e)
        local s=read(e.pointer,24)
        assert(s:sub(1,20)==e.identity and bit.band(u32(s,20),2)==0,'vehicle observation owner changed')
    end
    function self:local_control_state(scene)
        -- Same local-player descriptor chain as the production scene
        -- reader; preserve an unexpected controlled resource instead of guessing.
        local players=ptr(game+53634152);local counts=read(players+0x84,8)
        assert(u32(counts,0)<=4 and u32(counts,4)<=1,'diagnostic local-player counts invalid')
        local result={source='player_avatar_slot',player_count=u32(counts,0),local_count=u32(counts,4)}
        if result.local_count==0 then return result end
        local handle=u32(read(players+0x3a8,4),0);result.player_avatar_handle=handle
        if handle==0x7fff then return result end
        local world=ptr(game+54968216);local index=map_index(world+0xf22ec8,handle,1048576)
        if index then
            assert(index<262144,'controlled unit index invalid')
            local at=world+0xf32f18+index*24;local bytes=read(at,24)
            local e=entity(bytes,at)
            if scene and scene.avatar then
                assert(e.id==scene.avatar.id and e.unit==scene.avatar.unit,'player slot differs from sampled avatar')
            end
            result.controlled=describe(e)
            assert(read(at,24)==bytes and map_index(world+0xf22ec8,handle,1048576)==index,'controlled descriptor changed')
        end
        assert(read(players+0x84,8)==counts and u32(read(players+0x3a8,4),0)==handle,'controlled player changed')
        return result
    end
    function self:vehicle_state(scene,include_raw)
        assert(scene.mission and scene.avatar,'vehicle observation requires a local mission avatar')
        if not self.vehicle_probe_proven then
            assert(config.build==profile.steam_build and config.game_sha256:lower()==profile.game_sha256:lower()
                and #config.pins>=4,'vehicle probe build mismatch')
            for _,pin in ipairs(config.pins)do
                local bytes=pin.hex:gsub('..',function(x)return string.char(tonumber(x,16))end)
                assert(read(game+pin.rva,#bytes)==bytes,'vehicle layout mismatch: '..pin.label)
            end
            self.vehicle_probe_proven=true
        end
        local guards={}
        local function get(at,n)local s=read(at,n);guards[#guards+1]={at,s};return s end
        local function finish(result)
            for _,guard in ipairs(guards)do assert(read(guard[1],#guard[2])==guard[2],'vehicle state changed during read')end
            valid(scene.avatar);return result
        end
        valid(scene.avatar)
        local manager=assert(memory.pointer(get(game+config.globals.seater,8)));local h=get(manager,0x50)
        local count=u32(h,12);assert(count<=u32(h,8)and u32(h,8)<=256,'seater count invalid')
        local index=map_index(manager+0x20,scene.avatar.id,1024)
        local result={status='not_seated',avatar=describe(scene.avatar)}
        if not index then return finish(result)end
        assert(index<count,'seater index outside live rows')
        local owner=nullable(assert(memory.pointer(h,0x38))+index*8)
        assert(owner==scene.avatar.pointer,'seater avatar owner mismatch')
        get(assert(memory.pointer(h,0x38))+index*8,8)
        local row=get(assert(memory.pointer(h,0x48))+index*64,64)
        local collection=u32(row,0)
        result.seat={collection_entity=collection,transition_type=u32(row,4),role=u32(row,8),
            previous_node=signed(row,0x14),pending_node=signed(row,0x18),node=signed(row,0x1c),
            queued_node=signed(row,0x20),transitioning=row:byte(0x31)~=0,
            transition_aux=row:byte(0x32)~=0,active=row:byte(0x33)~=0}
        if include_raw then result.seat.raw_hex=rawhex(row)end
        if collection==0 or collection==0xffffffff then return finish(result)end
        result.status='seat_record'
        local collections=assert(memory.pointer(get(game+config.globals.collection,8)));local ch=get(collections,0x58)
        local live=u32(ch,12);assert(live<=u32(ch,8)and u32(ch,8)<=256,'seat collection count invalid')
        local ci=map_index(collections+0x20,collection,1024)
        if not ci then result.status='collection_unavailable';return finish(result)end
        assert(ci<live,'collection index outside live rows')
        local slot=assert(memory.pointer(ch,0x38))+ci*8
        local descriptor=assert(memory.pointer(get(slot,8)))
        local s=get(descriptor,24);local vehicle=entity(s,descriptor)
        assert(vehicle.id==collection and bit.band(u32(s,20),2)==0,'seat collection owner mismatch')
        local collection_row=get(assert(memory.pointer(ch,0x48))+ci*100,100)
        result.vehicle=describe(vehicle)
        local named=config.resources[vehicle.resource]
        result.vehicle.class_name=named and named.class_name or 'unknown_resource'
        result.collection_transition=u32(collection_row,0)
        result.stable_seat=result.seat.node>=0 and result.seat.node<16
            and result.seat.previous_node==result.seat.node and result.seat.pending_node==-1
            and result.seat.queued_node==-1 and not result.seat.transitioning and not result.seat.transition_aux
            and result.seat.active and result.collection_transition==result.seat.transition_type
        if include_raw then result.collection_raw_hex=rawhex(collection_row)end
        local ok,position=pcall(self.position,self,vehicle.unit)
        if ok then result.vehicle.position=position else result.vehicle.position_unavailable=tostring(position)end
        valid(vehicle);return finish(result)
    end
    function self:target_descriptions(h,states,scene,seated)
        local header=read(h.manager+4112,88)
        assert(u32(header,16)==h.count and memory.pointer(header,56)==h.descriptors,'target health table changed')
        local ids={};local out={}
        local function add(id)
            if type(id)=='number'and id~=0 and id~=0xffffffff then ids[id]=true end
        end
        for _,state in ipairs(states)do
            add(state.ai and state.ai.target);add(state.aim and state.aim.aim_target)
            add(state.replicated_target and state.replicated_target.target)
        end
        local count=0
        for id in pairs(ids)do
            count=count+1;assert(count<=24,'vehicle target description limit')
            local item={entity=id,relation='other_or_unresolved'}
            if id==scene.avatar.id then item=describe(scene.avatar);item.relation='local_avatar'
            elseif seated and seated.vehicle and id==seated.vehicle.entity then
                item=seated.vehicle;item.relation='current_seat_collection'
            else
                local index=map_index(h.manager+4144,id,65536)
                if index then
                    assert(index<h.count,'target health index outside live rows')
                    local slot=h.descriptors+index*8;local at=nullable(slot)
                    if at then
                        local bytes=read(at,24);local e=entity(bytes,at)
                        assert(e.id==id and bit.band(u32(bytes,20),2)==0,'target descriptor owner mismatch')
                        item=describe(e);item.relation='other_entity'
                        local named=config.resources[e.resource];item.class_name=named and named.class_name
                        assert(nullable(slot)==at and read(at,24)==bytes,'target descriptor changed')
                    end
                end
            end
            out[#out+1]=item
        end
        table.sort(out,function(a,b)return a.entity<b.entity end)
        assert(read(h.manager+4112,88)==header,'target health table changed during read')
        return out
    end
    function self:presentation_geometry()
        local S=rawget(_G,'stingray')
        if not(S and S.Gui and type(S.Gui.resolution)=='function')then return {available=false,reason='resolution unavailable'}end
        local w,h=S.Gui.resolution()
        assert(type(w)=='number'and type(h)=='number'and w>=320 and w<=16384 and h>=240 and h<=16384,'diagnostic resolution invalid')
        local anchor,why=self:head_anchor(w,h)
        return {width=w,height=h,head_projectable=anchor~=nil,anchor=anchor,reason=why}
    end
end
return M
