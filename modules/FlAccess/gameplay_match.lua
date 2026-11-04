-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 4, "FLAccess gameplay: missing or reordered component match")
function shared.reset_discovery()
    shared.references={};shared.cursor_slot=nil;shared.registry_reason=nil
end
function shared.discovery_step()
    local current,why=shared.registry_api.snapshot(shared.blob,shared.base)
    shared.registry_reason=why
    if current then
        for name,entry in pairs(current) do
            if not shared.references[name] or shared.references[name].entry~=entry.entry or shared.references[name].target~=entry.target then
                shared.report(string.format("native registry %s entry=%x data=%x",name,entry.entry,entry.target))
            end
        end
    end
    shared.references=current or {}
end
function shared.reference_data(name,size)
    local ref=shared.references[name];if not ref then return nil end
    local target=shared.ptr(shared.blob(ref.entry,24),16)
    if target~=ref.target then return nil end
    return shared.blob(target,size),target
end
function shared.m.playing_stage(data,second)
    if not data or #data<0x40 or not second or #second<0xa4 then return nil,"match-stage-unavailable" end
    if data:byte(0x21)~=0 or second:byte(0x9e)~=0 then return nil,"paused" end
    -- Live FL2026 passage uses stage 8. Upstream stage enum comments describe
    -- older game versions; use the native running-clock flag instead.
    if data:byte(0x23)~=1 then return nil,"clock-not-running" end
    return true
end
function shared.control_data()
    -- Retry only within this synchronous read, never reuse a previous frame's pose.
    for attempt=1,2 do
        local world=shared.ptr(shared.blob(shared.base+shared.GAME_ROOT,8),0)
        local address=shared.ptr(shared.blob(world,0x188),0x180)
        local data=shared.blob(address,24*0x74)
        if data then return data end
    end
end
function shared.match_state(stats)
    if not stats or not stats.ptr then return nil,"no-live-match" end
    local data=shared.blob(tonumber(ffi.cast("uintptr_t",stats.ptr)),0x40)
    return shared.m.playing_stage(data,shared.blob(shared.ptr(data,0x38),0xa4))
end
function shared.possession(actor)
    if not shared.possession_supported then return false,"keeper-layout-unverified",false end
    local _,raw=shared.reference_data("analyze",8)
    if not raw then return false,"keeper-ANALYZE-unavailable",false end
    -- AnalyzeInfoRef getter 4589a0 returns raw+8. Producer 457259 writes
    -- AnalyzeInfo+2601c via its AnalyzeInfoRef at +4e8 (cache +508).
    -- MATCH/INFO is a different, smaller 2378-byte payload: never read this
    -- offset from MATCH. Player 0 is a valid actor only when read from ANALYZE.
    local keeper=shared.uint(shared.blob(raw+8+0x2601c,4),0)
    if shared.ptr(shared.blob(shared.references.analyze.entry,24),16)~=raw then return false,"keeper-entry-changed",false end
    if keeper==255 or keeper==4294967295 then return false,"loose-ball",true,255 end
    if not keeper or keeper>=22 then return false,"keeper-index-unavailable",false end
    return keeper==actor,"keeper=" .. tostring(keeper),true,keeper
end
function shared.m.goal_centers(attack_sign,length)
    if attack_sign~=1 and attack_sign~=-1 then return nil end
    return {-attack_sign*length,0,0},{attack_sign*length,0,0}
end
function shared.goal_direction(actor)
    -- a48a30 returns the current TeamAIInfo payload, not the initial match side.
    -- Its signed byte +254 is assigned by 4feb9c -> 4f4ae0 -> a42570 each phase.
    -- Native goal getter a62780 returns (-sign * field half-length, 0, 0).
    -- ActionShoot 9792af inverts the team before calling it: opponent target.
    local world=shared.ptr(shared.blob(shared.base+shared.GAME_ROOT,8),0)
    local refs=shared.blob(world and world+0x1910,0x50)
    if not refs then return nil,"goal-team-unavailable" end
    local signs={}
    for side=0,1 do
        local offset=side*0x28
        if shared.ptr(refs,offset)~=shared.base+0x2596cd8 then return nil,"goal-team-type-invalid" end
        local team=shared.ptr(refs,offset+0x18)
        if not team or team<65536 then return nil,"goal-team-unavailable" end
        local data=shared.blob(team+0x254,1)
        local sign=data and data:byte(1)
        signs[side+1]=sign==255 and -1 or sign
        if shared.blob(team+0x254,1)~=data then return nil,"goal-team-direction-changed" end
    end
    if (signs[1]~=1 and signs[1]~=-1) or signs[2]~=-signs[1] then return nil,"goal-team-directions-unavailable" end
    if shared.blob(world+0x1910,0x50)~=refs or shared.ptr(shared.blob(shared.base+shared.GAME_ROOT,8),0)~=world then return nil,"goal-team-changed" end
    return signs[math.floor(actor/11)+1],"native-team-direction"
end
function shared.pose()
    local controls=shared.control_data()
    local actor,slot=shared.m.controlled_slot(controls)
    local cursor=shared.reference_data("cursor",4+24*0x74)
    if actor~=nil then
        if shared.m.cursor_actor(cursor,slot)==actor and shared.cursor_slot~=slot then
            shared.cursor_slot=slot;shared.report(string.format("cursor binding validated slot=%d actor=%d",slot,actor))
        end
    elseif not controls and shared.cursor_slot~=nil then
        actor=shared.m.cursor_actor(cursor,shared.cursor_slot);slot=shared.cursor_slot
    end
    if actor==nil then return nil,type(slot)=="string" and slot or "controlled-player-unavailable" end
    local player=shared.ptr(shared.blob(shared.base+shared.PLAYERS+actor*8,8),0);local data=shared.blob(player,0x630)
    if not data or shared.ptr(data,0)~=shared.base+shared.PLAYER_VTABLE or shared.uint(data,0x18)~=actor then return nil,"player-identity-unavailable" end
    local position=shared.vector(data,0x624);if not shared.valid_position(position) then return nil,"player-position-invalid" end
    local ball=shared.reference_data("ball",0x20);local field=shared.reference_data("field",0x0c)
    if not ball or not field then return nil,"resolving-game-references" end
    local ball_position=shared.vector(ball,0x10)
    local yaw=shared.float(data,0x61c)
    local length,width=shared.float(field,4),shared.float(field,8)
    if not shared.valid_position(ball_position) then return nil,"ball-position-invalid" end
    local env=shared.reference_data("camera_env",0x49)
    local camera_id=env and env:byte(0x49)
    local camera=shared.reference_data("camera",0x5c)
    local camera_frame,camera_reason
    if shared.camera_api and shared.camera_source_supported then
        -- FL27 Player=8: native session capture plus the user's explicit
        -- confirmation of the selected view. This is not eFootball's enum.
        if camera_id==8 then
            local body_right,body_up,body_forward=shared.m.body_basis(yaw)
            if body_forward then
                camera_frame,camera_reason=shared.camera_api.listener_frame(nil,position,camera_id,body_forward)
            else camera_reason="body-heading-invalid" end
        else
            local general=camera_id==2 or camera_id==3 or camera_id==5 or camera_id==6
            local make=general and shared.camera_api.listener_frame or shared.camera_api.frame
            camera_frame,camera_reason=make(camera,position,camera_id)
        end
        local current_env=shared.reference_data("camera_env",0x49)
        if not current_env or current_env:byte(0x49)~=camera_id then
            camera_frame=nil;camera_reason="camera-changed-during-read"
        end
    else camera_reason="camera-source-unverified" end
    if not length or not width or length<40 or length>70 or width<20 or width>50 then return nil,"field-size-invalid" end
    local owns_ball,ownership,possession_known,keeper=shared.possession(actor)
    local attack_sign,goal_reason=shared.goal_direction(actor)
    return {camera=camera_frame,camera_id=camera_id,camera_reason=camera_reason,keeper=keeper,attack_sign=attack_sign,goal_reason=goal_reason,yaw=yaw,actor=actor,slot=slot,player=position,ball=ball_position,right=camera_frame and camera_frame.right,up=camera_frame and camera_frame.up,forward=camera_frame and camera_frame.forward,length=length,width=width,owns_ball=owns_ball,ownership=ownership,possession_known=possession_known}
end

    shared.stage = 5
end
function component.init(ctx)
    component.install(ctx)

end
return component
