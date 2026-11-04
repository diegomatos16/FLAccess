-- Shared grouping rules. Inputs belong to a proven native owner/component;
-- captions, translations and write order never establish a relationship.
local component={}
function component.install(ctx)
    assert(ctx.flaccess,"FLAccess core must load first")
    local shared=ctx.flaccess.reader
    assert(shared.stage==5,"reader_groups must follow semantics")

    -- Aliases belong to verified native field families, never column positions.
    shared.a11y.record_columns={
        {"teamNameText","Time","Team"},{"leagueRank_teamName","Time","Team"},{"teamName","Time","Team"},
        {"leagueRank_rank","Posição","Position"},{"ranking","Posição","Position"},
        {"leagueRank_point","Pontos","Points"},{"point","Pontos","Points"},
        {"ptsText","Pontos","Points"},{"num_Points","Pontos","Points"},
        {"goalDifferenceText","Saldo de gols","Goal difference"},{"num_GoalsDifference","Saldo de gols","Goal difference"},
        {"winText","Vitórias","Wins"},{"num_Wins","Vitórias","Wins"},
        {"drawText","Empates","Draws"},{"num_Draw","Empates","Draws"},
        {"loseText","Derrotas","Losses"},{"num_Losses","Derrotas","Losses"},
        {"goalsText","Gols marcados","Goals for"},{"num_Goals","Gols marcados","Goals for"},
        {"goalsAgainstText","Gols sofridos","Goals against"},{"num_GoalsConceded","Gols sofridos","Goals against"},
        {"match","Jogos","Played"},
        {"date","Dia","Day"},{"event","Evento","Event"},
        {"teamName_home","Time da casa","Home team"},{"teamName_away","Time visitante","Away team"},
    }

function shared.a11y.group_label_names(name)
    local stem,suffix=name:match("^(.-)_value(.*)$")
    if stem then return {stem .. "_item" .. suffix,stem .. "_headline" .. suffix,stem .. "_label" .. suffix} end
    local number=name:match("^value_(%d+)$")
    if number then return {"item_" .. number,"label_" .. number} end
    if name=="budget_difference" then return {"budget_headline"} end
    if name=="value" then return {"label","item","setName"} end
    if name=="abilityNumber" then return {"abilityName","setName"} end
    return nil
end

function shared.a11y.group_signature(groups)
    local parts={}
    for index,group in pairs(groups or {}) do
        if group.title then parts[#parts+1]=index .. ":" .. tostring(group.key) .. ":" .. group.title end
    end
    table.sort(parts);return table.concat(parts,"|")
end

function shared.a11y.group_field_speech(state,text,group,restart)
    local identity=group and group.title and tostring(group.key) .. ":" .. group.title
    local prefix=identity and (restart or state.review_group~=identity)
    state.review_group=identity
    return prefix and group.title .. ". " .. text or text
end

-- One indexed pass over a native component. Duplicate values/labels remain
-- unresolved. Shared columns are optional and require unique native names.
function shared.a11y.resolve_group_fields(items,options)
    options=options or {}
    local buckets,fields,used={},{},{}
    for _,item in ipairs(items) do
        if item.name and item.text and not shared.a11y.empty_selection_caption(item.text)
                and not shared.a11y.unresolved_format(item.text) then
            local scope=item.scope or ""
            buckets[scope]=buckets[scope] or {}
            local bucket=buckets[scope]
            bucket[item.name]=bucket[item.name] or {};table.insert(bucket[item.name],item)
        end
    end
    local function at_parent(bucket,name,parent)
        local found,count=nil,0
        for _,item in ipairs(bucket[name] or {}) do
            if parent and item.parent==parent then found,count=item,count+1 end
        end
        return found,count
    end
    for _,value in ipairs(items) do
        local aliases=value.name and shared.a11y.group_label_names(value.name)
        local bucket=buckets[value.scope or ""]
        if aliases and bucket and not value.header and not shared.a11y.empty_selection_caption(value.text) then
            local _,peers=at_parent(bucket,value.name,value.parent)
            local label,ambiguous
            for _,name in ipairs(aliases) do
                local candidate,count=at_parent(bucket,name,value.parent)
                if count>0 then label=candidate;ambiguous=count~=1 or peers~=1;break end
            end
            if not label and not ambiguous and options.allow_shared and #(bucket[value.name] or {})==1 then
                for _,name in ipairs(aliases) do
                    local matches=bucket[name] or {}
                    if #matches>0 then label=matches[1];ambiguous=#matches~=1;break end
                end
            end
            if label and not ambiguous and not shared.a11y.review_chrome(label.text) then
                local key=label.name
                if #(bucket[label.name] or {})>1 then key=key .. ":" .. tostring(label.address) end
                fields[#fields+1]={key=key,label=label.node or label,value=value.node or value,
                    label_item=label,value_item=value,parent=value.parent,scope=value.scope,
                    name=value.name,text=label.text .. ": " .. value.text}
                used[label]=true
            end
        end
    end
    local titles={}
    for _,item in ipairs(items) do
        if not used[item] and item.name and item.text and not shared.a11y.empty_selection_caption(item.text)
                and (item.name=="title" or item.name=="text_title" or item.name=="headline"
                    or item.name:match("_title$")) then
            local at,seen=item.parent,{}
            for _=1,32 do
                if not at or seen[at] then break end
                seen[at]=true
                local key=tostring(item.scope) .. ":" .. at
                titles[key]=titles[key] or {};titles[key][item]=true
                at=item.parents and item.parents[at]
            end
        end
    end
    for _,field in ipairs(fields) do
        local at,seen=field.parent,{}
        for _=1,32 do
            if not at or seen[at] then break end
            seen[at]=true
            local key=tostring(field.scope) .. ":" .. at
            local title,count=nil,0
            for item in pairs(titles[key] or {}) do title,count=item,count+1 end
            if count==1 then field.group_title,field.group_key,field.group_title_item=title.text,key,title;break end
            at=field.value_item.parents and field.value_item.parents[at]
        end
    end
    table.sort(fields,function(a,b)
        local priority={height_item=1,weight_item=2}
        local left,right=priority[a.label_item.name] or 3,priority[b.label_item.name] or 3
        if left~=right then return left<right end
        local ai,bi=a.name:match("^value_(%d+)$"),b.name:match("^value_(%d+)$")
        if options.order=="record" then
            if ai and bi then return tonumber(ai)<tonumber(bi) end
            if a.name~=b.name then return a.name<b.name end
        end
        local as,bs=a.label.sequence or a.label.address or 0,b.label.sequence or b.label.address or 0
        if as~=bs then return as<bs end
        return tostring(a.value.address)<tostring(b.value.address)
    end)
    return fields
end

function shared.a11y.group_items(names,window,header)
    local result={}
    for name,entries in pairs(names) do
        for _,entry in ipairs(entries) do
            local member=shared.a11y.native_windows.members[tonumber(entry.address)]
            local parents={}
            for _,owner in ipairs(member and member.owners or {}) do
                if owner.enabled and owner.address==window.address and owner.root==window.root then parents=owner.parents or {};break end
            end
            local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[entry.key]
            result[#result+1]={name=name,text=entry.text,address=entry.address,node=entry,
                sequence=node and node.sequence,parent=parents[tonumber(entry.address)],parents=parents,
                scope=window.address .. ":" .. window.root,header=header}
            entry.sequence=node and node.sequence
        end
    end
    return result
end

function shared.a11y.group_record_fields(names,window)
    local items=shared.a11y.group_items(names,window)
    local need_headers=false
    for name,entries in pairs(names) do
        local aliases=shared.a11y.group_label_names(name)
        if aliases and #entries==1 then
            local present=false;for _,label in ipairs(aliases) do if names[label] then present=true end end
            if not present then need_headers=true end
        end
    end
    if need_headers or shared.a11y.detail_reads_allowed then
        local headers=shared.a11y.group_items(shared.a11y.collect_record_nodes(window,window.root,function(name)
            return not shared.a11y.group_label_names(name) and (name:match("_item") or name:match("_headline")
                or name=="title" or name=="text_title" or name=="headline" or name:match("_title$"))
        end),window,true)
        local seen={};for _,item in ipairs(items) do seen[item.address]=true end
        for _,item in ipairs(headers) do
            if not seen[item.address] and not shared.a11y.group_label_names(item.name) then items[#items+1]=item end
        end
    end
    return shared.a11y.resolve_group_fields(items,{allow_shared=true,order="record"})
end

function shared.a11y.group_window_live(window)
    if not window.enabled then return false end
    if not window.impl then return true end -- synthetic/older providers carry ownership directly
    local flags=shared.a11y.menu_read(window.impl+9,"u8")
    return shared.a11y.menu_read(window.address+0x88,"u64")==window.impl and flags and flags%2==1
        and shared.a11y.menu_read(window.impl+0x98,"u64")==window.root
end

function shared.a11y.group_member_live(address,window,root)
    if not shared.a11y.group_window_live(window) then return false end
    local cached=shared.a11y.native_tree_cache and shared.a11y.native_tree_cache[root]
    if not cached or not cached.evidence or not cached.evidence.edges then return true end
    local at,seen=tonumber(address),{}
    local work=shared.a11y.render_read_work
    if work then work.edges=work.edges or {} end
    for _=1,64 do
        if at==root then return true end
        if not at or seen[at] then return false end
        seen[at]=true
        local parent,edge=cached.parents[at],cached.evidence.edges[at]
        if not parent or not edge then return false end
        local live=work and work.edges[edge]
        if live==nil then live=shared.a11y.cursor_edge_live(parent,at,edge);if work then work.edges[edge]=live end end
        if not live then return false end
        at=parent
    end
    return false
end

function shared.a11y.read_group_fields(window,root)
    if not root or root<0x10000 or not shared.a11y.group_window_live(window) then return {} end
    local scope={};for key,value in pairs(window) do scope[key]=value end;scope.root=root
    local names=shared.a11y.collect_record_nodes(scope,root)
    for name,entries in pairs(names) do
        local valid={}
        for _,entry in ipairs(entries) do
            if shared.a11y.group_member_live(entry.address,window,root) then valid[#valid+1]=entry end
        end
        names[name]=valid
    end
    local fields=shared.a11y.resolve_group_fields(shared.a11y.group_items(names,scope),{allow_shared=true})
    for _,field in ipairs(fields) do
        field.label=shared.a11y.observe_ui_widget(field.label.address,field.label.text)
        field.value=shared.a11y.observe_ui_widget(field.value.address,field.value.text)
        field.text=shared.a11y.field_visualization_text(field.label.text,field.value.text,field.label.name)
    end
    return fields
end

    shared.a11y.groups_ready=true
end
component.init=component.install
return component
