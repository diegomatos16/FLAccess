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

-- Resource grammars describe relationships, not screen names or translated
-- captions. Future components can add an anchored grammar without editing
-- the collector, resolver, speech queue or input handlers.
shared.a11y.group_patterns={}
function shared.a11y.register_group_pattern(rule)
    assert(type(rule)=="table" and type(rule.id)=="string" and type(rule.value_pattern)=="string")
    assert(rule.value_pattern:sub(1,1)=="^" and rule.value_pattern:sub(-1)=="$","group patterns must be anchored")
    assert(type(rule.labels)=="table" and #rule.labels>0 and #rule.labels<=8)
    assert(rule.scope==nil or rule.scope=="component" or rule.scope=="component-tree")
    for _,existing in ipairs(shared.a11y.group_patterns) do assert(existing.id~=rule.id,"duplicate group pattern") end
    local copy={id=rule.id,value_pattern=rule.value_pattern,scope=rule.scope or "component-tree",
        allow_label_reuse=rule.allow_label_reuse,labels={}}
    for i,label in ipairs(rule.labels) do
        assert(type(label)=="string")
        local literal,count=label:gsub("%%s","")
        assert(count<=2 and not literal:find("%%"),"label templates support at most two string captures")
        copy.labels[i]=label
    end
    shared.a11y.group_patterns[#shared.a11y.group_patterns+1]=copy
    shared.a11y.group_pattern_cache={};shared.a11y.group_pattern_cache_count=0
end
for _,rule in ipairs({
    {id="budget-difference",value_pattern="^budget_difference$",labels={"budget_headline"},allow_label_reuse=true},
    {id="ability",value_pattern="^abilityNumber$",labels={"abilityName","setName"}},
    {id="snake-field",value_pattern="^(.-)_value(.*)$",labels={"%s_item%s","%s_headline%s","%s_label%s","%s_name%s"}},
    {id="indexed-field",value_pattern="^value_(%d+)$",labels={"item_%s","label_%s","caption_%s"}},
    {id="camel-field",value_pattern="^(.-)Value(_?%d*)$",labels={"%sLabel%s","%sName%s","%sCaption%s"}},
    {id="component-value",value_pattern="^value$",labels={"label","item","setName"}},
    {id="component-text",value_pattern="^text$",labels={"setName"},scope="component"},
    {id="component-word",value_pattern="^textWord$",labels={"setName"},scope="component"},
}) do shared.a11y.register_group_pattern(rule) end

function shared.a11y.group_field_pattern(name)
    if type(name)~="string" then return nil end
    local cache=shared.a11y.group_pattern_cache
    if cache[name]~=nil then return cache[name] or nil end
    if shared.a11y.group_pattern_cache_count>=1024 then
        cache={};shared.a11y.group_pattern_cache=cache;shared.a11y.group_pattern_cache_count=0
    end
    shared.a11y.group_pattern_cache_count=shared.a11y.group_pattern_cache_count+1
    for _,rule in ipairs(shared.a11y.group_patterns) do
        local first,second=name:match(rule.value_pattern)
        if first then
            local labels={}
            for i,format in ipairs(rule.labels) do labels[i]=string.format(format,first,second or "") end
            local pattern={id=rule.id,scope=rule.scope,labels=labels,allow_label_reuse=rule.allow_label_reuse}
            cache[name]=pattern;return pattern
        end
    end
    cache[name]=false
end
function shared.a11y.group_label_names(name)
    local pattern=shared.a11y.group_field_pattern(name)
    return pattern and pattern.labels
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

function shared.a11y.filter_group_pairs(fields)
    -- A physical label cannot silently supply two populated comparison
    -- columns or two generic value kinds. Explicit native variants may opt in.
    local labels={}
    for _,field in ipairs(fields) do
        if not field.allow_label_reuse then
            local key=tostring(field.scope) .. ":" .. tostring(field.label.address)
            labels[key]=labels[key] or {};labels[key][field.value.address]=true
        end
    end
    local accepted={}
    for _,field in ipairs(fields) do
        local count=0
        for _ in pairs(labels[tostring(field.scope) .. ":" .. tostring(field.label.address)] or {}) do count=count+1 end
        if field.allow_label_reuse or count==1 then accepted[#accepted+1]=field end
    end
    return accepted
end

function shared.a11y.assign_group_titles(fields,items,used)
    used=used or {}
    for _,field in ipairs(fields) do if field.label_item then used[field.label_item]=true end end
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
end

function shared.a11y.group_field_less(a,b)
    local priority={height_item=1,weight_item=2}
    local left,right=priority[a.label.name] or 3,priority[b.label.name] or 3
    if left~=right then return left<right end
    local ag,bg=a.group_title_item,b.group_title_item
    local ar=ag and tonumber(ag.sequence or ag.address) or 0
    local br=bg and tonumber(bg.sequence or bg.address) or 0
    if ar~=br then return ar<br end
    if (a.group_key or "")~=(b.group_key or "") then return (a.group_key or "")<(b.group_key or "") end
    local x=tonumber((a.name or ""):match("(%d+)$")) or math.huge
    local y=tonumber((b.name or ""):match("(%d+)$")) or math.huge
    if x~=y then return x<y end
    if a.name~=b.name then return (a.name or "")<(b.name or "") end
    return (a.label.sequence or a.label.address)<(b.label.sequence or b.label.address)
end

-- One indexed pass over a native component. Duplicate values/labels remain
-- unresolved. Shared columns are optional and require unique native names.
function shared.a11y.resolve_group_fields(items,options)
    options=options or {}
    local buckets,fields,used,parents_by_bucket={},{},{},{}
    for _,item in ipairs(items) do
        if item.name and item.text and not shared.a11y.empty_selection_caption(item.text)
                and not shared.a11y.unresolved_format(item.text) then
            local scope=item.scope or ""
            buckets[scope]=buckets[scope] or {}
            local bucket=buckets[scope]
            bucket[item.name]=bucket[item.name] or {};table.insert(bucket[item.name],item)
            if item.parent then
                local parents=parents_by_bucket[bucket] or {};parents_by_bucket[bucket]=parents
                local named=parents[item.name] or {};parents[item.name]=named
                local pair=named[item.parent] or {count=0};named[item.parent]=pair
                pair.item,pair.count=item,pair.count+1
            end
        end
    end
    local function at_parent(bucket,name,parent)
        local parents=parents_by_bucket[bucket]
        local pair=parents and parents[name] and parents[name][parent]
        return pair and pair.item or nil,pair and pair.count or 0
    end
    for _,value in ipairs(items) do
        local pattern=shared.a11y.group_field_pattern(value.name)
        local aliases=pattern and pattern.labels
        local bucket=buckets[value.scope or ""]
        if aliases and bucket and not value.header and not shared.a11y.empty_selection_caption(value.text) then
            local _,peers=at_parent(bucket,value.name,value.parent)
            local label,ambiguous
            for _,name in ipairs(aliases) do
                local candidate,count=at_parent(bucket,name,value.parent)
                if count>0 then label=candidate;ambiguous=count~=1 or peers~=1;break end
            end
            -- Delegated label/value nodes may have different immediate
            -- parents. Pair within their nearest unique native component.
            if not label and not ambiguous and pattern.scope~="component" and value.parents then
                local ancestors,at,seen={},value.parent,{}
                for depth=1,32 do
                    if not at or seen[at] then break end
                    seen[at]=true;ancestors[at]=depth;at=value.parents[at]
                end
                local best,count
                for _,name in ipairs(aliases) do
                    for _,candidate in ipairs(bucket[name] or {}) do
                        local parent,visited=candidate.parent,{}
                        for depth=1,32 do
                            if not parent or visited[parent] then break end
                            visited[parent]=true
                            if ancestors[parent] then
                                local distance=ancestors[parent]+depth
                                if not best or distance<best then label,best,count=candidate,distance,1
                                elseif distance==best then count=count+1 end
                                break
                            end
                            parent=candidate.parents and candidate.parents[parent]
                        end
                    end
                end
                if label and count==1 then
                    -- A shared label cannot choose between equally close
                    -- comparison columns carrying the same resource name.
                    for _,peer in ipairs(bucket[value.name] or {}) do
                        if peer~=value then
                            local peer_ancestors,at,seen={},peer.parent,{}
                            for depth=1,32 do
                                if not at or seen[at] then break end
                                seen[at]=true;peer_ancestors[at]=depth;at=peer.parents and peer.parents[at]
                            end
                            at=label.parent;seen={}
                            for depth=1,32 do
                                if not at or seen[at] then break end
                                seen[at]=true
                                if peer_ancestors[at] then
                                    if peer_ancestors[at]+depth<=best then ambiguous=true end
                                    break
                                end
                                at=label.parents and label.parents[at]
                            end
                        end
                    end
                end
                if (count and count~=1) or ambiguous then label=nil;ambiguous=true end
            end
            if not label and not ambiguous and pattern.scope~="component" and options.allow_shared and #(bucket[value.name] or {})==1 then
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
                    name=value.name,text=label.text .. ": " .. value.text,pattern=pattern.id,
                    allow_label_reuse=pattern.allow_label_reuse}
                used[label]=true
            end
        end
    end
    fields=shared.a11y.filter_group_pairs(fields)
    shared.a11y.assign_group_titles(fields,items,used)
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
                if (owner.enabled or window.review_input) and owner.address==window.address and owner.root==window.root then parents=owner.parents or {};break end
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

-- Content may belong to a shown parent Task while its child owns input.
-- A sibling/background window is never admitted merely for containing fields.
function shared.a11y.associated_group_window(window,primary)
    local base=tonumber(shared.process_base_u64)
    if not base or not primary or not primary.enabled or not window.impl or not primary.impl then return false end
    if shared.a11y.menu_read(primary.address+0x88,"u64")~=primary.impl
            or (shared.a11y.menu_read(primary.impl+9,"u8") or 0)%2~=1 then return false end
    local by_address={}
    for _,item in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do by_address[item.address]=item end
    local current,seen=primary,{}
    for _=1,16 do
        if not shared.a11y.is_native_window_task(current.address,base) then return false end
        local parent=shared.a11y.menu_read(current.address+0x38,"u64")
        if not parent or seen[parent] then return false end
        seen[parent]=true
        current=by_address[parent]
        if not current or not shared.a11y.is_native_window_task(parent,base) then return false end
        local presentation=current.presentation_root
        if not current.impl or shared.a11y.menu_read(current.address+0x88,"u64")~=current.impl
                or shared.a11y.menu_read(current.impl+0x90,"u64")~=presentation then return false end
        local flags=presentation and shared.a11y.menu_read(presentation+0xc,"u32")
        if not flags or flags%8~=7 then return false end
        if parent==window.address then return true end
    end
    return false
end

function shared.a11y.group_window_live(window)
    if not window.enabled and not (window.review_input and shared.a11y.associated_group_window(window,window.review_input)) then return false end
    if not window.impl then return true end -- synthetic/older providers carry ownership directly
    local flags=shared.a11y.menu_read(window.impl+9,"u8")
    return shared.a11y.menu_read(window.address+0x88,"u64")==window.impl and flags and (window.review_input or flags%2==1)
        and shared.a11y.menu_read(window.impl+0x98,"u64")== (window.native_root or window.root)
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

function shared.a11y.collect_group_scope(window,root)
    if not root or root<0x10000 or not shared.a11y.group_window_live(window) then return nil end
    local scope={};for key,value in pairs(window) do scope[key]=value end;scope.root=root
    local names={}
    for name,entries in pairs(shared.a11y.collect_record_nodes(scope,root)) do
        local valid={}
        for _,entry in ipairs(entries) do
            if shared.a11y.group_member_live(entry.address,window,root) then valid[#valid+1]=entry end
        end
        names[name]=valid
    end
    local indexed,relationships={},{}
    for _,entries in pairs(names) do for _,entry in ipairs(entries) do indexed[entry.address]=entry end end
    for _,entries in pairs(names) do
        for _,value in ipairs(entries) do
            if value.name=="text" or value.name=="textWord" or value.name=="jump" then
                local label=shared.a11y.native_field_label(value.address)
                local current=label and indexed[tonumber(label.address)]
                if current and current.address~=value.address and shared.a11y.group_member_live(current.address,window,root) then
                    relationships[value.address]=current.address
                end
            end
        end
    end
    local recognized=false
    for name,entries in pairs(names) do
        local aliases=shared.a11y.group_label_names(name)
        for _,alias in ipairs(aliases or {}) do
            if #entries>0 and names[alias] and #names[alias]>0 then recognized=true end
        end
    end
    return {window=window,root=root,scope=scope,names=names,relationships=relationships,recognized=recognized,
        items=shared.a11y.group_items(names,scope)}
end

function shared.a11y.resolve_group_scope(collection)
    local window,root,scope,names=collection.window,collection.root,collection.scope,collection.names
    local fields=shared.a11y.resolve_group_fields(collection.items,{allow_shared=true})
    local indexed,paired,descriptors={},{},{}
    for _,item in ipairs(collection.items) do descriptors[item.address]=item end
    for _,entries in pairs(names) do for _,entry in ipairs(entries) do indexed[tonumber(entry.address)]=entry end end
    for _,field in ipairs(fields) do paired[tonumber(field.value.address)]=true end
    for _,entries in pairs(names) do
        for _,value in ipairs(entries) do
            if not paired[value.address] and (value.name=="text" or value.name=="textWord" or value.name=="jump") then
                local current=indexed[collection.relationships[value.address]]
                if current and not shared.a11y.review_chrome(current.text) then
                    fields[#fields+1]={key="native-field:" .. current.address .. ":" .. value.address,
                        label=current,value=value,name=value.name,text=current.text .. ": " .. value.text,
                        label_item=descriptors[current.address],value_item=descriptors[value.address],
                        parent=descriptors[value.address].parent,scope=descriptors[value.address].scope,
                        pattern="native-selector"}
                    paired[value.address]=true
                end
            end
        end
    end
    fields=shared.a11y.filter_group_pairs(fields)
    shared.a11y.assign_group_titles(fields,collection.items)
    table.sort(fields,shared.a11y.group_field_less)
    return fields
end

-- Bind entity identity to the native component containing the accepted fields,
-- rather than every player caption retained anywhere in a large window root.
function shared.a11y.group_entity_for_fields(fields,items)
    if #fields==0 then return nil,false end
    local counts={}
    for _,field in ipairs(fields)do counts[field.label_item.name]=(counts[field.label_item.name] or 0)+1 end
    local seeds={}
    for _,field in ipairs(fields)do if counts[field.label_item.name]==1 then seeds[#seeds+1]=field end end
    if #seeds==0 then seeds=fields end
    local first=seeds[1].value_item
    if not first or not first.parents then return nil,false end
    local chain,seen={},{}
    local at=first.parent
    for _=1,32 do
        if not at or seen[at] then break end
        seen[at]=true;chain[#chain+1]=at;at=first.parents[at]
    end
    local function inside(item,root)
        local cursor,visited=item.address,{}
        for _=1,64 do
            if cursor==root then return true end
            if not cursor or visited[cursor] then return false end
            visited[cursor]=true;cursor=item.parents and item.parents[cursor]
        end
        return false
    end
    local common
    for _,root in ipairs(chain) do
        local all=true
        for _,field in ipairs(seeds) do
            if not inside(field.label_item,root) or not inside(field.value_item,root) then all=false;break end
        end
        if all then common=root;break end
    end
    if not common then return nil,false end
    local start=false
    for _,root in ipairs(chain) do
        if root==common then start=true end
        if start then
            local entity,ambiguous
            for _,item in ipairs(items) do
                if item.name=="playerName" and not shared.a11y.empty_selection_caption(item.text) and inside(item,root) then
                    if entity and entity~=item.text then ambiguous=true end
                    entity=item.text
                end
            end
            if entity and not ambiguous then
                local scoped={}
                for _,field in ipairs(fields)do
                    if inside(field.label_item,root) and inside(field.value_item,root) then scoped[#scoped+1]=field end
                end
                return entity,false,scoped
            end
            if ambiguous then
                if common~=chain[#chain] then
                    local scoped={}
                    for _,field in ipairs(fields)do
                        if inside(field.label_item,common) and inside(field.value_item,common) then scoped[#scoped+1]=field end
                    end
                    return nil,false,scoped
                end
                -- Unique property pairs still describe the current native
                -- component; a background player list is not an entity anchor.
                -- Competing copies of the same property remain unsafe.
                local properties={}
                for _,field in ipairs(fields) do
                    local key=field.label_item.name
                    if properties[key] and properties[key]~=field.label.address then return nil,true end
                    properties[key]=field.label.address
                end
                return nil,false
            end
        end
    end
    return nil,false
end

function shared.a11y.read_group_fields(window,root)
    local collection=shared.a11y.collect_group_scope(window,root)
    if not collection then return {} end
    local fields=shared.a11y.resolve_group_scope(collection)
    local entity,ambiguous,scoped=shared.a11y.group_entity_for_fields(fields,collection.items)
    if ambiguous then fields={} elseif scoped then fields=scoped end
    local shape={}
    for name,entries in pairs(collection.names) do shape[#shape+1]=name .. "=" .. #entries end
    table.sort(shape)
    local trace=window.address .. ":" .. root .. ":" .. #fields .. ":" .. table.concat(shape,",")
    shared.a11y.group_scope_seen=shared.a11y.group_scope_seen or {}
    if not shared.a11y.group_scope_seen[trace] and (shared.a11y.group_scope_trace_count or 0)<32 then
        shared.a11y.group_scope_seen[trace]=true
        shared.a11y.group_scope_trace_count=(shared.a11y.group_scope_trace_count or 0)+1
        log("[FLAccess] group-scope window:root:fields:names=" .. trace)
    end
    for _,field in ipairs(fields) do
        field.label=shared.a11y.observe_ui_widget(field.label.address,field.label.text)
        field.value=shared.a11y.observe_ui_widget(field.value.address,field.value.text)
        field.text=shared.a11y.field_visualization_text(field.label.text,field.value.text,field.label.name)
    end
    return fields,{recognized=collection.recognized,root=root,entity=entity,ambiguous=ambiguous}
end

    shared.a11y.groups_ready=true
end
component.init=component.install
return component
