-- Execute real init/display_frame with restricted Sider globals and synthetic memory.
-- No game process, Windows audio session or sound is accessed.
local ffi=require("ffi")
local bit=require("bit")
local render_mode=arg[2]=="--render"
local modular=arg[4]=="--modular"
local bundled=arg[4]=="--bundle" or modular
local project=arg[9] or "FLAccess"
ffi.cdef[[typedef struct {
    void* BaseAddress; void* AllocationBase; unsigned long AllocationProtect;
    unsigned short PartitionId; size_t RegionSize; unsigned long State,Protect,Type;
} MEMORY_BASIC_INFORMATION;]]
local base=0x140000000
local regions={}
local function block(address,size)
    local b=ffi.new("uint8_t[?]",size);regions[#regions+1]={address=address,size=size,data=b};return b
end
local function qword(b,offset,value) ffi.cast("uint64_t*",b+offset)[0]=value end
local function dword(b,offset,value) ffi.cast("uint32_t*",b+offset)[0]=value end
local function float(b,offset,value) ffi.cast("float*",b+offset)[0]=value end
local ref_region=block(0x100000,4096)
local world=block(0x200000,0x1960)
local controls=block(0x210000,24*0x74)
for i=0,23 do dword(controls,i*0x74+0x20,255) end
dword(controls,0x20,2);qword(world,0x180,0x210000)
qword(block(base+0x36f3dc8,8),0,0x200000)
local player=block(0x220000,0x630);qword(player,0,base+0x26329a8);dword(player,0x18,2)
float(player,0x61c,0);float(player,0x624,10);float(player,0x628,0);float(player,0x62c,5)
local players=block(base+0x36f3fc0,22*8)
qword(players,2*8,0x220000)
local ball=block(0x230000,120);float(ball,0x10,15);float(ball,0x14,0.1);float(ball,0x18,8)
local camera=block(0x240000,120);float(camera,0x0c,1);float(camera,0x24,1);float(camera,0x30,-1);float(camera,0x48,1)
local field=block(0x250000,120);float(field,4,52.56);float(field,8,34.06)
local cursor=block(0x260000,4+24*0x74);dword(cursor,4+0x20,2)
local refs={
    {offset=0x100,vt=0x259afb0,target=0x230000,ready=true},
    {offset=0x200,vt=0x2599550,target=0x240000},
    {offset=0x300,vt=0x2608810,target=0x250000},
    {offset=0x400,vt=0x2597558,target=0x260000,ready=true},
}
for i,r in ipairs(refs) do
    qword(ref_region,r.offset,base+r.vt)
    local entry=block(0x270000+i*0x1000,32);qword(entry,16,r.target)
    qword(ref_region,r.offset+16,0x270000+i*0x1000)
    ref_region[r.offset+8]=r.ready and 1 or 0
end
local score=block(0x300000,64);score[0x22]=1;qword(score,0x38,0x310000)
local second=block(0x310000,0xa4);second[0x88]=8
for _,signature in ipairs({{0x41b68c,"\x48\x83\xc1\x04"},{0x87a47d,"\x0f\xb6\x59\x44"},{0x41b6fc,"\x48\x83\xc1\x08"},{0xa627ae,"\x0f\xbe\x80\x54\x02\x00\x00"},{0xa42570,"\x88\x91\x54\x02\x00\x00"},{0xa48a30,"\x83\xfa\x02"},{0x8c4d1e,"\xf3\x0f\x10\xb1\x1c\x06\x00\x00"},{0x923572,"\x48\x8b\x8f\xd8\x07\x00\x00"},{0xa627e8,"\x48\x8b\x41\x18\x8b\x80\x1c\x60\x02\x00"},{0x4589ec,"\x48\x83\xc1\x08"},{0x1b55f40,"\x48\x8b\x05\x81\xab\xc9\x01"},{0x91ed11,"\x48\x8d\x05\xa8\x52\xdd\x02"},{0x440669,"\x48\x8b\x05\x58\x37\x2b\x03"}}) do
    ffi.copy(block(base+signature[1],#signature[2]),signature[2],#signature[2])
end
local fixture_chunk=assert(loadfile(project .. "/tests/match_registry_fixture.lua"))
setfenv(fixture_chunk,{ffi=ffi,ipairs=ipairs})
qword(world,0x258,base+0x25969b8);qword(world,0x270,0x320008)
local match_info=block(0x320000,8+0x2378)
-- Reproduce the old bug: an out-of-bounds MATCH read lands on unrelated zero.
local unrelated_zero=block(0x320000+8+0x2601c,4)
local analyze_info=block(0x730000,8+0x26038);dword(analyze_info,8+0x2601c,255)
local record_raw=0xa00000
local flow=block(0x9a0000,0xf4)
qword(block(base+0x3704e38,8),0,0x9a0000)
dword(block(base+0x34fc9c0+51*16,4),0,12)
dword(block(base+0x34fc9c0+52*16,4),0,11)
block(record_raw,8)
local card_count=block(record_raw+8+0x1803c0,1)
local cards=block(record_raw+8+0x17fd80,80)
for _,signature in ipairs({
    {0xa3e8a0,"\x48\x8d\x81\xd0\x50\x07\x00\xc3"},
    {0x8c6e60,"\x0f\xb6\x81\xf0\xb2\x10\x00\x3c\x27\x73\x3f"},
    {0x4ec19f,"\x41\x80\x78\x18\x00\x41\xb0\x01"},
    {0x4ec1cd,"\x8b\x47\x14\x89\x44\x24\x20\x48\x8d\x57\x04\x4c\x8d\x44\x24\x20"},
    {0x149a470,"\x48\x8b\x05\xc1\xa9\x26\x02\xc3"},
    {0x149f4f0,"\x8b\x81\xf0\x00\x00\x00"},
}) do ffi.copy(block(base+signature[1],#signature[2]),signature[2],#signature[2]) end
qword(world,0x18,0x320008)
local camera_env=block(0x790000,0x49);camera_env[0x48]=5
local fixture=fixture_chunk()(block,qword,base,{BALL=0x230000,CAMERA=0x240000,FIELD=0x250000,CURSOR=0x260000,MATCH=0x320000,ANALYZE=0x730000,RECORD=record_raw,MATCH_ENV=0x790000})
qword(fixture.entries.CAMERA.data,16,0);qword(fixture.entries.FIELD.data,16,0)
local teams={block(0x700000,0x258),block(0x710000,0x258)}
for side=0,1 do
    qword(world,0x1910+side*0x28,base+0x2596cd8)
    qword(world,0x1928+side*0x28,0x700000+side*0x10000)
    teams[side+1][0x254]=side==0 and 1 or 255
end
local tick,scan_reads,master_calls=0,0,0
local wrong_match_reads=0
local master_muted,master_volume=false,0.4
local last_master_tick
local kernel={
    SetEnvironmentVariableA=function(key,value) assert(key=="ALSOFT_DRIVERS" and value=="wasapi");return 1 end,
    GetCurrentProcess=function() return ffi.cast("void*",1) end,
    GetCurrentProcessId=function() return 42 end,
    GetLastError=function() return 0 end,
    GetTickCount64=function() return tick end,
    ReadProcessMemory=function(_,address,out,size,got)
        address=tonumber(ffi.cast("uintptr_t",address))
        if address==0x320000+8+0x2601c then wrong_match_reads=wrong_match_reads+1 end
        for _,r in ipairs(regions) do
            if address>=r.address and address+size<=r.address+r.size then
                ffi.copy(out,r.data+address-r.address,size);got[0]=size
                if address==0x100000 and size==4096 then scan_reads=scan_reads+1 end
                return 1
            end
        end
        got[0]=0;return 0
    end,
    VirtualQuery=function(address,out)
        address=tonumber(ffi.cast("uintptr_t",address))
        if address>0x100000 then return 0 end
        out[0].BaseAddress=ffi.cast("void*",0x100000);out[0].RegionSize=4096
        out[0].State=0x1000;out[0].Type=0x20000;out[0].Protect=4
        return ffi.sizeof(out[0])
    end,
}
local real_load=ffi.load
local openal,loop_device,loop_context
local ball_source,ball_point,silence_ball,buffer_count= nil,nil,false,0
local silence_radar=false
local side_peak,side_rms
local source_ids,source_plays,source_looping,source_points={}, {}, {}, {}
local silence_goals=false
local missing_cues=arg[7]=="--missing-cues"
local missing_goals=arg[7]=="--missing-goals"
local missing_team=arg[7]=="--missing-team"
local missing_tackle=arg[7]=="--missing-tackle"
local have_stats=true
if render_mode then
    ffi.cdef[[
        void* alcLoopbackOpenDeviceSOFT(const char*);
        void alcRenderSamplesSOFT(void*,void*,int);
        void* alcCreateContext(void*,const int*);
        void alcDestroyContext(void*);char alcCloseDevice(void*);
        void alGetBufferi(unsigned int,int,int*);
    ]]
    openal=real_load(arg[6] or ".\\SiderAddons\\modules\\FlAccessGameplay\\bin\\soft_oal.dll")
end
ffi.load=function(name)
    if name=="kernel32" then return kernel end
    assert(name:find(modular and "modules\\FlAccess\\bin\\" or "modules\\FlAccessGameplay\\bin\\",1,true),"DLL outside Gameplay bin")
    if name:match("flaccess_audio_master.dll$") then
        assert(bundled)
        return {FLAccessAudio_Start=function() return 1 end,FLAccessAudio_GetState=function(out)
            if last_master_tick~=tick then master_calls=master_calls+1;last_master_tick=tick end
            out[0].status=render_mode and 1 or 0;out[0].native_sessions=render_mode and 1 or 0
            out[0].process_id=42;out[0].volume=master_volume;out[0].muted=master_muted and 1 or 0
            ffi.copy(out[0].device_name,"Test endpoint")
            return 1
        end}
    end
    assert(render_mode and name:match("soft_oal.dll$"))
    return setmetatable({alcCreateContext=function(device,attributes)
        -- Add the test-only loopback format to the production attributes.
        local loop_attributes=ffi.new("int[?]",13,{0x1990,0x1501,0x1991,0x1406})
        local index=0
        while attributes[index]~=0 do
            loop_attributes[4+index],loop_attributes[5+index]=attributes[index],attributes[index+1]
            index=index+2
        end
        loop_context=openal.alcCreateContext(device,loop_attributes)
        return loop_context
    end,
    alcGetString=function(device,key)
        if device==nil and key==0x1013 then
            local names=ffi.new("char[?]",64,"OpenAL Soft on Test endpoint\0\0")
            -- Keep alive while the shared output selector walks this list.
            kernel.test_device_names=names;return ffi.cast("const char*",names)
        end
        return openal.alcGetString(device,key)
    end,
    alcOpenDevice=function() loop_device=openal.alcLoopbackOpenDeviceSOFT(nil);return loop_device end,
    alBufferData=function(id,format,data,size,rate)
        buffer_count=buffer_count+1
        if buffer_count==2 then
            local pcm=ffi.cast("int16_t*",data);local sum=0;side_peak=0
            for i=0,size/2-1 do local v=tonumber(pcm[i])/32768;sum=sum+v*v;side_peak=math.max(side_peak,math.abs(v)) end
            side_rms=math.sqrt(sum/(size/2))
        end
        openal.alBufferData(id,format,data,size,rate)
    end,
    alGenSources=function(count,out)
        openal.alGenSources(count,out);ball_source=out[0]
        for i=0,count-1 do source_ids[i+1]=tonumber(out[i]) end
    end,
    alSourcePlay=function(source)
        local id=tonumber(source);source_plays[id]=(source_plays[id] or 0)+1
        openal.alSourcePlay(source)
    end,
    alSourcei=function(source,key,value)
        if key==0x1007 then source_looping[tonumber(source)]=value end
        openal.alSourcei(source,key,value)
    end,
    alSource3f=function(source,key,x,y,z)
        source_points[tonumber(source)]={x,y,z}
        if source==ball_source then ball_point={x,y,z} end
        openal.alSource3f(source,key,x,y,z)
    end,
    alSourcef=function(source,key,value)
        local id=tonumber(source)
        local suppressed=key==0x100a and ((silence_goals and (id==source_ids[6] or id==source_ids[7])) or (silence_ball and source==ball_source)
            or (silence_radar and (id==source_ids[1] or id==source_ids[2] or id==source_ids[3])))
        openal.alSourcef(source,key,suppressed and 0 or value)
    end},{__index=function(_,key) return openal[key] end})
end
local logs={}
local env={assert=assert,ffi=ffi,bit=bit,math=math,table=table,string=string,pairs=pairs,ipairs=ipairs,
    tonumber=tonumber,tostring=tostring,error=error,type=type,
    log=function(s) logs[#logs+1]=s end,
    memory={get_process_info=function() return {base=base} end},
    match={stats=function() return have_stats and {ptr=ffi.cast("void*",0x300000)} or nil end},
    io={open=function(path,mode)
        if mode=="rb" then
            if path:match("%.wav$") then
                if missing_tackle and path:match("alertTacle%.wav$") then return nil end
                if (missing_cues or missing_team) and path:match("teamStillWithBall%.wav$") then return nil end
                if missing_goals and path:match("Goalkeeper%.wav$") then return nil end
                if missing_cues and (path:match("gotBall%.wav$") or path:match("LostBall%.wav$")) then return nil end
                assert(path:find(modular and "content\\FlAccess\\sounds\\" or "livecpk\\FlAccessGameplay\\sounds\\",1,true),"WAV outside Gameplay assets")
                local name=assert(path:match("([^\\]+%.wav)$"))
                return io.open((arg[5] or "FLAccess/livecpk/FlAccessGameplay/sounds/") .. name,mode)
            end
            local camera_file=path:match("(camera_%d%d%.ini)$")
            if camera_file then
                if modular then return io.open(project .. "/content/FlAccess/cameras/" .. camera_file,mode) end
                local parent=assert(arg[1]:match("^(.*)[/\\][^/\\]+$"))
                return io.open(parent .. (bundled and "/engine/cameraRadars/" or "/cameraRadars/") .. camera_file,mode)
            end
            if path:match("FlAccessGameplay%.ini$") or (modular and path:match("FlAccess%.ini$")) then return io.open(arg[8] or "FLAccess/modules/FlAccessGameplay/FlAccessGameplay.ini",mode) end
            assert(path:find(modular and "modules\\FlAccess\\state\\" or "modules\\FlAccessGameplay\\state\\",1,true),"layout outside Gameplay state")
            assert(path:match("live%-layout.txt$"));return {read=function() return "validated_single_local_player=1" end,close=function() end}
        end
        return {write=function() end,close=function() end}
    end},
}
local m
if not modular then local chunk=assert(loadfile(assert(arg[1])));setfenv(chunk,env);m=chunk() end
local ctx={sider_dir="test\\",register=function() end,flaccess_audio={
    prepare_output=function()
        master_calls=master_calls+1
        if render_mode then return {volume=master_volume,muted=master_muted} end
        return nil,"waiting-for-game-audio"
    end,
    open_output=function()
        assert(render_mode);loop_device=openal.alcLoopbackOpenDeviceSOFT(nil);assert(loop_device~=nil);return loop_device
    end,
}}
if modular then
    local function load_component(name,method)
        local chunk=assert(loadfile(arg[1] .. "/" .. name .. ".lua"));setfenv(chunk,env)
        local component=chunk();component[method or "init"](ctx)
    end
    load_component("core")
    load_component("audio_policy");load_component("match_registry");load_component("camera")
    for _,name in ipairs({"state","rules","memory","audio","match","diagnostics","render","lifecycle"}) do
        load_component("gameplay_" .. name,"install")
    end
    m=ctx.flaccess.gameplay.m
elseif bundled then ctx.flaccess_audio=nil
else
    local registry_chunk=assert(loadfile(arg[3] or "FLAccess/modules/FlAccessGameplay/engine/registry.lua"))
    setfenv(registry_chunk,env);registry_chunk().init(ctx)
    local camera_chunk=assert(loadfile("FLAccess/modules/FlAccessGameplay/engine/cameraRadars.lua"))
    setfenv(camera_chunk,env)
    local profiles={}
    for i=0,9 do local f=assert(io.open(string.format("FLAccess/modules/FlAccessGameplay/engine/cameraRadars/camera_%02d.ini",i),"rb"));profiles[i]=f:read("*a");f:close() end
    camera_chunk().init(ctx,profiles)
end
m.init(ctx)
assert(ctx.flaccess_audio and ctx.flaccess_match_registry)
local peak=0
local function frame()
    tick=tick+16;m.display_frame(ctx);peak=0
    if loop_device then
        local samples=ffi.new("float[8192]");openal.alcRenderSamplesSOFT(loop_device,samples,4096)
        for i=6144,8191 do peak=math.max(peak,math.abs(tonumber(samples[i]))) end
    end
end
frame();frame();assert(scan_reads==0 and master_calls==0)
-- Native entries become ready while every heap CAMERA/FIELD ref stays inactive.
qword(fixture.entries.CAMERA.data,16,0x240000);qword(fixture.entries.FIELD.data,16,0x250000)
frame();assert(master_calls==1,"late camera/field activation never reached audio initialization")
assert(wrong_match_reads==0,"MATCH possession read exceeds its native 0x2378-byte payload; must use ANALYZE")
if render_mode then assert(peak>0.00001,"real radar pipeline rendered silence with valid pose and real WAV") end
assert(scan_reads==0,"native registry lookup must never scan the heap")
-- Raw fields/camera becoming invalid must mute, then recover using fresh reads.
float(field,8,0);frame();assert(master_calls==1)
float(field,8,34.06);frame();assert(master_calls==2)
-- Screen frame requires camera. Body heading never governs the radar.
float(camera,0x0c,0);frame();assert(master_calls==3)
float(camera,0x0c,1);float(player,0x61c,0/0);frame();assert(master_calls==4)
float(player,0x61c,0)
score[0x20]=1;frame();assert(master_calls==4)
score[0x20]=0;frame();assert(master_calls==5)
-- Lost transient native table uses only the already proven slot and current cursor.
qword(world,0x180,0);frame();assert(master_calls==6)
dword(cursor,4+0x20,255);frame();assert(master_calls==6)
dword(cursor,4+0x20,2);qword(world,0x180,0x210000)
m.context_reset(ctx);frame();frame();assert(master_calls==8)
if render_mode then
    assert(peak>0.00001)
    if modular then
        local gameplay=ctx.flaccess.gameplay
        silence_radar,silence_goals=true,true
        float(player,0x624,51)
        local endline_peak=0
        for _=1,20 do frame();endline_peak=math.max(endline_peak,peak) end
        assert(endline_peak>0.001 and source_plays[source_ids[11]]==1,"end line alert must play near the end line")
        gameplay.sound_enabled.endline=false
        for _=1,75 do frame() end
        assert(peak<0.00001,"end line toggle must silence the sound")
        print(string.format("PASS end line proximity PCM %.4f and independent toggle",endline_peak))
        float(player,0x624,10)
        silence_radar,silence_goals=false,false
        frame()
    end
    local initial=ball_point
    float(camera,0x0c,-1);float(camera,0x30,1);frame()
    assert(math.abs(ball_point[1]+initial[1])<0.0001 and math.abs(ball_point[3]+initial[3])<0.0001,"screen camera turn did not project radar")
    float(player,0x61c,90)
    for i=1,70 do frame() end
    assert(math.abs(ball_point[1]+initial[1])<0.0001 and math.abs(ball_point[3]+initial[3])<0.0001,"stationary body turn changed screen radar")
    qword(fixture.entries.CAMERA.data,16,0)
    for _,id in ipairs({7,9}) do
        camera_env[0x48]=id;float(player,0x61c,0);frame()
        assert(math.abs(ball_point[1]+3)<.0001 and math.abs(ball_point[3]+5)<.0001,"vertical view must face the attack")
        float(player,0x61c,90);frame()
        assert(math.abs(ball_point[1]+3)<.0001 and math.abs(ball_point[3]+5)<.0001,"body turn rotated vertical audio")
        teams[1][0x254],teams[2][0x254]=255,1;frame()
        assert(math.abs(ball_point[1]-3)<.0001 and math.abs(ball_point[3]-5)<.0001,"vertical view ignored the side switch")
        teams[1][0x254],teams[2][0x254]=1,255
    end
    teams[1][0x254]=0;frame()
    local vertical_gain=ffi.new("float[1]")
    openal.alGetSourcef(source_ids[1],0x100a,vertical_gain)
    assert(vertical_gain[0]==0,"unknown attack direction kept directional audio")
    teams[1][0x254]=1
    qword(fixture.entries.CAMERA.data,16,0x240000)
    camera_env[0x48]=8;frame()
    assert(math.abs(ball_point[1]+5)<.0001 and math.abs(ball_point[3]+3)<.0001,"Player ball radar ignored the camera's left side")
    float(camera,0x0c,1);float(camera,0x30,-1);frame()
    assert(math.abs(ball_point[1]-5)<.0001 and math.abs(ball_point[3]-3)<.0001,"Player ball radar ignored camera turn")
    qword(fixture.entries.CAMERA.data,16,0);frame()
    openal.alGetSourcef(source_ids[1],0x100a,vertical_gain)
    assert(vertical_gain[0]==0,"missing Player view left directional ball audible")
    qword(fixture.entries.CAMERA.data,16,0x240000)
    camera_env[0x48]=5
    float(player,0x61c,0);float(camera,0x0c,1);float(camera,0x30,-1)
    for i=1,70 do frame() end
    assert(side_rms>0.13 and side_peak<0.851,"sideline PCM compensation missing or clipped")
    local function cue_count(index) return source_plays[source_ids[index]] or 0 end
    assert(source_looping[source_ids[8]]==0 and source_looping[source_ids[4]]==0 and source_looping[source_ids[5]]==0,"possession cues loop")
    assert(cue_count(4)==0 and cue_count(5)==0,"startup emitted a false possession event")
    local expected=missing_cues and 0 or 1
    dword(analyze_info,8+0x2601c,2);frame();assert(ball_point[1]==0 and ball_point[2]==0 and ball_point[3]==0,"confirmed local possession not centered")
    assert(cue_count(4)==expected and cue_count(5)==0,"gain did not emit exactly one gotBall")
    frame();assert(cue_count(4)==expected,"held possession repeated gotBall")
    qword(fixture.entries.MATCH.data,16,0);frame()
    assert(ball_point[1]==0 and ball_point[3]==0,"ownership still depends on MATCH")
    qword(fixture.entries.MATCH.data,16,0x320000)
    dword(analyze_info,8+0x2601c,13);frame();assert(math.abs(ball_point[1])>1,"opponent possession incorrectly centered")
    assert(cue_count(5)==expected,"loss did not emit exactly one LostBall")
    dword(analyze_info,8+0x2601c,255);frame();assert(math.abs(ball_point[1])>1,"loose ball incorrectly centered")
    qword(world,0x18,0);dword(analyze_info,8+0x2601c,2);frame()
    assert(ball_point[1]==0,"typed ANALYZE binding incorrectly depends on unrelated world+18")
    local before_lost=cue_count(5)
    qword(fixture.entries.ANALYZE.data,16,0);frame();assert(math.abs(ball_point[1])>1,"missing native ANALYZE incorrectly centered")
    assert(cue_count(5)==before_lost,"unknown possession emitted false loss")
    qword(fixture.entries.ANALYZE.data,16,0x730000)
    local before_got=cue_count(4);frame();assert(cue_count(4)==before_got,"recovery emitted stale gain")
    qword(world,0x18,0x320008);dword(analyze_info,8+0x2601c,255)
    -- Unknown/broken camera must not suppress ownership events or poison another profile.
    local camera_before_lost=cue_count(5)
    camera_env[0x48]=255;dword(analyze_info,8+0x2601c,13);frame()
    assert(cue_count(5)==camera_before_lost+expected,"unknown camera suppressed LostBall")
    local camera_gain=ffi.new("float[1]")
    openal.alGetSourcef(source_ids[1],0x100a,camera_gain);assert(camera_gain[0]==0,"unknown camera left directional ball audible")
    local camera_before_got=cue_count(4)
    qword(fixture.entries.CAMERA.data,16,0);dword(analyze_info,8+0x2601c,2);frame()
    assert(cue_count(4)==camera_before_got+expected and ball_point[3]==0,"missing camera suppressed GotBall or own-ball center")
    qword(fixture.entries.CAMERA.data,16,0x240000)
    camera_env[0x48]=6;ctx.flaccess_camera_radars.profiles[6].depth_scale="invalid"
    dword(analyze_info,8+0x2601c,13);frame()
    openal.alGetSourcef(source_ids[1],0x100a,camera_gain);assert(camera_gain[0]==0,"invalid profile left directional ball audible")
    camera_env[0x48]=5;frame()
    openal.alGetSourcef(source_ids[1],0x100a,camera_gain);assert(camera_gain[0]>0,"invalid profile poisoned next camera")
    ctx.flaccess_camera_radars.profiles[6].depth_scale=1
    camera_env[0x48]=6;frame()
    openal.alGetSourcef(source_ids[1],0x100a,camera_gain);assert(camera_gain[0]>0,"repaired camera did not recover")
    camera_env[0x48]=5;dword(analyze_info,8+0x2601c,255);m.context_reset(ctx);frame()
    print("PASS camera faults isolated: invalid/missing/unknown profile mutes directions, keeps possession cues and own-ball center, next profile recovers")
    -- Isolate side loops in the test adapter, never changing production ball gain.
    silence_ball=true
    openal.alSourceStop(source_ids[4]);openal.alSourceStop(source_ids[5]);openal.alSourceStop(source_ids[8])
    float(player,0x62c,33);local positive_peak=0
    for i=1,32 do frame();positive_peak=math.max(positive_peak,peak) end
    assert(positive_peak>0.001,"positive sideline silent through a complete real WAV loop near its line")
    float(player,0x62c,-33);local negative_peak=0
    for i=1,32 do frame();negative_peak=math.max(negative_peak,peak) end
    assert(negative_peak>0.001,"negative sideline silent through a complete real WAV loop near its line")
    float(player,0x62c,0)
    for i=1,60 do frame() end
    assert(peak<0.00001,"sideline warning should fade outside its 8m zone")
    silence_ball=false;frame()
    -- Fixed goal centers, current native team direction, and silent unknown side.
    silence_ball=true
    float(player,0x624,-50);float(player,0x62c,0)
    local own_peak=0
    for i=1,40 do frame();own_peak=math.max(own_peak,peak) end
    assert(missing_goals and own_peak<0.00001 or not missing_goals and own_peak>0.001,"own goal optional WAV policy failed")
    local gain=ffi.new("float[1]")
    openal.alGetSourcef(source_ids[6],0x100a,gain);assert(missing_goals and gain[0]==0 or not missing_goals and gain[0]>0.2)
    openal.alGetSourcef(source_ids[7],0x100a,gain);assert(gain[0]<0.0001)
    local own_point=source_points[source_ids[6]]
    assert(own_point[1]<-2.5 and math.abs(own_point[3])<0.001,"goal does not target fixed center")
    float(player,0x624,50)
    local opponent_peak=0
    for i=1,40 do frame();opponent_peak=math.max(opponent_peak,peak) end
    assert(missing_goals and opponent_peak<0.00001 or not missing_goals and opponent_peak>0.001,"opponent goal optional WAV policy failed")
    openal.alGetSourcef(source_ids[7],0x100a,gain);assert(missing_goals and gain[0]==0 or not missing_goals and gain[0]>0.2)
    teams[1][0x254]=255;teams[2][0x254]=1
    for i=1,40 do frame() end
    openal.alGetSourcef(source_ids[6],0x100a,gain);assert(missing_goals and gain[0]==0 or not missing_goals and gain[0]>0.2,"phase change/optional goals failed")
    teams[1][0x254]=0;frame()
    openal.alGetSourcef(source_ids[6],0x100a,gain);assert(gain[0]==0,"unknown team direction kept goal audible")
    assert(ball_point,"unknown team direction broke ball radar")
    qword(world,0x1928,0);frame()
    openal.alGetSourcef(source_ids[6],0x100a,gain);assert(gain[0]==0,"missing team payload kept goal audible")
    qword(world,0x1928,0x700000)
    teams[1][0x254]=1;teams[2][0x254]=255
    local away_player=block(0x720000,0x630)
    ffi.copy(away_player,player,0x630);dword(away_player,0x18,11)
    float(away_player,0x61c,180)
    qword(players,11*8,0x720000)
    dword(controls,0x20,11);dword(cursor,4+0x20,11)
    for i=1,40 do frame() end
    openal.alGetSourcef(source_ids[6],0x100a,gain)
    assert(missing_goals and gain[0]==0 or not missing_goals and gain[0]>0.2,"local away team goal not mapped")
    assert(source_points[source_ids[6]][1]>2.5,"actor body heading changed screen goal projection")
    dword(controls,0x20,2);dword(cursor,4+0x20,2)
    float(player,0x624,10);silence_ball=false;silence_goals=true
    for i=1,40 do frame() end
    print(string.format("PASS fixed goals isolated PCM own=%.6f opponent=%.6f; current team direction/swap/unknown; screen alignment and body-turn independence",own_peak,opponent_peak))
    -- Changing controlled player to the native holder must emit gotBall.
    local another_player=block(0x680000,0x630)
    ffi.copy(another_player,player,0x630);dword(another_player,0x18,7)
    qword(players,7*8,0x680000)
    dword(analyze_info,8+0x2601c,7);frame() -- Current actor 2 remains without possession.
    before_got=cue_count(4);dword(controls,0x20,7);dword(cursor,4+0x20,7);frame()
    assert(cue_count(4)==before_got+expected,"switch to native holder did not emit gotBall")
    frame();assert(cue_count(4)==before_got+expected,"switch cue repeated")
    -- Pause/unknown/startup establish fresh baselines rather than making fake events.
    score[0x20]=1;frame();dword(analyze_info,8+0x2601c,255);score[0x20]=0
    before_lost=cue_count(5);frame();assert(cue_count(5)==before_lost,"resume invented loss")
    master_muted=true;dword(analyze_info,8+0x2601c,7);before_got=cue_count(4);frame()
    master_muted=false;frame();assert(cue_count(4)==before_got,"muted transition replayed after unmute")
    dword(analyze_info,8+0x2601c,255);frame()
    have_stats=false;frame();have_stats=true;dword(analyze_info,8+0x2601c,7)
    before_got=cue_count(4);frame();assert(cue_count(4)==before_got,"match re-entry invented gain")
    silence_radar=true
    local function cue_pcm(keeper,index)
        dword(analyze_info,8+0x2601c,keeper);local maximum=0
        for i=1,4 do frame();maximum=math.max(maximum,peak) end
        if not missing_cues then
            assert(maximum>0.0001,"isolated possession WAV rendered silence")
            local status=ffi.new("int[1]");openal.alGetSourcei(source_ids[index],0x1010,status)
            -- Render to completion offline; cue durations differ between
            -- real WAV assets. This advances PCM, never sleeps in wall time.
            for _=1,120 do
                if status[0]==0x1014 then break end
                frame();openal.alGetSourcei(source_ids[index],0x1010,status)
            end
            assert(status[0]==0x1014,"possession WAV did not finish naturally")
        else assert(maximum<0.00001,"missing optional cues generated audio") end
        return maximum
    end
    local lost_peak=cue_pcm(13,5)
    local got_peak=cue_pcm(7,4)
    silence_radar=false
    -- Actor zero is valid. The fix changes the source, never excludes player 0.
    local player_zero=block(0x780000,0x630)
    ffi.copy(player_zero,player,0x630);dword(player_zero,0x18,0)
    qword(players,0,0x780000)
    local before_team=cue_count(8)
    before_got=cue_count(4)
    local before_lost_pass=cue_count(5)
    dword(analyze_info,8+0x2601c,255);frame()
    dword(controls,0x20,0);dword(cursor,4+0x20,0);frame()
    assert(cue_count(4)==before_got and cue_count(5)==before_lost_pass and cue_count(8)==before_team,"pass flight emitted false possession cue")
    silence_radar=true
    dword(analyze_info,8+0x2601c,0)
    local team_peak=0
    for i=1,4 do frame();team_peak=math.max(team_peak,peak) end
    if not missing_cues and not missing_team then assert(team_peak>0.0001,"isolated team WAV rendered silence")
    else assert(team_peak<0.00001,"missing optional team WAV generated sound") end
    local team_status=ffi.new("int[1]");openal.alGetSourcei(source_ids[8],0x1010,team_status)
    assert(team_status[0]~=0x1012,"team cue did not finish naturally")
    silence_radar=false
    print(string.format("PASS pass flight/assisted switch: only team cue; no lost/got pair; team PCM=%.6f",team_peak))
    assert(cue_count(4)==before_got and cue_count(8)==before_team+((missing_cues or missing_team) and 0 or 1) and ball_point[1]==0,"player zero pass did not emit only team cue")
    dword(analyze_info,8+0x2601c,7);frame()
    tick=tick+1000;frame()
    local found_structure=false
    for _,line in ipairs(logs) do
        if line:find("keeper-source=ANALYZE/INFO",1,true) and line:find("keeper=7",1,true) then found_structure=true end
    end
    assert(found_structure,"ANALYZE source diagnostic missing")
    assert(wrong_match_reads==0,"out-of-bounds MATCH read returned")
    print(string.format("PASS possession one-shots: isolated lost PCM peak=%.6f got=%.6f; native transitions, held-state suppression, player switch, unknown/recovery, pause/re-entry, muted transitions%s",lost_peak,got_peak,missing_cues and "; optional WAVs absent, radar preserved" or ""))
    -- A teammate receipt while muted is consumed, never replayed on unmute.
    dword(controls,0x20,0);dword(cursor,4+0x20,0);dword(analyze_info,8+0x2601c,0)
    m.context_reset(ctx);frame()
    local muted_team_before=cue_count(8)
    master_muted=true;dword(analyze_info,8+0x2601c,255);frame()
    dword(controls,0x20,7);dword(cursor,4+0x20,7);dword(analyze_info,8+0x2601c,7);frame()
    master_muted=false;frame();assert(cue_count(8)==muted_team_before,"muted team handoff replayed late")
    master_muted=true;frame();assert(peak<0.000001,"muted radar rendered nonzero PCM")
    master_muted=false;master_volume=0;frame();assert(peak<0.000001,"zero-volume radar rendered nonzero PCM")
    master_volume=0.4;frame();assert(peak>0.00001,"radar failed to resume after unmute")
    -- Experimental tackle proximity: real continuous PCM, not native tackle certainty.
    silence_radar=true;silence_goals=true
    float(ball,0x10,11);float(ball,0x14,0.1);float(ball,0x18,0)
    dword(analyze_info,8+0x2601c,13);frame()
    openal.alSourceStop(source_ids[4]);openal.alSourceStop(source_ids[5]);openal.alSourceStop(source_ids[8])
    local tackle_start=cue_count(9);local tackle_peak=0
    for i=1,12 do frame();tackle_peak=math.max(tackle_peak,peak) end
    local playing=ffi.new("int[1]")
    openal.alGetSourcei(source_ids[9],0x1010,playing)
    assert(source_looping[source_ids[9]]==1,"tackle alert is not a loop")
    if not missing_tackle then
        assert(tackle_start>0 and cue_count(9)==tackle_start and tackle_peak>0.0001 and playing[0]==0x1012,"tackle WAV did not loop continuously")
        local target=source_points[source_ids[9]];assert(target[1]>0.9,"tackle loop does not follow ball direction")
    else assert(tackle_peak<0.00001 and tackle_start==0,"missing tackle WAV generated audio") end
    if modular and not missing_tackle then
        local settings=ctx.flaccess.gameplay.tackle_settings
        local previous=settings.volume
        settings.volume=m.tackle_settings("tackle_volume=3").volume
        assert(settings.volume==3,"maximum tackle gain was not accepted")
        local boosted=0
        for _=1,12 do frame();boosted=math.max(boosted,peak) end
        assert(boosted>tackle_peak*2 and boosted<=1.001,"maximum gain must get louder and stay within the output limit")
        settings.volume=previous
        for _=1,12 do frame() end
        print(string.format("PASS 300%% tackle PCM peak %.4f, normal %.4f",boosted,tackle_peak))
    end
    float(ball,0x10,12.2);frame()
    openal.alGetSourcei(source_ids[9],0x1010,playing)
    if not missing_tackle then assert(playing[0]==0x1012,"tackle hysteresis failed") end
    float(ball,0x10,12.5);frame();assert(peak<0.00001,"tackle loop did not stop outside zone")
    float(ball,0x10,12.2);frame();assert(peak<0.00001,"tackle loop re-entered before enter threshold")
    float(ball,0x10,11);float(ball,0x14,2);frame();assert(peak<0.00001,"high ball enabled tackle warning")
    float(ball,0x14,0.1);dword(analyze_info,8+0x2601c,2);frame();assert(peak<0.00001,"teammate enabled tackle warning")
    dword(analyze_info,8+0x2601c,255);frame();assert(peak<0.00001,"loose ball enabled opponent warning")
    qword(fixture.entries.ANALYZE.data,16,0);frame();assert(peak<0.00001,"unknown holder enabled opponent warning")
    qword(fixture.entries.ANALYZE.data,16,0x730000);dword(analyze_info,8+0x2601c,13);frame()
    master_muted=true;frame();assert(peak<0.00001,"tackle loop ignored game mute")
    master_muted=false;frame();if not missing_tackle then assert(peak>0.0001,"tackle loop failed to resume") end
    master_volume=0;frame();assert(peak<0.00001,"tackle loop ignored zero app volume")
    master_volume=0.4;frame()
    score[0x20]=1;frame();assert(peak<0.00001,"tackle loop ignored pause")
    score[0x20]=0;frame()
    m.context_reset(ctx);frame()
    float(ball,0x10,15);float(ball,0x18,8);silence_radar=false;frame()
    print(string.format("PASS experimental tackle proximity loop PCM=%.6f: repeat, direction, hysteresis, high/loose/friendly/unknown exclusion, mute/pause/reset%s",tackle_peak,missing_tackle and "; WAV absent preserves radar" or ""))
    print(string.format("PASS full radar render: real WAV/HRTF, both sidelines isolated, normalized PCM rms=%.4f peak=%.4f, native keeper identity/unknown, master mute/zero/resume; final PCM peak=%.6f; offline, no audible output",side_rms,side_peak,peak))
    -- A stopped spatial loop must recover after valid playback resumes, but
    -- an already playing loop and one-shot cues must not restart each frame.
    openal.alSourceStop(source_ids[1]);local count=source_plays[source_ids[1]] or 0
    frame();local state=ffi.new("int[1]");openal.alGetSourcei(source_ids[1],0x1010,state)
    assert(state[0]==0x1012 and (source_plays[source_ids[1]] or 0)==count+1,"stopped radar loop did not recover")
    frame();assert((source_plays[source_ids[1]] or 0)==count+1,"playing loop restarted every frame")
end
if modular then
    local gameplay=ctx.flaccess.gameplay
    local reader=ctx.flaccess.reader
    local tone=ffi.new("int16_t[4800]")
    for i=0,4799 do tone[i]=math.floor(12000*math.sin(2*math.pi*200*i/48000)) end
    for _,speed in ipairs({25,50,200}) do
        local stretched,frames=m.stretch_sound(tone,4800,48000,speed)
        assert(frames==4800*100/speed)
        local cycles=0
        for i=1,frames-1 do
            if stretched[i]>0 and stretched[i-1]<=0 then cycles=cycles+1 end
        end
        assert(math.abs(cycles/(frames/48000)-200)<15,"tempo shifted tone frequency")
    end
    local function check_speed(key,source_index,speed)
        local sound=gameplay.sound_buffers[key]
        local value=ffi.new("int[1]")
        local source=source_ids[source_index+1]
        openal.alGetSourcei(source,0x1009,value) -- AL_BUFFER
        assert(value[0]==sound.buffer)
        openal.alGetBufferi(sound.buffer,0x2004,value) -- AL_SIZE
        assert(value[0]==2*math.floor(sound.frames*100/speed+0.5),"speed must change the buffer duration")
        openal.alGetBufferi(sound.buffer,0x2001,value) -- AL_FREQUENCY
        assert(value[0]==sound.rate,"tempo must preserve the sample rate")
        local pitch=ffi.new("float[1]")
        openal.alGetSourcef(source,0x1003,pitch)
        assert(pitch[0]==1,"tempo must preserve pitch")
    end
    if render_mode then
        reader.overlay_visible=true
        gameplay.ball_speed=25
        gameplay.sound_preview_request="ball"
        gameplay.process_sound_preview(ctx)
        assert(source_plays[source_ids[10]]==1)
        check_speed("ball",9,25)
        reader.overlay_visible=false
        gameplay.process_sound_preview(ctx)
        assert(not gameplay.preview_active)
        gameplay.ball_speed=100
    end
    local roster_home,roster_away=block(0x7a0000,0x30),block(0x7b0000,0x30)
    qword(block(0x201978,0x30),0,0x7a0000)
    qword(regions[#regions].data,0x28,0x7b0000)
    dword(roster_home,4+2*4,12)
    dword(roster_away,0,1)
    dword(roster_away,4+2*4,23)
    qword(block(base+0x3705e10,8),0,0x7c0000)
    qword(block(0x7c0050,8),0,0x800000)
    local function player_record(side,slot,id,name)
        local record=block(0x800000+0x35960+0x1308+(side*40+slot)*0x188,0x148)
        dword(record,0x30,id)
        ffi.copy(record+0x38,name,#name)
    end
    player_record(0,12,1212,"Mohamed Salah")
    player_record(1,23,2323,"Pedri")
    for side,name in ipairs({"Liverpool","Barcelona"}) do
        local team=block(0x800000+0x35960+0x138+(side-1)*0x690,0x428)
        dword(team,0,(side+100)*0x4000)
        ffi.copy(team+4,name,#name)
        team[0x426]=40
        team[0x29a+23*2]=8
    end
    gameplay.match_names_supported=true
    gameplay.shirt_number_supported=true
    reader.a11y={possession_interval=5,ui_language="pt",native_speech_last=0,native_speech_queue={}}
    reader.speak=function(text,interrupt)
        local queue=reader.a11y
        queue.native_speech_last=queue.native_speech_last+1
        queue.native_speech_queue[queue.native_speech_last]={text=text,interrupt=interrupt}
    end
    m.context_reset(ctx)
    dword(analyze_info,8+0x2601c,2)
    have_stats=true;score[0x20]=0;score[0x22]=1
    frame()
    local queue=reader.a11y.native_speech_queue
    assert(queue[1] and queue[1].text=="Mohamed Salah")
    dword(analyze_info,8+0x2601c,13)
    frame();assert(#queue==1)
    reader.a11y.possession_number=true
    tick=tick+5000;frame();assert(queue[2].text=="8 Pedri")
    tick=tick+5000;frame();assert(#queue==2)
    dword(analyze_info,8+0x2601c,255)
    tick=tick+5000;frame();assert(#queue==2)
    dword(analyze_info,8+0x2601c,2)
    tick=tick+100;frame();assert(#queue==3 and queue[3].text:find("Mohamed Salah",1,true))
    reader.a11y.possession_interval=1
    dword(analyze_info,8+0x2601c,13)
    tick=tick+900;frame();assert(#queue==3)
    tick=tick+100;frame();assert(#queue==4 and queue[4].text:find("Pedri",1,true))
    reader.a11y.possession_interval=0
    dword(analyze_info,8+0x2601c,2)
    tick=tick+5000;frame();assert(#queue==4)
    env.match.stats=function()return {ptr=ffi.cast("void*",0x300000),clock_minutes=42,home_score=0,away_score=1} end
    ctx.home_team,ctx.away_team=101,102
    assert(m.announce_scoreboard(ctx) and queue[5].text=="42 minutos. Liverpool 0, Barcelona 1.")
    ctx.away_team=103
    assert(not m.announce_scoreboard(ctx) and #queue==5)
    reader.a11y.possession_interval=-1
    reader.a11y.possession_number=false
    frame();assert(queue[6].text=="Mohamed Salah" and queue[6].interrupt)
    dword(analyze_info,8+0x2601c,13)
    frame();assert(queue[7].text=="Pedri" and queue[7].interrupt)
    frame();assert(#queue==7)
    reader.a11y.controlled_player=true
    local simultaneous={actor=2,keeper=2,possession_known=true}
    assert(gameplay.poll_controlled_player(ctx,tick,true,simultaneous))
    gameplay.poll_ball_holder(ctx,tick,true,simultaneous,true)
    assert(#queue==8 and queue[8].text=="Mohamed Salah" and queue[8].controlled_actor==2)
    assert(not gameplay.poll_controlled_player(ctx,tick,true,simultaneous))
    if render_mode then
        assert(gameplay.control_earcon_pending(queue[8],tick),"control cue did not start before speech")
        local pcm=ffi.new("float[8192]")
        for _=1,4 do openal.alcRenderSamplesSOFT(loop_device,pcm,4096) end
        assert(not gameplay.control_earcon_pending(queue[8],tick+100),"cue must release the announcement after playback")
        assert(source_plays[source_ids[12]]==1,"control cue must play once")
    end
    ctx.away_team=102
    score[0x20]=1
    assert(not m.announce_scoreboard(ctx))
    assert(m.announce_scoreboard(ctx,"pause-test") and queue[9].pause_header=="pause-test")
    score[0x20]=0
    for position=0,10 do
        dword(roster_home,4+position*4,position)
        dword(roster_away,4+position*4,position)
    end
    player_record(0,1,1011,"Alexander-Arnold")
    player_record(1,1,2011,"Gavi")
    local function sample_substitutions(playing)
        tick=tick+125;gameplay.poll_substitutions(ctx,tick,playing)
    end
    sample_substitutions(true);sample_substitutions(true)
    assert(#queue==9,"initial lineup is not a substitution")
    dword(roster_home,4,2);dword(roster_home,12,0)
    sample_substitutions(true);sample_substitutions(true)
    assert(#queue==9,"changing formation is not a substitution")
    dword(roster_home,8,12);dword(roster_away,8,23)
    sample_substitutions(false);assert(#queue==9)
    sample_substitutions(true);sample_substitutions(true)
    assert(queue[10].text=="Liverpool. Sai Alexander-Arnold. Entra Mohamed Salah.")
    assert(queue[11].text=="Barcelona. Sai Gavi. Entra Pedri.")
    sample_substitutions(true);assert(#queue==11,"unchanged lineup must not repeat")
    print("PASS match announcements: live lineup, interval, unchanged/loose ball, off, home-first scoreboard and team identity")
    if render_mode then
        local positions={[2]={10,0,5},[3]={14,0,5},[4]={10,0,12},[12]={16,0,5},[13]={0,0,5}}
        local entries={}
        for id,position in pairs(positions) do
            local address=0x900000+id*0x1000
            local entry=block(address,0x630)
            qword(entry,0,base+0x26329a8);dword(entry,0x18,id)
            for axis=1,3 do float(entry,0x624+(axis-1)*4,position[axis]) end
            qword(players,id*8,address)
            entries[id]=entry
        end
        for _,id in ipairs({0,7,11}) do qword(players,id*8,0) end
        dword(controls,0x20,2);camera_env[0x48]=5
        local radar=gameplay.radar
        radar.enabled,radar.radius,radar.mode,radar.opponent_count=1,10,1,1
        local state=assert(gameplay.pose())
        local targets=gameplay.m.player_radar_targets(positions,2,state.player,radar,{})
        assert(not targets[2] and targets[3].group=="marked" and targets[4].group=="free")
        assert(targets[12].group=="opponent" and not targets[13],"count mode must keep the nearest opponent")
        radar.mode=0
        targets=gameplay.m.player_radar_targets(positions,2,state.player,radar,{})
        assert(targets[12] and targets[13],"distance mode must ignore the count")
        radar.radius,radar.marked_enabled=9,0
        targets=gameplay.m.player_radar_targets(positions,2,state.player,radar,{})
        assert(not targets[3] and not targets[13] and targets[4] and targets[12],"radius and group switch must apply")
        radar.marked_enabled=1
        state.keeper,state.possession_known,state.owns_ball=3,true,false
        gameplay.sound_speeds.marked=50
        assert(gameplay.play_pose(state,0.016,nil,tick+250))
        assert(gameplay.radar_active and gameplay.radar_active.id==3 and source_plays[source_ids[13]]==1,
            "nearest radar target must play its WAV through OpenAL")
        check_speed("marked",12,50)
        local pcm=ffi.new("float[8192]")
        for _=1,5 do openal.alcRenderSamplesSOFT(loop_device,pcm,4096) end
        assert(gameplay.play_pose(state,0.016,nil,tick+650))
        assert(gameplay.radar_active and gameplay.radar_active.id==12,"interleaving must let another target play")
        state.keeper,state.tackle_active=12,true
        assert(gameplay.play_pose(state,0.016,nil,tick+660))
        local playing=ffi.new("int[1]")
        openal.alGetSourcei(source_ids[13],0x1010,playing)
        assert(not gameplay.radar_active and playing[0]~=0x1012,"opponent possession must stop player radar immediately")
        if not missing_tackle then
            openal.alGetSourcei(source_ids[9],0x1010,playing)
            assert(playing[0]==0x1012,"player radar suppression must preserve tackle audio")
        end
        openal.alGetSourcei(source_ids[1],0x1010,playing)
        assert(playing[0]==0x1012,"player radar suppression must preserve ball audio")
        state.keeper,state.tackle_active=255,false
        assert(gameplay.play_pose(state,0.016,nil,tick+670) and not gameplay.radar_active)
        state.keeper=3
        assert(gameplay.play_pose(state,0.016,nil,tick+680) and gameplay.radar_active,
            "player radar must resume when a teammate receives the ball")
        state.possession_known=false
        assert(gameplay.play_pose(state,0.016,nil,tick+690) and not gameplay.radar_active)
        radar.enabled=0
        float(entries[12],0x624,12.5)
        state.owns_ball=true
        assert(gameplay.play_pose(state,0.016,nil,tick+800))
        assert(source_plays[source_ids[14]]==1 and source_points[source_ids[14]][1]>0,
            "pressure cue must point toward the nearby opponent with the main radar off")
        state.owns_ball=false
        assert(gameplay.play_pose(state,0.016,nil,tick+810))
        local pressure_state=ffi.new("int[1]")
        openal.alGetSourcei(source_ids[14],0x1010,pressure_state)
        assert(pressure_state[0]~=0x1012,"pressure cue must stop when possession is lost")
        radar.enabled=1
        gameplay.mute()
        assert(not gameplay.radar_active and not gameplay.radar_sample,"mute must clear the radar")
        reader.overlay_visible=true
        gameplay.sound_speeds.free=150
        radar.free_volume=300
        gameplay.sound_preview_request="free"
        gameplay.process_sound_preview(ctx)
        assert(gameplay.preview_active,"fixed radar sound must be audible from the settings")
        check_speed("free",9,150)
        local preview_value=ffi.new("float[1]")
        openal.alGetSourcef(source_ids[10],0x100a,preview_value)
        assert(math.abs(preview_value[0]-.9)<.001,"radar preview must support 300 percent volume")
        reader.overlay_visible=false
        gameplay.process_sound_preview(ctx)
        state.possession_known=true
        gameplay.sound_speeds.sidelines=200
        assert(gameplay.play_pose(state,0.016,nil,tick+850))
        check_speed("sidelines",1,200)
        check_speed("sidelines",2,200)
        local real_get_error=gameplay.al.alGetError
        local calls=0
        gameplay.al.alGetError=function()
            calls=calls+1
            if calls==2 then return 0xa003 end
            return real_get_error()
        end
        assert(gameplay.play_pose(state,0.016,nil,tick+700))
        assert(not gameplay.radar_active and gameplay.sources and not gameplay.disabled,
            "player radar errors must leave the other audio active")
        gameplay.al.alGetError=function() return 0xa003 end
        assert(not gameplay.play_pose(state,0.016,nil,tick+720))
        assert(not gameplay.disabled and not gameplay.sources,"base audio must recover without disabling match data")
        loop_context,loop_device=nil,nil
        player_record(0,3,1013,"Ronaldinho")
        dword(analyze_info,8+0x2601c,3)
        frame()
        assert(queue[12] and queue[12].text=="Ronaldinho","an audio reset must not stop announcements for new holders")
        score[0x22]=0 -- Card ceremonies can stop the match clock.
        dword(cards,0,1);dword(cards,4,0);dword(cards,0x14,3);card_count[0]=1
        tick=tick+100;frame()
        assert(queue[13] and queue[13].match_card and queue[13].text=="Cartão amarelo para Ronaldinho")
        dword(cards,40,1);dword(cards,44,1);dword(cards,40+0x14,23);cards[40+0x18]=1;card_count[0]=2
        tick=tick+100;frame()
        assert(queue[14] and queue[14].text=="Cartão vermelho para Pedri")
        tick=tick+100;frame();assert(#queue==14,"unchanged card history must not repeat")
        gameplay.al.alGetError=real_get_error
        env.match.stats=function() return nil end
        dword(flow,0xf0,52)
        local windows={}
        reader.a11y.native_windows={windows=windows}
        qword(fixture.entries.CURSOR.data,16,0)
        tick=tick+1200;frame()
        assert(ctx.flaccess.match_playing and gameplay.status=="training radar active",
            "free training must render without Sider stats or CURSOR/INFO")
        windows[1]={enabled=true,slot=0,vtable=base+0x25ad750}
        frame();assert(not ctx.flaccess.match_playing and gameplay.audio_muted)
        windows[1]=nil
        frame();assert(ctx.flaccess.match_playing and not gameplay.audio_muted)
        dword(flow,0xf0,51)
        windows[1]={enabled=true,slot=0,vtable=base+0x267e750}
        frame();assert(ctx.flaccess.match_playing,"skills instructions must not mute gameplay")
        dword(flow,0xf0,7)
        frame();assert(not ctx.flaccess.match_playing and gameplay.audio_muted)
        print("PASS player radar: fixed WAVs, range, count, interleaving, mute, preview and audio fault isolation")
        print("PASS pressure alert only on possession and card history speaks yellow and red once")
    end
end
if loop_device then
    openal.alcMakeContextCurrent(nil)
    openal.alcDestroyContext(loop_context);openal.alcCloseDevice(loop_device)
end
ffi.load=real_load
print("PASS gameplay lifecycle in restricted Sider globals: native entries with inactive heap refs, no heap scan, invalid/recovered field and camera; body independent, pause/resume, fresh cursor, context reset; synthetic memory, not audible game proof")
