local root=arg[1];local calls={};local temp=17;local world={};local worlds={world}
local function vec(...)temp=temp+16;return {...}end
_G.stingray={
 Application={worlds=function()return worlds end},
 Script={temp_count=function()return temp end,set_temp_count=function(n)temp=n end},
 Vector2=setmetatable({},{__call=function(_,...)return vec(...)end}),
 Vector3=setmetatable({},{__call=function(_,...)return vec(...)end}),Color=vec,
 Quaternion={from_elements=vec},Material={set_vector4=function()calls.colours=(calls.colours or 0)+1 end},
 World={create_screen_gui=function(w)assert(w==world);calls.create=(calls.create or 0)+1;return {}end,
        destroy_gui=function(w)assert(w==world);calls.close=(calls.close or 0)+1 end},
 Gui={resolution=function()return 1920,1080 end,
      bitmap=function(gui,name,p,s,c)assert(c[1]==255 and p[3]==950);calls.bitmap=(calls.bitmap or 0)+1;return 42 end,
      update_bitmap=function(gui,id,name)assert(id==42);calls.name=name end,
      material=function()return {}end},
}
local n={ui_world=function()return world end,image_ready=function()return true end}
local assets={fps=60,frames={{name='frame0',hash='a'},{name='frame1',hash='b'}},colours={{1,1,0,0},{1,1,1,1},{0,0,0,0},{0,0,0,0}}}
local o=dofile(root..'/src/overlay.lua').new(n,assets,function()end)
assert(not o:warmup());assert(o:warmup());assert(o:play(1))
o:step(1);assert(temp==17 and calls.create==1 and calls.bitmap==1)
o:step(1.02);assert(temp==17 and calls.name=='frame1' and calls.colours==8)
o:step(2);assert(calls.close==1 and not o.gui)
o:play(3);o:step(3);worlds={};o:close();assert(calls.close==1,'stale world must not be destroyed')
worlds={world};o:play(4)
stingray.Gui.bitmap=function()error('mock renderer failure')end
assert(not pcall(o.step,o,4));assert(temp==17,'temporary arena must restore even after failure');o:close()
print('PASS retained GUI, frame switching, temporary arena restore, expiration and stale-world cleanup')
