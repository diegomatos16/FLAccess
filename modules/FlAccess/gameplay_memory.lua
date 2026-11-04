-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.gameplay
    assert(shared.stage == 2, "FLAccess gameplay: missing or reordered component memory")
function shared.blob(address,size)
    if not address or address<65536 or address>=140737488355328 or size>shared.CAPACITY then
        shared.read_failure="invalid pointer=" .. tostring(address) .. " size=" .. tostring(size)
        return nil
    end
    shared.got[0]=0
    if shared.kernel.ReadProcessMemory(shared.process,ffi.cast("const void*",address),shared.buffer,size,shared.got)==0 or tonumber(shared.got[0])~=size then
        shared.read_failure=string.format("address=%x size=%d read=%d error=%d",address,size,tonumber(shared.got[0]),tonumber(shared.kernel.GetLastError()))
        return nil
    end
    return ffi.string(shared.buffer,size)
end
shared.number64,shared.number32,shared.number_float=ffi.new("uint64_t[1]"),ffi.new("uint32_t[1]"),ffi.new("float[1]")
function shared.ptr(data,o)
    if not data or #data<o+8 then return nil end
    ffi.copy(shared.number64,data:sub(o+1,o+8),8);return tonumber(shared.number64[0])
end
function shared.uint(data,o)
    if not data or #data<o+4 then return nil end
    ffi.copy(shared.number32,data:sub(o+1,o+4),4);return tonumber(shared.number32[0])
end
function shared.float(data,o)
    if not data or #data<o+4 then return nil end
    ffi.copy(shared.number_float,data:sub(o+1,o+4),4)
    local v=tonumber(shared.number_float[0]);if shared.finite(v) then return v end
end
function shared.vector(data,o)
    local x,y,z=shared.float(data,o),shared.float(data,o+4),shared.float(data,o+8)
    if x and y and z then return {x,y,z} end
end
function shared.valid_position(v) return v and math.abs(v[1])<150 and v[2]>-10 and v[2]<100 and math.abs(v[3])<120 end
function shared.m.controlled_slot(data)
    if not data or #data<24*0x74 then return nil,"control-table-unavailable" end
    local selected,slot
    for i=0,23 do
        local o=i*0x74;local actor=shared.uint(data,o+0x20)
        -- Native cursor consumer 0x440960 excludes records whose byte +6 != 0.
        if data:byte(o+7)==0 and actor and actor<22 then
            if selected~=nil then return nil,"multiple-controlled-players" end
            selected,slot=actor,i
        end
    end
    if selected==nil then return nil,"controlled-player-unavailable" end
    return selected,slot
end
function shared.m.cursor_actor(data,slot)
    if not data or not slot or slot<0 or slot>=24 then return nil end
    -- Registry header is 4 bytes; CursorInfo records match the native 0x74 stride.
    local actor=shared.uint(data,4+slot*0x74+0x20)
    if actor and actor<22 then return actor end
end

    shared.stage = 3
end
function component.init(ctx)
    component.install(ctx)

end
return component
