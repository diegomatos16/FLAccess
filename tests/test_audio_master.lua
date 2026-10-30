-- Shared audio contracts. Fake native ABI/OpenAL only; no audio sessions opened.
ffi=require("ffi")
log=function() end
local real_load=ffi.load
local current={status=0,native_sessions=0,volume=0,muted=1,device="Fones de ouvido (Realtek(R) Audio)"}
local starts,opens=0,0
local native={
    FLAccessAudio_Start=function() starts=starts+1;return 1 end,
    FLAccessAudio_GetState=function(out)
        assert(out[0].size==288)
        out[0].status=current.status;out[0].native_sessions=current.native_sessions
        out[0].volume=current.volume;out[0].muted=current.muted;out[0].process_id=42
        ffi.copy(out[0].device_name,current.device)
        return 1
    end,
}
ffi.load=function(path)
    if path=="kernel32" then return {SetEnvironmentVariableA=function(key,value)
        assert(key=="ALSOFT_DRIVERS" and value=="wasapi");return 1
    end} end
    assert(path:match("flaccess_audio_master.dll$"));return native
end
-- Sider module globals deliberately omit pcall, require, package and os.
-- Keep the host test runner outside this environment.
local module_chunk=assert(loadfile(assert(arg[1])))
setfenv(module_chunk,{ffi=ffi,log=log,tonumber=tonumber,tostring=tostring,string=string})
local m=module_chunk()
local ctx={sider_dir="test\\"};m.init(ctx);assert(ctx.flaccess_audio==m and starts==0)
local value,why=m.prepare_output();assert(not value and why=="waiting-for-game-audio" and starts==1)
local list=ffi.new("char[?]",512,"Other output\0OpenAL Soft on " .. current.device .. "\0\0")
local al={
    alcIsExtensionPresent=function() return 1 end,
    alcGetString=function() return ffi.cast("const char*",list) end,
    alcOpenDevice=function(name)
        assert(name=="OpenAL Soft on " .. current.device);opens=opens+1;return ffi.cast("void*",123)
    end,
}
assert(not m.open_output(al) and opens==0)
current.status=1;current.native_sessions=1;current.volume=0.4;current.muted=0
value=m.prepare_output();assert(value and math.abs(value.volume-0.4)<0.00001 and not value.muted)
assert(m.open_output(al)~=nil and opens==1 and starts==1)
current.muted=1;assert(m.prepare_output().muted)
current.volume=0;assert(m.prepare_output().volume==0)
current.muted=0;current.volume=0.8;assert(not m.prepare_output().muted)
current.device="Different endpoint"
value,why=m.open_output(al);assert(not value and why=="game-audio-device-not-found" and opens==1)
current.status=-1;assert(not m.prepare_output())
current.status=1;current.native_sessions=0;assert(not m.prepare_output())
current.native_sessions=1;current.device="";assert(not m.prepare_output())
ffi.load=real_load
-- Missing shared core must disable gameplay before opening any backend.
local gameplay=assert(loadfile(assert(arg[2])))();gameplay.init({flaccess_match_registry={}})
print("PASS shared Lua audio in restricted Sider globals: lazy startup, mandatory binding, readiness, mute/zero, restore, exact game endpoint, no fallback, native errors; fake ABI only")
