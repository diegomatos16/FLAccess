-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 3, "FLAccess gameplay: missing or reordered component audio")
function shared.mute()
    if shared.audio_muted then return end
    shared.tackle_playing=false
    shared.gains={0,0,0,0,0,0}
    if shared.sources then
        shared.al.alcMakeContextCurrent(shared.context)
        for i=0,8 do
            shared.al.alSourcef(shared.sources[i],0x100a,0)
            if i==3 or i==4 or i==7 or i==8 then shared.al.alSourceStop(shared.sources[i]) end
        end
        shared.al.alSourcef(shared.sources[10],0x100a,0)
    end
    shared.audio_muted=true
end
function shared.cleanup()
    shared.audio_muted=nil
    if shared.context~=nil then
        shared.al.alcMakeContextCurrent(shared.context)
        if shared.sources then for i=0,11 do shared.al.alSourceStop(shared.sources[i]) end;shared.al.alDeleteSources(12,shared.sources);shared.sources=nil end
        if shared.buffers then shared.al.alDeleteBuffers(10,shared.buffers);shared.buffers=nil end
        shared.al.alcMakeContextCurrent(nil);shared.al.alcDestroyContext(shared.context);shared.context=nil
    end
    if shared.device~=nil then shared.al.alcCloseDevice(shared.device);shared.device=nil end
end

function shared.control_earcon_pending(entry,now)
    if shared.disabled or shared.busy then return false end
    if not entry.control_cue_started then
        local master=shared.shared_audio.prepare_output()
        if not master or master.muted or master.volume==0 then return false end
        if not shared.sources then shared.initialize_audio() end
        if not shared.control_cue_state or shared.al.alcMakeContextCurrent(shared.context)==0 then return false end
        local source=shared.sources[11]
        shared.al.alSourceStop(source)
        shared.al.alSourcePlay(source)
        entry.control_cue_started=true
        entry.control_cue_deadline=now+shared.control_cue_duration+200
    elseif not shared.control_cue_state or shared.al.alcMakeContextCurrent(shared.context)==0 then
        return false
    end
    if now>=entry.control_cue_deadline then
        shared.al.alSourceStop(shared.sources[11])
        return false
    end
    shared.al.alGetSourcei(shared.sources[11],0x1010,shared.control_cue_state) -- AL_SOURCE_STATE
    return shared.control_cue_state[0]==0x1012 -- AL_PLAYING
end
function shared.ensure(condition,message)
    if not condition then shared.disabled=true;shared.cleanup();shared.report("disabled: " .. message);error(message) end
    return condition
end
function shared.audio_error(where)
    local code=shared.al.alGetError();shared.ensure(code==0,string.format("%s OpenAL error 0x%x",where,code))
end
function shared.load_wav(path,optional)
    local function valid(condition,message)
        if optional then return condition end
        return shared.ensure(condition,message)
    end
    local f=io.open(path,"rb")
    if not valid(f,"missing WAV: " .. path) then return end
    local data=f:read(optional and 1048577 or "*a");f:close()
    if not valid(data and (not optional or #data<=1048576)
            and data:sub(1,4)=="RIFF" and data:sub(9,12)=="WAVE","invalid WAV") then return end
    local function u16(p) local a,b=data:byte(p,p+1);return a+b*256 end
    local function u32(p) local a,b,c,d=data:byte(p,p+3);return a+b*256+c*65536+d*16777216 end
    local o,channels,rate,pcm=13
    while o+7<=#data do
        local tag,size=data:sub(o,o+3),u32(o+4)
        if not valid(o+7+size<=#data,"truncated WAV") then return end
        if tag=="fmt " then
            if not valid(size>=16 and u16(o+8)==1 and u16(o+22)==16,"requires PCM16 WAV") then return end
            channels,rate=u16(o+10),u32(o+12)
            if not valid((channels==1 or channels==2) and rate>0 and u16(o+20)==channels*2
                    and (not optional or rate<=192000),"invalid WAV format") then return end
        elseif tag=="data" then pcm=data:sub(o+8,o+7+size) end
        o=o+8+size+size%2
    end
    if not valid(pcm and channels and #pcm>0 and #pcm%(channels*2)==0,"invalid PCM") then return end
    local frames=#pcm/(channels*2)
    if optional and frames>rate then return end
    local input,mono=ffi.new("int16_t[?]",#pcm/2),ffi.new("int16_t[?]",frames);ffi.copy(input,pcm,#pcm)
    for i=0,frames-1 do mono[i]=channels==1 and input[i] or math.floor((tonumber(input[2*i])+tonumber(input[2*i+1]))/2) end
    if path:match("alertSidelines%.wav$") then
        local sum,peak=0,0
        for i=0,frames-1 do local v=tonumber(mono[i])/32768;sum=sum+v*v;peak=math.max(peak,math.abs(v)) end
        local rms=math.sqrt(sum/frames);local factor=shared.ensure(shared.m.normalization_factor(rms,peak),"silent sideline WAV")
        for i=0,frames-1 do mono[i]=math.floor(tonumber(mono[i])*factor) end
        shared.report(string.format("sideline PCM level compensated factor=%.3f original-rms=%.5f peak-limit=0.85",factor,rms))
    end
    return mono,frames*2,rate
end
function shared.m.stretch_ball(pcm,frames,rate,speed)
    local window=math.floor(rate*0.04)
    if speed==100 or frames<=window then return pcm,frames end
    local overlap=math.floor(window/2)
    local hop=window-overlap
    local length=math.max(window,math.floor(frames*100/speed+0.5))
    local output=ffi.new("int16_t[?]",length)
    ffi.copy(output,pcm,window*2)
    -- Overlap waveforms at matching phases while advancing through the input
    -- at the requested tempo. Keep the original sample rate and pitch.
    local search=math.floor(rate*0.012)
    for at=hop,length-1,hop do
        local expected=math.min(frames-window,math.floor(at*speed/100+0.5))
        local best,score=expected,-math.huge
        local width=math.min(overlap,length-at)
        for start=math.max(0,expected-search),math.min(frames-window,expected+search),4 do
            local dot,energy=0,0
            for i=0,width-1,4 do
                local value=tonumber(pcm[start+i])
                dot=dot+output[at+i]*value
                energy=energy+value*value
            end
            local match=dot/math.sqrt(energy+1)-math.abs(start-expected)*0.001
            if match>score then best,score=start,match end
        end
        for i=0,width-1 do
            local mix=(i+1)/overlap
            output[at+i]=math.floor(output[at+i]*(1-mix)+pcm[best+i]*mix+0.5)
        end
        local rest=math.min(window,length-at)-width
        if rest>0 then ffi.copy(output+at+width,pcm+best+width,rest*2) end
    end
    local fade=math.min(length,math.floor(rate*0.003))
    for i=1,fade do output[length-i]=math.floor(output[length-i]*(i-1)/fade+0.5) end
    return output,length
end

function shared.update_ball_speed()
    if shared.loaded_ball_speed==shared.ball_speed then return end
    local pcm,frames=shared.m.stretch_ball(shared.ball_pcm,shared.ball_frames,shared.ball_rate,shared.ball_speed)
    local al,source,buffer=shared.al,shared.sources[0],shared.buffers[0]
    al.alSourceStop(source)
    al.alSourcei(source,0x1009,0)
    -- The preview source may still reference the same buffer.
    al.alSourceStop(shared.sources[9])
    al.alSourcei(shared.sources[9],0x1009,0)
    shared.preview_active=false
    al.alBufferData(buffer,0x1101,pcm,frames*2,shared.ball_rate)
    al.alSourcei(source,0x1009,buffer)
    shared.loaded_ball_speed=shared.ball_speed
    shared.audio_error("ball tempo")
end

function shared.process_sound_preview(ctx)
    local reader=ctx.flaccess.reader
    local key=shared.sound_preview_request
    shared.sound_preview_request=nil
    if shared.preview_active and (key or shared.sound_preview_stop or not reader.overlay_visible) then
        shared.al.alcMakeContextCurrent(shared.context)
        shared.al.alSourceStop(shared.sources[9])
        shared.preview_active=false
    end
    shared.sound_preview_stop=nil
    if not key or not reader.overlay_visible then return end
    local master=shared.shared_audio.prepare_output()
    local function unavailable()
        reader.speak(reader.a11y.strings().sound_preview_unavailable)
    end
    if not master or master.muted or master.volume==0 then unavailable();return end
    if not shared.sources then shared.initialize_audio() end
    shared.ensure(shared.al.alcMakeContextCurrent(shared.context)~=0,"audio context lost")
    local index,gain
    local level=key~="tackle" and shared.sound_gain(key)
    if key=="ball" then
        shared.update_ball_speed()
        index,gain=0,0.28*level
    elseif key=="sidelines" then index,gain=1,0.30*level
    elseif key=="endline" and shared.endline_ready then index,gain=8,0.30*level
    elseif key=="own_goal" and shared.goal_ready[1] then index,gain=4,0.30*level
    elseif key=="opponent_goal" and shared.goal_ready[2] then index,gain=5,0.30*level
    elseif key=="tackle" and shared.tackle_ready then index,gain=7,shared.tackle_settings.enabled and shared.tackle_settings.volume or 0
    elseif shared.cue_ready[key] then index,gain=shared.cue_buffers[key],0.40*level end
    if not index then unavailable();return end
    if gain==0 then reader.speak(reader.a11y.strings().sound_preview_muted);return end
    local al,source=shared.al,shared.sources[9]
    al.alSourcei(source,0x1009,shared.buffers[index])
    al.alSource3f(source,0x1004,0,0,-1)
    al.alSourcef(source,0x100a,gain)
    al.alSourcePlay(source)
    shared.preview_active=true
    shared.audio_error("sound preview")
end

function shared.initialize_audio()
    shared.al=ffi.load(shared.library_root .. "soft_oal.dll")
    local why;shared.device,why=shared.shared_audio.open_output(shared.al);shared.ensure(shared.device~=nil,why or "no game audio output")
    shared.audio_connection=shared.al.alcIsExtensionPresent(shared.device,"ALC_EXT_disconnect")~=0 and ffi.new("int[1]") or nil
    shared.ensure(shared.al.alcIsExtensionPresent(shared.device,"ALC_SOFT_HRTF")~=0,"HRTF unavailable")
    local limiter=shared.al.alcIsExtensionPresent(shared.device,"ALC_SOFT_output_limiter")~=0
    local attributes=ffi.new("int[7]",{0x1992,1,0x1007,48000,limiter and 0x199a or 0,1,0})
    shared.context=shared.al.alcCreateContext(shared.device,attributes)
    shared.ensure(shared.context~=nil and shared.al.alcMakeContextCurrent(shared.context)~=0,"cannot create audio context")
    local value=ffi.new("int[1]");shared.al.alcGetIntegerv(shared.device,0x1992,1,value);shared.ensure(value[0]~=0,"HRTF not enabled")
    if shared.al.alcIsExtensionPresent(shared.device,"ALC_ENUMERATE_ALL_EXT")~=0 then
        local name=shared.al.alcGetString(shared.device,0x1013)
        if name~=nil then shared.report("audio output=" .. ffi.string(name)) end
    end
    shared.buffers=ffi.new("unsigned int[10]");shared.al.alGenBuffers(10,shared.buffers)
    for i,name in ipairs({"ball.wav","alertSidelines.wav"}) do
        local pcm,size,rate=shared.load_wav(shared.asset_root .. name)
        if i==1 then
            shared.ball_pcm,shared.ball_frames,shared.ball_rate=pcm,size/2,rate
            local adjusted,frames=shared.m.stretch_ball(pcm,size/2,rate,shared.ball_speed)
            pcm,size=adjusted,frames*2
            shared.loaded_ball_speed=shared.ball_speed
        end
        shared.al.alBufferData(shared.buffers[i-1],0x1101,pcm,size,rate);shared.audio_error("WAV")
    end
    shared.cue_ready={}
    for i,name in ipairs({"gotBall","LostBall","teamStillWithBall"}) do
        local path=shared.asset_root .. name .. ".wav"
        local exists=io.open(path,"rb")
        if exists then
            exists:close()
            local pcm,size,rate=shared.load_wav(path)
            shared.al.alBufferData(shared.buffers[shared.cue_buffers[name]],0x1101,pcm,size,rate);shared.audio_error("possession WAV")
            shared.cue_ready[name]=true
        else shared.report("optional possession WAV missing: " .. name .. ".wav; radar preserved") end
    end
    shared.goal_ready={}
    for i,name in ipairs({"alertYourGoalkeeper","alertOpponentGoalkeeper"}) do
        local path=shared.asset_root .. name .. ".wav"
        local exists=io.open(path,"rb")
        if exists then
            exists:close()
            local pcm,size,rate=shared.load_wav(path)
            shared.al.alBufferData(shared.buffers[i+3],0x1101,pcm,size,rate);shared.audio_error("goal WAV")
            shared.goal_ready[i]=true
        else shared.report("optional goal WAV missing: " .. name .. ".wav; radar preserved") end
    end
    local tackle_file=io.open(shared.asset_root .. "alertTacle.wav","rb")
    shared.tackle_ready=tackle_file~=nil
    if tackle_file then
        tackle_file:close()
        local pcm,size,rate=shared.load_wav(shared.asset_root .. "alertTacle.wav")
        shared.al.alBufferData(shared.buffers[7],0x1101,pcm,size,rate);shared.audio_error("tackle WAV")
    else shared.report("optional alertTacle.wav missing; proximity alert disabled") end
    local endline_path=shared.asset_root .. "alertGoal line.wav"
    local endline_file=io.open(endline_path,"rb")
    shared.endline_ready=endline_file~=nil
    if endline_file then
        endline_file:close()
        local pcm,size,rate=shared.load_wav(endline_path)
        shared.al.alBufferData(shared.buffers[8],0x1101,pcm,size,rate);shared.audio_error("endline WAV")
    end
    local control_path=shared.asset_root .. "playerControlled.wav"
    local control_file=io.open(control_path,"rb")
    shared.control_cue_state=nil
    if control_file then
        control_file:close()
        local pcm,size,rate=shared.load_wav(control_path,true)
        if pcm then
            shared.al.alBufferData(shared.buffers[9],0x1101,pcm,size,rate);shared.audio_error("controlled player WAV")
            shared.control_cue_state=ffi.new("int[1]")
            shared.control_cue_duration=size*500/rate
        else
            shared.report("invalid playerControlled.wav; controlled player name remains available")
        end
    end
    shared.sources=ffi.new("unsigned int[12]");shared.al.alGenSources(12,shared.sources)
    if limiter then shared.al.alcGetIntegerv(shared.device,0x199a,1,value) end
    local max_gain=1
    if limiter and value[0]~=0 and shared.al.alIsExtensionPresent("AL_SOFT_gain_clamp_ex")~=0 then
        max_gain=math.min(shared.sound_level_max/100,shared.al.alGetFloat(0x200e)) -- AL_GAIN_LIMIT_SOFT
    end
    for i=0,11 do
        shared.al.alSourcei(shared.sources[i],0x202,1) -- AL_SOURCE_RELATIVE
        shared.al.alSourcef(shared.sources[i],0x100e,max_gain) -- AL_MAX_GAIN
    end
    shared.al.alDistanceModel(0);shared.al.alDopplerFactor(0);shared.al.alListener3f(0x1004,0,0,0)
    shared.al.alListenerfv(0x100f,ffi.new("float[6]",{0,0,-1,0,1,0}))
    for i=0,2 do
        shared.al.alSourcei(shared.sources[i],0x1009,shared.buffers[i==0 and 0 or 1]);shared.al.alSourcei(shared.sources[i],0x1007,1)
        shared.al.alSourcef(shared.sources[i],0x100a,0);shared.al.alSource3f(shared.sources[i],0x1004,0,0,-1);shared.al.alSourcePlay(shared.sources[i])
    end
    for i,name in ipairs({"gotBall","LostBall","teamStillWithBall"}) do
        local source=shared.sources[shared.cue_sources[name]]
        if shared.cue_ready[name] then shared.al.alSourcei(source,0x1009,shared.buffers[shared.cue_buffers[name]]) end
        shared.al.alSourcei(source,0x1007,0);shared.al.alSourcef(source,0x100a,0)
        shared.al.alSource3f(source,0x1004,0,0,0)
    end
    for i=1,2 do
        local source=shared.sources[i+4]
        if shared.goal_ready[i] then
            shared.al.alSourcei(source,0x1009,shared.buffers[i+3]);shared.al.alSourcei(source,0x1007,1)
            shared.al.alSourcef(source,0x100a,0);shared.al.alSource3f(source,0x1004,0,0,0);shared.al.alSourcePlay(source)
        end
    end
    if shared.tackle_ready then shared.al.alSourcei(shared.sources[8],0x1009,shared.buffers[7]) end
    shared.al.alSourcei(shared.sources[8],0x1007,1);shared.al.alSourcef(shared.sources[8],0x100a,0)
    shared.al.alSource3f(shared.sources[8],0x1004,0,0,-1);shared.tackle_playing=false
    if shared.endline_ready then
        shared.al.alSourcei(shared.sources[10],0x1009,shared.buffers[8])
        shared.al.alSourcei(shared.sources[10],0x1007,1)
        shared.al.alSourcef(shared.sources[10],0x100a,0)
    end
    if shared.control_cue_state then
        local source=shared.sources[11]
        shared.al.alSourcei(source,0x1009,shared.buffers[9])
        shared.al.alSource3f(source,0x1004,0,0,-1)
        shared.al.alSourcef(source,0x100a,0.28)
    end
    shared.audio_error("initialize");shared.report("HRTF enabled; horizontal orientation for verified general cameras; ball, sidelines and fixed goal loops; three possession cues; experimental tackle proximity loop")
end

    shared.stage = 4
end
function component.init(ctx)
    component.install(ctx)

end
return component
