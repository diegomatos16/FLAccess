-- Shared app master for every FLAccess sound effect, current and future.
-- Windows applies absolute session volume once. Never multiply it into AL gain.
local m={version="0.1.2"}
local native,kernel,root,started,failed,last_status
local function report(value)
    if last_status~=value then last_status=value;log("[FlAccessGameplay-audio] " .. value) end
end
function m.prepare_output()
    if failed then return nil,failed end
    if not started then
        -- Sider omits pcall. Its callback boundary logs DLL load errors;
        -- the consumer's existing failure guard keeps effects silent afterward.
        native=native or ffi.load(root .. "flaccess_audio_master.dll")
        if native.FLAccessAudio_Start()~=1 then
            failed="app master unavailable; effects muted";report(failed);return nil,failed
        end
        started=true
    end
    local state=ffi.new("FLAccessAudioMasterState[1]");state[0].size=ffi.sizeof(state[0])
    if native.FLAccessAudio_GetState(state)~=1 then
        report("cannot read app master; effects muted");return nil,"app-master-unavailable"
    end
    local s=state[0]
    if s.status~=1 or s.native_sessions==0 then
        local why=s.status<0 and "app-master-error" or "waiting-for-game-audio"
        report(string.format("%s HRESULT=%x",why,tonumber(ffi.cast("uint32_t",s.last_hresult))))
        return nil,why
    end
    local device=ffi.string(s.device_name)
    if device=="" then report("game audio device unavailable");return nil,"game-device-unavailable" end
    report("app master linked; game PID=" .. tostring(tonumber(s.process_id)) .. "; device=" .. device)
    return {device=device,volume=tonumber(s.volume),muted=s.muted~=0}
end
function m.open_output(al)
    local state,why=m.prepare_output();if not state then return nil,why end
    -- Pinned OpenAL Soft WASAPI backend uses the process default session (GUID_NULL).
    -- It was prepared by the native master before opening this playback stream.
    if al.alcIsExtensionPresent(nil,"ALC_ENUMERATE_ALL_EXT")==0 then return nil,"audio-device-enumeration-unavailable" end
    local names=al.alcGetString(nil,0x1013)
    if names==nil then return nil,"audio-device-enumeration-empty" end
    local expected="OpenAL Soft on " .. state.device
    local offset=0
    while offset<65536 do
        local name=ffi.string(names+offset)
        if name=="" then break end
        if name==expected then
            local device=al.alcOpenDevice(name)
            if device~=nil then return device end
            return nil,"cannot-open-game-audio-device"
        end
        offset=offset+#name+1
    end
    return nil,"game-audio-device-not-found"
end
function m.init(ctx)
    ffi.cdef[[
        typedef struct {
            uint32_t size; int32_t status; uint32_t process_id,native_sessions,linked_sessions;
            float volume; int32_t muted,last_hresult; char device_name[256];
        } FLAccessAudioMasterState;
        int FLAccessAudio_Start(void);
        int FLAccessAudio_GetState(FLAccessAudioMasterState*);
        int SetEnvironmentVariableA(const char*,const char*);
    ]]
    root=ctx.sider_dir .. "modules\\FlAccess\\bin\\"
    kernel=ffi.load("kernel32")
    -- Backend choice is process-local, before the first OpenAL load. No system settings.
    if kernel.SetEnvironmentVariableA("ALSOFT_DRIVERS","wasapi")==0 then failed="cannot select shared WASAPI output" end
    ctx.flaccess_audio=m
    report("shared audio policy ready; starts with first effect; version=" .. m.version)
end
return m
