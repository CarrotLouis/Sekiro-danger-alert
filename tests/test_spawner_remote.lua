local root=arg[1]
local R=dofile(root..'/tools/enemy_spawner/src/remote.lua')
local C=dofile(root..'/tools/enemy_spawner/src/controller.lua')
local HOST,CLIENT='0000000100000001','0000000200000002'
local next_nonce=0
local function nonce()next_nonce=next_nonce+1;return string.format('%016x',next_nonce)end
local enemy={id='tripod',hash='965eae5a51acdd4a',label='Harvester',faction=4,behavior=280}
local catalog={enemies={enemy}}
local bus={};local epoch='mission';local alive=true;local net=22;local present=true
local host={begin=function()end};local client={begin=function()end}
local function scene(mine)
    return {mission=true,host=mine,key=epoch,faction=4,player_count=2,
        avatar={id=mine and 101 or 202,unit=mine and 111 or 222,network_id=mine and 11 or net}}
end
function host:peer_scene()return scene(true)end
function client:peer_scene()if alive then return scene(false)end end
function client:direction()return {x=0,y=1}end
function host:scene(requester)
    if requester and (not present or requester.peer~=CLIENT or requester.network~=net or not alive)then return nil,'bad requester'end
    local s=scene(true);if requester then s.avatar=scene(false).avatar end;return s
end
local spawned,local_requests,client_creates=0,0,0
local last_spawned_enemy
function host:prepare()return true end
function host:spawn(e,s)
    assert(s.avatar.id==202,'a client request must target the requester, not the host')
    spawned=spawned+1;last_spawned_enemy=e;return {verified=true,entity=333,unit=444,behavior=280,target_local=true,position={x=0,y=20,z=0}}
end
local function channel(mine)
    return {snapshot=function()
        local members={[HOST]={},[CLIENT]={}};if not present then members[CLIENT]=nil end
        local values={};for p,v in pairs(bus)do if p~=mine and members[p]then values[p]=v end end
        return {key='lobby',host_peer=HOST,local_peer=mine,is_host=mine==HOST,members=members,values=values}
    end,publish=function(_,v)bus[mine]=v;return true end}
end
local host_router;local hstatus,cstatus
local controller=C.new(host,function()end,function(s)hstatus=s end,function(r,ok,why)host_router:complete(r,ok,why)end)
local old=controller.request
function controller:request(e,t,r)local_requests=local_requests+1;return old(self,e,t,r)end
host_router=R.new(host,controller,channel(HOST),catalog,function()end,function(s)hstatus=s end,nonce)
local client_router=R.new(client,{request=function()client_creates=client_creates+1 end},channel(CLIENT),catalog,function()end,function(s)cstatus=s end,nonce)
host_router:step(0);assert(R.parse(bus[HOST]).kind=='H')
assert(client_router:request(enemy,0));client_router:step(0)
assert(R.parse(bus[CLIENT]).kind=='R'and client_creates==0)
host_router:step(.5);assert(local_requests==1 and controller.pending)
controller:step(.5);assert(controller.pending.due==3.5)
host_router:step(1);assert(local_requests==1,'unchanged member property is never replayed')
controller:step(3.5);assert(spawned==1)
host_router:step(4);client_router:step(4)
assert(not client_router.pending and cstatus:find('Created ahead',1,true))
host_router:step(5);assert(spawned==1 and local_requests==1)
-- Resend a completed token after a newer rejected request: still cannot run twice.
local completed=bus[CLIENT]
bus[CLIENT]=completed:gsub(' R (%x+) (%x+) ',function(n)return ' R '..n..' '..nonce()..' 'end)
present=false;host_router:step(6);assert(local_requests==1)
present=true;host_router:step(7);assert(local_requests==2)
controller:stop('test cancellation');host_router:step(7.5)
bus[CLIENT]=completed;host_router:step(8);assert(local_requests==2)
-- Rotating the mission challenge invalidates saved client requests.
epoch='mission2';host_router:step(9);assert(local_requests==2)
bus[CLIENT]=completed;host_router:step(10);assert(local_requests==2)
-- A pending client cannot carry an intent through reinforcement or mission changes.
assert(client_router:request(enemy,10));client_router:step(10);net=23;client_router:step(11)
assert(not client_router.pending)
net=22
assert(client_router:request(enemy,16));client_router:step(16);epoch='mission3';host_router:step(17);client_router:step(17)
assert(not client_router.pending)
-- Malformed or unbounded network data never reaches the controller.
for _,v in ipairs({'','SDAES2 R '..nonce()..' '..nonce()..' 33 22 0 1000',
    'SDAES2 R '..nonce()..' '..nonce()..' 1 32767 0 1000',
    'SDAES2 R '..nonce()..' '..nonce()..' 1 22 900 900',string.rep('x',513),
    'SDAES2 H '..nonce()..' '..CLIENT..' '..nonce()..' X',
    'SDAES1 R '..nonce()..' '..nonce()..' 1 22 0 1000'})do assert(not R.parse(v))end
local h=R.parse(bus[HOST]);assert(h)
bus[CLIENT]='SDAES2 R '..h.nonce..' '..nonce()..' 16 22 0 1000'
host_router:step(18);assert(local_requests==2,'uncatalogued index is rejected')
assert(client_creates==0,'client must never enter native authoritative creation')
local old_nonce=R.parse(bus[HOST]).nonce
host_router:step(80)
assert(R.parse(bus[HOST]).nonce~=old_nonce,'idle readiness lease expires, rather than reviving a delayed property forever')
local cost_clock=0
local slow=R.new(client,{},channel(CLIENT),catalog,function()end,function()end,nonce,
    function()cost_clock=cost_clock+.03;return cost_clock end)
slow:step(0);assert(slow.next_poll==2 and slow.slow==1)
slow:step(1);assert(slow.slow==1,'slow polling backs off')
slow:step(2);slow:step(4);assert(slow.disabled,'three slow native polls stop the optional channel')
local local_after_error=0
local failing=R.new(host,{request=function()local_after_error=local_after_error+1;return true end},
    {snapshot=function()error('unreadable channel')end},catalog,function()end,function()end,nonce)
failing:step(0);failing:step(.5);failing:step(1);assert(failing.disabled)
assert(failing:request(enemy,2)and local_after_error==1,'channel failure cannot disable the original host-local action')
for i=2,22 do catalog.enemies[i]={id='added_'..i,hash=enemy.hash,label='Added '..i,faction=4,behavior=280}end
epoch='mission_added';net=22;alive=true;present=true;bus={}
host_router:step(100)
local before_added=spawned
assert(client_router:request(catalog.enemies[22],100));client_router:step(100)
assert(R.parse(bus[CLIENT]).enemy==22,'new indices must survive encoding')
host_router:step(101);controller:step(101);controller:step(104)
host_router:step(105);client_router:step(106)
assert(spawned==before_added+1 and last_spawned_enemy==catalog.enemies[22])
assert(client_router.pending==nil and client_creates==0,'new selections also stay host-authoritative')
print('PASS remote spawner: current host/requester binding, one-shot requests, ACK, stale/reordered data, scene/death/avatar cancellation and malformed input')
