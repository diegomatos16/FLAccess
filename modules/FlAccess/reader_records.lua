-- Reusable selected-record reader. Automatic speech and exploration consume
-- the same validated packet; exploration exposes one labelled field per step.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared=ctx.flaccess.reader
    assert(shared.stage==5, "FLAccess records must load after semantics and before review")

    assert(shared.a11y.groups_ready,"reader_groups must precede records")
    function shared.a11y.primary_input_window()
        local found,ambiguous
        for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
            if window.enabled and window.primary then
                if not found or (window.priority or 0)>(found.priority or 0) then found,ambiguous=window,false
                elseif (window.priority or 0)==(found.priority or 0) and window.address~=found.address then ambiguous=true end
            end
        end
        if ambiguous then return nil,true end
        return found,false
    end
    function shared.a11y.current_review_window()
        local info=shared.a11y.native_information_context and shared.a11y.native_information_context()
        if info then
            for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
                if window.enabled and window.address==info.window then return window end
            end
        end
        return shared.a11y.primary_input_window()
    end
    function shared.a11y.review_nodes_in_window(nodes,window)
        if not window then return nodes end
        local current={}
        for _,node in ipairs(nodes) do
            local member=shared.a11y.native_windows.members[tonumber(node.address)]
            for _,owner in ipairs(member and member.owners or {}) do
                if owner.enabled and owner.address==window.address then current[#current+1]=node;break end
            end
        end
        return current
    end
    function shared.a11y.native_list_in_window(window)
        local item=shared.a11y.native_list_selection
        if not item or not item.widget or not shared.a11y.native_list_has_focus() then return false end
        local member=shared.a11y.native_windows and shared.a11y.native_windows.members[tonumber(item.widget)]
        for _,owner in ipairs(member and member.owners or {}) do
            if owner.enabled and owner.address==window.address then return true end
        end
        return false
    end
    function shared.a11y.active_native_standings()
        local base=tonumber(shared.process_base_u64)
        if not base then return nil end
        local work=shared.a11y.render_read_work
        local snapshot=shared.a11y.native_windows
        if work and work.standings_snapshot==snapshot and work.standings_window~=nil then
            return work.standings_window or nil
        end
        local found
        local primary=shared.a11y.primary_input_window()
        for _,window in ipairs(snapshot and snapshot.windows or {}) do
            if window.enabled and (not primary or primary.address==window.address)
                    and shared.a11y.menu_read(window.address,"u64")==base+0x2684408
                    and shared.a11y.menu_read(base+0x2684408+0x18,"u64")==base+0xaed5d0
                    and shared.a11y.menu_read(base+0x2684408+0x130,"u64")==base+0xaedf80 then
                if found then return nil end
                found=window
            end
        end
        if work then work.standings_snapshot,work.standings_window=snapshot,found or false end
        return found
    end
    function shared.a11y.record_contains(node,window,row)
        local address=node and tonumber(node.address)
        local member=address and shared.a11y.native_windows and shared.a11y.native_windows.members[address]
        for _,owner in ipairs(member and member.owners or {}) do
            if (owner.enabled or window.review_input and shared.a11y.group_window_live(window)) and owner.address==window.address and owner.root==window.root then
                local at,seen=address,{}
                for _=1,32 do
                    if at==row then
                        return not shared.a11y.cursor_member_live or shared.a11y.cursor_member_live(address,window)
                    end
                    if not at or seen[at] then break end
                    seen[at]=true;at=owner.parents and owner.parents[at]
                end
            end
        end
        return false
    end
    function shared.a11y.record_content_ready(node,window,row)
        if not (window.enabled or window.review_input and shared.a11y.group_window_live(window)) or not shared.a11y.record_contains(node,window,row) then return false end
        if not window.review_input and shared.a11y.native_presentation_ready(node.address) then return true end
        -- Native getter e4bb90 checks the low state bits only. e4bb70 also
        -- requires bit8 (input participation). A record value need not accept
        -- input. Scope is still proven by the selected row and enabled owner.
        local flags=shared.a11y.menu_read(tonumber(node.address)+0xc,"u32")
        return flags~=nil and flags%8==7
    end
    function shared.a11y.collect_record_nodes(window,row,filter)
        local work=shared.a11y.render_read_work
        local cache_key=tostring(window.address) .. ":" .. tostring(window.root) .. ":" .. tostring(row)
        if work and not filter and work.record_nodes and work.record_nodes[cache_key] then return work.record_nodes[cache_key] end
        local names,seen={},{}
        local snapshot=shared.a11y.native_windows
        local function add(address,node)
            address=tonumber(address)
            if not address or seen[address] then return end
            seen[address]=true
            node=node or {address=address,key=memory.hex(address)}
            if not shared.a11y.record_content_ready(node,window,row) then return end
            local name=shared.a11y.widget_internal_name(address) or node.name
            if not name then return end
            if filter and not filter(name) then return end
            local text=shared.a11y.read_native_rendered_text(address)
            if text==nil or shared.a11y.unresolved_format(text) then return end
            local entry={address=address,key=memory.hex(address),name=name,text=text}
            names[name]=names[name] or {};names[name][#names[name]+1]=entry
        end
        -- Read native members directly: numeric/unlocalized fields may never
        -- have reached the localization hook or its rotating observation budget.
        local candidates=snapshot and snapshot.members or {}
        local graph=shared.a11y.native_tree_cache and shared.a11y.native_tree_cache[window.root]
        local subtree=shared.a11y.cached_cursor_subtree(row,graph,true)
        if subtree then candidates=subtree end
        for address in pairs(candidates) do
            local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(address)]
            add(address,node)
        end
        -- Only native members can pass record_contains. Visiting the entire
        -- historical UI model again cannot contribute another eligible field.
        if work and not filter then work.record_nodes=work.record_nodes or {};work.record_nodes[cache_key]=names end
        return names
    end
    function shared.a11y.record_anchor_count(names)
        local count=0
        for _,name in ipairs({"teamNameText","teamName","leagueRank_teamName","date","itemName"}) do
            count=math.max(count,#(names[name] or {}))
        end
        return count
    end
    function shared.a11y.native_calendar_row(window,scope,names,base)
        local vt=shared.a11y.menu_read(window.address,"u64")
        if vt~=base+0x268bda8 or shared.a11y.menu_read(vt+0x18,"u64")~=base+0xb05640 then return nil,false end
        -- Native b011a0 hides the old day cursor, shows the new one and stores
        -- its visible row at Window+fc. This calendar does NOT put that index
        -- into the outer NodeCursor, which stays on the entire "choice".
        -- b01296 uses index+14 for cursor layers; data rows keep listItem_0..13.
        local index=shared.a11y.menu_read(window.address+0xfc,"u32")
        if not index or index>=14 then return nil,true end
        local wanted="listItem_" .. index
        local found
        for _,node in ipairs(names.date or {}) do
            local member=shared.a11y.native_windows.members[node.address]
            for _,owner in ipairs(member and member.owners or {}) do
                if owner.enabled and owner.address==window.address and owner.root==window.root then
                    local at,seen=node.address,{}
                    for _=1,32 do
                        if not at or seen[at] or at==scope then break end
                        seen[at]=true
                        if shared.a11y.widget_internal_name(at)==wanted then
                            if found and found~=at then return nil,true end
                            found=at;break
                        end
                        at=owner.parents and owner.parents[at]
                    end
                end
            end
        end
        return found,true
    end
    function shared.a11y.record_parent(node,window)
        local member=shared.a11y.native_windows.members[node.address]
        local found
        for _,owner in ipairs(member and member.owners or {}) do
            if owner.enabled and owner.address==window.address and owner.root==window.root then
                local parent=owner.parents and owner.parents[node.address]
                if parent and found and parent~=found then return nil end
                found=parent or found
            end
        end
        return found
    end
    -- Selection adapters return a live row descriptor, never formatted speech.
    function shared.a11y.standings_row_selection(window,base)
        local first,last=shared.a11y.menu_read(window.address+0x90,"u64"),shared.a11y.menu_read(window.address+0x98,"u64")
        if not first or first<0x10000 or not last or last<=first or (last-first)%4~=0 or last-first>48*4 then return nil,"data" end
        local count=(last-first)/4
        local impl=window.impl or shared.a11y.menu_read(window.address+0x88,"u64")
        -- aedbb3/aedeba initialize the standings data and selector in group
        -- zero. Impl+a0 and NodeCursor can point to a different control.
        local group=shared.a11y.menu_child(window.root,0)
        local selectors=group and shared.a11y.holder_kind_nodes(group+0x98,0x10)
        local selector=selectors and selectors[1]
        local total=selector and shared.a11y.menu_read(selector+0xb4,"u32")
        local visible=selector and shared.a11y.menu_read(selector+0xb8,"u32")
        local source="standings-data-selector"
        local index
        if total and total>=count and total<=48 and visible and visible>0 and visible<=total then
            index=shared.a11y.menu_read(selector+0xbc,"u32")
        else
            index,selector=shared.a11y.native_window_selected_index(window,base)
            local group_index=impl and shared.a11y.menu_read(impl+0xa0,"u32")
            group=group_index and group_index<256 and shared.a11y.menu_child(window.root,group_index)
            source="window-selector"
        end
        if source~="standings-data-selector" and (not group or not selector or not index or index==0xffffffff) then
            -- Some ML tables leave Window::get_select_index unset. Their
            -- NodeCursor still owns a real group containing the list selector.
            local detail=window.cursor_detail
            if not detail or detail.cursor_type~=base+0x27c1ac0
                    or not shared.a11y.list_cursor_unchanged(window,base) then return nil,"cursor" end
            group=detail.group
            local selectors=group and shared.a11y.holder_kind_nodes(group+0x98,0x10)
            if not selectors or #selectors==0 then return nil,"selector" end
            selector=selectors[1]
            index=shared.a11y.menu_read(selector+0xbc,"u32")
            source="cursor-group-selector"
        end
        if not index or index<0 or index>=count or index==0xffffffff then return nil,"index" end
        -- e41512..e41532 converts the absolute selection to a visible row.
        local scroll=selector and shared.a11y.menu_read(selector+0xc0,"u32")
        if not scroll or scroll>index then return nil,"scroll" end
        local row=shared.a11y.menu_child(group,index-scroll)
        if row and row<0x10000 then row=nil end
        if not row and source~="standings-data-selector" then return nil,"row" end
        return {row=row or group,rendered_row=row,index=index,count=count,group=group,source=source,first=first,
            scroll=scroll,selector=selector,total=total,visible=visible,
            identity=window.address .. ":" .. window.root .. ":" .. group .. ":" .. index .. ":" .. (row or group)}
    end
    local function standings_table(window,base,selection)
        local read=shared.a11y.menu_read
        local manager=read(base+0x3705e10,"u64")
        local data=manager and manager>=0x10000 and read(manager+0x48,"u64")
        local runtime=manager and manager>=0x10000 and read(manager+0x78,"u64")
        local competition=read(window.address+0xa8,"u16")
        if not data or data<0x10000 or not runtime or runtime<0x10000
                or not competition or competition==0xffff then return end
        local cached=shared.a11y.standings_table_cache
        if cached and cached.runtime==runtime and cached.data==data and cached.first==selection.first
                and cached.competition==competition and cached.count==selection.count
                and cached.window==window.address and cached.root==window.root then
            return cached.rows,data
        end
        cached={runtime=runtime,data=data,first=selection.first,competition=competition,
            count=selection.count,window=window.address,root=window.root}
        shared.a11y.standings_table_cache=cached
        -- 15451a0 resolves the competition descriptor, then 159ebf0 and
        -- 158df30 select its earliest valid schedule and matching competition.
        local count=read(data+0xd0bcf4,"u32")
        if not count or count<1 or count>300 then return end
        local key
        for i=0,count-1 do
            local at=data+0xc12e9c+i*0x314
            if read(at,"u16")==competition then key=read(at+0x80,"u32");break end
        end
        if not key or key==0xffffffff then return end
        local rows
        for i=0,99 do
            local at=runtime+i*0xb4
            if read(at,"u32")==key then
                local schedule,earliest
                for slot=0,1 do
                    local candidate=at+4+slot*0x58
                    local year=read(candidate+4,"u16")
                    if year and year<0xffff and read(candidate,"u32")~=0xffffffff
                            and (not earliest or year<earliest) then schedule,earliest=candidate,year end
                end
                if not schedule then return end
                for slot=0,19 do
                    local index=read(schedule+8+slot*4,"u32")
                    if not index or index==0xffffffff then break end
                    local record=runtime+0x4650+index*0x187c
                    if index<600 and read(record,"u16")==competition then rows=record+0x318;break end
                end
                break
            end
        end
        if not rows or read(rows+0x3c0,"u32")~=selection.count then return end
        -- Prove this is the same ordered dataset the window populated.
        for _,index in ipairs({0,selection.count-1}) do
            local id=read(selection.first+index*4,"u32")
            if not id or read(rows+index*20,"u32")~=id then return end
        end
        cached.rows=rows
        return rows,data
    end
    local function standings_team_name(data,id)
        local read=shared.a11y.menu_read
        local first=data+0xadf4bc
        local index=id%0x4000
        local address
        if read(data+0x183789c,"u32")==2 then
            if index<=750 then address=first+index*0x690 end
        else
            local count=read(data+0xd0bcec,"u32")
            if not count or count<1 or count>1400 then return end
            local low,high=0,count-1
            while low<=high do
                local mid=math.floor((low+high)/2)
                local at=first+mid*0x690
                local candidate=read(at,"u32")
                if not candidate then return end
                if candidate==id then address=at;break end
                if candidate%0x4000<index or (candidate%0x4000==index and candidate<id) then
                    low=mid+1
                else
                    high=mid-1
                end
            end
        end
        if not address or read(address,"u32")~=id then return end
        local name=shared.a11y.read_native_c_string(address+4,70)
        if name and name:find("%S") and not name:find("%c") then return shared.clean_text(name) end
    end
    local function standings_native_columns(window,base,selection)
        local rows,data=standings_table(window,base,selection)
        if not rows then return end
        local read=shared.a11y.menu_read
        local at=rows+selection.index*20
        local id=read(selection.first+selection.index*4,"u32")
        if not id or read(at,"u32")~=id then return end
        local rank,results,goals=read(at+4,"u32"),read(at+8,"u32"),read(at+0xc,"u32")
        if not rank or rank>selection.count or not results or not goals then return end
        local cache=shared.a11y.standings_name_cache
        if not cache or cache.data~=data or cache.id~=id then
            cache={data=data,id=id,name=standings_team_name(data,id)}
            shared.a11y.standings_name_cache=cache
        end
        if not cache.name or cache.name=="" then return end
        -- aee0c0 supplies these exact values to the standings row.
        local scored,conceded=goals%4096,math.floor(goals/4096)%4096
        local values={teamName=cache.name,ranking=rank,num_Points=results%256,
            num_Wins=math.floor(results/256)%64,num_Draw=math.floor(results/1048576)%64,
            num_Losses=math.floor(results/16384)%64,num_Goals=scored,
            num_GoalsConceded=conceded,num_GoalsDifference=scored-conceded}
        if read(rows+0x78c,"u32")==0x37 then values.ranking="-" end
        local names={}
        for name,value in pairs(values) do
            names[name]={{name=name,text=tostring(value),address=selection.row,key=memory.hex(selection.row)}}
        end
        return names
    end
    function shared.a11y.selected_record_scope(window,base)
        local row=window.cursor_detail.selected
        local vt=shared.a11y.menu_read(window.address,"u64")
        if vt==base+0x2684408 and shared.a11y.menu_read(vt+0x18,"u64")==base+0xaed5d0
                and shared.a11y.menu_read(vt+0x130,"u64")==base+0xaedf80 then
            local selection,reason=shared.a11y.standings_row_selection(window,base)
            local trace=selection and (selection.identity .. ":" .. selection.source
                .. ":scroll=" .. selection.scroll .. ":visible=" .. tostring(selection.visible)
                .. ":total=" .. tostring(selection.total)) or tostring(window.address) .. ":" .. tostring(reason)
            if trace~=shared.a11y.standings_scope_trace and (shared.a11y.standings_scope_trace_count or 0)<96 then
                shared.a11y.standings_scope_trace=trace
                shared.a11y.standings_scope_trace_count=(shared.a11y.standings_scope_trace_count or 0)+1
                log("[FLAccess] standings-selection " .. trace)
            end
            if not selection then return row,{},true end
            local names=standings_native_columns(window,base,selection)
            return selection.row,names or (selection.rendered_row
                and shared.a11y.collect_record_nodes(window,selection.rendered_row) or {}),false,selection,names~=nil
        end
        local names=shared.a11y.collect_record_nodes(window,row)
        local calendar,recognized=shared.a11y.native_calendar_row(window,row,names,base)
        if recognized then
            if not calendar then return row,names,true end
            return calendar,shared.a11y.collect_record_nodes(window,calendar),false
        end
        local ambiguous=false
        for _=1,6 do
            if shared.a11y.record_anchor_count(names)==1 then break end
            -- budgetReport has two named budget subcomponents in one current
            -- report. Its selectors are controls, not another table of records.
            if names.budget_headline and names.budget_value then break end
            if shared.a11y.menu_read(row,"u64")~=base+0x27cb508 then break end
            local selectors=shared.a11y.holder_kind_nodes(row+0x98,0x10)
            if not selectors or #selectors==0 then break end
            if #selectors~=1 then ambiguous=true;break end
            local vt=shared.a11y.menu_read(selectors[1],"u64")
            if vt~=base+0x27b84d0 and vt~=base+0x27be998 then ambiguous=true;break end
            local index=shared.a11y.menu_read(selectors[1]+0xbc,"u32")
            local child=index and shared.a11y.menu_child(row,index)
            if not child or child==row then ambiguous=true;break end
            row=child;names=shared.a11y.collect_record_nodes(window,row)
        end
        return row,names,ambiguous
    end
    function shared.a11y.compose_record_packet(window,row,names,ambiguous)
        local fields,nodes,keys,encountered,labels={},{},{},{},{}
        local pt=shared.a11y.ui_language=="pt"
        local function unique(name)
            local candidates=names[name] or {}
            if #candidates>0 then encountered[name]=true end
            return #candidates==1 and candidates[1] or nil
        end
        local base=tonumber(shared.process_base_u64)
        local vt=shared.a11y.menu_read(window.address,"u64")
        local caption=unique("itemName")
        if base and vt==base+0x25b84a8 and caption
                and (caption.text=="Posse de bola" or caption.text=="Possession" or caption.text=="Ball Possession" or caption.text=="Ball possession") then
            local home,away=unique("valueHome"),unique("valueAway")
            if shared.a11y.detail_reads_allowed and home and away and not ambiguous then
                local teams=shared.a11y.collect_record_nodes(window,window.root,function(name)
                    return name=="teamName_left" or name=="teamName_right"
                end)
                local function team(name,fallback)
                    local items=teams[name]
                    return items and #items==1 and not shared.a11y.empty_selection_caption(items[1].text)
                        and items[1].text or fallback
                end
                local function percentage(text)
                    local number=tonumber(text:match("^%s*(%d+)%s*%%?%s*$"))
                    return number and number<=100 and (number .. "%") or nil
                end
                local home_percent,away_percent=percentage(home.text),percentage(away.text)
                if home_percent and away_percent then
                    fields[1]=caption.text .. ". " .. team("teamName_left",pt and "Mandante" or "Home")
                        .. " " .. home_percent .. ". " .. team("teamName_right",pt and "Visitante" or "Away") .. " " .. away_percent
                end
            end
            local identity="match-possession:" .. window.address .. ":" .. window.root .. ":" .. row
            return {entries=fields,nodes=nodes,identity=identity,signature=identity .. ":" .. (fields[1] or ""),
                navigation_only=true}
        end
        local function add(name,label)
            local candidate=unique(name)
            if not candidate or labels[label] or ambiguous then return end
            local text=candidate.text
            if name=="ranking" or name=="leagueRank_rank" then
                if shared.a11y.empty_selection_caption(text) and text~="" then text=pt and "traço" or "dash" end
            end
            if text and not shared.a11y.empty_selection_caption(text) then
                fields[#fields+1]=label .. ": " .. text;nodes[#nodes+1]=candidate
                keys[name],labels[label]=true,true
            end
        end
        for _,column in ipairs(shared.a11y.record_columns) do add(column[1],column[pt and 2 or 3]) end
        local pair_count=0
        local group_fields={}
        local paired={}
        for _,field in ipairs(not ambiguous and shared.a11y.group_record_fields(names,window) or {}) do
            local label=field.label.text
            if field.name=="budget_difference" then label=label .. (pt and " — diferença" or " — difference") end
            local pair_key=tostring(field.scope) .. ":" .. tostring(field.parent) .. ":" .. label
            if not ambiguous and not labels[label] and not paired[pair_key] then
                pair_count=pair_count+1;fields[#fields+1]=label .. ": " .. field.value.text
                nodes[#nodes+1]=field.value;paired[pair_key]=true;keys[field.name]=true
                group_fields[#fields]={title=field.group_title,key=field.group_key}
            end
        end
        local financial=names.budget_headline and names.budget_value
        local grouped_pairs=pair_count>=2 or financial and pair_count>=1
        local standings=(keys.teamNameText or keys.teamName or keys.leagueRank_teamName)
            and (keys.ptsText or keys.point or keys.num_Points or keys.leagueRank_point or keys.ranking or keys.leagueRank_rank)
        local calendar=keys.date and (encountered.event or keys.teamName_home or keys.teamName_away
            or (shared.a11y.widget_internal_name(row) or ""):match("^listItem_"))
        local table_scope=encountered.date and encountered.event
            or encountered.leagueRank_teamName and encountered.leagueRank_point
            or encountered.teamName and encountered.num_Points
        local save=base and vt==base+0x2948538
            and shared.a11y.menu_read(vt+0x18,"u64")==base+0x14217c0
            and shared.a11y.menu_read(vt+0x100,"u64")==base+0xca1a50
        local native_standings=base and vt==base+0x2684408
            and shared.a11y.menu_read(vt+0x18,"u64")==base+0xaed5d0
            and shared.a11y.menu_read(vt+0x130,"u64")==base+0xaedf80
        if save then
            local number,caption=unique("thumbailNumber"),unique("text_0")
            fields,nodes={},{}
            if not ambiguous and number and number.text:match("^%d+$") and caption then
                fields[1]=(pt and "Slot " or "Slot ") .. number.text;nodes[1]=number
                for _,name in ipairs({"text_0","text_1","text_2"}) do
                    local item=unique(name)
                    if item and not shared.a11y.empty_selection_caption(item.text) then
                        fields[#fields+1]=item.text;nodes[#nodes+1]=item
                    end
                end
            end
        end
        local journal=names.journal_text_0 or names.journal_text_1
            or shared.a11y.widget_internal_name(row)=="p_journal"
        local dashboard_standings=names.leagueRank_teamName and names.leagueRank_point
            and #(names.leagueRank_teamName)>1
        if not ambiguous and (journal or dashboard_standings) then
            fields,nodes={},{}
            local label=journal and (pt and "Diário" or "Journal") or (pt and "Classificação" or "Standings")
            local identity="card:" .. window.address .. ":" .. window.root .. ":" .. row
            return {entries=fields,nodes=nodes,groups={},identity=identity,window=window.address,row=row,
                label=label,signature=identity .. ":" .. label,unresolved=false,dashboard_card=true}
        end
        if not standings and not calendar and not grouped_pairs and not save then
            if not table_scope and not caption and not native_standings then return nil end
            -- A dashboard card or unresolved list owns its scope, but cannot
            -- release every row to the generic exploration buffer.
            fields,nodes={},{}
        end
        local label
        if not standings and not calendar and not grouped_pairs and not save then
            label=caption and caption.text or encountered.leagueRank_teamName and (pt and "Classificação" or "Standings")
                or encountered.date and encountered.event and (pt and "Calendário" or "Calendar")
                or native_standings and (pt and "Classificação" or "Standings") or nil
        elseif encountered.leagueRank_teamName then label=pt and "Classificação" or "Standings" end
        local identity="record:" .. window.address .. ":" .. window.root .. ":" .. row
        return {entries=fields,nodes=nodes,groups=group_fields,identity=identity,window=window.address,row=row,label=label,
            native_standings=native_standings,
            signature=identity .. ":" .. (label or "") .. ":" .. table.concat(fields,"; ") .. ":" .. shared.a11y.group_signature(group_fields),
            unresolved=#fields==0}
    end
    function shared.a11y.structured_record_packet()
        if shared.core_context and shared.core_context.match_playing then return nil end
        local context=shared.a11y.read_context_state()
        local snapshot=shared.a11y.native_windows
        local base=tonumber(shared.process_base_u64)
        if not base or not snapshot or shared.a11y.keyboard_window or context.structural_question or context.structural_event then return nil end
        local work=shared.a11y.render_read_work
        local cache_key=shared.a11y.detail_reads_allowed and "structured_detail" or "structured"
        if work then
            if work.structured_snapshot~=snapshot then
                work.structured_snapshot,work.structured,work.structured_detail=snapshot,nil,nil
            end
            if work[cache_key]~=nil then return work[cache_key] or nil end
        end
        if shared.a11y.native_information_context and shared.a11y.native_information_context() then return nil end
        local standings_window=shared.a11y.active_native_standings()
        local list_focused=not standings_window and shared.a11y.native_list_has_focus and shared.a11y.native_list_has_focus()
        local list_item=shared.a11y.native_list_selection
        local primary_window=shared.a11y.primary_input_window()
        if not standings_window and list_focused and list_item and (list_item.country or list_item.nested
                or list_item.name=="playerName") then return nil end
        local found
        for _,window in ipairs(snapshot.windows or {}) do
            local detail=window.enabled and (not primary_window or window.address==primary_window.address)
                and (not standings_window or window.address==standings_window.address) and window.cursor_detail
            local player_row=false
            if detail and detail.selected and not standings_window then
                for _,node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.names.playerName or {}) do
                    if shared.a11y.record_contains(node,window,detail.selected) then player_row=true;break end
                end
            end
            if detail and detail.selected and (shared.a11y.detail_reads_allowed or not player_row) then
                local row,names,ambiguous,selection,authoritative=shared.a11y.selected_record_scope(window,base)
                local packet=shared.a11y.compose_record_packet(window,row,names,ambiguous)
                if packet and selection then
                    packet.signature=selection.identity .. ":" .. packet.signature
                    packet.authoritative_standings=authoritative
                end
                if list_focused and packet and not packet.dashboard_card and not packet.native_standings then packet=nil end
                -- Change-only evidence for unresolved components: never invent
                -- labels from a card index or release all of a table's rows.
                if (shared.a11y.record_trace_count or 0)<64 then
                    local shape={}
                    for name,items in pairs(names) do shape[#shape+1]=name .. "=" .. #items end
                    table.sort(shape)
                    local trace=window.address .. ":" .. row .. ":" .. table.concat(shape,",") .. ":" .. tostring(ambiguous)
                    if trace~=shared.a11y.last_record_trace then
                        shared.a11y.last_record_trace=trace
                        shared.a11y.record_trace_count=(shared.a11y.record_trace_count or 0)+1
                        log("[FLAccess] record-scope " .. trace .. " fields=" .. tostring(packet and #packet.entries or 0))
                    end
                end
                if packet then
                    if found and found.signature~=packet.signature then return nil end
                    found=packet
                end
            end
        end
        if work then work[cache_key]=found or false end
        return found
    end
    function shared.a11y.structured_record_allowed(stamp)
        local previous=shared.a11y.detail_reads_allowed
        shared.a11y.detail_reads_allowed=stamp.detail or false
        local packet=shared.a11y.structured_record_packet()
        shared.a11y.detail_reads_allowed=previous
        return packet and packet.signature==stamp.signature and shared.a11y.native_owner_token()==stamp.owner
    end
    function shared.a11y.poll_structured_record(blocked)
        local packet=shared.a11y.structured_record_packet()
        if not packet then shared.a11y.structured_record_announced=nil;return false end
        if packet.navigation_only then shared.a11y.structured_record_announced=nil;return true end
        if packet.native_standings and packet.unresolved then
            shared.a11y.standings_observation=nil
            return true
        end
        if packet.native_standings and not packet.authoritative_standings then
            -- The renderer updates columns individually. Observe the complete
            -- packet in another frame before automatically publishing it; do
            -- not turn each intermediate cell write into an interruption.
            local observed=shared.a11y.standings_observation
            if not observed or observed.signature~=packet.signature then
                shared.a11y.standings_observation={signature=packet.signature,frame=shared.frame}
                return true
            end
            if shared.frame<=observed.frame then return true end
        end
        if blocked then
            local context=shared.a11y.read_context_state()
            if (shared.a11y.navigation_frame or -10000)<(context.started_frame or 0)
                    or shared.frame-(shared.a11y.navigation_frame or -10000)>2 then return true end
            shared.modal_focus_hold_until_ms=0
        end
        local previous=shared.a11y.structured_record_announced
        if previous and previous.signature==packet.signature and previous.status~="pending" then return true end
        local state={signature=packet.signature,status="pending",attempt=(previous and previous.attempt or 0)+1}
        shared.a11y.structured_record_announced=state
        local first=packet.native_standings and packet.nodes and packet.nodes[1]
        local club=first and (first.name=="teamName" or first.name=="teamNameText" or first.name=="leagueRank_teamName")
        local text
        if club then
            local rest=table.concat(packet.entries,"; ",2)
            text=first.text .. (rest~="" and ". " .. rest or "")
        else
            text=table.concat(packet.entries,"; ")
            if packet.label then text=packet.label .. (text~="" and ". " .. text or "") end
        end
        if text=="" then return true end
        local before=shared.a11y.native_speech_last
        shared.speak(text,true,true,"structured-record:" .. packet.signature .. ":" .. state.attempt)
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].structured_record={signature=packet.signature,owner=shared.a11y.native_owner_token(),state=state}
            state.status="queued"
        end
        return true
    end
    -- 15765e0 copies the game's current career Date (u16 year,u8 month,u8 day).
    -- Calendar display at b05840 instead starts with an ordinal day; do not
    -- substitute its selected fixture date or the computer's clock.
    function shared.a11y.native_ml_date()
        local base=tonumber(shared.process_base_u64)
        local found
        if not base then return nil end
        for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
            if window.enabled and window.root and window.root>=0x10000
                    and shared.a11y.menu_read(window.address,"u64")==base+0x26ae818
                    and shared.a11y.menu_read(base+0x26ae818+0x18,"u64")==base+0xb850f0 then
                if found then return nil end
                found=window
            end
        end
        if not found or shared.a11y.menu_read(base+0x14b6a60,"u16")~=0x8b48
                or shared.a11y.menu_read(base+0x14b6a62,"u8")~=5
                or shared.a11y.menu_read(base+0x14b6a63,"u32")~=0x224f3a9
                or shared.a11y.menu_read(base+0x15765f4,"u32")~=0x1642a24 then return nil end
        local manager=shared.a11y.menu_read(base+0x3705e10,"u64")
        local data=manager and manager>=0x10000 and shared.a11y.menu_read(manager+0x48,"u64")
        if not data or data<0x10000 then return nil end
        local date=data+0x1642a24
        local year,month,day=shared.a11y.menu_read(date,"u16"),shared.a11y.menu_read(date+2,"u8"),shared.a11y.menu_read(date+3,"u8")
        if not year or year<1900 or year>9999 or not month or month<1 or month>12 or not day or day<1 then return nil end
        local lengths={31,28,31,30,31,30,31,31,30,31,30,31}
        if year%4==0 and (year%100~=0 or year%400==0) then lengths[2]=29 end
        if day>lengths[month] then return nil end
        local text=string.format(shared.a11y.ui_language=="pt" and "Data: %02d/%02d/%04d" or "Date: %02d/%02d/%04d",day,month,year)
        local identity=found.address .. ":" .. found.root
        return {text=text,identity=identity,signature=identity .. ":" .. data .. ":" .. year .. ":" .. month .. ":" .. day}
    end
    function shared.a11y.ml_date_allowed(stamp)
        local packet=shared.a11y.native_ml_date()
        return shared.a11y.read_context_state().kind~="dialog" and packet and packet.signature==stamp.signature
    end
    function shared.a11y.poll_ml_date()
        local packet=shared.a11y.native_ml_date()
        if not packet then shared.a11y.ml_date_announcement=nil;return end
        if shared.a11y.read_context_state().kind=="dialog" then return end
        local state=shared.a11y.ml_date_announcement
        if not state or state.signature~=packet.signature then
            state={signature=packet.signature,status="pending",attempt=0};shared.a11y.ml_date_announcement=state
        end
        if state.status~="pending" then return end
        state.attempt=state.attempt+1
        local before=shared.a11y.native_speech_last
        shared.speak(packet.text,false,true,"ml-date:" .. packet.signature .. ":" .. state.attempt)
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].ml_date={signature=packet.signature,state=state};state.status="queued"
        end
    end
    shared.a11y.records_ready=true
end
component.init=component.install
return component
