local module_path = assert(arg[1], "module path is required")
local sider_dir = assert(arg[2], "temporary Sider directory is required")
local logs = {}

local host = {
    assert = assert,
    table = table,
    pairs = pairs,
    ipairs = ipairs,
    string = string,
    math = math,
    tonumber = tonumber,
    tostring = tostring,
    unpack = unpack,
    error = error,
    _VERSION = _VERSION,
    type = type,
    io = io,
    collectgarbage = collectgarbage,
    jit = jit,
    os = {time = os.time, clock = os.clock, date = os.date},
    ffi = require("ffi"),
    log = function(message)
        logs[#logs + 1] = tostring(message)
    end,
}
host._G = host

local next_cave = 0x70000000
host.memory = {
    get_process_info = function()
        return {base = 0}
    end,
    read = function(_, size)
        return string.rep("\x90", size)
    end,
    guard = function() end,
    allocate_codecave = function()
        next_cave = next_cave + 0x100
        return next_cave
    end,
    pack = function(kind)
        return string.rep("\0", kind == "u16" and 2 or 8)
    end,
    write = function() end,
    hex = tostring,
    unpack = function()
        return 0
    end,
}

local chunk = assert(loadfile(module_path))
setfenv(chunk, host)
local module = assert(chunk())
local event_count = 0
local callbacks = {}
local context = {
    custom_evt_rbx = 1,
    sider_dir = sider_dir,
    get_event_id = function()
        event_count = event_count + 1
        return event_count
    end,
    register = function(name, callback)
        callbacks[name] = callback
    end,
}
module.init(context)

assert(event_count == 12, "unexpected custom event count: " .. event_count)
assert(callbacks.display_frame, "display_frame callback was not registered")
for _ = 1, 120 do
    callbacks.display_frame(context)
end
local prism_status
for _, message in ipairs(logs) do
    if message:find("native-prism-ready", 1, true) then
        prism_status = "ready"
        break
    elseif message:find("native-prism-no-backend", 1, true) then
        prism_status = "no-backend-in-headless-test"
    end
end
assert(prism_status,
    "native Prism boundary did not initialize during runtime test: " ..
    table.concat(logs, " | "))
print("SIDER_SANDBOX_RUNTIME_OK events=" .. event_count ..
    " frames=120 prism=" .. prism_status)
