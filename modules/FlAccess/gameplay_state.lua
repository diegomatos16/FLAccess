-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 0, "FLAccess gameplay: missing or reordered component state")
-- Local gameplay experiment 1. All positions come from the running game.
shared.m={version="0.2.0 experimental19 audio recovery"}
shared.shared_audio,shared.registry_api,shared.registry_reason,shared.camera_api = nil,nil,nil,nil
shared.camera_source_supported=false
shared.possession_supported=false
shared.al,shared.kernel,shared.root,shared.asset_root,shared.library_root,shared.base,shared.process,shared.buffer,shared.got,shared.device,shared.context,shared.sources,shared.buffers = nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
shared.disabled,shared.busy,shared.was_match=false,false,false
shared.last_frame,shared.status = nil,nil
shared.next_diagnostic,shared.next_layout,shared.next_state_diagnostic=0,0,0
shared.enabled=false
shared.references={}
shared.read_failure = nil
shared.cursor_slot = nil
shared.gains={0,0,0,0,0,0}
shared.loop_sources={0,1,2,5,6,10}
shared.goal_ready={}
shared.heading_previous = nil
shared.possession_previous = nil
shared.cue_ready={}
shared.tackle_settings,shared.tackle_previous,shared.tackle_playing,shared.tackle_ready = nil,nil,nil,nil
shared.cue_sources={gotBall=3,LostBall=4,teamStillWithBall=7}
shared.cue_buffers={gotBall=2,LostBall=3,teamStillWithBall=6}
shared.CAPACITY=512*1024
shared.GAME_ROOT,shared.PLAYERS,shared.PLAYER_VTABLE=0x36f3dc8,0x36f3fc0,0x26329a8
function shared.report(text) log("[FlAccessGameplay] " .. text) end
function shared.transition(text) if shared.status~=text then shared.status=text;shared.report(text) end end
function shared.finite(x) return x==x and x>-math.huge and x<math.huge end
function shared.dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
function shared.unit(v)
    local n=math.sqrt(shared.dot(v,v))
    if shared.finite(n) and n>0.001 then return {v[1]/n,v[2]/n,v[3]/n} end
end

    shared.stage = 1
end
function component.init(ctx)
    component.install(ctx)

end
return component
