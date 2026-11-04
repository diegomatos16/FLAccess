-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 1, "FLAccess gameplay: missing or reordered component rules")
function shared.m.project(d,r,u,f) return {shared.dot(d,r),shared.dot(d,u),-shared.dot(d,f)} end
function shared.m.horizontal_basis(right,forward)
    local r=shared.unit({right[1],0,right[3]})
    if not r then return nil end
    local f={r[3],0,-r[1]}
    if shared.dot(f,forward)<-0.001 then return nil end
    return r,{0,1,0},f
end
-- Native Player+61c is degrees around Y: 0 faces +Z, 90 faces +X.
-- The model consumer 923572 -> 1eb56d0 receives this exact angle.
function shared.m.body_basis(degrees)
    if not degrees or not shared.finite(degrees) or degrees<0 or degrees>=360 then return nil end
    local yaw=degrees*math.pi/180
    return {math.cos(yaw),0,-math.sin(yaw)},{0,1,0},{math.sin(yaw),0,math.cos(yaw)}
end
function shared.m.smooth_heading(previous,actor,degrees,dt)
    if not previous or previous.actor~=actor then return {actor=actor,degrees=degrees} end
    local delta=(degrees-previous.degrees+180)%360-180
    return {actor=actor,degrees=(previous.degrees+delta*(1-math.exp(-math.min(math.max(dt,0),0.1)/0.08)))%360}
end
function shared.m.ball_point(d,r,u,f,owns_ball)
    if owns_ball then return {0,0,-1} end
    return shared.m.project(d,r,u,f)
end
function shared.m.normalization_factor(rms,peak)
    if not shared.finite(rms) or not shared.finite(peak) or rms<=0 or peak<=0 then return nil end
    return math.min(0.18/rms,0.85/peak)
end
function shared.m.possession_change(previous,actor,keeper,known)
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
function shared.m.tackle_settings(text)
    local settings={enabled=true,distance=2,exit_distance=2.3,max_ball_height=1,volume=0.3}
    text="\n" .. (text or "")
    local function value(key)
        return tonumber(text:match("[\r\n]%s*" .. key .. "%s*=%s*([^\r\n;#]+)"))
    end
    local enabled=value("tackle_enabled")
    if enabled==0 then settings.enabled=false end
    for _,rule in ipairs({{"distance",0.5,5},{"exit_distance",0.5,6},{"max_ball_height",0.1,1},{"volume",0,1}}) do
        local v=value("tackle_" .. rule[1])
        if v and shared.finite(v) and v>=rule[2] and v<=rule[3] then settings[rule[1]]=v end
    end
    if settings.exit_distance<settings.distance then settings.exit_distance=settings.distance+0.3 end
    return settings
end
function shared.m.tackle_proximity(previous,actor,keeper,known,player,ball,settings)
    local current={actor=actor,active=false}
    if not settings.enabled or not known or not keeper or keeper==255
        or math.floor(keeper/11)==math.floor(actor/11) then return current end
    if ball[2]>settings.max_ball_height or math.abs(ball[2]-player[2])>settings.max_ball_height then return current end
    local radius=previous and previous.actor==actor and previous.active and settings.exit_distance or settings.distance
    local dx,dz=ball[1]-player[1],ball[3]-player[3]
    current.active=dx*dx+dz*dz<=radius*radius
    return current
end
function shared.m.proximity(distance,radius)
    local t=math.max(0,math.min(1,1-distance/radius));return t*t*(3-2*t)
end

    shared.stage = 2
end
function component.init(ctx)
    component.install(ctx)

end
return component
