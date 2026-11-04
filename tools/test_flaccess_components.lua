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
assert(reader.VERSION=="0.2.0" and reader.m)
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
for _,events in pairs(callbacks)do if events.context_reset then events.context_reset(ctx)end end
print("FLACCESS_COMPONENTS_OK modules="..count.." events="..event_count.." registrations="..registrations.." frames=120 native-Prism=true reset=true settings-preserved=true order-guard=true camera-fallback=true")
