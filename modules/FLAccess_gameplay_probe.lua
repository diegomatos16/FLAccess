-- Read-only feasibility probe for this FL_2026.exe build (image base 0x140000000).
-- Bounded scans spread across display frames; no hooks or writes to game memory.
local m = {}
local native_ffi = ffi
local ffi, kernel, root, scan, output
local classes = {
    {"BallInfoRef", 0x259afb0}, {"PlayerInfoRef", 0x259b070},
    {"PlayerMoveRef", 0x259b150}, {"CameraInfoRef", 0x2599550},
    {"CameraTargetInfoRef", 0x2608738}, {"FieldInfoRef", 0x2608810},
    {"BallControl", 0x25988b0}, {"InplayCamera", 0x2609c28}, {"Player", 0x26329a8},
}
local objects, seen = {}, {}
local capacity = 1024*1024
local buffer, got, region, handle
local halted = false
local function report(text) log("[FLAccess-gameplay-probe] " .. text) end
local function read(address, size)
    if address < 65536 or address >= 140737488355328 then return nil end
    got[0] = 0
    if kernel.ReadProcessMemory(handle, ffi.cast("const void*", address), buffer, size, got) == 0
        or tonumber(got[0]) ~= size then return nil end
    return ffi.string(buffer, size)
end
local function pointer(data, offset)
    if #data < offset+8 then return 0 end
    local value = ffi.new("uint64_t[1]")
    ffi.copy(value, data:sub(offset+1,offset+8), 8)
    return tonumber(value[0])
end
local function hex(data)
    return (data:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end
local function valid_ref(address, name, needle)
    -- Needle strings themselves occur in Lua memory. Require a hydrated registry
    -- reference with a readable registry entry and data, not just matching bytes.
    if not name:match("Ref$") then return false end
    local object = read(address,40)
    if not object or object:sub(1,8) ~= needle or object:byte(9) ~= 1 then return false end
    local entry = read(pointer(object,16),32)
    if not entry then return false end
    return read(pointer(entry,16),32) ~= nil
end
local function capture(now)
    local f = io.open(root .. "gameplay-snapshots.tsv", "ab")
    if not f then report("cannot open snapshots"); return end
    for _,obj in ipairs(objects) do
        local data = read(obj.address, 512)
        if data and data:sub(1,8) == obj.needle then
            f:write(string.format("%.0f\t%s\t%x\t%s\n",now,obj.name,obj.address,hex(data)))
            if obj.name ~= "Player" then
                for _,offset in ipairs({8,16,24,32,64}) do
                    local ptr = pointer(data,offset)
                    if ptr % 8 == 0 then
                        local child = read(ptr,2048)
                        if child then
                            local label = obj.name .. "+" .. string.format("%x",offset)
                            f:write(string.format("%.0f\t%s\t%x\t%s\n",now,label,ptr,hex(child)))
                            if offset == 16 then
                                local target = pointer(child,16)
                                local grandchild = read(target,4096)
                                if grandchild then f:write(string.format("%.0f\t%s+10\t%x\t%s\n",now,label,target,hex(grandchild))) end
                            end
                        end
                    end
                end
            end
        end
    end
    f:close()
    report(string.format("snapshot objects=%d time=%.0f",#objects,now))
end

local function scan_step(now)
    if scan.done then
        if now >= scan.next_capture and scan.captures < 30 then
            capture(now); scan.next_capture = now+3000; scan.captures = scan.captures+1
        end
        return
    end
    if now < scan.next_step then return end
    scan.next_step = now+20
    if scan.remaining <= 0 then
        local queried = kernel.VirtualQuery(ffi.cast("void*",scan.address),region,ffi.sizeof(region[0]))
        if queried == 0 or scan.scanned >= 2048*1024*1024 then
            scan.done = true; scan.next_capture = now; scan.captures = 0
            report(string.format("scan complete scanned=%.1fMB objects=%d",scan.scanned/1048576,#objects))
            return
        end
        local start = tonumber(ffi.cast("uintptr_t",region[0].BaseAddress))
        local size = tonumber(region[0].RegionSize)
        scan.address = start+size
        if size <= 0 then scan.done=true; return end
        if region[0].State == 0x1000 and region[0].Type == 0x20000
            and bit.band(region[0].Protect,0x101) == 0 then
            scan.cursor = start; scan.remaining = size
        end
        return
    end
    local size = math.min(capacity,scan.remaining)
    local data = read(scan.cursor,size)
    if data then
        for _,entry in ipairs(classes) do
            local pos = 1
            while #objects < 256 do
                local first = data:find(entry[3],pos,true)
                if not first then break end
                local address = scan.cursor+first-1
                pos = first+8
                if address%8 == 0 and not seen[address] and valid_ref(address,entry[1],entry[3]) then
                    seen[address] = true
                    objects[#objects+1] = {name=entry[1],address=address,needle=entry[3]}
                    report(string.format("candidate=%s address=%x",entry[1],address))
                end
            end
        end
    end
    scan.cursor = scan.cursor+size; scan.remaining = scan.remaining-size; scan.scanned=scan.scanned+size
end

function m.display_frame(ctx)
    if halted then return end
    halted = true -- Sider catches errors; avoid repeating a failed operation every frame.
    local now = tonumber(kernel.GetTickCount64())
    scan_step(now)
    if not scan.done and #objects > 0 and now >= scan.next_capture then
        capture(now); scan.next_capture = now+3000
    end
    halted = false
end

function m.init(ctx)
    ffi = assert(native_ffi,"requires LuaJIT ffi")
    ffi.cdef[[
        unsigned long long GetTickCount64(void);
        void *GetCurrentProcess(void);
        int ReadProcessMemory(void *process, const void *address, void *buffer, size_t size, size_t *read);
    ]]
    kernel=ffi.load("kernel32"); handle=kernel.GetCurrentProcess()
    root=ctx.sider_dir .. "modules\\FLAccess-Audio\\"
    buffer=ffi.new("uint8_t[?]",capacity); got=ffi.new("size_t[1]"); region=ffi.new("MEMORY_BASIC_INFORMATION[1]")
    local info=memory.get_process_info()
    local base=tonumber(ffi.cast("uintptr_t",info.base))
    assert(base == 0x140000000,"unrecognized image base")
    for _,entry in ipairs(classes) do
        local value=ffi.new("uint64_t[1]",base+entry[2]); entry[3]=ffi.string(value,8)
    end
    scan={address=0,remaining=0,next_step=0,next_capture=0,scanned=0}
    ctx.register("display_frame",m.display_frame)
    report("read-only scan started; positions remain unproven")
end

return m
