local ffi=require('ffi')
local component=assert(loadfile(arg[1] or 'modules/FlAccess/camera.lua'))
setfenv(component,{ffi=ffi,math=math,type=type,tonumber=tonumber,tostring=tostring})
local camera=component();camera.init({})
local checks=0
local function close(a,b)assert(math.abs(a-b)<0.0001,tostring(a)..' differs from '..tostring(b));checks=checks+1 end
local function matrix(yaw,zoom)
    local a=yaw*math.pi/180
    local rx,rz=math.cos(a),-math.sin(a)
    local fx,fz=math.sin(a),math.cos(a)
    local m={rx*zoom,fx*.55,fx,fx*.8,0,.8,-.55,-.55,rz*zoom,fz*.55,fz,fz*.8,0,0,40,40}
    local raw=ffi.new('float[23]')
    for i=1,16 do raw[i+2]=m[i] end
    return ffi.string(raw,92),{rx,0,rz},{fx,0,fz}
end
for _,yaw in ipairs({0,45,90,180,270})do
 for _,zoom in ipairs({.7,2.3})do
  local raw,right,forward=matrix(yaw,zoom)
  for _,origin in ipairs({{0,0,0},{12,0,-7},{-15,1,4}})do
   local frame=assert(camera.listener_frame(raw,origin,5))
   close(frame.right[1]*frame.forward[1]+frame.right[3]*frame.forward[3],0)
   for _,delta in ipairs({{10,0,0},{-10,2,8},{3,-1,-12}})do
    local p=assert(camera.project(frame,{origin[1]+delta[1],origin[2]+delta[2],origin[3]+delta[3]}))
    close(p[1],delta[1]*right[1]+delta[3]*right[3]);close(p[2],delta[2]);close(p[3],-(delta[1]*forward[1]+delta[3]*forward[3]))
    close(p[1]^2+p[2]^2+p[3]^2,delta[1]^2+delta[2]^2+delta[3]^2)
   end
   local body=assert(camera.listener_frame(raw,origin,5,{1,0,0}))
   local p=camera.project(body,{origin[1]+5,origin[2],origin[3]+2})
   close(p[1],-2);close(p[3],-5)
  end
 end
end
local raw=matrix(0,1)
assert(not camera.listener_frame(raw,{0,0,0},5,{0,0,0}))
assert(not camera.listener_frame(raw,{0,0,0},99))
local original=camera.profiles[5];camera.profiles[5]=nil
assert(not camera.listener_frame(raw,{0,0,0},5))
assert(camera.listener_frame(raw,{0,0,0},6));camera.profiles[5]=original
local p=camera.project(assert(camera.listener_frame(raw,{0,0,0},5)),{0,0,0})
close(p[1],0);close(p[2],0);close(p[3],0)
-- Confirmed FL27 Player=8 is independent of the camera matrix. Turning the
-- body changes bearings; a fixed body does not follow visual camera changes.
local body=assert(camera.listener_frame(nil,{2,0,3},8,{0,0,1}))
local p=camera.project(body,{7,0,3});close(p[1],5);close(p[3],0)
local turned=assert(camera.listener_frame(nil,{2,0,3},8,{1,0,0}))
p=camera.project(turned,{7,0,3});close(p[1],0);close(p[3],-5)
assert(not camera.listener_frame(nil,{2,0,3},8,{0,0,0}))
local same=assert(camera.listener_frame('invalid-view-matrix',{2,0,3},8,{0,0,1}))
p=camera.project(same,{7,0,3});close(p[1],5)
for id=1,6 do
    for _,yaw in ipairs({0,20,160,180}) do
        local field=assert(camera.field_frame(matrix(yaw,1),{2,0,3},id))
        local sign=yaw<90 and 1 or -1
        local point=camera.project(field,{7,1,6})
        close(point[1],sign*5);close(point[2],1);close(point[3],-sign*3)
    end
end
print('CAMERA_ORIENTATION_OK checks='..checks..' including fixed lateral bearings')
