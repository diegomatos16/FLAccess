ffi=require("ffi")
local blocks={}
local function block(address,size)
    local data=ffi.new("uint8_t[?]",size);blocks[#blocks+1]={address=address,size=size,data=data};return data
end
local function qword(data,offset,value) ffi.cast("uint64_t*",data+offset)[0]=value end
local function read(address,size)
    if not address then return nil end
    for _,b in ipairs(blocks) do
        if address>=b.address and address+size<=b.address+b.size then return ffi.string(b.data+address-b.address,size) end
    end
end
local image=0x140000000
local fixture=assert(loadfile("FLAccess/tests/match_registry_fixture.lua"))()(block,qword,image,{BALL=0x700000,CAMERA=0x710000,FIELD=0x720000,CURSOR=0x730000,MATCH=0x750000,ANALYZE=0x760000,MATCH_ENV=0x770000})
local chunk=assert(loadfile(assert(arg[1])));setfenv(chunk,{ffi=ffi,pairs=pairs,table=table,tonumber=tonumber})
local m=chunk();local ctx={};m.init(ctx);assert(ctx.flaccess_match_registry==m)
local result,why=m.snapshot(read,image);assert(result,why)
assert(result.camera.target==0x710000 and result.field.target==0x720000 and result.ball.target==0x700000 and result.cursor.target==0x730000)
assert(result.camera_env.target==0x770000,"MATCH/ENV not bound separately")
assert(result.match.target==0x750000 and result.analyze.target==0x760000,"MATCH/ANALYZE conflated")
qword(fixture.entries.ANALYZE.data,16,0)
local without=m.snapshot(read,image);assert(without and not without.analyze and without.ball.target==0x700000)
qword(fixture.entries.ANALYZE.data,16,0x760000)
-- Entry replacement is read fresh; no prior target can escape.
qword(fixture.entries.CAMERA.data,16,0x740000);assert(m.snapshot(read,image).camera.target==0x740000)
qword(fixture.groups.CAMERA.data,0x10,0);assert(m.snapshot(read,image).camera==nil);qword(fixture.groups.CAMERA.data,0x10,fixture.registry)
qword(fixture.groups.CAMERA.data,0x20,fixture.groups.FIELD.address)
assert(m.snapshot(read,image).camera.target==0x720000) -- Native directory alias, not a guessed camera.
qword(fixture.groups.CAMERA.data,0x20,0)
qword(fixture.groups.CAMERA.data,0x20,fixture.groups.CAMERA.address);assert(m.snapshot(read,image).camera==nil);qword(fixture.groups.CAMERA.data,0x20,0)
qword(fixture.nodes[1][2],24,fixture.nodes[1][1]);assert(not m.snapshot(read,image));qword(fixture.nodes[1][2],24,fixture.root+0x38)
qword(fixture.entries.FIELD.data,16,0);assert(not m.snapshot(read,image));qword(fixture.entries.FIELD.data,16,0x720000)
local changed=false
result=m.snapshot(function(address,size)
    if address==image+0x37f0ac8 then
        if changed then return string.rep("\0",8) end
        changed=true
    end
    return read(address,size)
end,image)
assert(not result)
print("PASS native registry contracts: typed owner/root, BALL/CAMERA/FIELD/CURSOR INFO keys, current entries, foreign owner, alias/tree cycles, missing data, root replacement; synthetic layout only")
