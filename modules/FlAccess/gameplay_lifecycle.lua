-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 7, "FLAccess gameplay: missing or reordered component lifecycle")
function shared.m.context_reset(ctx)
    if shared.core_context then shared.core_context.match_playing=false end
    shared.mute();shared.reset_discovery();shared.heading_previous=nil;shared.tackle_previous=nil;shared.possession_previous=nil;shared.was_match=false;shared.last_frame=nil;shared.transition("context-reset; audio muted")
end
function shared.m.display_frame(ctx)
    if shared.disabled then
        if shared.core_context then shared.core_context.match_playing=false end
        return
    end
    if shared.busy then
        if shared.core_context then shared.core_context.match_playing=false end
        shared.mute();shared.disabled=true;shared.report("callback failed; audio muted");return end
    shared.busy=true -- Sider catches errors; avoid repeating a failed operation every frame.
    local now=tonumber(shared.kernel.GetTickCount64());local dt=shared.last_frame and (now-shared.last_frame)/1000 or 1/60;shared.last_frame=now
    shared.read_failure=nil
    local stats=match.stats()
    if not stats then
        if shared.core_context then shared.core_context.match_playing=false end
        if shared.was_match then shared.reset_discovery();shared.was_match=false end
        shared.heading_previous=nil;shared.tackle_previous=nil;shared.possession_previous=nil;shared.mute();shared.transition("no-live-match");shared.busy=false;return
    end
    shared.was_match=true;shared.discovery_step()
    local state,reason=shared.pose()
    if reason=="control-table-unavailable" and shared.status~=reason and shared.read_failure then shared.report("control-read-failed " .. shared.read_failure) end
    shared.diagnostics(now,state);shared.read_layout(now)
    local playing,why=shared.match_state(stats)
    if shared.core_context then shared.core_context.match_playing=playing==true end
    if now>=shared.next_state_diagnostic then
        shared.next_state_diagnostic=now+1000
        local clock=shared.blob(tonumber(ffi.cast("uintptr_t",stats.ptr)),0x40)
        local second=shared.blob(shared.ptr(clock,0x38),0xa4)
        shared.report(string.format("match-state running=%s paused=%s stage=%s second-paused=%s",
            tostring(clock and clock:byte(0x23)),tostring(clock and clock:byte(0x21)),
            tostring(second and second:byte(0x89)),tostring(second and second:byte(0x9e))))
    end
    if not state or not playing or not shared.enabled then
        shared.heading_previous=nil;shared.tackle_previous=nil;shared.possession_previous=nil;shared.mute();shared.transition(shared.registry_reason or reason or why or "awaiting-live-layout-validation")
    else
        shared.tackle_previous=shared.m.tackle_proximity(shared.tackle_previous,state.actor,state.keeper,state.possession_known,state.player,state.ball,shared.tackle_settings)
        state.tackle_active=shared.tackle_previous.active
        local cue
        shared.possession_previous,cue=shared.m.possession_change(shared.possession_previous,state.actor,state.keeper,state.possession_known)
        -- Consume transitions even while master is muted/unavailable: never replay late.
        local active,audio_reason=shared.play_pose(state,dt,cue)
        shared.transition(active and "real-game radar active" or audio_reason)
    end
    shared.busy=false
end
function shared.m.init(ctx)
    shared.core_context=ctx.flaccess
    shared.camera_api=ctx.flaccess_camera_radars
    shared.registry_api=ctx.flaccess_match_registry
    if not shared.registry_api then shared.disabled=true;shared.report("native match registry module missing");return end
    shared.shared_audio=ctx.flaccess_audio
    if not shared.shared_audio then shared.disabled=true;shared.report("shared audio policy missing; effects disabled");return end
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
    shared.kernel=ffi.load("kernel32");shared.process=shared.kernel.GetCurrentProcess()
    shared.buffer=ffi.new("uint8_t[?]",shared.CAPACITY);shared.got=ffi.new("size_t[1]")
    shared.root=ctx.sider_dir .. "modules\\FlAccess\\state\\"
    shared.asset_root=ctx.sider_dir .. "content\\FlAccess\\sounds\\"
    shared.library_root=ctx.sider_dir .. "modules\\FlAccess\\bin\\"
    local configuration=io.open(ctx.sider_dir .. "modules\\FlAccess\\FlAccess.ini","rb")
    local configuration_text
    if configuration then configuration_text=configuration:read(8192);configuration:close() end
    shared.tackle_settings=shared.m.tackle_settings(configuration_text)
    shared.report(string.format("experimental tackle proximity enabled=%s enter=%.2fm exit=%.2fm height=%.2fm gain=%.2f",
        tostring(shared.tackle_settings.enabled),shared.tackle_settings.distance,shared.tackle_settings.exit_distance,shared.tackle_settings.max_ball_height,shared.tackle_settings.volume))
    local session=io.open(shared.root .. "live-controls.tsv","ab")
    if session then
        session:write(string.format("# session pid=%d version=%s tick=%.0f\n",tonumber(shared.kernel.GetCurrentProcessId()),shared.m.version,tonumber(shared.kernel.GetTickCount64())))
        session:close()
    end
    shared.base=tonumber(ffi.cast("uintptr_t",memory.get_process_info().base))
    local checks={{0xa627ae,"\x0f\xbe\x80\x54\x02\x00\x00"},{0xa42570,"\x88\x91\x54\x02\x00\x00"},{0xa48a30,"\x83\xfa\x02"},{0x8c4d1e,"\xf3\x0f\x10\xb1\x1c\x06\x00\x00"},{0x923572,"\x48\x8b\x8f\xd8\x07\x00\x00"},{0x1b55f40,"\x48\x8b\x05\x81\xab\xc9\x01"},{0x91ed11,"\x48\x8d\x05\xa8\x52\xdd\x02"},{0x440669,"\x48\x8b\x05\x58\x37\x2b\x03"}}
    for _,check in ipairs(checks) do
        if shared.blob(shared.base+check[1],#check[2])~=check[2] then shared.disabled=true;shared.report(string.format("unsupported executable signature at %x",check[1]));return end
    end
    shared.camera_source_supported=shared.blob(shared.base+0x41b68c,4)=="\x48\x83\xc1\x04"
        and shared.blob(shared.base+0x87a47d,4)=="\x0f\xb6\x59\x44"
    shared.possession_supported=shared.blob(shared.base+0xa627e8,10)=="\x48\x8b\x41\x18\x8b\x80\x1c\x60\x02\x00"
        and shared.blob(shared.base+0x4589ec,4)=="\x48\x83\xc1\x08"
    ctx.register("display_frame",shared.m.display_frame);ctx.register("context_reset",shared.m.context_reset)
    shared.report("version=" .. shared.m.version .. "; native discovery; single local player; no user controls")
end


    shared.stage = 8
end
function component.init(ctx)
    component.install(ctx)
    ctx.flaccess.gameplay.m.init(ctx)
end
return component
