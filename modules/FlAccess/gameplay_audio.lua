-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 3, "FLAccess gameplay: missing or reordered component audio")
function shared.mute()
    shared.tackle_playing=false
    shared.gains={0,0,0,0,0}
    if shared.sources then
        shared.al.alcMakeContextCurrent(shared.context)
        for i=0,8 do
            shared.al.alSourcef(shared.sources[i],0x100a,0)
            if i==3 or i==4 or i==7 or i==8 then shared.al.alSourceStop(shared.sources[i]) end
        end
    end
end
function shared.cleanup()
    if shared.context~=nil then
        shared.al.alcMakeContextCurrent(shared.context)
        if shared.sources then for i=0,8 do shared.al.alSourceStop(shared.sources[i]) end;shared.al.alDeleteSources(9,shared.sources);shared.sources=nil end
        if shared.buffers then shared.al.alDeleteBuffers(8,shared.buffers);shared.buffers=nil end
        shared.al.alcMakeContextCurrent(nil);shared.al.alcDestroyContext(shared.context);shared.context=nil
    end
    if shared.device~=nil then shared.al.alcCloseDevice(shared.device);shared.device=nil end
end
function shared.ensure(condition,message)
    if not condition then shared.disabled=true;shared.cleanup();shared.report("disabled: " .. message);error(message) end
    return condition
end
function shared.audio_error(where)
    local code=shared.al.alGetError();shared.ensure(code==0,string.format("%s OpenAL error 0x%x",where,code))
end
function shared.load_wav(path)
    local f=shared.ensure(io.open(path,"rb"),"missing WAV: " .. path);local data=f:read("*a");f:close()
    shared.ensure(data:sub(1,4)=="RIFF" and data:sub(9,12)=="WAVE","invalid WAV")
    local function u16(p) local a,b=data:byte(p,p+1);return a+b*256 end
    local function u32(p) local a,b,c,d=data:byte(p,p+3);return a+b*256+c*65536+d*16777216 end
    local o,channels,rate,pcm=13
    while o+7<=#data do
        local tag,size=data:sub(o,o+3),u32(o+4);shared.ensure(o+7+size<=#data,"truncated WAV")
        if tag=="fmt " then
            shared.ensure(size>=16 and u16(o+8)==1 and u16(o+22)==16,"requires PCM16 WAV")
            channels,rate=u16(o+10),u32(o+12)
            shared.ensure((channels==1 or channels==2) and rate>0 and u16(o+20)==channels*2,"invalid WAV format")
        elseif tag=="data" then pcm=data:sub(o+8,o+7+size) end
        o=o+8+size+size%2
    end
    shared.ensure(pcm and channels and #pcm>0 and #pcm%(channels*2)==0,"invalid PCM")
    local frames=#pcm/(channels*2)
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
function shared.initialize_audio()
    shared.al=ffi.load(shared.library_root .. "soft_oal.dll")
    local why;shared.device,why=shared.shared_audio.open_output(shared.al);shared.ensure(shared.device~=nil,why or "no game audio output")
    shared.ensure(shared.al.alcIsExtensionPresent(shared.device,"ALC_SOFT_HRTF")~=0,"HRTF unavailable")
    shared.context=shared.al.alcCreateContext(shared.device,ffi.new("int[5]",{0x1992,1,0x1007,48000,0}))
    shared.ensure(shared.context~=nil and shared.al.alcMakeContextCurrent(shared.context)~=0,"cannot create audio context")
    local value=ffi.new("int[1]");shared.al.alcGetIntegerv(shared.device,0x1992,1,value);shared.ensure(value[0]~=0,"HRTF not enabled")
    if shared.al.alcIsExtensionPresent(shared.device,"ALC_ENUMERATE_ALL_EXT")~=0 then
        local name=shared.al.alcGetString(shared.device,0x1013)
        if name~=nil then shared.report("audio output=" .. ffi.string(name)) end
    end
    shared.buffers=ffi.new("unsigned int[8]");shared.al.alGenBuffers(8,shared.buffers)
    for i,name in ipairs({"ball.wav","alertSidelines.wav"}) do
        local pcm,size,rate=shared.load_wav(shared.asset_root .. name);shared.al.alBufferData(shared.buffers[i-1],0x1101,pcm,size,rate);shared.audio_error("WAV")
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
    shared.sources=ffi.new("unsigned int[9]");shared.al.alGenSources(9,shared.sources)
    for i=0,8 do shared.al.alSourcei(shared.sources[i],0x202,1) end -- AL_SOURCE_RELATIVE
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
    shared.audio_error("initialize");shared.report("HRTF enabled; horizontal orientation for verified general cameras; ball, sidelines and fixed goal loops; three possession cues; experimental tackle proximity loop")
end

    shared.stage = 4
end
function component.init(ctx)
    component.install(ctx)

end
return component
