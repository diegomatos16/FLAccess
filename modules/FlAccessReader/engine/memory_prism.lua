function a11y.safe_memory_read(address,size)
    local at=tonumber(address)
    if not at or at<0x10000 or at>0x7fffffffffff or at~=math.floor(at)
            or not size or size<0 or size>65536 or size~=math.floor(size) then return nil end
    if size==0 then return "" end
    if not a11y.memory_copy_buffer or a11y.memory_copy_capacity<size then
        local capacity=64
        while capacity<size do capacity=capacity*2 end
        a11y.memory_copy_buffer=ffi.new("uint8_t[?]",capacity)
        a11y.memory_copy_capacity=capacity
    end
    if not a11y.memory_copy_count then a11y.memory_copy_count=ffi.new("size_t[1]") end
    a11y.memory_copy_count[0]=0
    if a11y.render_metric then a11y.render_metric.reads=a11y.render_metric.reads+1 end
    local copied=ffi.C.ReadProcessMemory(ffi.C.GetCurrentProcess(),ffi.cast("const void*",at),
        a11y.memory_copy_buffer,size,a11y.memory_copy_count)
    if copied==0 or tonumber(a11y.memory_copy_count[0])~=size then return nil end
    return ffi.string(a11y.memory_copy_buffer,size)
end
a11y.production_memory_read=a11y.safe_memory_read

function a11y.prism_proc(name, ctype)
    local address = ffi.C.GetProcAddress(
        a11y.prism_library, a11y.to_c_string(name))
    if address == nil then return nil end
    return ffi.cast(ctype, address)
end

function a11y.create_prism_backend(backend_id)
    if not backend_id or not a11y.prism_functions then return nil end
    local prism = a11y.prism_functions
    local backend = prism.registry_create(a11y.prism_context, backend_id)
    if backend == nil then return nil end
    if tonumber(prism.backend_features(backend)) % 2 ~= 1
            or prism.backend_initialize(backend) ~= 0 then
        prism.backend_free(backend)
        return nil
    end
    return backend
end

function a11y.replace_prism_backend(backend)
    if not backend then return false end
    local prism = a11y.prism_functions
    if a11y.prism_backend then
        prism.backend_free(a11y.prism_backend)
    end
    a11y.prism_backend = backend
    local name = prism.backend_name(backend)
    a11y.prism_backend_name = name ~= nil and ffi.string(name) or "unknown"
    log(string.format(
        "[FLAccess] native-prism-backend=%q",
        a11y.prism_backend_name))
    return true
end

function a11y.select_prism_backend(excluded_name)
    for _, reader in ipairs(a11y.prism_screen_readers) do
        if reader.name ~= excluded_name then
            local backend = a11y.create_prism_backend(reader.id)
            if backend then return a11y.replace_prism_backend(backend) end
        end
    end
    -- UIA is useful for Narrator and other readers which expose the Windows
    -- screen-reader flag. Without that flag it would initialize successfully
    -- but silently beat SAPI at the same Prism priority.
    if a11y.prism_uia_id and excluded_name ~= "UIA"
            and user32.GetSystemMetrics(70) ~= 0 then
        local backend = a11y.create_prism_backend(a11y.prism_uia_id)
        if backend then return a11y.replace_prism_backend(backend) end
    end
    local sapi = a11y.create_prism_backend(a11y.prism_sapi_id)
    return sapi and a11y.replace_prism_backend(sapi) or false
end

function a11y.initialize_native_prism()
    if a11y.prism_context then return true end
    if a11y.prism_failed or not a11y.sider_dir then return false end
    local dll_path = a11y.sider_dir .. "\\modules\\FlAccessReader\\bin\\prism.dll"
    local wide_path = to_wide(dll_path)
    a11y.prism_library = wide_path and ffi.C.LoadLibraryW(wide_path) or nil
    if a11y.prism_library == nil then
        a11y.prism_failed = true
        log(string.format("[FLAccess] native-prism-load-failed path=%q", dll_path))
        return false
    end
    local specifications = {
        {"init", "prism_init", "FLACCESS_PRISM_INIT"},
        {"shutdown", "prism_shutdown", "FLACCESS_PRISM_SHUTDOWN"},
        {"registry_count", "prism_registry_count", "FLACCESS_PRISM_REGISTRY_COUNT"},
        {"registry_id_at", "prism_registry_id_at", "FLACCESS_PRISM_REGISTRY_ID_AT"},
        {"registry_name", "prism_registry_name", "FLACCESS_PRISM_REGISTRY_NAME"},
        {"registry_priority", "prism_registry_priority", "FLACCESS_PRISM_REGISTRY_PRIORITY"},
        {"registry_create", "prism_registry_create", "FLACCESS_PRISM_REGISTRY_CREATE"},
        {"backend_free", "prism_backend_free", "FLACCESS_PRISM_BACKEND_FREE"},
        {"backend_name", "prism_backend_name", "FLACCESS_PRISM_BACKEND_NAME"},
        {"backend_features", "prism_backend_get_features", "FLACCESS_PRISM_BACKEND_FEATURES"},
        {"backend_initialize", "prism_backend_initialize", "FLACCESS_PRISM_BACKEND_INITIALIZE"},
        {"backend_speak", "prism_backend_speak", "FLACCESS_PRISM_BACKEND_SPEAK"},
    }
    a11y.prism_functions = {}
    for _, specification in ipairs(specifications) do
        local fn = a11y.prism_proc(specification[2], specification[3])
        if not fn then
            a11y.prism_failed = true
            log("[FLAccess] native-prism-export-missing " .. specification[2])
            return false
        end
        a11y.prism_functions[specification[1]] = fn
    end
    -- Older Prism builds may lack these optional APIs. Navigation still uses
    -- interrupting speak when they are unavailable.
    a11y.prism_functions.backend_stop = a11y.prism_proc(
        "prism_backend_stop", "FLACCESS_PRISM_BACKEND_STOP")
    local prism = a11y.prism_functions
    a11y.prism_context = prism.init(nil)
    if a11y.prism_context == nil then
        a11y.prism_failed = true
        log("[FLAccess] native-prism-init-failed")
        return false
    end
    local supported_readers = {
        VoiceOver=true, NVDA=true, JAWS=true, Orca=true,
        ["Android Screen Reader"]=true, ZDSR=true, ZoomText=true,
        BoyPCReader=true, PCTalker=true, SenseReader=true,
        SystemAccess=true, WindowEyes=true, Spiel=true,
    }
    a11y.prism_screen_readers = {}
    local count = tonumber(prism.registry_count(a11y.prism_context))
    for index = 0, count - 1 do
        local id = prism.registry_id_at(a11y.prism_context, index)
        local name_pointer = prism.registry_name(a11y.prism_context, id)
        local name = name_pointer ~= nil and ffi.string(name_pointer) or ""
        if name == "SAPI" then
            a11y.prism_sapi_id = id
        elseif name == "UIA" then
            a11y.prism_uia_id = id
        elseif supported_readers[name] then
            a11y.prism_screen_readers[#a11y.prism_screen_readers + 1] = {
                id=id,
                name=name,
                priority=prism.registry_priority(a11y.prism_context, id),
            }
        end
    end
    table.sort(a11y.prism_screen_readers, function(left, right)
        return left.priority > right.priority
    end)
    if not a11y.select_prism_backend() then
        a11y.prism_failed = true
        log("[FLAccess] native-prism-no-backend")
        return false
    end
    log(string.format("[FLAccess] native-prism-ready path=%q", dll_path))
    return true
end

function a11y.refresh_native_prism(now_ms)
    if not a11y.prism_backend then return a11y.select_prism_backend() end
    local prism = a11y.prism_functions
    if a11y.prism_backend_name ~= "SAPI" then
        if tonumber(prism.backend_features(a11y.prism_backend)) % 2 ~= 1 then
            local failed_name = a11y.prism_backend_name
            return a11y.select_prism_backend(failed_name)
        end
        return true
    end
    if now_ms < a11y.prism_next_reader_probe_ms then return true end
    a11y.prism_next_reader_probe_ms = now_ms + 750
    for _, reader in ipairs(a11y.prism_screen_readers) do
        local backend = a11y.create_prism_backend(reader.id)
        if backend then return a11y.replace_prism_backend(backend) end
    end
    if a11y.prism_uia_id and user32.GetSystemMetrics(70) ~= 0 then
        local backend = a11y.create_prism_backend(a11y.prism_uia_id)
        if backend then return a11y.replace_prism_backend(backend) end
    end
    return true
end

local function start_native_prism(ctx)
    a11y.sider_dir = ctx.sider_dir
    a11y.initialize_native_prism()
end

read_u64 = function(bytes)
    if bytes==nil or (type(bytes)=="string" and #bytes<8) then return nil end
    return memory.unpack("u64", bytes)
end

function a11y.query_memory_region(address)
    local mbi=a11y.memory_query_info
    if not mbi then mbi=ffi.new("MEMORY_BASIC_INFORMATION[1]");a11y.memory_query_info=mbi end
    if ffi.C.VirtualQuery(ffi.cast("void*",address),mbi,ffi.sizeof(mbi[0]))==0 then return nil end
    local first=tonumber(ffi.cast("uint64_t",mbi[0].BaseAddress))
    local protect=tonumber(mbi[0].Protect)
    return {first=first,last=first+tonumber(mbi[0].RegionSize),
        allowed=tonumber(mbi[0].State)==0x1000 and protect%0x100~=1
            and math.floor(protect/0x100)%2~=1}
end

readable = function(address,size)
    local at=tonumber(ffi.cast("uint64_t",address))
    local cache=a11y.snapshot_read_work or a11y.render_read_work
    local region=cache and cache.region
    local page=math.floor(at/4096)
    if (not region or at<region.first or at>=region.last) and cache and cache.pages then region=cache.pages[page] end
    if not region or at<region.first or at>=region.last then
        region=a11y.query_memory_region(address)
        if cache then
            cache.region=region
            cache.pages=cache.pages or {};cache.pages[page]=region
        end
    end
    return region~=nil and region.allowed and at+size<=region.last
end

local function game_is_foreground()
    local window = user32.GetForegroundWindow()
    if window == nil then
        return false
    end
    foreground_process_id[0] = 0
    user32.GetWindowThreadProcessId(window, foreground_process_id)
    return tonumber(foreground_process_id[0]) ==
        tonumber(ffi.C.GetCurrentProcessId())
end
a11y.game_is_foreground = game_is_foreground

