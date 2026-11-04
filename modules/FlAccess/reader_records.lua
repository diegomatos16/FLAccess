-- Reusable selected-record reader. Automatic speech and exploration consume
-- the same validated packet; exploration exposes one labelled field per step.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared=ctx.flaccess.reader
    assert(shared.stage==5, "FLAccess records must load after semantics and before review")

    assert(shared.a11y.groups_ready,"reader_groups must precede records")
    function shared.a11y.record_contains(node,window,row)
        local address=node and tonumber(node.address)
        local member=address and shared.a11y.native_windows and shared.a11y.native_windows.members[address]
        for _,owner in ipairs(member and member.owners or {}) do
            if owner.enabled and owner.address==window.address and owner.root==window.root then
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
        if not window.enabled or not shared.a11y.record_contains(node,window,row) then return false end
        if shared.a11y.native_presentation_ready(node.address) then return true end
        -- Native getter e4bb90 checks the low state bits only. e4bb70 also
        -- requires bit8 (input participation). A record value need not accept
        -- input. Scope is still proven by the selected row and enabled owner.
        local flags=shared.a11y.menu_read(tonumber(node.address)+0xc,"u32")
        return flags~=nil and flags%8==7
    end
    function shared.a11y.collect_record_nodes(window,row,filter)
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
        for address in pairs(snapshot and snapshot.members or {}) do
            local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(address)]
            add(address,node)
        end
        -- Only native members can pass record_contains. Visiting the entire
        -- historical UI model again cannot contribute another eligible field.
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
    function shared.a11y.selected_record_scope(window,base)
        local row=window.cursor_detail.selected
        local vt=shared.a11y.menu_read(window.address,"u64")
        if vt==base+0x2684408 and shared.a11y.menu_read(vt+0x18,"u64")==base+0xaed5d0
                and shared.a11y.menu_read(vt+0x130,"u64")==base+0xaedf80 then
            -- This mapped list keeps the outer cursor on its first card.
            -- e3d140 reads the selection from the GROUP's kind-16 selector;
            -- descending inside the first card loses the rest of the table.
            local index=shared.a11y.native_window_selected_index(window,base)
            local first,last=shared.a11y.menu_read(window.address+0x90,"u64"),shared.a11y.menu_read(window.address+0x98,"u64")
            local impl=window.impl or shared.a11y.menu_read(window.address+0x88,"u64")
            local group_index=impl and shared.a11y.menu_read(impl+0xa0,"u32")
            local group=group_index and shared.a11y.menu_child(window.root,group_index)
            if not index or not first or first<0x10000 or not last or last<first or (last-first)%4~=0
                    or last-first>48*4 or index>=(last-first)/4 or not group then return row,{},true end
            local selected=shared.a11y.menu_child(group,index)
            local stamp=window.address .. ":" .. index .. ":" .. tostring(selected)
            if shared.a11y.standings_selection_trace~=stamp then
                shared.a11y.standings_selection_trace=stamp
                log("[FLAccess] standings-selection index=" .. index .. " count=" .. (last-first)/4 .. " row=" .. tostring(selected))
            end
            if not selected or selected<0x10000 then return row,{},true end
            return selected,shared.a11y.collect_record_nodes(window,selected),false
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
        for _,field in ipairs(shared.a11y.group_record_fields(names,window)) do
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
        local vt=shared.a11y.menu_read(window.address,"u64")
        local base=tonumber(shared.process_base_u64)
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
        local caption=unique("itemName")
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
        if shared.a11y.native_information_context and shared.a11y.native_information_context() then return nil end
        if shared.a11y.native_list_has_focus and shared.a11y.native_list_has_focus() then return nil end
        local work=shared.a11y.render_read_work
        local cache_key=shared.a11y.detail_reads_allowed and "structured_detail" or "structured"
        if work and work[cache_key]~=nil then return work[cache_key] or nil end
        local found
        for _,window in ipairs(snapshot.windows or {}) do
            local detail=window.enabled and window.cursor_detail
            local player_row=false
            if detail and detail.selected then
                for _,node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.names.playerName or {}) do
                    if shared.a11y.record_contains(node,window,detail.selected) then player_row=true;break end
                end
            end
            if detail and detail.selected and (shared.a11y.detail_reads_allowed or not player_row) then
                local row,names,ambiguous=shared.a11y.selected_record_scope(window,base)
                local packet=shared.a11y.compose_record_packet(window,row,names,ambiguous)
                -- Change-only evidence for unresolved components: never invent
                -- labels from a card index or release all of a table's rows.
                local shape={}
                for name,items in pairs(names) do shape[#shape+1]=name .. "=" .. #items end
                table.sort(shape)
                local trace=window.address .. ":" .. row .. ":" .. table.concat(shape,",") .. ":" .. tostring(ambiguous)
                if trace~=shared.a11y.last_record_trace and (shared.a11y.record_trace_count or 0)<64 then
                    shared.a11y.last_record_trace=trace
                    shared.a11y.record_trace_count=(shared.a11y.record_trace_count or 0)+1
                    log("[FLAccess] record-scope " .. trace .. " fields=" .. tostring(packet and #packet.entries or 0))
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
        if packet.native_standings then
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
        local text=table.concat(packet.entries,"; ")
        if packet.label then text=packet.label .. (text~="" and ". " .. text or "") end
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
