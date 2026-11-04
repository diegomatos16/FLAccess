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
qword(block(base+0x36f3fc0+2*8,8),0,0x220000)
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
qword(world,0x18,0x320008)
local camera_env=block(0x790000,0x49);camera_env[0x48]=5
local fixture=fixture_chunk()(block,qword,base,{BALL=0x230000,CAMERA=0x240000,FIELD=0x250000,CURSOR=0x260000,MATCH=0x320000,ANALYZE=0x730000,MATCH_ENV=0x790000})
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
    return setmetatable({alcCreateContext=function(device)
        -- Test-only loopback format. Production device/attributes are untouched.
        loop_context=openal.alcCreateContext(device,ffi.new("int[9]",{0x1992,1,0x1007,48000,0x1990,0x1501,0x1991,0x1406,0}))
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
                return io.open((arg[5] or "FLAccess/livecpk/FlAccessGameplay/sounds/") .. assert(path:match("([^\\]+%.wav)$")),mode)
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
    local initial=ball_point
    float(camera,0x0c,-1);float(camera,0x30,1);frame()
    assert(math.abs(ball_point[1]+initial[1])<0.0001 and math.abs(ball_point[3]+initial[3])<0.0001,"screen camera turn did not project radar")
    float(player,0x61c,90)
    for i=1,70 do frame() end
    assert(math.abs(ball_point[1]+initial[1])<0.0001 and math.abs(ball_point[3]+initial[3])<0.0001,"stationary body turn changed screen radar")
    -- Confirmed FL27 Player=8 uses the body, not visual camera rotation.
    camera_env[0x48]=8;float(player,0x61c,0);frame()
    assert(math.abs(ball_point[1]-5)<.0001 and math.abs(ball_point[3]+3)<.0001,"Player yaw zero has wrong bearings")
    float(player,0x61c,90);frame()
    assert(math.abs(ball_point[1]+3)<.0001 and math.abs(ball_point[3]+5)<.0001,"Player body turn ignored")
    qword(fixture.entries.CAMERA.data,16,0);frame()
    assert(math.abs(ball_point[1]+3)<.0001 and math.abs(ball_point[3]+5)<.0001,"Player still depends on view matrix")
    qword(fixture.entries.CAMERA.data,16,0x240000)
    float(player,0x61c,0/0);frame();assert(peak<.00001,"invalid Player heading kept directional audio")
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
    qword(block(base+0x36f3fc0+11*8,8),0,0x720000)
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
    qword(block(base+0x36f3fc0+7*8,8),0,0x680000)
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
    qword(block(base+0x36f3fc0,8),0,0x780000)
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
    openal.alcDestroyContext(loop_context);openal.alcCloseDevice(loop_device)
end
ffi.load=real_load
print("PASS gameplay lifecycle in restricted Sider globals: native entries with inactive heap refs, no heap scan, invalid/recovered field and camera; body independent, pause/resume, fresh cursor, context reset; synthetic memory, not audible game proof")
