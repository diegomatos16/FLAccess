-- Contract tests: camera coordinates, native controller identity, pause/replay gates.
ffi=require("ffi")
local m
if arg[2]=="--modular" then
    local ctx={sider_dir="./",flaccess={gameplay={stage=0}}}
    for _,name in ipairs({"state","rules","memory","audio","match","diagnostics","render","lifecycle"}) do
        local component=assert(loadfile(arg[1] .. "/gameplay_" .. name .. ".lua"))()
        component.install(ctx)
    end
    m=ctx.flaccess.gameplay.m
else m=assert(loadfile(assert(arg[1])))() end
local checks=0
local function same(a,b)
    for i=1,3 do assert(math.abs(a[i]-b[i])<0.00001) end
    checks=checks+1
end
local r,u,f={1,0,0},{0,1,0},{0,0,-1}
same(m.project({3,2,-4},r,u,f),{3,2,-4})
-- Camera yawed 90 degrees: world +X is directly in front, +Z is right.
same(m.project({5,0,2},{0,0,1},u,{1,0,0}),{2,0,-5})
same(m.project({-5,1,-2},{0,0,1},u,{1,0,0}),{-2,1,5})
assert(m.proximity(8,8)==0 and m.proximity(0,8)==1)
assert(m.proximity(2,8)>m.proximity(4,8) and m.proximity(4,8)>m.proximity(6,8));checks=checks+2
local function controls(assignments)
    local bytes=ffi.new("uint8_t[?]",24*0x74)
    for i=0,23 do ffi.cast("uint32_t*",bytes+i*0x74+0x20)[0]=255 end
    for _,a in ipairs(assignments) do
        bytes[a[1]*0x74+6]=a[3] or 0
        ffi.cast("uint32_t*",bytes+a[1]*0x74+0x20)[0]=a[2]
    end
    return ffi.string(bytes,24*0x74)
end
local actor,slot=m.controlled_slot(controls({{0,0}}));assert(actor==0 and slot==0);checks=checks+1
actor,slot=m.controlled_slot(controls({{0,17},{1,4,1}}));assert(actor==17 and slot==0);checks=checks+1
actor,slot=m.controlled_slot(controls({{0,3}}));assert(actor==3);checks=checks+1
actor,slot=m.controlled_slot(controls({{0,9}}));assert(actor==9);checks=checks+1 -- Real selection may swap independently of ball.
assert(not m.controlled_slot(controls({{0,3},{1,7}})));checks=checks+1
assert(not m.controlled_slot(controls({{0,3},{1,3}})));checks=checks+1
assert(not m.controlled_slot(controls({})));checks=checks+1
local cursor=ffi.new("uint8_t[?]",4+24*0x74)
ffi.cast("uint32_t*",cursor+4+0x20)[0]=9
assert(m.cursor_actor(ffi.string(cursor,4+24*0x74),0)==9);checks=checks+1
ffi.cast("uint32_t*",cursor+4+0x20)[0]=2
assert(m.cursor_actor(ffi.string(cursor,4+24*0x74),0)==2);checks=checks+1
ffi.cast("uint32_t*",cursor+4+0x20)[0]=255
assert(not m.cursor_actor(ffi.string(cursor,4+24*0x74),0));checks=checks+1
assert(not m.cursor_actor(nil,0));checks=checks+1
assert(not m.cursor_actor(ffi.string(cursor,4+24*0x74),nil));checks=checks+1
assert(not m.cursor_actor(ffi.string(cursor,4+24*0x74),24));checks=checks+1
local a,b=ffi.new("uint8_t[64]"),ffi.new("uint8_t[164]")
b[0x88]=5
a[0x22]=1
local function playing() return m.playing_stage(ffi.string(a,64),ffi.string(b,164)) end
assert(playing());checks=checks+1
a[0x20]=1;assert(not playing());a[0x20]=0;checks=checks+1
b[0x9d]=1;assert(not playing());b[0x9d]=0;checks=checks+1
b[0x88]=8;assert(playing());checks=checks+1 -- Observed live FL2026 stage.
b[0x88]=6;a[0x22]=0;assert(not playing());a[0x22]=1;checks=checks+1
b[0x88]=12;assert(playing());checks=checks+1
b[0x88]=16;assert(playing());checks=checks+1
assert(not m.playing_stage(nil,nil));checks=checks+1
local horizontal_right,horizontal_up,horizontal_front=m.horizontal_basis({1,0,0},{0,-0.8,-0.6})
same(horizontal_right,{1,0,0});same(horizontal_up,{0,1,0});same(horizontal_front,{0,0,-1})
same(m.ball_point({5,0,-2},horizontal_right,horizontal_up,horizontal_front,true),{0,0,-1})
same(m.ball_point({5,0,-2},horizontal_right,horizontal_up,horizontal_front,false),{5,0,-2})
same(m.project({52,0,0},horizontal_right,horizontal_up,horizontal_front),{52,0,0})
same(m.project({-52,0,0},horizontal_right,horizontal_up,horizontal_front),{-52,0,0})
same(m.project({0,0,-34},horizontal_right,horizontal_up,horizontal_front),{0,0,-34})
local factor=m.normalization_factor(0.0111329845,0.0706787109)
assert(factor>12 and factor<12.1 and factor*0.0706787109<=0.850001);checks=checks+1
assert(not m.normalization_factor(0,0));checks=checks+1
local previous,cue
local function possession_step(actor,keeper,known,expected)
    previous,cue=m.possession_change(previous,actor,keeper,known)
    assert(cue==expected,"expected "..tostring(expected).." got "..tostring(cue));checks=checks+1
end
possession_step(2,255,true,nil)
possession_step(2,2,true,"gotBall")
possession_step(2,2,true,nil)
possession_step(2,13,true,"LostBall")
possession_step(2,nil,false,nil)
assert(previous==nil);checks=checks+1
possession_step(2,2,true,nil)
possession_step(7,7,true,"teamStillWithBall") -- Auto switch to pass receiver: no got/lost pair.
possession_step(3,13,true,"LostBall")
possession_step(9,13,true,nil)
previous=nil
possession_step(2,2,true,nil)
possession_step(2,255,true,nil) -- Flight is neither loss nor confirmed receipt.
possession_step(7,255,true,nil) -- Assisted selection can move during flight.
possession_step(7,7,true,"teamStillWithBall")
possession_step(7,7,true,nil)
possession_step(7,255,true,nil)
possession_step(7,14,true,"LostBall") -- Intercepted pass.
possession_step(7,14,true,nil)
previous=nil
possession_step(2,2,true,nil)
possession_step(2,7,true,"teamStillWithBall")
possession_step(7,7,true,nil) -- Selecting receiver later must not add gotBall.
possession_step(7,255,true,nil)
possession_step(7,7,true,"gotBall") -- Same player recovers loose ball.
previous=nil
possession_step(0,255,true,nil)
possession_step(0,0,true,"gotBall")
possession_step(0,255,true,nil)
possession_step(0,11,true,"LostBall")
previous=nil
possession_step(2,7,true,nil)
possession_step(7,7,true,"gotBall") -- Ordinary switch without a preceding local pass still works.
previous=nil
possession_step(2,2,true,nil)
possession_step(7,2,true,"teamStillWithBall") -- Selection changes before the ball leaves passer.
possession_step(7,255,true,nil)
possession_step(7,7,true,nil) -- No extra gotBall when it arrives.
possession_step(7,255,true,nil)
possession_step(7,14,true,"LostBall")
previous=nil
possession_step(2,2,true,nil)
possession_step(7,2,true,"teamStillWithBall")
possession_step(7,255,true,nil)
possession_step(7,13,true,"LostBall") -- Intercepted after early selection.
local r,u,f=m.body_basis(0)
same(r,{1,0,0});same(f,{0,0,1})
same(m.project({0,0,10},r,u,f),{0,0,-10})
r,u,f=m.body_basis(90)
same(m.project({10,0,0},r,u,f),{0,0,-10})
same(m.project({0,0,10},r,u,f),{-10,0,0})
r,u,f=m.body_basis(180)
same(m.project({0,0,-10},r,u,f),{0,0,-10})
assert(not m.body_basis(0/0) and not m.body_basis(360));checks=checks+1
local h=m.smooth_heading({actor=2,degrees=359},2,1,0.016)
assert(h.degrees>359 or h.degrees<1);checks=checks+1
h=m.smooth_heading(h,7,180,0.016);assert(h.degrees==180);checks=checks+1
local own,other=m.goal_centers(1,52.56)
same(own,{-52.56,0,0});same(other,{52.56,0,0})
own,other=m.goal_centers(-1,52.56)
same(own,{52.56,0,0});same(other,{-52.56,0,0})
assert(not m.goal_centers(0,52.56));checks=checks+1
local settings=m.tackle_settings(nil)
assert(settings.enabled and settings.distance==2 and settings.exit_distance==2.3 and settings.max_ball_height==1);checks=checks+1
local near
local function tackle(actor,keeper,known,x,y,expected)
    near=m.tackle_proximity(near,actor,keeper,known,{0,0,0},{x,y,0},settings)
    assert(near.active==expected);checks=checks+1
end
tackle(2,13,true,1.9,0.1,true)
tackle(2,13,true,2.2,0.1,true)
tackle(2,13,true,2.4,0.1,false)
tackle(2,13,true,2.2,0.1,false)
tackle(2,13,true,2.0,0.1,true)
tackle(2,13,true,1,1.1,false)
tackle(2,7,true,1,0.1,false)
tackle(2,255,true,1,0.1,false)
tackle(2,nil,false,1,0.1,false)
tackle(2,13,true,1.9,0.1,true)
tackle(7,13,true,2.2,0.1,false) -- New actor does not inherit hysteresis.
settings=m.tackle_settings("tackle_enabled=0\ntackle_distance=3\ntackle_exit_distance=1\ntackle_volume=0.25")
assert(not settings.enabled and settings.distance==3 and settings.exit_distance==3.3 and settings.volume==0.25);checks=checks+1
tackle(2,13,true,1,0.1,false)
settings=m.tackle_settings("tackle_distance=99\ntackle_volume=-1\ntackle_max_ball_height=10")
assert(settings.distance==2 and settings.volume==0.3 and settings.max_ball_height==1);checks=checks+1
print(string.format("PASS %d gameplay contracts; simulated inputs, not an audible game test",checks))
