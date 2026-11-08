-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 4, "FLAccess gameplay: missing or reordered component match")
function shared.reset_discovery()
    shared.references={};shared.cursor_slot=nil;shared.registry_reason=nil
end
function shared.discovery_step(training)
    local current,why=shared.registry_api.snapshot(shared.blob,shared.base,training)
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

function shared.training_mode()
    if not shared.training_mode_supported then return end
    local flow=shared.ptr(shared.blob(shared.base+0x3704e38,8),0)
    local index=flow and shared.uint(shared.blob(flow+0xf0,4),0)
    -- The game's flow table names these STEPUP_TUTORIAL and FREE_TRAINING.
    if index==51 or index==52 then return index end
end

function shared.training_state(mode)
    local reader=shared.core_context.reader
    local snapshot=reader.a11y and reader.a11y.native_windows
    if not snapshot then return nil,"training-window-state-unavailable" end
    for _,window in ipairs(snapshot.windows) do
        if window.enabled and window.slot<7 then
            local tutorial_hud=mode==51 and window.vtable==shared.base+0x267e750
            if not tutorial_hud then return nil,"training-menu-active" end
        end
    end
    if reader.overlay_visible or reader.sider_overlay_visible then return nil,"training-overlay-active" end
    local world=shared.ptr(shared.blob(shared.base+shared.GAME_ROOT,8),0)
    if not world or world<65536 then return nil,"training-world-unavailable" end
    return world
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

-- The match HUD resolves live lineup slots through TeamPlayerInfo, then
-- indexes the two match rosters in the current game data service.
function shared.match_roster_data()
    local service=shared.ptr(shared.blob(shared.base+0x3705e10,8),0)
    return service and shared.ptr(shared.blob(service+0x50,8),0)
end

local function native_name(bytes)
    local name=bytes and bytes:match("^([^%z]+)%z")
    if name and not name:find("%c") and name:find("%S") then return name end
end

local function roster_player(data,side,slot)
    local record=data and shared.blob(data+0x35960+0x1308+(side*40+slot)*0x188,0x148)
    local id=shared.uint(record,0x30)
    local flags=shared.uint(record,0x144)
    if not id or id==0 or not flags or flags>=0x80000000 then return end
    return native_name(record:sub(0x39,0x75)),id
end

function shared.poll_cards(ctx,now)
    if not shared.card_layout_supported or not shared.match_names_supported
            or not shared.announcement_session or now<(shared.next_card_poll or 0) then return end
    shared.next_card_poll=now+100
    local _,raw=shared.reference_data("record",8)
    if not raw then return end
    -- Timeline renderer 4ebb00 reads the card array through RecordInfo+750d0.
    -- 8c6e60 appends 40-byte entries before advancing the count (maximum 39).
    local count_bytes=shared.blob(raw+8+0x1803c0,1)
    local count=count_bytes and count_bytes:byte(1)
    if not count or count>39 then return end
    local previous=shared.card_record==raw and shared.card_count
    if not previous or count<previous then
        shared.card_record,shared.card_count=raw,count
        return
    end
    if previous==count then return end
    local reader=ctx.flaccess.reader
    if reader.overlay_visible or reader.sider_overlay_visible then
        shared.card_count=count
        return
    end
    local entries=shared.blob(raw+8+0x17fd80+previous*40,(count-previous)*40)
    local roster=shared.match_roster_data()
    if not entries or not roster then return end
    local spoken={}
    for offset=0,#entries-1,40 do
        local side,slot=shared.uint(entries,offset+4),shared.uint(entries,offset+0x14)
        if shared.uint(entries,offset)==1 and side<=1 and slot<40 then
            local name=roster_player(roster,side,slot)
            if not name then return end
            local red=entries:byte(offset+0x19)~=0
            local pt=reader.a11y.ui_language=="pt"
            local label=red and (pt and "Cartão vermelho" or "Red card") or (pt and "Cartão amarelo" or "Yellow card")
            spoken[#spoken+1]=label .. (pt and " para " or " for ") .. name
        end
    end
    local _,current=shared.reference_data("record",8)
    if current~=raw or shared.blob(raw+8+0x1803c0,1)~=count_bytes or shared.match_roster_data()~=roster then return end
    shared.card_count=count
    if #spoken>0 and shared.speak_match(ctx,table.concat(spoken,". "),true) then
        reader.a11y.native_speech_queue[reader.a11y.native_speech_last].match_card=true
    end
end

local function team_name(data,side,expected)
    local bytes=shared.blob(data+0x35960+0x138+side*0x690,0x4a)
    local encoded=shared.uint(bytes,0)
    if encoded and tonumber(expected)==math.floor(encoded/0x4000)%0x20000 then
        return native_name(bytes:sub(5))
    end
end

function shared.ball_holder_name(keeper,include_number)
    if not shared.match_names_supported or not keeper or keeper<0 or keeper>=22 then return end
    local side=math.floor(keeper/11)
    local world=shared.ptr(shared.blob(shared.base+shared.GAME_ROOT,8),0)
    local roster_link=world and world+0x1978+side*0x28
    local roster=shared.ptr(shared.blob(roster_link,8),0)
    local lineup=shared.blob(roster,0x30)
    if shared.uint(lineup,0)~=side then return end
    local slot=shared.uint(lineup,4+(keeper%11)*4)
    if not slot or slot>=40 then return end
    local data=shared.match_roster_data()
    local name,id=roster_player(data,side,slot)
    local number
    if name and include_number and shared.shirt_number_supported then
        -- The substitution panel uses this roster count and number array for
        -- playerName_number_str, indexed by the same slot as the name.
        local team=data+0x35960+0x138+side*0x690
        local count=shared.blob(team+0x426,1)
        if count and slot<count:byte(1)%128 then
            local bytes=shared.blob(team+0x29a+slot*2,2)
            if bytes then
                local value=bytes:byte(1)+256*bytes:byte(2)
                if value>=1 and value<=99 then number=value end
            end
        end
    end
    if name and shared.blob(roster,0x30)==lineup and shared.ptr(shared.blob(roster_link,8),0)==roster
            and shared.ptr(shared.blob(shared.base+shared.GAME_ROOT,8),0)==world
            and shared.match_roster_data()==data then
        return name,side .. ":" .. id,number
    end
end

function shared.m.scoreboard_text(stats,home,away,pt)
    if not stats or not home or not away then return end
    local minutes,home_score,away_score=stats.clock_minutes,stats.home_score,stats.away_score
    for _,value in ipairs({minutes or false,home_score or false,away_score or false}) do
        if type(value)~="number" or value<0 or value>255 or value%1~=0 then return end
    end
    local unit=pt and (minutes==1 and "minuto" or "minutos") or (minutes==1 and "minute" or "minutes")
    return string.format("%d %s. %s %d, %s %d.",minutes,unit,home,home_score,away,away_score)
end

function shared.m.announce_scoreboard(ctx,pause)
    if not shared.match_names_supported then return false end
    local stats=match.stats()
    local playing,reason=shared.match_state(stats)
    if not playing and not (pause and reason=="paused") then return false end
    local data=shared.match_roster_data()
    if not data then return false end
    local home=team_name(data,0,ctx.home_team)
    local away=team_name(data,1,ctx.away_team)
    if shared.match_roster_data()~=data then return false end
    local reader=ctx.flaccess.reader
    return shared.speak_match(ctx,shared.m.scoreboard_text(stats,home,away,reader.a11y.ui_language=="pt"),true,pause)
end

function shared.poll_substitutions(ctx,now,playing)
    local reader=ctx.flaccess.reader
    if not playing or not shared.match_names_supported or not reader.speak
            or reader.overlay_visible or reader.sider_overlay_visible
            or now<(shared.next_substitution_poll or 0) then return end
    shared.next_substitution_poll=now+125
    local world=shared.ptr(shared.blob(shared.base+shared.GAME_ROOT,8),0)
    local data=shared.match_roster_data()
    if not world or not data then return end
    if shared.substitution_world~=world or shared.substitution_data~=data then
        shared.substitution_world,shared.substitution_data=world,data
        shared.substitution_teams={}
    end
    local pt=reader.a11y.ui_language=="pt"
    for side=0,1 do
        local link=world+0x1978+side*0x28
        local roster=shared.ptr(shared.blob(link,8),0)
        local lineup=shared.blob(roster,0x30)
        if shared.uint(lineup,0)==side then
            local state=shared.substitution_teams[side]
            if not state then state={};shared.substitution_teams[side]=state end
            if lineup==state.lineup then
                state.candidate=nil
            else
                local slots,count={},0
                for position=0,10 do
                    local slot=shared.uint(lineup,4+position*4)
                    if slot<40 and not slots[slot] then slots[slot]=true;count=count+1
                    elseif slot~=255 and slot~=4294967295 then count=0;break end
                end
                if count>=7 and lineup==state.candidate
                        and shared.ptr(shared.blob(link,8),0)==roster then
                    local exits,entries={},{}
                    if state.slots then
                        for slot=0,39 do
                            if state.slots[slot] and not slots[slot] then exits[#exits+1]=slot
                            elseif slots[slot] and not state.slots[slot] then entries[#entries+1]=slot end
                        end
                    end
                    local accepted=true
                    if #exits>0 and #exits==#entries then
                        local out_names,in_names={},{}
                        for index,slot in ipairs(exits) do
                            out_names[index]=roster_player(data,side,slot)
                            in_names[index]=roster_player(data,side,entries[index])
                            if not out_names[index] or not in_names[index] then accepted=false;break end
                        end
                        if accepted then
                            local expected=side==0 and ctx.home_team or ctx.away_team
                            local name=team_name(data,side,expected)
                                or (pt and (side==0 and "Mandante" or "Visitante") or (side==0 and "Home" or "Away"))
                            local out_prefix=pt and (#exits==1 and "Sai " or "Saem ") or "Off: "
                            local in_prefix=pt and (#entries==1 and "Entra " or "Entram ") or "On: "
                            local caption=name .. ". " .. out_prefix .. table.concat(out_names,", ")
                                .. ". " .. in_prefix .. table.concat(in_names,", ") .. "."
                            if shared.match_roster_data()==data and shared.blob(roster,0x30)==lineup then
                                accepted=shared.speak_match(ctx,caption,false)
                            else
                                accepted=false
                            end
                        end
                    end
                    if accepted then state.lineup,state.slots,state.candidate=lineup,slots,nil end
                else
                    state.candidate=count>=7 and lineup or nil
                end
            end
        end
    end
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
local function player_position(actor,pointer)
    local data=shared.blob(pointer,0x630)
    if not data or shared.ptr(data,0)~=shared.base+shared.PLAYER_VTABLE or shared.uint(data,0x18)~=actor then return end
    local position=shared.vector(data,0x624)
    if shared.valid_position(position) then return position,data end
end

function shared.radar_positions(state)
    local address=shared.base+shared.PLAYERS
    local pointers=shared.blob(address,22*8)
    if not pointers then return end
    local positions,count={},0
    for actor=0,21 do
        local position=player_position(actor,shared.ptr(pointers,actor*8))
        if position and math.abs(position[1])<=state.length+4 and math.abs(position[3])<=state.width+4 then
            positions[actor]=position
            count=count+1
        end
    end
    if shared.blob(address,22*8)~=pointers then return end
    if not shared.radar_scan_reported then
        shared.report("player radar: validated positions=" .. count .. "/22")
        shared.radar_scan_reported=true
    end
    return positions
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
    local player=shared.ptr(shared.blob(shared.base+shared.PLAYERS+actor*8,8),0)
    local position,data=player_position(actor,player)
    if not position then return nil,"player-pose-unavailable" end
    local ball=shared.reference_data("ball",0x20);local field=shared.reference_data("field",0x0c)
    if not ball or not field then return nil,"resolving-game-references" end
    local ball_position=shared.vector(ball,0x10)
    local yaw=shared.float(data,0x61c)
    local length,width=shared.float(field,4),shared.float(field,8)
    if not shared.valid_position(ball_position) then return nil,"ball-position-invalid" end
    local env=shared.reference_data("camera_env",0x49)
    local camera_id=env and env:byte(0x49)
    local attack_sign,goal_reason=shared.goal_direction(actor)
    local camera_frame,camera_reason,ball_camera
    if shared.camera_api and shared.camera_source_supported then
        local camera=shared.reference_data("camera",0x5c)
        camera_frame,camera_reason=shared.camera_api.field_frame(camera,position,camera_id,attack_sign)
        if camera_id==8 then
            ball_camera=shared.camera_api.listener_frame(camera,position,camera_id)
        else
            ball_camera=camera_frame
        end
        local current_env=shared.reference_data("camera_env",0x49)
        if not current_env or current_env:byte(0x49)~=camera_id then
            camera_frame=nil;ball_camera=nil;camera_reason="camera-changed-during-read"
        end
    else camera_reason="camera-source-unverified" end
    if not length or not width or length<40 or length>70 or width<20 or width>50 then return nil,"field-size-invalid" end
    local owns_ball,ownership,possession_known,keeper=shared.possession(actor)
    return {camera=camera_frame,ball_camera=ball_camera,camera_id=camera_id,camera_reason=camera_reason,keeper=keeper,attack_sign=attack_sign,goal_reason=goal_reason,yaw=yaw,actor=actor,slot=slot,player=position,ball=ball_position,right=camera_frame and camera_frame.right,up=camera_frame and camera_frame.up,forward=camera_frame and camera_frame.forward,length=length,width=width,owns_ball=owns_ball,ownership=ownership,possession_known=possession_known}
end

    shared.stage = 5
end
function component.init(ctx)
    component.install(ctx)

end
return component
