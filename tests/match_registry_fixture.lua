-- Synthetic native registry layout, shared by reader and full radar tests.
return function(block,qword,image,targets)
    local next_address=0x400000
    local function allocate(size)
        local address=next_address;next_address=next_address+0x1000
        return address,block(address,size)
    end
    local owner,owner_data=allocate(0x28)
    local registry,registry_data=allocate(0x18)
    qword(owner_data,0,image+0x2ac6670);qword(owner_data,0x20,registry)
    qword(registry_data,0,image+0x2acaa40)
    local global=block(image+0x37f0ac8,8);qword(global,0,owner)
    local function directory()
        local address,data=allocate(0xe8)
        qword(data,0,image+0x2acb380);qword(data,0x10,registry)
        for _,offset in ipairs({0x38,0xa8}) do
            qword(data,offset,address+offset);qword(data,offset+0x10,address+offset)
            qword(data,offset+0x20,address+offset)
        end
        return address,data
    end
    local function node(name,value,sentinel)
        local text,text_data=allocate(#name);ffi.copy(text_data,name,#name)
        local key,key_data=allocate(16);qword(key_data,0,text);qword(key_data,8,#name)
        local address,data=allocate(0x30)
        qword(data,0,key);qword(data,16,value);qword(data,24,sentinel);qword(data,40,sentinel)
        return address+24,data
    end
    local root,root_data=directory();qword(registry_data,0x10,root)
    local result={owner=owner,owner_data=owner_data,registry=registry,registry_data=registry_data,root=root,root_data=root_data,global=global,groups={},entries={}}
    local nodes={}
    local names={"BALL","CAMERA","CURSOR","FIELD"}
    if targets.MATCH then names[#names+1]="MATCH" end
    if targets.ANALYZE then names[#names+1]="ANALYZE" end
    for _,name in ipairs(names) do
        local group,group_data=directory()
        local entry,entry_data=allocate(24);qword(entry_data,16,targets[name])
        local property,property_data=node("INFO",entry,group+0xa8)
        qword(group_data,0xc8,property)
        if name=="MATCH" and targets.MATCH_ENV then
            local env_entry,env_data=allocate(24);qword(env_data,16,targets.MATCH_ENV)
            local env_property=node("ENV",env_entry,group+0xa8)
            qword(property_data,40,env_property)
            result.entries.MATCH_ENV={address=env_entry,data=env_data}
        end
        local n,n_data=node(name,group,root+0x38);nodes[#nodes+1]={n,n_data}
        result.groups[name]={address=group,data=group_data,property=property,property_data=property_data}
        result.entries[name]={address=entry,data=entry_data}
    end
    qword(root_data,0x58,nodes[2][1])
    qword(nodes[2][2],24,nodes[1][1]);qword(nodes[2][2],40,nodes[3][1]);qword(nodes[3][2],40,nodes[4][1])
    for i=4,#nodes-1 do qword(nodes[i][2],40,nodes[i+1][1]) end
    result.nodes=nodes
    return result
end
