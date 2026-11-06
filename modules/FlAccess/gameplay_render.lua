-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 6, "FLAccess gameplay: missing or reordered component render")
function shared.play_pose(state,dt,cue)
    local master,why=shared.shared_audio.prepare_output()
    if not master then shared.mute();return false,why end
    if not shared.sources then shared.initialize_audio() end
    -- Windows owns app volume; only a mute/zero gate here, never volume squared.
    if master.muted or master.volume==0 then shared.mute();return false,"game-app-audio-muted" end
    shared.audio_muted=false
    shared.ensure(shared.al.alcMakeContextCurrent(shared.context)~=0,"audio context lost")
    shared.update_ball_speed()
    local d={state.ball[1]-state.player[1],state.ball[2]-state.player[2],state.ball[3]-state.player[3]}
    local function projected(target,centered)
        if centered then return {0,0,0} end
        if state.camera then return shared.camera_api.project(state.camera,target) end
    end
    local ball_point=projected(state.ball,state.owns_ball)
    local points={ball_point or {0,0,-1}}
    local gain=shared.sound_gain
    local volumes={ball_point and 0.28/(1+math.sqrt(shared.dot(d,d))/12)*gain("ball") or 0}
    local sideline_gain=gain("sidelines")
    for i,sign in ipairs({-1,1}) do
        local x=math.max(-state.length,math.min(state.length,state.player[1]))
        local target={x,0,sign*state.width}
        local v={target[1]-state.player[1],-state.player[2],target[3]-state.player[3]}
        local point=projected(target)
        points[i+1]=point or {0,0,-1};volumes[i+1]=point and 0.3*shared.m.proximity(math.sqrt(shared.dot(v,v)),8)*sideline_gain or 0
    end
    local own_goal,opponent_goal=shared.m.goal_centers(state.attack_sign,state.length)
    for i,goal in ipairs({own_goal or false,opponent_goal or false}) do
        local v=goal and {goal[1]-state.player[1],goal[2]-state.player[2],goal[3]-state.player[3]}
        local point=goal and projected(goal)
        points[i+3]=point or {0,0,-1}
        local level=gain(i==1 and "own_goal" or "opponent_goal")
        volumes[i+3]=point and shared.goal_ready[i] and 0.3*shared.m.proximity(math.sqrt(shared.dot(v,v)),20)*level or 0
        if not point then shared.gains[i+3]=0 end
    end
    local endline_gain=gain("endline")
    local endline_distance=math.abs(state.length-math.abs(state.player[1]))
    local endline_point
    if shared.endline_ready and endline_gain>0 and endline_distance<8 then
        local x=state.player[1]<0 and -state.length or state.length
        local z=math.max(-state.width,math.min(state.width,state.player[3]))
        endline_point=projected({x,0,z})
        endline_distance=math.sqrt((x-state.player[1])^2+state.player[2]^2+(z-state.player[3])^2)
    end
    points[6]=endline_point or {0,0,-1}
    volumes[6]=endline_point and 0.30*shared.m.proximity(endline_distance,8)*endline_gain or 0
    if not state.camera then
        -- Camera faults only mute directional loops. Possession cues below work.
        for i=1,#shared.loop_sources do if not (i==1 and state.owns_ball) then shared.gains[i]=0 end end
    end
    if cue and shared.cue_ready[cue] then
        -- Latest confirmed transition wins; don't overlap contradictory cues.
        for _,index in pairs(shared.cue_sources) do shared.al.alSourceStop(shared.sources[index]) end
        local source=shared.sources[shared.cue_sources[cue]]
        local level=gain(cue)
        if level>0 then
            shared.al.alSourcef(source,0x100a,0.4*level);shared.al.alSourcePlay(source)
            shared.report(string.format("possession cue=%s actor=%d %s",cue,state.actor,state.ownership))
        end
    end
    local blend=1-math.exp(-math.min(dt,0.1)/0.08)
    for i,source_index in ipairs(shared.loop_sources) do
        shared.gains[i]=shared.gains[i]+(volumes[i]-shared.gains[i])*blend;local p=points[i]
        shared.al.alSource3f(shared.sources[source_index],0x1004,p[1],p[2],p[3]);shared.al.alSourcef(shared.sources[source_index],0x100a,shared.gains[i])
        if volumes[i]>0 then
            shared.loop_state=shared.loop_state or ffi.new("int[1]")
            shared.al.alGetSourcei(shared.sources[source_index],0x1010,shared.loop_state)
            if shared.loop_state[0]~=0x1012 then shared.al.alSourcePlay(shared.sources[source_index]) end
        end
    end
    local tackle_point=state.camera and shared.camera_api.project(state.camera,state.ball)
    if state.tackle_active and tackle_point and shared.tackle_ready and shared.tackle_settings.volume>0 then
        local p=tackle_point
        shared.al.alSource3f(shared.sources[8],0x1004,p[1],p[2],p[3]);shared.al.alSourcef(shared.sources[8],0x100a,shared.tackle_settings.volume)
        if not shared.tackle_playing then
            shared.al.alSourcePlay(shared.sources[8]);shared.tackle_playing=true
            shared.report("tackle proximity active; experimental distance/height/confirmed opponent, not native success")
        end
    else
        if shared.tackle_playing then shared.al.alSourceStop(shared.sources[8]);shared.tackle_playing=false;shared.report("tackle proximity inactive") end
        shared.al.alSourcef(shared.sources[8],0x100a,0)
    end
    shared.audio_error("update real positions")
    return true
end

    shared.stage = 7
end
function component.init(ctx)
    component.install(ctx)

end
return component
