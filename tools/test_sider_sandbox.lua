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
local registration_count = 0
local context = {
    custom_evt_rbx = 1,
    sider_dir = sider_dir,
    get_event_id = function()
        event_count = event_count + 1
        return event_count
    end,
    register = function(name, callback)
        assert(callbacks[name] == nil,
            "duplicate Sider callback registration: " .. name)
        callbacks[name] = callback
        registration_count = registration_count + 1
    end,
}
module.init(context)

assert(event_count == 16, "unexpected custom event count: " .. event_count)
assert(registration_count == 23,
    "unexpected callback count: " .. registration_count)
assert(callbacks.display_frame, "display_frame callback was not registered")
assert(callbacks.livecpk_data_ready, "flow metadata callback was not registered")
assert(callbacks["custom:flaccess_keyboard_input_set"], "native input callback was not registered")
assert(callbacks["custom:flaccess_ui_focus_event"], "shared focus callback was not registered")
assert(callbacks["custom:flaccess_nested_list_caption"], "nested-list caption callback was not registered")
assert(callbacks["custom:flaccess_roster_rule_boundary"], "native roster boundary callback was not registered")
assert(callbacks.context_reset and callbacks.overlay_content,
    "screen reset or overlay callback was not registered")
for _ = 1, 120 do
    callbacks.display_frame(context)
end
local prism_status
local text_asset_languages = {}
for _, message in ipairs(logs) do
    if message:find("native-prism-ready", 1, true) then
        prism_status = "ready"
        break
    elseif message:find("native-prism-no-backend", 1, true) then
        prism_status = "no-backend-in-headless-test"
    end
    local language, count = message:match(
        "text%-assets%-loaded language=(%a+) count=(%d+)")
    if language then
        text_asset_languages[language] = tonumber(count)
    end
end
assert(prism_status,
    "native Prism boundary did not initialize during runtime test: " ..
    table.concat(logs, " | "))
assert((text_asset_languages.pt or 0) > 10000,
    "Portuguese runtime text assets were not loaded")
assert((text_asset_languages.en or 0) > 10000,
    "English runtime text assets were not loaded")
print("SIDER_SANDBOX_RUNTIME_OK events=" .. event_count ..
    " frames=120 prism=" .. prism_status ..
    " text_pt=" .. text_asset_languages.pt ..
    " text_en=" .. text_asset_languages.en)
