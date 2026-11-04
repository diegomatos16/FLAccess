-- One-shot audio feasibility probe. Positions below are simulated, not game data.
-- Armed by modules/FLAccess-Audio/armed.txt; consumes it before playing.
local m = {}
local native_ffi = ffi -- Sider exposes ffi directly; require/pcall are not in its sandbox.
local ffi, al, device, context, sources, buffers, kernel
local root, due, started, finished, last_phase, next_check
local cleanup
local function report(text) log("[FLAccess-audio-probe] " .. text) end

local function check(where)
    local err = al.alGetError()
    if err ~= 0 then finished = true; cleanup(); error(string.format("%s OpenAL error 0x%x", where, err)) end
end

cleanup = function()
    if context ~= nil then
        al.alcMakeContextCurrent(context)
        if sources ~= nil then
            al.alSourceStop(sources[0]); al.alSourceStop(sources[1]); al.alSourceStop(sources[2])
            al.alDeleteSources(3, sources)
            sources = nil
        end
        if buffers ~= nil then al.alDeleteBuffers(2, buffers); buffers = nil end
        al.alcMakeContextCurrent(nil)
        al.alcDestroyContext(context)
        context = nil
    end
    if device ~= nil then al.alcCloseDevice(device); device = nil end
end

local function ensure(condition, message)
    if not condition then
        finished = true
        if al then cleanup() end
        error(message or "audio probe failed")
    end
    return condition
end

local function mono_wav(path)
    local f = ensure(io.open(path, "rb"))
    local data = f:read("*a"); f:close()
    ensure(data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WAVE", "not RIFF WAVE")
    local function u16(p) local a,b = data:byte(p,p+1); return a+b*256 end
    local function u32(p) local a,b,c,d = data:byte(p,p+3); return a+b*256+c*65536+d*16777216 end
    local p, channels, rate, pcm = 13
    while p + 7 <= #data do
        local tag, size = data:sub(p,p+3), u32(p+4)
        ensure(p + 7 + size <= #data, "truncated WAV chunk")
        if tag == "fmt " then
            ensure(size >= 16 and u16(p+8) == 1 and u16(p+22) == 16, "requires PCM16 WAV")
            channels, rate = u16(p+10), u32(p+12)
            ensure(channels == 1 or channels == 2, "requires mono/stereo WAV")
            ensure(u16(p+20) == channels * 2 and rate > 0, "invalid PCM layout")
        elseif tag == "data" then pcm = data:sub(p+8,p+7+size) end
        p = p + 8 + size + size % 2
    end
    ensure(pcm and channels and #pcm > 0 and #pcm % (channels*2) == 0, "missing/invalid PCM")
    local frames = #pcm / (channels*2)
    local input = ffi.new("int16_t[?]", #pcm/2)
    ffi.copy(input, pcm, #pcm)
    local output = ffi.new("int16_t[?]", frames)
    for i=0,frames-1 do
        if channels == 1 then output[i] = input[i]
        else output[i] = math.floor((tonumber(input[i*2]) + tonumber(input[i*2+1])) / 2) end
    end
    report(string.format("wav=%s channels=%d rate=%d frames=%d", path, channels, rate, frames))
    return output, frames*2, rate
end

local function initialize()
    device = al.alcOpenDevice(nil)
    ensure(device ~= nil, "no playback device")
    ensure(al.alcIsExtensionPresent(device, "ALC_SOFT_HRTF") ~= 0, "HRTF extension unavailable")
    local attrs = ffi.new("int[5]", {0x1992, 1, 0x1007, 48000, 0})
    context = al.alcCreateContext(device, attrs)
    ensure(context ~= nil and al.alcMakeContextCurrent(context) ~= 0, "cannot create audio context")
    local status, enabled = ffi.new("int[1]"), ffi.new("int[1]")
    al.alcGetIntegerv(device, 0x1993, 1, status)
    al.alcGetIntegerv(device, 0x1992, 1, enabled)
    report(string.format("HRTF enabled=%d status=%d device=%s", enabled[0], status[0],
        ffi.string(al.alcGetString(device, 0x1005))))
    ensure(enabled[0] ~= 0, "HRTF requested but not enabled")
    local hrtf = al.alcGetString(device, 0x1995)
    if hrtf ~= nil then report("HRTF profile=" .. ffi.string(hrtf)) end
    buffers = ffi.new("unsigned int[2]")
    sources = ffi.new("unsigned int[3]")
    al.alGenBuffers(2, buffers); check("buffers")
    for i,name in ipairs({"ball.wav", "alertSidelines.wav"}) do
        local pcm, bytes, rate = mono_wav(root .. name)
        al.alBufferData(buffers[i-1], 0x1101, pcm, bytes, rate); check("load " .. name)
    end
    al.alGenSources(3, sources); check("sources")
    al.alDistanceModel(0) -- Manual gain makes proximity predictable for this probe.
    al.alDopplerFactor(0)
    al.alListener3f(0x1004, 0, 0, 0)
    al.alListenerfv(0x100f, ffi.new("float[6]", {0,0,-1, 0,1,0}))
    for i=0,2 do
        al.alSourcei(sources[i], 0x1009, buffers[i == 0 and 0 or 1])
        al.alSourcei(sources[i], 0x1007, 1) -- AL_LOOPING: no restarts on position changes.
        al.alSourcef(sources[i], 0x100a, 0)
        al.alSource3f(sources[i], 0x1004, 0,0,-2)
        al.alSourcePlay(sources[i])
    end
    check("start loops")
    report("started simulated sweep; no game coordinates connected")
end

local function update(t)
    local phase = t < 8 and "ball-circle" or t < 14 and "sideline-left" or "sideline-right"
    if phase ~= last_phase then report("phase=" .. phase); last_phase = phase end
    al.alSourcef(sources[0], 0x100a, 0)
    al.alSourcef(sources[1], 0x100a, 0)
    al.alSourcef(sources[2], 0x100a, 0)
    if t < 8 then
        local angle = t * math.pi / 4
        al.alSource3f(sources[0], 0x1004, 2*math.sin(angle), 0, -2*math.cos(angle))
        al.alSourcef(sources[0], 0x100a, 0.25)
    else
        local i = t < 14 and 1 or 2
        local elapsed = t < 14 and t-8 or t-14
        local proximity = 0.5 - 0.5*math.cos(elapsed*math.pi/3)
        al.alSource3f(sources[i], 0x1004, i == 1 and -2 or 2, 0, 0)
        al.alSourcef(sources[i], 0x100a, 0.3*proximity)
    end
    check("update")
    if t >= next_check then
        local state = ffi.new("int[1]")
        for i=0,2 do
            al.alGetSourcei(sources[i], 0x1010, state)
            ensure(state[0] == 0x1012, "loop unexpectedly stopped")
        end
        report(string.format("loops-playing elapsed=%.1f", t))
        next_check = t + 2
    end
end

function m.display_frame(ctx)
    if finished then return end
    local now = tonumber(kernel.GetTickCount64())
    if now < due then return end
    -- Sider itself protects callback execution. Mark stopped before initialization
    -- so a failed DLL/device/WAV operation cannot repeat on every rendered frame.
        if not started then
            finished = true
            initialize(); started = now; next_check = 0
            finished = false
        end
        local elapsed = (now-started)/1000
        if elapsed >= 20 then
            cleanup(); finished = true
            report("completed 20s probe; audio resources released")
        else
            finished = true
            update(elapsed)
            finished = false
        end
end

function m.init(ctx)
    root = ctx.sider_dir .. "modules\\FLAccess-Audio\\"
    local marker = io.open(root .. "armed.txt", "rb")
    if not marker then report("not armed"); finished = true; return end
    local armed = marker:read("*l"); marker:close()
    if armed ~= "armed" then report("already consumed"); finished = true; return end
    marker = ensure(io.open(root .. "armed.txt", "wb"))
    marker:write("consumed\n"); marker:close()
    ffi = ensure(native_ffi, "enable luajit.ext.enabled")
    ffi.cdef[[
        unsigned long long GetTickCount64(void);
        void *alcOpenDevice(const char *name);
        char alcCloseDevice(void *device);
        void *alcCreateContext(void *device, const int *attributes);
        char alcMakeContextCurrent(void *context);
        void alcDestroyContext(void *context);
        char alcIsExtensionPresent(void *device, const char *name);
        void alcGetIntegerv(void *device, int param, int size, int *values);
        const char *alcGetString(void *device, int param);
        int alGetError(void);
        void alGenBuffers(int count, unsigned int *buffers);
        void alDeleteBuffers(int count, const unsigned int *buffers);
        void alBufferData(unsigned int buffer, int format, const void *data, int size, int rate);
        void alGenSources(int count, unsigned int *sources);
        void alDeleteSources(int count, const unsigned int *sources);
        void alSourcei(unsigned int source, int param, int value);
        void alSourcef(unsigned int source, int param, float value);
        void alSource3f(unsigned int source, int param, float x, float y, float z);
        void alGetSourcei(unsigned int source, int param, int *value);
        void alSourcePlay(unsigned int source);
        void alSourceStop(unsigned int source);
        void alListener3f(int param, float x, float y, float z);
        void alListenerfv(int param, const float *values);
        void alDistanceModel(int model);
        void alDopplerFactor(float value);
    ]]
    kernel = ffi.load("kernel32")
    al = ffi.load(root .. "soft_oal.dll")
    due = tonumber(kernel.GetTickCount64()) + 15000
    ctx.register("display_frame", m.display_frame)
    report("armed; simulated audio test starts after 15 seconds; duration 20 seconds")
end

return m
