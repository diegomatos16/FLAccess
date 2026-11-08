-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 6, "FLAccess gameplay: missing or reordered component render")
local function distance_squared(a,b)
    return (a[1]-b[1])^2+(a[3]-b[3])^2
end

function shared.m.player_radar_targets(positions,actor,origin,settings,previous)
    local side=math.floor(actor/11)
    local opponents,groups,marked={},{marked={},free={},opponent={}},{}
    for id,position in pairs(positions) do
        if math.floor(id/11)~=side then opponents[#opponents+1]=position end
    end
    for id,position in pairs(positions) do
        local distance=distance_squared(origin,position)
        if id~=actor and distance<=settings.radius^2 then
            local group
            if math.floor(id/11)~=side then
                group="opponent"
            elseif #opponents>0 then
                local limit=previous[id] and 3.5 or 3
                for _,opponent in ipairs(opponents) do
                    if distance_squared(position,opponent)<=limit^2 then marked[id]=true;break end
                end
                group=marked[id] and "marked" or "free"
            end
            if group and settings[group.."_enabled"]==1 and settings[group.."_volume"]>0 then
                local entries=groups[group]
                entries[#entries+1]={id=id,group=group,distance=distance,position=position}
            end
        end
    end
    local targets={}
    for group,entries in pairs(groups) do
        table.sort(entries,function(a,b)
            if a.distance==b.distance then return a.id<b.id end
            return a.distance<b.distance
        end)
        local count=settings.mode==1 and math.min(#entries,settings[group.."_count"]) or #entries
        for i=1,count do targets[entries[i].id]=entries[i] end
    end
    return targets,marked
end

function shared.reset_player_radar()
    if shared.radar_active and shared.sources then
        shared.al.alcMakeContextCurrent(shared.context)
        shared.al.alSourceStop(shared.sources[12])
    end
    shared.radar_active,shared.radar_sample=nil,nil
end

local function radar_positions(state,now)
    local sample=shared.radar_positions_sample
    if not sample or sample.actor~=state.actor or now>=sample.next_scan then
        sample={actor=state.actor,next_scan=now+120,positions=shared.radar_positions(state) or {}}
        shared.radar_positions_sample=sample
    end
    return sample.positions
end

function shared.reset_pressure()
    if shared.pressure_actor and shared.sources then shared.al.alSourceStop(shared.sources[13]) end
    shared.pressure_actor,shared.pressure_next=nil,nil
end

local function play_pressure(state,now)
    local settings,reader=shared.radar,shared.core_context.reader
    if not state.owns_ball or not state.ball_camera or not shared.sound_buffers.pressure
            or settings.pressure_enabled==0 or settings.pressure_volume==0
            or reader.overlay_visible or reader.sider_overlay_visible then
        shared.reset_pressure()
        return
    end
    if shared.pressure_actor and shared.pressure_actor~=state.actor then shared.reset_pressure() end
    local closest,distance,closest_id
    local side=math.floor(state.actor/11)
    for id,position in pairs(radar_positions(state,now)) do
        if math.floor(id/11)~=side then
            local squared=distance_squared(state.player,position)
            if not distance or squared<distance or squared==distance and id<closest_id then
                closest,distance,closest_id=position,squared,id
            end
        end
    end
    local radius=settings.pressure_radius+(shared.pressure_actor and 0.5 or 0)
    local point=distance and distance<=radius^2 and shared.camera_api.project(state.ball_camera,closest)
    if not point then shared.reset_pressure();return end
    local al,source=shared.al,shared.sources[13]
    al.alSource3f(source,0x1004,point[1],point[2],point[3])
    al.alSourcef(source,0x100a,0.30*settings.pressure_volume/100)
    if now>=(shared.pressure_next or 0) then
        shared.loop_state=shared.loop_state or ffi.new("int[1]")
        al.alGetSourcei(source,0x1010,shared.loop_state)
        if shared.loop_state[0]~=0x1012 then
            al.alSourcePlay(source)
            shared.pressure_next=now+400
        end
    end
    shared.pressure_actor=state.actor
end

local function play_player_radar(state,now)
    local settings,reader=shared.radar,shared.core_context.reader
    local keeper=state.possession_known and state.keeper
    if settings.enabled==0 or not keeper or keeper>=22 or math.floor(keeper/11)~=math.floor(state.actor/11)
            or not state.ball_camera or reader.overlay_visible or reader.sider_overlay_visible then
        shared.reset_player_radar()
        return
    end
    if now<(shared.radar_retry_at or 0) then return end
    local sample=shared.radar_sample
    if not sample or sample.actor~=state.actor then
        shared.reset_player_radar()
        sample={actor=state.actor,marked={},last={},next_scan=now,next_play=now}
        shared.radar_sample=sample
    end
    if now>=sample.next_scan then
        sample.targets,sample.marked=shared.m.player_radar_targets(
            radar_positions(state,now),state.actor,state.player,settings,sample.marked)
        sample.next_scan=now+120
    end
    local targets=sample.targets
    local al,source=shared.al,shared.sources[12]
    local active=shared.radar_active
    if active then
        local target=targets[active.id]
        if target and target.group==active.group then
            shared.loop_state=shared.loop_state or ffi.new("int[1]")
            al.alGetSourcei(source,0x1010,shared.loop_state)
            if shared.loop_state[0]==0x1012 then
                local p=shared.camera_api.project(state.ball_camera,target.position)
                if p then
                    al.alSource3f(source,0x1004,p[1],p[2],p[3])
                    al.alSourcef(source,0x100a,0.30*settings[target.group.."_volume"]/100)
                    return
                end
                al.alSourceStop(source)
            end
        else al.alSourceStop(source) end
        shared.radar_active=nil
    end
    if now<sample.next_play then return end
    local next_target,oldest
    for id,target in pairs(targets) do
        local group=target.group
        local last=sample.last[id] or -math.huge
        if now-last>=350 and shared.sound_buffers[group]
                and (not oldest or last<oldest or last==oldest
                    and (target.distance<next_target.distance or target.distance==next_target.distance and id<next_target.id)) then
            next_target,oldest=target,last
        end
    end
    if not next_target then return end
    local group=next_target.group
    local p=shared.camera_api.project(state.ball_camera,next_target.position)
    sample.last[next_target.id]=now
    if not p then return end
    al.alSourceStop(source)
    shared.bind_sound(12,group)
    al.alSource3f(source,0x1004,p[1],p[2],p[3])
    al.alSourcef(source,0x100a,0.30*settings[group.."_volume"]/100)
    al.alSourcePlay(source)
    shared.radar_active={id=next_target.id,group=group}
    sample.next_play=now+150
end

function shared.play_pose(state,dt,cue,now)
    if now<(shared.audio_retry_at or 0) then return false,"audio-output-recovering" end
    local master,why=shared.shared_audio.prepare_output()
    if not master then shared.mute();return false,why end
    if not shared.sources then shared.initialize_audio() end
    -- Windows owns app volume; only a mute/zero gate here, never volume squared.
    if master.muted or master.volume==0 then shared.mute();return false,"game-app-audio-muted" end
    shared.audio_muted=false
    if shared.al.alcMakeContextCurrent(shared.context)==0 then return shared.recover_audio("match context",0) end
    for key in pairs(shared.sound_buffers) do
        local ready,reason=shared.update_sound_speed(key)
        if not ready then return false,reason end
    end
    local d={state.ball[1]-state.player[1],state.ball[2]-state.player[2],state.ball[3]-state.player[3]}
    local function projected(target)
        if state.camera then return shared.camera_api.project(state.camera,target) end
    end
    local ball_point=state.owns_ball and {0,0,0}
        or (state.ball_camera and shared.camera_api.project(state.ball_camera,state.ball))
    if not ball_point then shared.gains[1]=0 end
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
        for i=2,#shared.loop_sources do shared.gains[i]=0 end
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
    local blend=1-math.exp(-math.max(0,math.min(dt,0.1))/0.08)
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
    local code=shared.al.alGetError()
    if code~=0 then return shared.recover_audio("ball and field sounds",code) end
    play_player_radar(state,now)
    code=shared.al.alGetError()
    if code~=0 then
        shared.report(string.format("player radar paused after OpenAL error 0x%x",code))
        shared.reset_player_radar()
        shared.radar_retry_at=now+1000
    end
    if now>=(shared.pressure_retry_at or 0) then
        play_pressure(state,now)
        code=shared.al.alGetError()
        if code~=0 then
            shared.report(string.format("pressure alert paused after OpenAL error 0x%x",code))
            shared.reset_pressure()
            shared.pressure_retry_at=now+1000
        end
    end
    return true
end

    shared.stage = 7
end
function component.init(ctx)
    component.install(ctx)

end
return component
