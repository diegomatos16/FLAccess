-- Real installed Lua components, isolated Sider environments and native Prism.
-- Memory/hooks are synthetic here; no game process is modified.
local root=assert(arg[1]);local sider_dir=assert(arg[2])
local ffi=require("ffi")
local logs,callbacks,owner,event_count,registrations={}, {}, nil,0,0
local host={assert=assert,table=table,pairs=pairs,ipairs=ipairs,string=string,
    math=math,tonumber=tonumber,tostring=tostring,unpack=unpack,error=error,
    _VERSION=_VERSION,type=type,io=io,collectgarbage=collectgarbage,jit=jit,ffi=ffi,
    os={time=os.time,clock=os.clock,date=os.date},log=function(s) logs[#logs+1]=s end}
local cave=0x70000000
host.memory={get_process_info=function() return {base=0} end,
    read=function(_,size)return string.rep("\x90",size)end,guard=function()end,
    allocate_codecave=function()cave=cave+0x100;return cave end,
    pack=function(kind)return string.rep("\0",kind=="u16" and 2 or 8)end,
    write=function()end,hex=tostring,unpack=function()return 0 end}
host.match={stats=function()return nil end}
local ctx={sider_dir=sider_dir,custom_evt_rbx=1,
    get_event_id=function()event_count=event_count+1;return event_count end,
    register=function(event,callback)
        callbacks[owner]=callbacks[owner] or {}
        assert(not callbacks[owner][event],"duplicate callback " .. event)
        callbacks[owner][event]=callback;registrations=registrations+1
    end}
local snippet=assert(io.open(arg[3] or root.."/packaging/sider.ini.snippet","rt") or io.open(root.."/sider/sider.ini.snippet","rt"))
local count=0
for line in snippet:lines() do
    local relative=line:match('^lua%.module%s*=%s*"([^"]+)"')
    if relative then
        owner=relative;local env={};for k,v in pairs(host)do env[k]=v end;env._G=env
        local chunk=assert(loadfile(root.."/modules/"..relative));setfenv(chunk,env)
        local component=assert(chunk());assert(type(component.init)=="function")
        component.init(ctx);count=count+1
    end
end
snippet:close()
assert(count==31 and ctx.flaccess.reader.stage==16 and ctx.flaccess.gameplay.stage==8)
assert(event_count==16 and registrations==23)
local reader=ctx.flaccess.reader
assert(reader.VERSION=="0.2.1" and reader.m)
for i=1,120 do
    for _,events in pairs(callbacks)do if events.display_frame then events.display_frame(ctx)end end
end
local prism=false
for _,line in ipairs(logs)do
    if line:find("native-prism-ready",1,true)or line:find("native-prism-no-backend",1,true)then prism=true end
end
assert(prism,"native Prism failed to initialize: "..table.concat(logs," | "))
assert(reader.a11y.text_asset_counts.pt>10000 and reader.a11y.text_asset_counts.en>10000)
assert(ctx.flaccess_audio and ctx.flaccess_match_registry and ctx.flaccess_camera_radars)
for i=0,9 do assert(ctx.flaccess_camera_radars.profiles[i],"camera profile missing "..i)end
-- Installed settings must survive saving the reader's two existing options.
local config_path=arg[4] or root.."/.test-temp/flaccess020-config.ini"
local config=assert(io.open(config_path,"wt"));config:write("read_tooltips=true\ntackle_volume=0.12\ncustom_future=9\n");config:close()
local old_path,old_tooltips=reader.a11y.config_path,reader.a11y.read_tooltips
reader.a11y.config_path=config_path;reader.a11y.read_tooltips=false;reader.a11y.save_config()
config=assert(io.open(config_path,"rt"));local saved=config:read("*a");config:close()
assert(saved:find("read_tooltips = false",1,true)and saved:find("tackle_volume=0.12",1,true)and saved:find("custom_future=9",1,true))
local settings=ctx.flaccess.gameplay.tackle_settings
local old_enabled,old_volume=settings.enabled,settings.volume
local old_language=reader.a11y.ui_language
reader.a11y.ui_language="pt"
settings.enabled,settings.volume=true,0.12
reader.m.show(ctx)
reader.m.key_down(ctx,0x37);reader.m.key_down(ctx,0x37)
assert(reader.m.overlay_on(ctx):find("---> Sons de acessibilidade <---",1,true))
reader.m.key_down(ctx,0x30)
assert(reader.m.overlay_on(ctx):find("---> Som da bola, Ligado <---",1,true))
reader.m.key_down(ctx,0x30);assert(ctx.flaccess.gameplay.sound_gain("ball")==0)
reader.m.key_down(ctx,0x37)
ctx.flaccess.gameplay.sound_levels.ball=298
reader.m.key_down(ctx,0x30);assert(ctx.flaccess.gameplay.sound_levels.ball==300)
reader.m.key_down(ctx,0x37)
ctx.flaccess.gameplay.ball_speed=100
reader.m.key_down(ctx,0x39);assert(ctx.flaccess.gameplay.ball_speed==75)
reader.m.key_down(ctx,0x35);assert(ctx.flaccess.gameplay.sound_preview_request=="ball")
for _=1,9 do reader.m.key_down(ctx,0x37) end
reader.m.key_down(ctx,0x30);assert(not settings.enabled)
reader.m.key_down(ctx,0x37)
reader.m.key_down(ctx,0x30);assert(settings.volume==0.17)
config=assert(io.open(config_path,"rt"));saved=config:read("*a");config:close()
assert(saved:find("tackle_enabled = 0",1,true) and saved:find("tackle_volume = 0.17",1,true)
    and saved:find("sound_ball = 300",1,true) and saved:find("ball_speed = 75",1,true)
    and saved:find("sound_ball_enabled = 0",1,true)
    and saved:find("custom_future=9",1,true))
reader.m.key_down(ctx,0x08)
assert(reader.m.overlay_on(ctx):find("---> Sons de acessibilidade <---",1,true))
assert(not ctx.flaccess.gameplay.sound_preview_request)
reader.m.key_down(ctx,0x36);reader.m.key_down(ctx,0x36);reader.m.key_down(ctx,0x0d)
assert(not reader.m.overlay_on(ctx):find("Saída de fala,",1,true))
for _=1,2 do reader.m.key_down(ctx,0x37) end
reader.m.key_down(ctx,0x38)
reader.m.key_down(ctx,0x30)
assert(reader.a11y.tts_rate==55)
local original_speak=reader.speak
local before_sample=reader.a11y.native_speech_last
reader.speak=function(text)
    reader.a11y.native_speech_last=before_sample+1
    reader.a11y.native_speech_queue[before_sample+1]={text=text}
end
reader.m.key_down(ctx,0x35)
local sample=reader.a11y.native_speech_queue[before_sample+1]
assert(sample.tts_preview and sample.text==reader.a11y.strings().tts_sample)
reader.a11y.native_speech_queue[before_sample+1]=nil
reader.a11y.native_speech_last=before_sample
reader.speak=original_speak
config=assert(io.open(config_path,"rt"));saved=config:read("*a");config:close()
assert(saved:find("tts_rate = 55",1,true))
reader.m.hide(ctx)
reader.a11y.ui_language=old_language
settings.enabled,settings.volume=old_enabled,old_volume
reader.a11y.config_path=old_path;reader.a11y.read_tooltips=old_tooltips
local fresh={sider_dir=sider_dir}
local chunk=assert(loadfile(root.."/modules/FlAccess/core.lua"));setfenv(chunk,host);chunk().init(fresh)
chunk=assert(loadfile(root.."/modules/FlAccess/reader_focus.lua"));setfenv(chunk,host)
assert(not pcall(chunk().install,fresh),"out-of-order component was accepted")
-- Missing profile uses its own embedded default; corrupt profile stays disabled.
chunk=assert(loadfile(root.."/modules/FlAccess/camera.lua"));setfenv(chunk,host)
local camera=chunk();camera.init(fresh,nil,function(id) if id==3 then return "invalid" end end)
assert(fresh.flaccess_camera_radars.profiles[2].source=="embedded")
assert(not fresh.flaccess_camera_radars.profiles[3])
-- Repeated menu frames after gameplay must not resubmit the same mute calls.
local gameplay=ctx.flaccess.gameplay
local old_user32,old_foreground,old_scoreboard=reader.user32,reader.game_is_foreground,gameplay.m.announce_scoreboard
local old_readable=reader.readable
local p_down,foreground,announcements=false,true,0
reader.user32={GetAsyncKeyState=function(key) return key==0x50 and p_down and -1 or 0 end}
reader.game_is_foreground=function() return foreground end
reader.readable=function() return false end
gameplay.m.announce_scoreboard=function() announcements=announcements+1 end
for _=1,6 do reader.m.display_frame(ctx) end
p_down=true;reader.m.display_frame(ctx);assert(announcements==0,"P outside gameplay")
ctx.flaccess.match_playing=true
reader.m.display_frame(ctx);assert(announcements==0,"held P across match start")
p_down=false;reader.m.display_frame(ctx)
p_down=true;reader.m.display_frame(ctx);reader.m.display_frame(ctx)
assert(announcements==1,"one scoreboard per press")
p_down=false;reader.m.display_frame(ctx)
reader.sider_overlay_visible=true
p_down=true;reader.m.display_frame(ctx)
reader.sider_overlay_visible=false;reader.m.display_frame(ctx)
assert(announcements==1,"P in Sider overlay")
p_down=false;reader.m.display_frame(ctx)
foreground=false;p_down=true;reader.m.display_frame(ctx)
foreground=true;for _=1,6 do reader.m.display_frame(ctx) end
assert(announcements==1,"P while game is in background")
ctx.flaccess.match_playing=false
local old_input,old_pause=reader.a11y.poll_attribute_input,reader.a11y.native_pause_context
local select_pressed,paused=false,false
reader.a11y.poll_attribute_input=function() return select_pressed end
reader.a11y.native_pause_context=function() return paused and {identity="test-pause"} or nil end
gameplay.m.announce_scoreboard=function(_,pause)
    assert(pause=="test-pause");announcements=announcements+1
end
p_down=false;select_pressed=true;reader.m.display_frame(ctx)
assert(announcements==1,"Select outside pause")
paused=true;reader.m.display_frame(ctx);assert(announcements==2,"Select in pause")
select_pressed=false;p_down=true;reader.m.display_frame(ctx)
assert(announcements==3,"P in pause")
reader.a11y.poll_attribute_input,reader.a11y.native_pause_context=old_input,old_pause
local old_loading,old_windows=reader.a11y.poll_loading,reader.a11y.poll_native_windows
local refreshes=0
reader.a11y.poll_loading=function() return true end
reader.a11y.poll_native_windows=function() refreshes=refreshes+1 end
reader.m.display_frame(ctx);reader.m.display_frame(ctx)
assert(refreshes==2,"a persistent loading object must not silence interactive menus")
reader.a11y.poll_loading,reader.a11y.poll_native_windows=old_loading,old_windows
local old_snapshot,old_texts=reader.a11y.native_windows,reader.a11y.poll_native_texts
local building,text_polls=true,0
reader.a11y.poll_native_windows=function() reader.a11y.native_windows={match_menu_building=building} end
reader.a11y.poll_native_texts=function() text_polls=text_polls+1 end
reader.m.display_frame(ctx);assert(text_polls==0)
building=false;reader.m.display_frame(ctx);assert(text_polls==1,"read pre-match controls as soon as they exist")
reader.a11y.native_windows,reader.a11y.poll_native_texts,reader.a11y.poll_native_windows=old_snapshot,old_texts,old_windows
reader.user32,reader.game_is_foreground,gameplay.m.announce_scoreboard=old_user32,old_foreground,old_scoreboard
reader.readable=old_readable
ctx.flaccess.match_playing=false
local old_al,old_sources,old_muted=gameplay.al,gameplay.sources,gameplay.audio_muted
local old_gains,old_tackle=gameplay.gains,gameplay.tackle_playing
local gains,stops,current=0,0,0
gameplay.sources=ffi.new("unsigned int[11]")
gameplay.al={alcMakeContextCurrent=function()current=current+1 end,
    alSourcef=function()gains=gains+1 end,alSourceStop=function()stops=stops+1 end}
gameplay.audio_muted=false
for i=1,120 do gameplay.mute()end
assert(gains==10 and stops==4 and current==1,"mute must execute once per audible-to-muted transition")
gameplay.audio_muted=false;gameplay.mute();assert(gains==20 and stops==8)
gameplay.al,gameplay.sources,gameplay.audio_muted=old_al,old_sources,old_muted
gameplay.gains,gameplay.tackle_playing=old_gains,old_tackle
for _,events in pairs(callbacks)do if events.context_reset then events.context_reset(ctx)end end
print("FLACCESS_COMPONENTS_OK modules="..count.." events="..event_count.." registrations="..registrations.." frames=120 native-Prism=true reset=true settings-preserved=true order-guard=true camera-fallback=true")
