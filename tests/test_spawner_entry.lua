local root=arg[1]
local f=assert(io.open(root..'/tools/enemy_spawner/src/entry.lua','rb'));local source=f:read('*a');f:close()
local run=assert(loadstring('return function(project,build_id,runtime,memory_module,profile,core_module,native_module,spawn_profile,catalog,menu_module,controller_module,channel_module,peer_profile,remote_module)\n'..source..'\nend'))()
local t=0;local frame,action;local creates,requests,polls,channel_loads,stops=0,0,0,0,0
local supported=true;local native={begin=function()end,prove=function()end}
local control={step=function()end,stop=function()stops=stops+1 end,
    request=function()error('entry must route through role-aware requester')end}
local menu={register=function()return true end,set_status=function()end,consume=function()local a=action;action=nil;return a end}
local remote={request=function(_,e)assert(e.id=='tripod');requests=requests+1 end,
    step=function()polls=polls+1 end,stop=function()stops=stops+1 end}
local memory={time=function()return t end,verify_build=function()return supported,'test mismatch'end}
local runtime={guard=function(spec)frame=spec;return {install=function()return spec end}end}
_G.CowboyBingusModLoader={log_directory=root..'/build/test_logs'}
local function load()
    return run({name='Sekiro danger alert - Enemy Spawner',version='test'},'buildtest',runtime,{new=function()return memory end},{},
        {new=function()creates=creates+1;return {}end},{new=function()return native end},{},{},
        {new=function()return menu end},{new=function(_,_,_,done)assert(type(done)=='function');return control end},
        {new=function()channel_loads=channel_loads+1;return {}end},{},
        {new=function(n,c,ch,cat,log,status,nonce,clock)
            assert(n==native and c==control and type(ch)=='table'and clock==memory.time)
            assert(#nonce()==16 and nonce()~=nonce());return remote
        end})
end
local api=load();assert(load()==api)
action={id='tripod'};frame.step();assert(creates==0 and channel_loads==0 and requests==0)
t=19;frame.step();assert(creates==0 and channel_loads==0)
t=20;action={id='tripod'};frame.step();assert(creates==1 and channel_loads==1 and requests==1 and polls==1)
t=21;frame.step();assert(requests==1 and polls==2,'one applied intent routes once')
frame.stop('test');assert(stops==2)
_G.SekiroDangerAlertEnemySpawner=nil;t=50;supported=false;local before=creates
load();t=70;action={id='tripod'};frame.step()
assert(creates==before and channel_loads==1,'wrong build never constructs the native/channel objects')
_G.SekiroDangerAlertEnemySpawner=nil
print('PASS spawner entry: duplicate load, 20s native/channel grace, build rejection, role-aware Apply routing and cleanup')
