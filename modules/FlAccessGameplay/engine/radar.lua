-- Local gameplay experiment 1. All positions come from the running game.
local m={version="0.1.0 experiment 16"}
local shared_audio,registry_api,registry_reason,camera_api
local camera_source_supported=false
local possession_supported=false
local al,kernel,root,asset_root,library_root,base,process,buffer,got,device,context,sources,buffers
local disabled,busy,was_match=false,false,false
local last_frame,status
local next_diagnostic,next_layout,next_state_diagnostic=0,0,0
local enabled=false
local references={}
local read_failure
local cursor_slot
local gains={0,0,0,0,0}
local loop_sources={0,1,2,5,6}
local goal_ready={}
local heading_previous
local possession_previous
local cue_ready={}
local tackle_settings,tackle_previous,tackle_playing,tackle_ready
local cue_sources={gotBall=3,LostBall=4,teamStillWithBall=7}
local cue_buffers={gotBall=2,LostBall=3,teamStillWithBall=6}
local CAPACITY=512*1024
local GAME_ROOT,PLAYERS,PLAYER_VTABLE=0x36f3dc8,0x36f3fc0,0x26329a8
local function report(text) log("[FlAccessGameplay] " .. text) end
local function transition(text) if status~=text then status=text;report(text) end end
local function finite(x) return x==x and x>-math.huge and x<math.huge end
local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function unit(v)
    local n=math.sqrt(dot(v,v))
    if finite(n) and n>0.001 then return {v[1]/n,v[2]/n,v[3]/n} end
end
function m.project(d,r,u,f) return {dot(d,r),dot(d,u),-dot(d,f)} end
function m.horizontal_basis(right,forward)
    local r=unit({right[1],0,right[3]})
    if not r then return nil end
    local f={r[3],0,-r[1]}
    if dot(f,forward)<-0.001 then return nil end
    return r,{0,1,0},f
end
-- Native Player+61c is degrees around Y: 0 faces +Z, 90 faces +X.
-- The model consumer 923572 -> 1eb56d0 receives this exact angle.
function m.body_basis(degrees)
    if not degrees or not finite(degrees) or degrees<0 or degrees>=360 then return nil end
    local yaw=degrees*math.pi/180
    return {math.cos(yaw),0,-math.sin(yaw)},{0,1,0},{math.sin(yaw),0,math.cos(yaw)}
end
function m.smooth_heading(previous,actor,degrees,dt)
    if not previous or previous.actor~=actor then return {actor=actor,degrees=degrees} end
    local delta=(degrees-previous.degrees+180)%360-180
    return {actor=actor,degrees=(previous.degrees+delta*(1-math.exp(-math.min(math.max(dt,0),0.1)/0.08)))%360}
end
function m.ball_point(d,r,u,f,owns_ball)
    if owns_ball then return {0,0,-1} end
    return m.project(d,r,u,f)
end
function m.normalization_factor(rms,peak)
    if not finite(rms) or not finite(peak) or rms<=0 or peak<=0 then return nil end
    return math.min(0.18/rms,0.85/peak)
end
function m.possession_change(previous,actor,keeper,known)
    if not known then return nil,nil end
    local current={actor=actor,keeper=keeper}
    if not previous or math.floor(previous.actor/11)~=math.floor(actor/11) then return current,nil end
    current.pending_actor=previous.pending_actor
    current.handoff_notice=previous.handoff_notice
    local owns=keeper==actor
    if previous.keeper==previous.actor and (previous.actor~=actor or previous.keeper~=keeper) then
        current.pending_actor=previous.actor
    end
    -- A pass travels through a loose-ball interval. Classify only its recipient.
    if keeper==255 then return current,nil end
    if math.floor(keeper/11)~=math.floor(actor/11) then
        local lost=current.pending_actor~=nil or current.handoff_notice
        current.pending_actor=nil;current.handoff_notice=nil
        return current,lost and "LostBall" or nil
    end
    local cue
    if current.pending_actor~=nil then
        if keeper~=current.pending_actor or not owns then
            cue="teamStillWithBall";current.handoff_notice=not owns
        elseif owns then cue="gotBall";current.handoff_notice=nil end
        current.pending_actor=nil
    elseif owns and (previous.keeper~=previous.actor or previous.actor~=actor)
        and not current.handoff_notice then
        cue="gotBall"
    end
    if owns then current.handoff_notice=nil end
    return current,cue
end
function m.tackle_settings(text)
    local settings={enabled=true,distance=2,exit_distance=2.3,max_ball_height=1,volume=0.3}
    text="\n" .. (text or "")
    local function value(key)
        return tonumber(text:match("[\r\n]%s*" .. key .. "%s*=%s*([^\r\n;#]+)"))
    end
    local enabled=value("tackle_enabled")
    if enabled==0 then settings.enabled=false end
    for _,rule in ipairs({{"distance",0.5,5},{"exit_distance",0.5,6},{"max_ball_height",0.1,1},{"volume",0,1}}) do
        local v=value("tackle_" .. rule[1])
        if v and finite(v) and v>=rule[2] and v<=rule[3] then settings[rule[1]]=v end
    end
    if settings.exit_distance<settings.distance then settings.exit_distance=settings.distance+0.3 end
    return settings
end
function m.tackle_proximity(previous,actor,keeper,known,player,ball,settings)
    local current={actor=actor,active=false}
    if not settings.enabled or not known or not keeper or keeper==255
        or math.floor(keeper/11)==math.floor(actor/11) then return current end
    if ball[2]>settings.max_ball_height or math.abs(ball[2]-player[2])>settings.max_ball_height then return current end
    local radius=previous and previous.actor==actor and previous.active and settings.exit_distance or settings.distance
    local dx,dz=ball[1]-player[1],ball[3]-player[3]
    current.active=dx*dx+dz*dz<=radius*radius
    return current
end
function m.proximity(distance,radius)
    local t=math.max(0,math.min(1,1-distance/radius));return t*t*(3-2*t)
end
local function blob(address,size)
    if not address or address<65536 or address>=140737488355328 or size>CAPACITY then
        read_failure="invalid pointer=" .. tostring(address) .. " size=" .. tostring(size)
        return nil
    end
    got[0]=0
    if kernel.ReadProcessMemory(process,ffi.cast("const void*",address),buffer,size,got)==0 or tonumber(got[0])~=size then
        read_failure=string.format("address=%x size=%d read=%d error=%d",address,size,tonumber(got[0]),tonumber(kernel.GetLastError()))
        return nil
    end
    return ffi.string(buffer,size)
end
local number64,number32,number_float=ffi.new("uint64_t[1]"),ffi.new("uint32_t[1]"),ffi.new("float[1]")
local function ptr(data,o)
    if not data or #data<o+8 then return nil end
    ffi.copy(number64,data:sub(o+1,o+8),8);return tonumber(number64[0])
end
local function uint(data,o)
    if not data or #data<o+4 then return nil end
    ffi.copy(number32,data:sub(o+1,o+4),4);return tonumber(number32[0])
end
local function float(data,o)
    if not data or #data<o+4 then return nil end
    ffi.copy(number_float,data:sub(o+1,o+4),4)
    local v=tonumber(number_float[0]);if finite(v) then return v end
end
local function vector(data,o)
    local x,y,z=float(data,o),float(data,o+4),float(data,o+8)
    if x and y and z then return {x,y,z} end
end
local function valid_position(v) return v and math.abs(v[1])<150 and v[2]>-10 and v[2]<100 and math.abs(v[3])<120 end
function m.controlled_slot(data)
    if not data or #data<24*0x74 then return nil,"control-table-unavailable" end
    local selected,slot
    for i=0,23 do
        local o=i*0x74;local actor=uint(data,o+0x20)
        -- Native cursor consumer 0x440960 excludes records whose byte +6 != 0.
        if data:byte(o+7)==0 and actor and actor<22 then
            if selected~=nil then return nil,"multiple-controlled-players" end
            selected,slot=actor,i
        end
    end
    if selected==nil then return nil,"controlled-player-unavailable" end
    return selected,slot
end
function m.cursor_actor(data,slot)
    if not data or not slot or slot<0 or slot>=24 then return nil end
    -- Registry header is 4 bytes; CursorInfo records match the native 0x74 stride.
    local actor=uint(data,4+slot*0x74+0x20)
    if actor and actor<22 then return actor end
end
local function mute()
    tackle_playing=false
    gains={0,0,0,0,0}
    if sources then
        al.alcMakeContextCurrent(context)
        for i=0,8 do
            al.alSourcef(sources[i],0x100a,0)
            if i==3 or i==4 or i==7 or i==8 then al.alSourceStop(sources[i]) end
        end
    end
end
local function cleanup()
    if context~=nil then
        al.alcMakeContextCurrent(context)
        if sources then for i=0,8 do al.alSourceStop(sources[i]) end;al.alDeleteSources(9,sources);sources=nil end
        if buffers then al.alDeleteBuffers(8,buffers);buffers=nil end
        al.alcMakeContextCurrent(nil);al.alcDestroyContext(context);context=nil
    end
    if device~=nil then al.alcCloseDevice(device);device=nil end
end
local function ensure(condition,message)
    if not condition then disabled=true;cleanup();report("disabled: " .. message);error(message) end
    return condition
end
local function audio_error(where)
    local code=al.alGetError();ensure(code==0,string.format("%s OpenAL error 0x%x",where,code))
end
local function load_wav(path)
    local f=ensure(io.open(path,"rb"),"missing WAV: " .. path);local data=f:read("*a");f:close()
    ensure(data:sub(1,4)=="RIFF" and data:sub(9,12)=="WAVE","invalid WAV")
    local function u16(p) local a,b=data:byte(p,p+1);return a+b*256 end
    local function u32(p) local a,b,c,d=data:byte(p,p+3);return a+b*256+c*65536+d*16777216 end
    local o,channels,rate,pcm=13
    while o+7<=#data do
        local tag,size=data:sub(o,o+3),u32(o+4);ensure(o+7+size<=#data,"truncated WAV")
        if tag=="fmt " then
            ensure(size>=16 and u16(o+8)==1 and u16(o+22)==16,"requires PCM16 WAV")
            channels,rate=u16(o+10),u32(o+12)
            ensure((channels==1 or channels==2) and rate>0 and u16(o+20)==channels*2,"invalid WAV format")
        elseif tag=="data" then pcm=data:sub(o+8,o+7+size) end
        o=o+8+size+size%2
    end
    ensure(pcm and channels and #pcm>0 and #pcm%(channels*2)==0,"invalid PCM")
    local frames=#pcm/(channels*2)
    local input,mono=ffi.new("int16_t[?]",#pcm/2),ffi.new("int16_t[?]",frames);ffi.copy(input,pcm,#pcm)
    for i=0,frames-1 do mono[i]=channels==1 and input[i] or math.floor((tonumber(input[2*i])+tonumber(input[2*i+1]))/2) end
    if path:match("alertSidelines%.wav$") then
        local sum,peak=0,0
        for i=0,frames-1 do local v=tonumber(mono[i])/32768;sum=sum+v*v;peak=math.max(peak,math.abs(v)) end
        local rms=math.sqrt(sum/frames);local factor=ensure(m.normalization_factor(rms,peak),"silent sideline WAV")
        for i=0,frames-1 do mono[i]=math.floor(tonumber(mono[i])*factor) end
        report(string.format("sideline PCM level compensated factor=%.3f original-rms=%.5f peak-limit=0.85",factor,rms))
    end
    return mono,frames*2,rate
end
local function initialize_audio()
    al=ffi.load(library_root .. "soft_oal.dll")
    local why;device,why=shared_audio.open_output(al);ensure(device~=nil,why or "no game audio output")
    ensure(al.alcIsExtensionPresent(device,"ALC_SOFT_HRTF")~=0,"HRTF unavailable")
    context=al.alcCreateContext(device,ffi.new("int[5]",{0x1992,1,0x1007,48000,0}))
    ensure(context~=nil and al.alcMakeContextCurrent(context)~=0,"cannot create audio context")
    local value=ffi.new("int[1]");al.alcGetIntegerv(device,0x1992,1,value);ensure(value[0]~=0,"HRTF not enabled")
    if al.alcIsExtensionPresent(device,"ALC_ENUMERATE_ALL_EXT")~=0 then
        local name=al.alcGetString(device,0x1013)
        if name~=nil then report("audio output=" .. ffi.string(name)) end
    end
    buffers=ffi.new("unsigned int[8]");al.alGenBuffers(8,buffers)
    for i,name in ipairs({"ball.wav","alertSidelines.wav"}) do
        local pcm,size,rate=load_wav(asset_root .. name);al.alBufferData(buffers[i-1],0x1101,pcm,size,rate);audio_error("WAV")
    end
    cue_ready={}
    for i,name in ipairs({"gotBall","LostBall","teamStillWithBall"}) do
        local path=asset_root .. name .. ".wav"
        local exists=io.open(path,"rb")
        if exists then
            exists:close()
            local pcm,size,rate=load_wav(path)
            al.alBufferData(buffers[cue_buffers[name]],0x1101,pcm,size,rate);audio_error("possession WAV")
            cue_ready[name]=true
        else report("optional possession WAV missing: " .. name .. ".wav; radar preserved") end
    end
    goal_ready={}
    for i,name in ipairs({"alertYourGoalkeeper","alertOpponentGoalkeeper"}) do
        local path=asset_root .. name .. ".wav"
        local exists=io.open(path,"rb")
        if exists then
            exists:close()
            local pcm,size,rate=load_wav(path)
            al.alBufferData(buffers[i+3],0x1101,pcm,size,rate);audio_error("goal WAV")
            goal_ready[i]=true
        else report("optional goal WAV missing: " .. name .. ".wav; radar preserved") end
    end
    local tackle_file=io.open(asset_root .. "alertTacle.wav","rb")
    tackle_ready=tackle_file~=nil
    if tackle_file then
        tackle_file:close()
        local pcm,size,rate=load_wav(asset_root .. "alertTacle.wav")
        al.alBufferData(buffers[7],0x1101,pcm,size,rate);audio_error("tackle WAV")
    else report("optional alertTacle.wav missing; proximity alert disabled") end
    sources=ffi.new("unsigned int[9]");al.alGenSources(9,sources)
    al.alDistanceModel(0);al.alDopplerFactor(0);al.alListener3f(0x1004,0,0,0)
    al.alListenerfv(0x100f,ffi.new("float[6]",{0,0,-1,0,1,0}))
    for i=0,2 do
        al.alSourcei(sources[i],0x1009,buffers[i==0 and 0 or 1]);al.alSourcei(sources[i],0x1007,1)
        al.alSourcef(sources[i],0x100a,0);al.alSource3f(sources[i],0x1004,0,0,-1);al.alSourcePlay(sources[i])
    end
    for i,name in ipairs({"gotBall","LostBall","teamStillWithBall"}) do
        local source=sources[cue_sources[name]]
        if cue_ready[name] then al.alSourcei(source,0x1009,buffers[cue_buffers[name]]) end
        al.alSourcei(source,0x1007,0);al.alSourcef(source,0x100a,0)
        al.alSource3f(source,0x1004,0,0,-1)
    end
    for i=1,2 do
        local source=sources[i+4]
        if goal_ready[i] then
            al.alSourcei(source,0x1009,buffers[i+3]);al.alSourcei(source,0x1007,1)
            al.alSourcef(source,0x100a,0);al.alSource3f(source,0x1004,0,0,-1);al.alSourcePlay(source)
        end
    end
    if tackle_ready then al.alSourcei(sources[8],0x1009,buffers[7]) end
    al.alSourcei(sources[8],0x1007,1);al.alSourcef(sources[8],0x100a,0)
    al.alSource3f(sources[8],0x1004,0,0,-1);tackle_playing=false
    audio_error("initialize");report("HRTF enabled; screen orientation; ball, sidelines and fixed goal loops; three possession cues; experimental tackle proximity loop")
end
local function reset_discovery()
    references={};cursor_slot=nil;registry_reason=nil
end
local function discovery_step()
    local current,why=registry_api.snapshot(blob,base)
    registry_reason=why
    if current then
        for name,entry in pairs(current) do
            if not references[name] or references[name].entry~=entry.entry or references[name].target~=entry.target then
                report(string.format("native registry %s entry=%x data=%x",name,entry.entry,entry.target))
            end
        end
    end
    references=current or {}
end
local function reference_data(name,size)
    local ref=references[name];if not ref then return nil end
    local target=ptr(blob(ref.entry,24),16)
    if target~=ref.target then return nil end
    return blob(target,size),target
end
function m.playing_stage(data,second)
    if not data or #data<0x40 or not second or #second<0xa4 then return nil,"match-stage-unavailable" end
    if data:byte(0x21)~=0 or second:byte(0x9e)~=0 then return nil,"paused" end
    -- Live FL2026 passage uses stage 8. Upstream stage enum comments describe
    -- older game versions; use the native running-clock flag instead.
    if data:byte(0x23)~=1 then return nil,"clock-not-running" end
    return true
end
local function control_data()
    -- Retry only within this synchronous read, never reuse a previous frame's pose.
    for attempt=1,2 do
        local world=ptr(blob(base+GAME_ROOT,8),0)
        local address=ptr(blob(world,0x188),0x180)
        local data=blob(address,24*0x74)
        if data then return data end
    end
end
local function match_state(stats)
    if not stats or not stats.ptr then return nil,"no-live-match" end
    local data=blob(tonumber(ffi.cast("uintptr_t",stats.ptr)),0x40)
    return m.playing_stage(data,blob(ptr(data,0x38),0xa4))
end
local function possession(actor)
    if not possession_supported then return false,"keeper-layout-unverified",false end
    local _,raw=reference_data("analyze",8)
    if not raw then return false,"keeper-ANALYZE-unavailable",false end
    -- AnalyzeInfoRef getter 4589a0 returns raw+8. Producer 457259 writes
    -- AnalyzeInfo+2601c via its AnalyzeInfoRef at +4e8 (cache +508).
    -- MATCH/INFO is a different, smaller 2378-byte payload: never read this
    -- offset from MATCH. Player 0 is a valid actor only when read from ANALYZE.
    local keeper=uint(blob(raw+8+0x2601c,4),0)
    if ptr(blob(references.analyze.entry,24),16)~=raw then return false,"keeper-entry-changed",false end
    if keeper==255 or keeper==4294967295 then return false,"loose-ball",true,255 end
    if not keeper or keeper>=22 then return false,"keeper-index-unavailable",false end
    return keeper==actor,"keeper=" .. tostring(keeper),true,keeper
end
function m.goal_centers(attack_sign,length)
    if attack_sign~=1 and attack_sign~=-1 then return nil end
    return {-attack_sign*length,0,0},{attack_sign*length,0,0}
end
local function goal_direction(actor)
    -- a48a30 returns the current TeamAIInfo payload, not the initial match side.
    -- Its signed byte +254 is assigned by 4feb9c -> 4f4ae0 -> a42570 each phase.
    -- Native goal getter a62780 returns (-sign * field half-length, 0, 0).
    -- ActionShoot 9792af inverts the team before calling it: opponent target.
    local world=ptr(blob(base+GAME_ROOT,8),0)
    local refs=blob(world and world+0x1910,0x50)
    if not refs then return nil,"goal-team-unavailable" end
    local signs={}
    for side=0,1 do
        local offset=side*0x28
        if ptr(refs,offset)~=base+0x2596cd8 then return nil,"goal-team-type-invalid" end
        local team=ptr(refs,offset+0x18)
        if not team or team<65536 then return nil,"goal-team-unavailable" end
        local data=blob(team+0x254,1)
        local sign=data and data:byte(1)
        signs[side+1]=sign==255 and -1 or sign
        if blob(team+0x254,1)~=data then return nil,"goal-team-direction-changed" end
    end
    if (signs[1]~=1 and signs[1]~=-1) or signs[2]~=-signs[1] then return nil,"goal-team-directions-unavailable" end
    if blob(world+0x1910,0x50)~=refs or ptr(blob(base+GAME_ROOT,8),0)~=world then return nil,"goal-team-changed" end
    return signs[math.floor(actor/11)+1],"native-team-direction"
end
local function pose()
    local controls=control_data()
    local actor,slot=m.controlled_slot(controls)
    local cursor=reference_data("cursor",4+24*0x74)
    if actor~=nil then
        if m.cursor_actor(cursor,slot)==actor and cursor_slot~=slot then
            cursor_slot=slot;report(string.format("cursor binding validated slot=%d actor=%d",slot,actor))
        end
    elseif not controls and cursor_slot~=nil then
        actor=m.cursor_actor(cursor,cursor_slot);slot=cursor_slot
    end
    if actor==nil then return nil,type(slot)=="string" and slot or "controlled-player-unavailable" end
    local player=ptr(blob(base+PLAYERS+actor*8,8),0);local data=blob(player,0x630)
    if not data or ptr(data,0)~=base+PLAYER_VTABLE or uint(data,0x18)~=actor then return nil,"player-identity-unavailable" end
    local position=vector(data,0x624);if not valid_position(position) then return nil,"player-position-invalid" end
    local ball=reference_data("ball",0x20);local field=reference_data("field",0x0c)
    if not ball or not field then return nil,"resolving-game-references" end
    local ball_position=vector(ball,0x10)
    local yaw=float(data,0x61c)
    local length,width=float(field,4),float(field,8)
    if not valid_position(ball_position) then return nil,"ball-position-invalid" end
    local env=reference_data("camera_env",0x49)
    local camera_id=env and env:byte(0x49)
    local camera=reference_data("camera",0x5c)
    local camera_frame,camera_reason
    if camera_api and camera_source_supported then
        camera_frame,camera_reason=camera_api.frame(camera,position,camera_id)
        local current_env=reference_data("camera_env",0x49)
        if not current_env or current_env:byte(0x49)~=camera_id then
            camera_frame=nil;camera_reason="camera-changed-during-read"
        end
    else camera_reason="camera-source-unverified" end
    if not length or not width or length<40 or length>70 or width<20 or width>50 then return nil,"field-size-invalid" end
    local owns_ball,ownership,possession_known,keeper=possession(actor)
    local attack_sign,goal_reason=goal_direction(actor)
    return {camera=camera_frame,camera_id=camera_id,camera_reason=camera_reason,keeper=keeper,attack_sign=attack_sign,goal_reason=goal_reason,yaw=yaw,actor=actor,slot=slot,player=position,ball=ball_position,right=camera_frame and camera_frame.right,up=camera_frame and camera_frame.up,forward=camera_frame and camera_frame.forward,length=length,width=width,owns_ball=owns_ball,ownership=ownership,possession_known=possession_known}
end
local function diagnostics(now,state)
    if now<next_diagnostic then return end;next_diagnostic=now+1000
    if registry_reason then report("native registry pending=" .. registry_reason) end
    local controls=control_data()
    if controls then
        local f=io.open(root .. "live-controls.tsv","ab")
        if f then
            for i=0,23 do
                local o=i*0x74;local actor=uint(controls,o+0x20)
                if actor and actor<22 then
                    local player=ptr(blob(base+PLAYERS+actor*8,8),0);local xyz=vector(blob(player,0x630),0x624)
                    f:write(string.format("%.0f\t%d\t%d\t%d\t%s\t%s\t%s\t%s\n",now,i,controls:byte(o+7),actor,
                        tostring(player),tostring(xyz and xyz[1]),tostring(xyz and xyz[2]),tostring(xyz and xyz[3])))
                end
            end
            f:close()
        end
    end
    if state then report(string.format("pose actor=%d slot=%d player=(%.3f,%.3f,%.3f) ball=(%.3f,%.3f,%.3f) centered=%s %s",state.actor,state.slot,
        state.player[1],state.player[2],state.player[3],state.ball[1],state.ball[2],state.ball[3],tostring(state.owns_ball),state.ownership));report(string.format("body yaw=%.3f attack-sign=%s goals=%s",state.yaw or -1,tostring(state.attack_sign),state.goal_reason));report(string.format("cameraRadar id=%s profile=%s reason=%s",tostring(state.camera_id),tostring(state.camera and state.camera.name),tostring(state.camera_reason)))
        if state.camera then
            local point=camera_api.project(state.camera,state.ball)
            report(string.format("camera calibration source=%s pan=%d depth=%d scale=%.3f ball=(%s,%s,%s)",
                tostring(state.camera.profile_source),state.camera.pan_sign,state.camera.depth_sign,state.camera.depth_scale,
                tostring(point and point[1]),tostring(point and point[2]),tostring(point and point[3])))
        end
    end
    if state then
        local _,raw=reference_data("analyze",8)
        report(string.format("keeper-source=ANALYZE/INFO data=%s %s",tostring(raw),state.ownership))
    end
    if sources then
        local gain,playing,offset=ffi.new("float[1]"),ffi.new("int[1]"),ffi.new("float[1]")
        al.alcMakeContextCurrent(context)
        al.alGetSourcef(sources[0],0x100a,gain);al.alGetSourcei(sources[0],0x1010,playing);al.alGetSourcef(sources[0],0x1024,offset)
        report(string.format("audio ball gain=%.4f state=%x offset=%.3f",gain[0],playing[0],offset[0]))
        for i=1,2 do
            al.alGetSourcef(sources[i],0x100a,gain);al.alGetSourcei(sources[i],0x1010,playing)
            report(string.format("audio sideline=%d gain=%.4f state=%x",i,gain[0],playing[0]))
        end
    end
end
local function read_layout(now)
    if now<next_layout then return end;next_layout=now+1000
    local f=io.open(root .. "live-layout.txt","rb")
    if not f then enabled=false;return end
    local text=f:read("*a");f:close()
    -- Development gate armed only after live native mapping is checked.
    enabled=text:match("^validated_single_local_player%s*=%s*1%s*$")~=nil
end
local function play_pose(state,dt,cue)
    local master,why=shared_audio.prepare_output()
    if not master then mute();return false,why end
    if not sources then initialize_audio() end
    -- Windows owns app volume; only a mute/zero gate here, never volume squared.
    if master.muted or master.volume==0 then mute();return false,"game-app-audio-muted" end
    ensure(al.alcMakeContextCurrent(context)~=0,"audio context lost")
    local d={state.ball[1]-state.player[1],state.ball[2]-state.player[2],state.ball[3]-state.player[3]}
    local function projected(target,centered)
        if centered then return {0,0,-1} end
        if state.camera then return camera_api.project(state.camera,target) end
    end
    local ball_point=projected(state.ball,state.owns_ball)
    local points={ball_point or {0,0,-1}}
    local volumes={ball_point and 0.28/(1+math.sqrt(dot(d,d))/12) or 0}
    for i,sign in ipairs({-1,1}) do
        local x=math.max(-state.length,math.min(state.length,state.player[1]))
        local target={x,0,sign*state.width}
        local v={target[1]-state.player[1],-state.player[2],target[3]-state.player[3]}
        local point=projected(target)
        points[i+1]=point or {0,0,-1};volumes[i+1]=point and 0.3*m.proximity(math.sqrt(dot(v,v)),8) or 0
    end
    local own_goal,opponent_goal=m.goal_centers(state.attack_sign,state.length)
    for i,goal in ipairs({own_goal or false,opponent_goal or false}) do
        local v=goal and {goal[1]-state.player[1],goal[2]-state.player[2],goal[3]-state.player[3]}
        local point=goal and projected(goal)
        points[i+3]=point or {0,0,-1}
        volumes[i+3]=point and goal_ready[i] and 0.3*m.proximity(math.sqrt(dot(v,v)),20) or 0
        if not point then gains[i+3]=0 end
    end
    if not state.camera then
        -- Camera faults only mute directional loops. Possession cues below work.
        for i=1,5 do if not (i==1 and state.owns_ball) then gains[i]=0 end end
    end
    if cue and cue_ready[cue] then
        -- Latest confirmed transition wins; don't overlap contradictory cues.
        for _,index in pairs(cue_sources) do al.alSourceStop(sources[index]) end
        local source=sources[cue_sources[cue]]
        al.alSourcef(source,0x100a,0.4);al.alSourcePlay(source)
        report(string.format("possession cue=%s actor=%d %s",cue,state.actor,state.ownership))
    end
    local blend=1-math.exp(-math.min(dt,0.1)/0.08)
    for i,source_index in ipairs(loop_sources) do
        gains[i]=gains[i]+(volumes[i]-gains[i])*blend;local p=points[i]
        al.alSource3f(sources[source_index],0x1004,p[1],p[2],p[3]);al.alSourcef(sources[source_index],0x100a,gains[i])
    end
    local tackle_point=state.camera and camera_api.project(state.camera,state.ball)
    if state.tackle_active and tackle_point and tackle_ready and tackle_settings.volume>0 then
        local p=tackle_point
        al.alSource3f(sources[8],0x1004,p[1],p[2],p[3]);al.alSourcef(sources[8],0x100a,tackle_settings.volume)
        if not tackle_playing then
            al.alSourcePlay(sources[8]);tackle_playing=true
            report("tackle proximity active; experimental distance/height/confirmed opponent, not native success")
        end
    else
        if tackle_playing then al.alSourceStop(sources[8]);tackle_playing=false;report("tackle proximity inactive") end
        al.alSourcef(sources[8],0x100a,0)
    end
    audio_error("update real positions")
    return true
end
function m.context_reset(ctx)
    mute();reset_discovery();heading_previous=nil;tackle_previous=nil;possession_previous=nil;was_match=false;last_frame=nil;transition("context-reset; audio muted")
end
function m.display_frame(ctx)
    if disabled then return end
    if busy then mute();disabled=true;report("callback failed; audio muted");return end
    busy=true -- Sider catches errors; avoid repeating a failed operation every frame.
    local now=tonumber(kernel.GetTickCount64());local dt=last_frame and (now-last_frame)/1000 or 1/60;last_frame=now
    read_failure=nil
    local stats=match.stats()
    if not stats then
        if was_match then reset_discovery();was_match=false end
        heading_previous=nil;tackle_previous=nil;possession_previous=nil;mute();transition("no-live-match");busy=false;return
    end
    was_match=true;discovery_step()
    local state,reason=pose()
    if reason=="control-table-unavailable" and status~=reason and read_failure then report("control-read-failed " .. read_failure) end
    diagnostics(now,state);read_layout(now)
    local playing,why=match_state(stats)
    if now>=next_state_diagnostic then
        next_state_diagnostic=now+1000
        local clock=blob(tonumber(ffi.cast("uintptr_t",stats.ptr)),0x40)
        local second=blob(ptr(clock,0x38),0xa4)
        report(string.format("match-state running=%s paused=%s stage=%s second-paused=%s",
            tostring(clock and clock:byte(0x23)),tostring(clock and clock:byte(0x21)),
            tostring(second and second:byte(0x89)),tostring(second and second:byte(0x9e))))
    end
    if not state or not playing or not enabled then
        heading_previous=nil;tackle_previous=nil;possession_previous=nil;mute();transition(registry_reason or reason or why or "awaiting-live-layout-validation")
    else
        tackle_previous=m.tackle_proximity(tackle_previous,state.actor,state.keeper,state.possession_known,state.player,state.ball,tackle_settings)
        state.tackle_active=tackle_previous.active
        local cue
        possession_previous,cue=m.possession_change(possession_previous,state.actor,state.keeper,state.possession_known)
        -- Consume transitions even while master is muted/unavailable: never replay late.
        local active,audio_reason=play_pose(state,dt,cue)
        transition(active and "real-game radar active" or audio_reason)
    end
    busy=false
end
function m.init(ctx)
    camera_api=ctx.flaccess_camera_radars
    registry_api=ctx.flaccess_match_registry
    if not registry_api then disabled=true;report("native match registry module missing");return end
    shared_audio=ctx.flaccess_audio
    if not shared_audio then disabled=true;report("shared audio policy missing; effects disabled");return end
    ffi.cdef[[
        void *GetCurrentProcess(void); unsigned long long GetTickCount64(void);
        unsigned long GetCurrentProcessId(void);
        unsigned long GetLastError(void);
        int ReadProcessMemory(void*,const void*,void*,size_t,size_t*);
        void *alcOpenDevice(const char*); char alcCloseDevice(void*);
        void *alcCreateContext(void*,const int*); char alcMakeContextCurrent(void*);
        void alcDestroyContext(void*); char alcIsExtensionPresent(void*,const char*);
        void alcGetIntegerv(void*,int,int,int*); int alGetError(void);
        const char *alcGetString(void*,int);
        void alGenBuffers(int,unsigned int*); void alDeleteBuffers(int,const unsigned int*);
        void alBufferData(unsigned int,int,const void*,int,int);
        void alGenSources(int,unsigned int*); void alDeleteSources(int,const unsigned int*);
        void alSourcei(unsigned int,int,int); void alSourcef(unsigned int,int,float);
        void alSource3f(unsigned int,int,float,float,float); void alSourcePlay(unsigned int); void alSourceStop(unsigned int);
        void alGetSourcef(unsigned int,int,float*); void alGetSourcei(unsigned int,int,int*);
        void alListener3f(int,float,float,float); void alListenerfv(int,const float*);
        void alDistanceModel(int); void alDopplerFactor(float);
    ]]
    kernel=ffi.load("kernel32");process=kernel.GetCurrentProcess()
    buffer=ffi.new("uint8_t[?]",CAPACITY);got=ffi.new("size_t[1]")
    root=ctx.sider_dir .. "modules\\FlAccessGameplay\\state\\"
    asset_root=ctx.sider_dir .. "livecpk\\FlAccessGameplay\\sounds\\"
    library_root=ctx.sider_dir .. "modules\\FlAccessGameplay\\bin\\"
    local configuration=io.open(ctx.sider_dir .. "modules\\FlAccessGameplay\\FlAccessGameplay.ini","rb")
    local configuration_text
    if configuration then configuration_text=configuration:read(8192);configuration:close() end
    tackle_settings=m.tackle_settings(configuration_text)
    report(string.format("experimental tackle proximity enabled=%s enter=%.2fm exit=%.2fm height=%.2fm gain=%.2f",
        tostring(tackle_settings.enabled),tackle_settings.distance,tackle_settings.exit_distance,tackle_settings.max_ball_height,tackle_settings.volume))
    local session=io.open(root .. "live-controls.tsv","ab")
    if session then
        session:write(string.format("# session pid=%d version=%s tick=%.0f\n",tonumber(kernel.GetCurrentProcessId()),m.version,tonumber(kernel.GetTickCount64())))
        session:close()
    end
    base=tonumber(ffi.cast("uintptr_t",memory.get_process_info().base))
    local checks={{0xa627ae,"\x0f\xbe\x80\x54\x02\x00\x00"},{0xa42570,"\x88\x91\x54\x02\x00\x00"},{0xa48a30,"\x83\xfa\x02"},{0x8c4d1e,"\xf3\x0f\x10\xb1\x1c\x06\x00\x00"},{0x923572,"\x48\x8b\x8f\xd8\x07\x00\x00"},{0x1b55f40,"\x48\x8b\x05\x81\xab\xc9\x01"},{0x91ed11,"\x48\x8d\x05\xa8\x52\xdd\x02"},{0x440669,"\x48\x8b\x05\x58\x37\x2b\x03"}}
    for _,check in ipairs(checks) do
        if blob(base+check[1],#check[2])~=check[2] then disabled=true;report(string.format("unsupported executable signature at %x",check[1]));return end
    end
    camera_source_supported=blob(base+0x41b68c,4)=="\x48\x83\xc1\x04"
        and blob(base+0x87a47d,4)=="\x0f\xb6\x59\x44"
    possession_supported=blob(base+0xa627e8,10)=="\x48\x8b\x41\x18\x8b\x80\x1c\x60\x02\x00"
        and blob(base+0x4589ec,4)=="\x48\x83\xc1\x08"
    ctx.register("display_frame",m.display_frame);ctx.register("context_reset",m.context_reset)
    report("version=" .. m.version .. "; native discovery; single local player; no user controls")
end
return m
