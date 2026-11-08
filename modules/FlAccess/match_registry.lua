-- Read-only mirror of native registry lookup: group (BALL/CAMERA/FIELD/CURSOR), INFO.
-- No heap scan, native function calls, registry writes or retained spatial data.
local m={version="0.1.1"}
local scratch=ffi.new("uint64_t[1]")
local function pointer(data,offset)
    if not data or #data<offset+8 then return nil end
    ffi.copy(scratch,data:sub(offset+1,offset+8),8);return tonumber(scratch[0])
end
local function valid(p) return p and p>=65536 and p<140737488355328 and p%8==0 end
local function tree(read,image,registry,object,offset,wanted)
    local header=read(object,0xe8)
    if pointer(header,0)~=image+0x2acb380 or pointer(header,0x10)~=registry then return nil,"registry-node-owner-invalid" end
    local sentinel=object+offset
    local first=pointer(header,offset+0x20)
    if not first then return nil,"registry-tree-unreadable" end
    local stack,seen,result={first},{},{}
    local visited=0
    while #stack>0 do
        local node=table.remove(stack)
        if node~=sentinel then
            if not valid(node) or seen[node] then return nil,"registry-tree-cycle-or-invalid" end
            seen[node]=true;visited=visited+1
            if visited>256 then return nil,"registry-tree-limit" end
            -- Intrusive native RB tree: interned key at -0x18, value at -8,
            -- children at +0/+0x10, sentinel root at +0x20.
            local data=read(node-0x18,0x30)
            local key,value=pointer(data,0),pointer(data,0x10)
            local left,right=pointer(data,0x18),pointer(data,0x28)
            if not left or not right or not valid(key) then return nil,"registry-tree-node-unreadable" end
            local text=read(key,16)
            local address,length=pointer(text,0),pointer(text,8)
            if not length then return nil,"registry-key-unreadable" end
            -- Read only lengths used by this query; unrelated long names are irrelevant.
            for name in pairs(wanted) do
                if length==#name and address and read(address,length)==name then
                    if not valid(value) then return nil,"registry-value-invalid" end
                    if result[name] then return nil,"registry-key-ambiguous" end
                    result[name]=value
                end
            end
            stack[#stack+1]=left;stack[#stack+1]=right
        end
    end
    if pointer(read(sentinel+0x20,8),0)~=first then return nil,"registry-tree-changed" end
    return result
end
local function group_info(read,image,registry,group,property)
    property=property or "INFO"
    local aliases={}
    while true do
        if aliases[group] or #aliases>=16 then return nil,"registry-alias-cycle" end
        aliases[group]=true;aliases[#aliases+1]=group
        local data=read(group,0x28)
        if pointer(data,0)~=image+0x2acb380 or pointer(data,0x10)~=registry then return nil,"registry-group-owner-invalid" end
        local next_group=pointer(data,0x20)
        if next_group==0 then break end
        if not valid(next_group) then return nil,"registry-alias-invalid" end
        group=next_group
    end
    local values,why=tree(read,image,registry,group,0xa8,{[property]=true})
    if not values then return nil,why end
    local entry=values[property]
    local target=entry and pointer(read(entry,24),16)
    if not valid(target) then return nil,"registry-info-unavailable" end
    return {entry=entry,target=target}
end
function m.snapshot(read,image,training)
    local owner=pointer(read(image+0x37f0ac8,8),0)
    local owner_data=valid(owner) and read(owner,0x28)
    if pointer(owner_data,0)~=image+0x2ac6670 then return nil,"registry-service-unavailable" end
    local registry=pointer(owner_data,0x20)
    local registry_data=valid(registry) and read(registry,0x18)
    if pointer(registry_data,0)~=image+0x2acaa40 then return nil,"registry-root-invalid" end
    local root=pointer(registry_data,0x10)
    if not valid(root) then return nil,"registry-directory-unavailable" end
    local groups,why=tree(read,image,registry,root,0x38,{BALL=true,CAMERA=true,FIELD=true,CURSOR=true,MATCH=true,ANALYZE=true,RECORD=true})
    if not groups then return nil,why end
    local result={}
    for name,key in pairs({ball="BALL",field="FIELD",cursor="CURSOR"}) do
        local group=groups[key]
        if group then result[name],why=group_info(read,image,registry,group) end
        if not result[name] and (not training or name~="cursor") then
            return nil,group and why .. "-" .. key or "registry-group-missing-" .. key
        end
    end
    if groups.CAMERA then result.camera=group_info(read,image,registry,groups.CAMERA) end
    -- Optional: possession must never disable the already working spatial radar.
    if groups.MATCH then
        result.match=group_info(read,image,registry,groups.MATCH)
        result.camera_env=group_info(read,image,registry,groups.MATCH,"ENV")
    end
    if groups.ANALYZE then result.analyze=group_info(read,image,registry,groups.ANALYZE) end
    if groups.RECORD then result.record=group_info(read,image,registry,groups.RECORD) end
    -- Reject a lookup crossing a root/session replacement.
    if pointer(read(image+0x37f0ac8,8),0)~=owner or pointer(read(owner+0x20,8),0)~=registry
        or pointer(read(registry+0x10,8),0)~=root then return nil,"registry-session-changed" end
    return result
end
function m.init(ctx) ctx.flaccess_match_registry=m end
return m
