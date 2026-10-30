-- Load the actual DLL and read its idle state. Do not start the worker.
local ffi=require("ffi")
ffi.cdef[[
typedef struct {
    uint32_t size; int32_t status; uint32_t process_id,native_sessions,linked_sessions;
    float volume; int32_t muted,last_hresult; char device_name[256];
} FLAccessAudioMasterState;
int FLAccessAudio_GetState(FLAccessAudioMasterState*);
]]
local dll=ffi.load(assert(arg[1]))
local state=ffi.new("FLAccessAudioMasterState[1]")
assert(ffi.sizeof(state[0])==288)
assert(dll.FLAccessAudio_GetState(state)==0) -- Incorrect caller size rejected.
state[0].size=288
assert(dll.FLAccessAudio_GetState(state)==1)
assert(state[0].status==0 and state[0].muted==1 and state[0].volume==0)
assert(state[0].native_sessions==0 and state[0].linked_sessions==0)
print("PASS actual x64 DLL load/export/ABI; idle state only, worker never started")
