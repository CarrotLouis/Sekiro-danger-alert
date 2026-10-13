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
      bitmap=function(gui,name,p,s,c)assert(c[1]==255 and p[3]==950);calls.position=p;calls.bitmap=(calls.bitmap or 0)+1;return 42 end,
      update_bitmap=function(gui,id,name,p)assert(id==42);calls.name=name;calls.position=p end,
      material=function()return {}end},
}
local anchor={x=700,y=400,node=10,unit=7}
local n={ui_world=function()return world end,image_ready=function()return true end,
 head_anchor=function()return anchor,'head unavailable' end}
local assets={fps=60,frames={{name='frame0',hash='a'},{name='frame1',hash='b'}},colours={{1,1,0,0},{1,1,1,1},{0,0,0,0},{0,0,0,0}}}
local o=dofile(root..'/src/overlay.lua').new(n,assets,function()end)
assert(not o:warmup());assert(o:warmup());assert(o:play(1))
o:step(1);assert(temp==17 and calls.create==1 and calls.bitmap==1)
local x,y=calls.position[1],calls.position[2]
anchor.x=anchor.x+80;anchor.y=anchor.y-30
o:step(1.02);assert(temp==17 and calls.name=='frame1' and calls.colours==8)
assert(calls.position[1]==x+80 and calls.position[2]==y-30,'must follow current head position every frame')
o:step(2);assert(calls.close==1 and not o.gui)
o:play(3);o:step(3);worlds={};o:close();assert(calls.close==1,'stale world must not be destroyed')
worlds={world};o:play(4)
local saved=anchor;anchor=nil;o:step(4);assert(not o.gui,'missing head must not fall back to screen center')
anchor=saved
stingray.Gui.bitmap=function()error('mock renderer failure')end
assert(not pcall(o.step,o,4));assert(temp==17,'temporary arena must restore even after failure');o:close()
print('PASS head-follow GUI, missing-head hiding, frame switching, arena restore and stale-world cleanup')
-- Size scales around the existing anchor; offset limits do not grow with size.
local placement={x=0,y=0,scale=1}
local dims
stingray.Gui.bitmap=function(_,_,p,s)calls.position=p;dims=s;return 42 end
stingray.Gui.update_bitmap=function(_,_,_,p,s)calls.position=p;dims=s end
assets.quad_ratio=0.38
o=dofile(root..'/src/overlay.lua').new(n,assets,function()end,function()return placement end)
o:warmup();o:warmup();o:play(10);o:step(10)
local baseline=dims[1]
local cx=calls.position[1]+dims[1]/2;local cy=calls.position[2]+dims[2]/2
placement={x=1,y=-1,scale=3};o:step(10.01)
assert(math.abs(dims[1]-baseline*3)<0.001)
assert(math.abs(calls.position[1]+dims[1]/2-cx-108)<0.001)
assert(math.abs(calls.position[2]+dims[2]/2-cy+108)<0.001)
placement={x=0,y=0,scale=.5};anchor.x=anchor.x+25;o:step(10.02)
assert(math.abs(dims[1]-baseline*.5)<0.001)
assert(math.abs(calls.position[1]+dims[1]/2-cx-25)<0.001,'scaled glyph must continue following the moving avatar')
o:close()
print('PASS zero-anchor preservation, bounded offsets and 0.5x/3x scaling while following')
