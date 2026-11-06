-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 5, "FLAccess gameplay: missing or reordered component diagnostics")
function shared.diagnostics(now,state)
    if now<shared.next_diagnostic then return end;shared.next_diagnostic=now+1000
    if shared.registry_reason then shared.report("native registry pending=" .. shared.registry_reason) end
    local controls=shared.control_data()
    if controls then
        local f=io.open(shared.root .. "live-controls.tsv","ab")
        if f then
            for i=0,23 do
                local o=i*0x74;local actor=shared.uint(controls,o+0x20)
                if actor and actor<22 then
                    local player=shared.ptr(shared.blob(shared.base+shared.PLAYERS+actor*8,8),0);local xyz=shared.vector(shared.blob(player,0x630),0x624)
                    f:write(string.format("%.0f\t%d\t%d\t%d\t%s\t%s\t%s\t%s\n",now,i,controls:byte(o+7),actor,
                        tostring(player),tostring(xyz and xyz[1]),tostring(xyz and xyz[2]),tostring(xyz and xyz[3])))
                end
            end
            f:close()
        end
    end
    if state then shared.report(string.format("pose actor=%d slot=%d player=(%.3f,%.3f,%.3f) ball=(%.3f,%.3f,%.3f) centered=%s %s",state.actor,state.slot,
        state.player[1],state.player[2],state.player[3],state.ball[1],state.ball[2],state.ball[3],tostring(state.owns_ball),state.ownership));shared.report(string.format("body yaw=%.3f attack-sign=%s goals=%s",state.yaw or -1,tostring(state.attack_sign),state.goal_reason));shared.report(string.format("cameraRadar id=%s profile=%s reason=%s",tostring(state.camera_id),tostring(state.camera and state.camera.name),tostring(state.camera_reason)));shared.report("audio orientation=" .. tostring(state.camera and state.camera.orientation or "legacy-screen-projection"))
        if state.camera then
            local point=shared.camera_api.project(state.camera,state.ball)
            shared.report(string.format("camera calibration source=%s pan=%d depth=%d scale=%.3f ball=(%s,%s,%s)",
                tostring(state.camera.profile_source),state.camera.pan_sign,state.camera.depth_sign,state.camera.depth_scale,
                tostring(point and point[1]),tostring(point and point[2]),tostring(point and point[3])))
        end
    end
    if state then
        local _,raw=shared.reference_data("analyze",8)
        shared.report(string.format("keeper-source=ANALYZE/INFO data=%s %s",tostring(raw),state.ownership))
    end
    if shared.sources then
        if shared.audio_connection then
            shared.al.alcGetIntegerv(shared.device,0x313,1,shared.audio_connection) -- ALC_CONNECTED
            local connected=shared.audio_connection[0]~=0
            if connected~=shared.last_audio_connected then
                shared.report("audio output connected=" .. tostring(connected))
                shared.last_audio_connected=connected
            end
        end
        local gain,playing,offset=ffi.new("float[1]"),ffi.new("int[1]"),ffi.new("float[1]")
        shared.al.alcMakeContextCurrent(shared.context)
        shared.al.alGetSourcef(shared.sources[0],0x100a,gain);shared.al.alGetSourcei(shared.sources[0],0x1010,playing);shared.al.alGetSourcef(shared.sources[0],0x1024,offset)
        shared.report(string.format("audio ball gain=%.4f state=%x offset=%.3f",gain[0],playing[0],offset[0]))
        for i=1,2 do
            shared.al.alGetSourcef(shared.sources[i],0x100a,gain);shared.al.alGetSourcei(shared.sources[i],0x1010,playing)
            shared.report(string.format("audio sideline=%d gain=%.4f state=%x",i,gain[0],playing[0]))
        end
    end
end
function shared.read_layout(now)
    if now<shared.next_layout then return end;shared.next_layout=now+1000
    local f=io.open(shared.root .. "live-layout.txt","rb")
    if not f then shared.enabled=false;return end
    local text=f:read("*a");f:close()
    -- Development gate armed only after live native mapping is checked.
    shared.enabled=text:match("^validated_single_local_player%s*=%s*1%s*$")~=nil
end

    shared.stage = 6
end
function component.init(ctx)
    component.install(ctx)

end
return component
