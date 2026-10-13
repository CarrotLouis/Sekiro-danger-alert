local native=dofile(arg[1]..'/src/native.lua')
local camera={x=0,y=0,z=0,right={1,0,0},forward={0,1,0},up={0,0,1},fov=math.pi/2}
local function near(a,b)assert(math.abs(a-b)<0.001,tostring(a)..' != '..tostring(b))end
local p=native.project({x=0,y=10,z=0},camera,1920,1080);near(p.x,960);near(p.y,540)
p=native.project({x=2,y=10,z=1},camera,1920,1080);near(p.x,1068);near(p.y,594)
camera.x=1;p=native.project({x=2,y=10,z=1},camera,1920,1080);near(p.x,1014)
camera.x=0;p=native.project({x=2,y=10,z=1},camera,2560,1080);near(p.x,1388);near(p.y,594)
assert(not native.project({x=0,y=-10,z=0},camera,1920,1080))
assert(not native.project({x=200,y=10,z=0},camera,1920,1080))
camera.forward={1,0,0};camera.right={0,-1,0}
p=native.project({x=10,y=0,z=1},camera,1920,1080);near(p.x,960);near(p.y,594)
print('PASS camera-relative projection, camera movement/rotation, ultrawide aspect and behind/offscreen rejection')
