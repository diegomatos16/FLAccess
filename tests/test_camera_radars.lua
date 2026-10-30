local ffi=require("ffi")
local chunk=assert(loadfile("FLAccess/modules/FlAccessGameplay/engine/cameraRadars.lua"))
setfenv(chunk,{ffi=ffi,math=math,type=type,tonumber=tonumber,tostring=tostring})
local m=chunk()
local profiles={}
for i=0,9 do local f=assert(io.open(string.format("FLAccess/modules/FlAccessGameplay/engine/cameraRadars/camera_%02d.ini",i),"rb"));profiles[i]=f:read("*a");f:close() end
local ctx={};m.init(ctx,profiles);assert(ctx.flaccess_camera_radars==m)
profiles=m.profiles
local checks=0
local function check(value,why) assert(value,why);checks=checks+1 end
local function raw(matrix)
    local data=ffi.new("uint8_t[92]")
    for i=1,16 do ffi.cast("float*",data+0x0c+(i-1)*4)[0]=matrix[i] end
    return ffi.string(data,92)
end
local function close(a,b) return math.abs(a-b)<0.0001 end
local ortho={1,0,0,0, 0,0,1,0, 0,-1,0,0, 0,0,0,1}
local frame=assert(m.frame(raw(ortho),{0,0,0},5))
for _,target in ipairs({{10,0,0},{-10,0,0},{0,0,-10},{0,0,10},{5,0,-5},{-5,0,-5}}) do
    local p=m.project(frame,target)
    check(close(p[1],target[1]) and close(p[3],target[3]),"orthographic screen direction")
end
local p=m.project(frame,{0,2,0});check(close(p[1],0) and close(p[2],2),"height lost")
-- Independently compute NDC positions, then compare actual screen differences.
local function clip(matrix,p)
    local x,y,z=p[1],p[2],p[3]
    local w=x*matrix[4]+y*matrix[8]+z*matrix[12]+matrix[16]
    return (x*matrix[1]+y*matrix[5]+z*matrix[9]+matrix[13])/w,
        (x*matrix[2]+y*matrix[6]+z*matrix[10]+matrix[14])/w,w
end
local function perspective(aspect,zoom)
    local a,b=20/math.sqrt(1300),30/math.sqrt(1300)
    local w=math.sqrt(1300)
    return {zoom/aspect,0,0,0, 0,zoom*b,-a*1.01,-a, 0,zoom*a,b*1.01,b, 0,0,w*1.01-0.1,w}
end
for id=0,9 do
    for _,origin in ipairs({{0,0,0},{15,0,8},{-28,0,-5}}) do
        local matrix=perspective(16/9,2)
        local f=assert(m.frame(raw(matrix),origin,id))
        for _,target in ipairs({{20,0,12},{-15,0,30},{0,0,-20},{35,0,-10}}) do
            local ox,oy=clip(matrix,origin)
            local tx,ty=clip(matrix,target)
            local sx,sy=(tx-ox)*(16/9),ty-oy
            local n=math.sqrt(sx*sx+sy*sy)
            local actual=assert(m.project(f,target))
            local distance=math.sqrt(actual[1]^2+actual[3]^2)
            check(close(actual[1]/distance,sx/n) and close(-actual[3]/distance,sy/n),"perspective direction mismatch id="..id)
        end
    end
end
-- Off-center player: straight field-depth movement does change horizontal screen
-- position. The former constant camera bearing cannot represent this parallax.
local matrix=perspective(16/9,2)
frame=assert(m.frame(raw(matrix),{15,0,8},5))
check(m.project(frame,{15,0,18})[1]<0,"off-center perspective correction absent")
local zoomed=assert(m.frame(raw(perspective(16/9,4)),{15,0,8},5))
p=m.project(frame,{25,0,18});local q=m.project(zoomed,{25,0,18})
check(close(p[1],q[1]) and close(p[3],q[3]),"zoom changed direction")
-- Do not divide by a target's negative W and mirror a target behind the camera.
local front=m.project(frame,{15,0,-42})
local behind=m.project(frame,{15,0,-45})
check(front[1]*behind[1]+front[3]*behind[3]>0,"target crossing camera plane mirrored")
local baseline=m.project(assert(m.frame(raw(ortho),{0,0,0},6)),{5,0,-3})
profiles[5].pan_sign=-1
check(m.project(assert(m.frame(raw(ortho),{0,0,0},5)),{5,0,-3})[1]<0,"profile edit ignored")
q=m.project(assert(m.frame(raw(ortho),{0,0,0},6)),{5,0,-3})
check(close(q[1],baseline[1]) and close(q[3],baseline[3]),"one profile changed another")
profiles[5].pan_sign=1
profiles[5].depth_scale="invalid"
check(not m.frame(raw(ortho),{0,0,0},5),"invalid profile accepted")
check(m.frame(raw(ortho),{0,0,0},6),"invalid profile poisoned next camera")
profiles[5].depth_scale=1
check(m.frame(raw(ortho),{0,0,0},5),"repaired profile did not recover")
check(not m.frame(raw(ortho),{0,0,0},255),"unknown ID guessed")
check(not m.frame(raw(ortho),{0,0,0},nil),"missing ID guessed")
check(not m.frame("",{0,0,0},5),"short matrix accepted")
local invalid={unpack(ortho)};invalid[1]=0/0
check(not m.frame(raw(invalid),{0,0,0},5),"NaN matrix accepted")
invalid={unpack(ortho)};invalid[16]=-1
check(not m.frame(raw(invalid),{0,0,0},5),"origin behind camera accepted")
-- Malformed profile text cannot become executable or poison other IDs.
local saved=profiles[5]
profiles[5]=m.parse_profile("return { broken lua",5)
check(not m.frame(raw(ortho),{0,0,0},5),"malformed data accepted")
check(m.frame(raw(ortho),{0,0,0},6),"malformed text affected another ID")
profiles[5]=saved
-- Real existing registry matrices; arbitrary test ID does not identify their UI camera.
local fixture=assert(io.open("FLAccess/tests/camera-real-matrices-2026-10-27.tsv","rb"))
local captured=0
for line in fixture:lines() do
    local hex=line:match("\t([0-9a-f]+)%s*$")
    if hex then
        captured=captured+1
        local bytes=hex:gsub("..",function(h) return string.char(tonumber(h,16)) end)
        local a={}
        for i=0,15 do local v=ffi.new("float[1]");ffi.copy(v,bytes:sub(13+i*4,16+i*4),4);a[i+1]=tonumber(v[0]) end
        for _,origin in ipairs({{0,0,0},{20,0,10},{-20,0,-10}}) do
            local f=assert(m.frame(bytes,origin,5))
            for _,target in ipairs({{10,0,0},{-10,0,20},{30,0,-10}}) do
                local ox,oy=clip(a,origin);local tx,ty,tw=clip(a,target)
                assert(tw>0)
                local sx,sy=(tx-ox)*f.aspect,ty-oy;local n=math.sqrt(sx*sx+sy*sy)
                local actual=assert(m.project(f,target));local d=math.sqrt(actual[1]^2+actual[3]^2)
                check(close(actual[1]/d,sx/n) and close(-actual[3]/d,sy/n),"captured matrix mismatch")
            end
        end
    end
end
fixture:close();check(captured==4,"real matrix fixtures were skipped")
-- Installed data overrides embedded defaults without executable loading/rebuild.
local defaults={}
for i=0,9 do local f=assert(io.open(string.format("FLAccess/modules/FlAccessGameplay/engine/cameraRadars/camera_%02d.ini",i),"rb"));defaults[i]=f:read("*a");f:close() end
local instance=chunk()
local override=defaults[5]:gsub("pan_sign=1","pan_sign=-1")
instance.init({},defaults,function(id) if id==5 then return override end end)
check(instance.profiles[5].source=="installed","installed override not distinguished")
check(instance.project(assert(instance.frame(raw(ortho),{0,0,0},5)),{5,0,-3})[1]<0,"installed calibration ignored")
check(instance.project(assert(instance.frame(raw(ortho),{0,0,0},6)),{5,0,-3})[1]>0,"override changed other camera")
check(instance.profiles[6].source=="embedded","missing profile did not use bundled fallback")
instance.init({},defaults,function(id) if id==5 then return "" end end)
check(not instance.frame(raw(ortho),{0,0,0},5),"empty installed profile fell back silently")
check(instance.frame(raw(ortho),{0,0,0},6),"empty override poisoned other camera")
instance.init({},defaults,function(id) if id==5 then return string.char(239,187,191)..defaults[5] end end)
check(instance.frame(raw(ortho),{0,0,0},5),"Windows UTF8 BOM profile rejected")
instance.init({},defaults,function(id) if id==5 then return string.rep(" ",4097) end end)
check(not instance.frame(raw(ortho),{0,0,0},5),"oversized installed profile accepted")
check(instance.frame(raw(ortho),{0,0,0},6),"oversized override poisoned other camera")
instance.init({},defaults,function(id) if id==5 then return defaults[6] end end)
check(not instance.frame(raw(ortho),{0,0,0},5),"foreign profile ID accepted")
instance.init({},defaults)
check(instance.frame(raw(ortho),{0,0,0},5),"reinitialization did not recover")
check(instance.profiles[2].name=="fan_view" and instance.profiles[3].name=="broadcast" and instance.profiles[5].name=="dynamic_wide" and instance.profiles[6].name=="stadium","audited native families not named")
print(string.format("PASS %d cameraRadars contracts: 10 isolated profiles, independent NDC oracle, perspective/player offset, zoom, behind-view continuity and invalid/recovery; not audible game proof",checks))
