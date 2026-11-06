-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 7, "FLAccess gameplay: missing or reordered component lifecycle")

function shared.speak_match(ctx,text,interrupt,pause)
    local reader=ctx.flaccess.reader
    if not text or not reader.speak or reader.overlay_visible or reader.sider_overlay_visible then return false end
    local before=reader.a11y.native_speech_last
    reader.speak(text,interrupt,true)
    if reader.a11y.native_speech_last<=before then return false end
    local entry=reader.a11y.native_speech_queue[reader.a11y.native_speech_last]
    entry.match_session=shared.announcement_session
    entry.pause_header=pause
    return true
end

function shared.poll_ball_holder(ctx,now,playing,state,controlled_announced)
    local reader=ctx.flaccess.reader
    local seconds=reader.a11y and reader.a11y.possession_interval
    if not seconds or seconds==0 then
        shared.last_holder_announcement,shared.last_announced_holder=nil,nil
        return
    end
    if not playing or not shared.match_names_supported
            or reader.overlay_visible or reader.sider_overlay_visible then return end
    local instant=seconds==-1
    if not instant and shared.last_holder_announcement and now-shared.last_holder_announcement<seconds*1000 then return end
    local keeper=state and state.possession_known and state.keeper
    local changed=instant and state and keeper~=shared.last_sampled_keeper
    if not changed and shared.next_possession_sample and now<shared.next_possession_sample then return end
    -- A loose ball or unchanged player should not consume the announcement interval.
    shared.next_possession_sample=now+100
    if not state then
        local _,_,known,current=shared.possession(nil)
        if known then keeper=current end
    end
    shared.last_sampled_keeper=keeper
    local name,identity,number=shared.ball_holder_name(keeper or nil,reader.a11y.possession_number)
    if name and identity~=shared.last_announced_holder then
        local pt=reader.a11y.ui_language=="pt"
        if number then name=name .. (pt and ", camisa " or ", number ") .. number end
        if shared.speak_match(ctx,name,instant and not controlled_announced) then
            shared.last_holder_announcement,shared.last_announced_holder=now,identity
        end
    end
end

function shared.poll_controlled_player(ctx,now,playing,state)
    local a11y=ctx.flaccess.reader.a11y
    local enabled=a11y and a11y.controlled_player
    local actor=enabled and playing and state and state.actor or nil
    shared.current_controlled_actor=actor
    if not enabled then shared.last_controlled_actor,shared.controlled_entry=nil,nil end
    if not actor or actor==shared.last_controlled_actor then return end
    local reader=ctx.flaccess.reader
    if reader.overlay_visible or reader.sider_overlay_visible then return end
    local same_holder=state.possession_known and state.keeper==actor
        and a11y.possession_interval and a11y.possession_interval~=0
    local name,identity,number=shared.ball_holder_name(actor,same_holder and a11y.possession_number)
    if not name then return end
    if number then name=name .. (a11y.ui_language=="pt" and ", camisa " or ", number ") .. number end
    if shared.speak_match(ctx,name,true) then
        local entry=a11y.native_speech_queue[a11y.native_speech_last]
        entry.controlled_actor=actor
        shared.controlled_entry=entry
        shared.last_controlled_actor=actor
        if same_holder then
            shared.last_holder_announcement,shared.last_announced_holder=now,identity
        end
        return true
    end
end

function shared.m.context_reset(ctx)
    if shared.core_context then shared.core_context.match_playing=false end
    shared.announcement_session,shared.next_possession_sample,shared.last_announced_holder=nil,nil,nil
    shared.last_holder_announcement=nil
    shared.current_controlled_actor,shared.last_controlled_actor=nil,nil
    shared.substitution_world,shared.next_substitution_poll=nil,nil
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
    if shared.sound_preview_request or shared.preview_active then shared.process_sound_preview(ctx) end
    local now=tonumber(shared.kernel.GetTickCount64());local dt=shared.last_frame and (now-shared.last_frame)/1000 or 1/60;shared.last_frame=now
    shared.read_failure=nil
    local stats=match.stats()
    if not stats then
        if shared.core_context then shared.core_context.match_playing=false end
        shared.announcement_session,shared.next_possession_sample,shared.last_announced_holder=nil,nil,nil
        shared.last_holder_announcement=nil
        shared.current_controlled_actor,shared.last_controlled_actor=nil,nil
        if shared.was_match then shared.reset_discovery();shared.was_match=false end
        shared.heading_previous=nil;shared.tackle_previous=nil;shared.possession_previous=nil;shared.mute();shared.transition("no-live-match");shared.busy=false;return
    end
    shared.was_match=true;shared.discovery_step()
    local state,reason=shared.pose()
    if reason=="control-table-unavailable" and shared.status~=reason and shared.read_failure then shared.report("control-read-failed " .. shared.read_failure) end
    shared.diagnostics(now,state);shared.read_layout(now)
    local playing,why=shared.match_state(stats)
    if shared.core_context then shared.core_context.match_playing=playing==true end
    local session=stats.ptr and tonumber(ffi.cast("uintptr_t",stats.ptr))
    if session~=shared.announcement_session then
        shared.announcement_session=session
        shared.next_possession_sample,shared.last_announced_holder=nil,nil
        shared.last_holder_announcement=nil
        shared.current_controlled_actor,shared.last_controlled_actor=nil,nil
        shared.substitution_world,shared.next_substitution_poll=nil,nil
    end
    local controlled_announced=shared.poll_controlled_player(ctx,now,playing,state)
    shared.poll_ball_holder(ctx,now,playing,state,controlled_announced)
    shared.poll_substitutions(ctx,now,playing)
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
        char alIsExtensionPresent(const char*); float alGetFloat(int);
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
    local settings="\n" .. (configuration_text or "")
    local speed=tonumber(settings:match("[\r\n]%s*ball_speed%s*=%s*([^\r\n;#]+)"))
    if speed and speed>=25 and speed<=200 and speed%25==0 then shared.ball_speed=speed end
    for key in pairs(shared.sound_levels) do
        local value=tonumber(settings:match("[\r\n]%s*sound_" .. key .. "%s*=%s*([^\r\n;#]+)"))
        if value and value>=0 and value<=shared.sound_level_max and value%1==0 then shared.sound_levels[key]=value end
        local enabled=tonumber(settings:match("[\r\n]%s*sound_" .. key .. "_enabled%s*=%s*([^\r\n;#]+)"))
        shared.sound_enabled[key]=enabled~=0
    end
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
    shared.match_names_supported=shared.blob(shared.base+0x14b6a60,8)=="\x48\x8b\x05\xa9\xf3\x24\x02\xc3"
        and shared.blob(shared.base+0xa489d0,23)=="\x83\xfa\x02\x73\x12\x48\x63\xc2\x48\x05\xa3\x00\x00\x00\x48\x8d\x04\x80\x48\x8b\x04\xc1\xc3"
        and shared.blob(shared.base+0xa3af73,20)=="\x48\x63\x4c\x81\x04\x83\xf9\x28\x73\x0a\x48\x69\xc9\x28\x01\x00\x00\x4c\x03\xc1"
        and shared.blob(shared.base+0x14c218b,24)=="\x48\x8d\x0c\x80\x48\x8d\x0c\xca\x48\x69\xc1\x88\x01\x00\x00\x48\x05\x08\x13\x00\x00\x49\x03\xc1"
        and shared.blob(shared.base+0x14c02b6,4)=="\x48\x8d\x43\x38"
        and shared.blob(shared.base+0x14c10c3,17)=="\x48\x69\xc8\x90\x06\x00\x00\x49\x8d\x80\x38\x01\x00\x00\x48\x03\xc1"
        and shared.blob(shared.base+0xa73e20,5)=="\x48\x8d\x41\x04\xc3"
    shared.shirt_number_supported=shared.blob(shared.base+0x20d946d,24)=="\x0f\xb7\x88\x26\x04\x00\x00\x83\xe1\x7f\x44\x3b\xf1\x73\x0b\x46\x0f\xb7\xbc\x70\x9a\x02\x00\x00"
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
