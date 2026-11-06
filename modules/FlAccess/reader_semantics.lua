-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 4, "FLAccess reader: missing or reordered component semantics")
function shared.is_screen_title(text, widget)
    local role = shared.a11y.text_asset_role(text)
    local widget_name = widget and shared.a11y.widget_internal_name(widget) or nil
    if (widget_name == "title" or widget_name == "text_title")
            and #text <= 80 and not text:find("%", 1, true)
            and role ~= "control" and role ~= "dialog-button"
            and role ~= "status" and role ~= "technical"
            and not shared.looks_like_message(text) then
        return true
    end
    return (role == "menu-item-or-title" and #text <= 55
            and not text:match("[%.%!%?]$")
            and (text:match("^Escolha ") or text:match("^Escolher ")
                or text:match("^Selecionar ")
                or text:match("^Choose ") or text:match("^Select ")))
        or text == "Selecionar time"
        or text == "Selecionar Time"
        or text == "Selecionar time."
        or text == "Select Team"
        or text == "Escolha seu time"
        or text == "Escolher seu time"
        or text == "Escolha o seu time"
end

function shared.announce_screen_title(text, widget_key, widget)
    if shared.a11y.read_context_state().native_dialog then return end
    local source=widget and shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(widget)]
    if source and shared.a11y.is_media_caption(source) then return end
    local language=shared.a11y.native_language_context()
    if language and shared.a11y.native_language_heading(widget)==language.label then
        shared.a11y.poll_native_language();return
    end
    text=shared.a11y.native_language_heading(widget) or text
    if not shared.is_screen_title(text, widget) then
        return
    end
    local panel=shared.a11y.read_context_state()
    if panel.native_reading_panel and panel.title==text and shared.a11y.reading_panel_is_current() then return end
    if widget and not shared.a11y.native_presentation_ready(widget) then
        shared.a11y.defer_bound_guidance(widget,text)
        return
    end
    local title_name = widget and shared.a11y.widget_internal_name(widget)
    local title_role = shared.a11y.text_asset_role(text)
    if (title_name == "title" or title_name == "text_title")
            and (not title_role or title_role == "label-or-name") then
        -- An unknown overlay caption must not reset a working menu. Keep it
        -- pending only after an independently recognized context boundary.
        local member=shared.a11y.native_windows and shared.a11y.native_windows.members and shared.a11y.native_windows.members[tonumber(widget)]
        if shared.a11y.read_context_state().kind == "unknown" and member and (member.active or member.presented) then
            shared.a11y.read_context.pending_title = text
        end
        return
    end
    if title_name == "title" or title_name == "text_title" then
        -- A caption is presentation, not proof of a new native scene. A late
        -- title must never erase controls already observed in that scene.
        if shared.a11y.ui_model then shared.a11y.ui_model.surface = text end
        -- A real submenu title ends the horizontal pre-match action reader.
        -- Its background System Settings caption may still be rendered.
        shared.a11y.pre_match_active = false
        shared.a11y.pre_match_entry_pending = false
    end
    shared.a11y.transition_old_focus_texts = nil
    shared.a11y.transition_guard_until_ms = 0
    -- Returning from group assignment to team selection ends the table mode.
    shared.a11y.cup_group_table_active = false
    shared.a11y.set_read_title(text)
    shared.a11y.screen_title_hold_until_ms =
        tonumber(ffi.C.GetTickCount64()) + 500
    local key = text
    if key ~= shared.last_screen_title_key
            or shared.frame - shared.a11y.last_screen_title_frame > 120 then
        shared.last_screen_title_key = key
        shared.a11y.last_screen_title_frame = shared.frame
        shared.a11y.title_pending_first_item = nil
        shared.speak(text,not shared.a11y.read_context_state().native_reading_panel,nil,nil,widget)
        shared.a11y.title_pending_first_item = text
        shared.a11y.title_pending_first_item_until_ms =
            tonumber(ffi.C.GetTickCount64()) + 2000
    end
end

function shared.a11y.announce_skip_hint(text, node)
    if not text or shared.frame - shared.a11y.skip_hint_last_frame < 300
            or not shared.a11y.game_is_foreground() then
        return false
    end
    local lower = text:lower()
    if node and (text == "Pular" or text == "Skip") then
        if not shared.a11y.pending_skip_hint or shared.a11y.pending_skip_hint.key ~= node.key then
            shared.a11y.pending_skip_hint = {owner=node.owner_link,key=node.key,started=shared.frame,
                text=text,native_owner=shared.a11y.native_owner_token()}
        end
        return true
    end
    local skip_marker = text:find("<Pular>", 1, true)
        or text:find("<Skip>", 1, true)
        or text:match("[Pp]ressione%s+.+%s+para pular")
        or text:match("[Pp]ress%s+.+%s+to skip")
        or (lower:find("options", 1, true)
            and (lower:find("pular", 1, true)
                or lower:find("skip", 1, true)))
    if not skip_marker then return false end
    if text:find("%%s") then return false end
    shared.a11y.skip_hint_last_frame = shared.frame
    -- Preserve the game's wording rather than inventing an instruction.
    local spoken=text:gsub("<Pular>","Pular"):gsub("<Skip>","Skip")
    shared.speak(spoken,nil,nil,nil,node and node.address)
    return true
end

function shared.a11y.spoken_control_icon(text)
    return text and (text:find("botão",1,true) or text:find("button",1,true)
        or text:find("tecla ",1,true) or text:find("key ",1,true)
        or text=="Options" or text=="Start" or text=="Menu" or text=="Esc" or text=="Enter")
end

function shared.a11y.command_icon_for_node(source)
    local snapshot=shared.a11y.native_windows
    -- GuideBar pairs follow the indexed nodes used by its presentation
    -- routine. They need not be sibling UI nodes.
    local bound_button
    for _,pair in ipairs(snapshot and snapshot.command_bar and snapshot.command_bar.pairs or {}) do
        if source and pair.caption==tonumber(source.address)
                and shared.a11y.native_widget_allowed(pair.icon) and shared.a11y.native_widget_allowed(pair.caption) then
            local caption=shared.a11y.read_native_rendered_text(pair.caption)
            local icon=shared.a11y.read_native_rendered_text(pair.icon)
            if caption==source.text and shared.a11y.spoken_control_icon(icon) then
                if bound_button and bound_button~=icon then return nil end
                bound_button=icon
            end
        end
    end
    if bound_button then return bound_button end
    local member=source and snapshot and snapshot.members[tonumber(source.address)]
    if not member or not member.active then return nil end
    local nodes=shared.a11y.presented_nodes()
    for _,owner in ipairs(member.owners or {}) do
        local parents=owner.parents
        local ancestor=parents and parents[tonumber(source.address)]
        local visited={}
        for _=1,8 do
            if not owner.enabled or not ancestor or ancestor==owner.root or visited[ancestor] then break end
            visited[ancestor]=true
            local captions,icons,button=0,0,nil
            for _,node in ipairs(nodes) do
                local at,seen=tonumber(node.address),{}
                for _=1,10 do
                    if not at or seen[at] then break end
                    seen[at]=true
                    if at==ancestor then
                        if node.name=="padIcon" then
                            icons=icons+1
                            if shared.a11y.spoken_control_icon(node.text) then button=node.text end
                        elseif node.text and node.text~="" then captions=captions+1 end
                        break
                    end
                    at=parents[at]
                end
            end
            if captions>1 then break end
            if captions==1 and icons==1 and button then return button end
            ancestor=parents[ancestor]
        end
    end
end

function shared.a11y.poll_skip_hint()
    local hint = shared.a11y.pending_skip_hint
    if not hint then return end
    if hint.native_owner and hint.native_owner ~= shared.a11y.native_owner_token() then
        shared.a11y.pending_skip_hint=nil
        return
    end
    if not shared.a11y.native_key_allowed(hint.key) then shared.a11y.pending_skip_hint=nil; return end
    local button,ambiguous
    local source=shared.a11y.ui_model and shared.a11y.ui_model.nodes[hint.key]
    for _, node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.nodes or {}) do
        local peers=source and shared.a11y.component_peers(source.address,node.address)
        if (peers==true or (peers==nil and hint.owner and node.owner_link==hint.owner))
                and node.name == "padIcon" and shared.a11y.ui_node_matches_live(node)
                and shared.a11y.native_widget_allowed(node.address)
                and shared.a11y.spoken_control_icon(node.text) then
            if button and button ~= node.text then ambiguous=true end
            button=node.text
        end
    end
    if ambiguous then button=nil end
    if not button and not ambiguous then button=shared.a11y.command_icon_for_node(source) end
    if not button then
        if shared.frame-hint.started < 12 then return end
        if not hint.label_spoken then
            hint.label_spoken=true
            local source=shared.a11y.ui_model and shared.a11y.ui_model.nodes[hint.key]
            shared.speak(hint.text or (source and source.text),nil,nil,nil,source and source.address)
            shared.a11y.component_evidence(source,"skip-button-unresolved")
            local parts={}
            for _,node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.nodes or {}) do
                if node.name=="padIcon" and #parts<8 and shared.a11y.native_widget_allowed(node.address) then
                    local _,native_raw,native_font=shared.a11y.read_native_rendered_text(node.address)
                    parts[#parts+1]=string.format("%s raw=%q font=%s",node.key,
                        native_raw or node.raw_text or node.text or "",tostring(native_font or node.native_font))
                end
            end
            log("[FLAccess] skip-icon-unresolved widget=" .. hint.key .. " ambiguous=" .. tostring(ambiguous)
                .. " font-family=" .. tostring(shared.a11y.control_font_family) .. " icons=" .. table.concat(parts," | "))
        end
        if shared.frame-hint.started>120 then shared.a11y.pending_skip_hint=nil end
        return
    end
    shared.a11y.pending_skip_hint = nil
    if shared.frame - shared.a11y.skip_hint_last_frame < 300 then return end
    shared.a11y.skip_hint_last_frame = shared.frame
    local source=shared.a11y.ui_model and shared.a11y.ui_model.nodes[hint.key]
    shared.speak((hint.text or (source and source.text) or "") .. ", " .. button,
        nil,nil,nil,source and source.address)
end

function shared.enqueue_startup_speech(text, duration_ms)
    if not text or text == "" or shared.startup_speech.seen[text] then
        return
    end
    shared.startup_speech.seen[text] = true
    shared.startup_speech.last = shared.startup_speech.last + 1
    shared.startup_speech.queue[shared.startup_speech.last] = {
        text = text,
        duration_ms = duration_ms or 1000,
    }
end

function shared.queue_startup_text(text, now_ms)
    local lower = text:lower()
    if lower:find("edit file", 1, true) then
        shared.startup_speech.version = text
        shared.startup_speech.version_due_ms = now_ms + 5000
        return true
    end
    if lower:find("smokepatch", 1, true)
            or lower:find("smoke patch", 1, true) then
        if shared.startup_speech.version and not shared.startup_speech.version_queued then
            shared.enqueue_startup_speech(shared.startup_speech.version, 1500)
            shared.startup_speech.version_queued = true
        end
        return true
    end
    if shared.is_plain_text(text) and not shared.startup_complete then
        if shared.startup_speech.version and not shared.startup_speech.version_queued then
            shared.enqueue_startup_speech(shared.startup_speech.version, 1500)
            shared.startup_speech.version_queued = true
        end
        shared.enqueue_startup_speech(text, 900)
        return true
    end
    return false
end

function shared.process_startup_speech(now_ms)
    if shared.startup_speech.version and not shared.startup_speech.version_queued
            and shared.startup_speech.version_due_ms
            and now_ms >= shared.startup_speech.version_due_ms then
        shared.enqueue_startup_speech(shared.startup_speech.version, 1500)
        shared.startup_speech.version_queued = true
    end
    if now_ms < shared.startup_speech.next_ms then
        return true
    end
    local item = shared.startup_speech.queue[shared.startup_speech.first]
    if item then
        shared.startup_speech.queue[shared.startup_speech.first] = nil
        shared.startup_speech.first = shared.startup_speech.first + 1
        shared.speak(item.text)
        shared.startup_speech.next_ms = now_ms + item.duration_ms
        return true
    end
    return false
end

function shared.selector_role(label)
    if label == "Nome do treinador" or label == "Manager Name" or label == "Coach Name" then
        return "ativar para editar"
    end
    if label == "Nome dos ajustes" then
        return "campo de texto"
    end
    return "seletor"
end

function shared.control_speech(row)
    local spoken = row.label .. ", " .. (row.role or shared.selector_role(row.label))
    if row.value and row.value ~= "" then
        spoken = spoken .. ", " .. row.value
    end
    return spoken
end

function shared.a11y.track_control_focus(key)
    local row = shared.a11y.control_for_widget(key)
    local owner = row or key
    if shared.a11y.control_focus_owner ~= owner then
        shared.a11y.control_focus_owner = owner
        shared.last_controller_announcement, shared.last_announced_control_row = nil, nil
        shared.last_announced_selector_label = nil
    end
end

function shared.a11y.secondary_focus_is_current(key, index)
    local model = shared.a11y.ui_model
    local edge = shared.ui_focus_activated[key] and shared.ui_focus_activated[key][index] or -1
    return not model or not model.last_primary_edge or edge >= model.last_primary_edge
end

-- Investigation only: bounded observations, never used as visibility or focus authority.
function shared.a11y.capture_focus_trace(stage)
    if not shared.a11y.diagnostic_mode then return end
    local trace = shared.a11y.focus_trace
    if not trace or not shared.a11y.sider_dir or (trace.bytes or 0) >= 2097152 then return end
    local lines = {string.format("TRACE input=%d frame=%d stage=%s action=%s generation=%s reason=%s",
        trace.sequence, shared.frame, stage, tostring(trace.action),
        tostring(shared.a11y.ui_model and shared.a11y.ui_model.generation),
        tostring(shared.a11y.ui_model and shared.a11y.ui_model.focus_reason))}
    local generation = shared.a11y.ui_model and shared.a11y.ui_model.generation
    if trace.sample_generation ~= generation then
        trace.samples, trace.owner_samples, trace.sample_generation = {}, {}, generation
    end
    trace.samples = trace.samples or {}
    local nodes = {}
    for _, node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.nodes or {}) do nodes[#nodes + 1] = node end
    table.sort(nodes, function(left, right) return left.sequence > right.sequence end)
    for position, node in ipairs(nodes) do
        if position > 80 then break end
        if shared.readable(node.address, 0x180) then
            local bytes = shared.a11y.safe_memory_read(node.address, 0x180)
            if bytes and #bytes == 0x180 then
                local previous = trace.samples[node.identity]
                local fields = {}
                for offset = 0, 0x17c, 4 do
                    local relative = offset
                    local value = memory.unpack("u32", bytes:sub(relative + 1, relative + 4))
                    local old = previous and memory.unpack("u32", previous.bytes:sub(relative + 1, relative + 4))
                    if (not previous and value ~= 0) or (previous and value ~= old) then
                        fields[#fields + 1] = string.format("%x=%x", offset, value)
                    end
                end
                trace.samples[node.identity] = {bytes=bytes, text=node.text}
                local row = shared.a11y.control_for_widget(node.key)
                if not previous or #fields > 0 or previous.text ~= node.text then
                lines[#lines + 1] = string.format("node=%s identity=%s name=%q text=%q age=%d control=%s fields={%s}",
                    node.key, node.identity, node.name or "", node.text or "", shared.frame-node.last_seen,
                    row and shared.control_speech(row) or "none", table.concat(fields, ","))
                end
            end
        end
    end
    local owners, owner_count = {}, 0
    trace.owner_samples = trace.owner_samples or {}
    for _, node in ipairs(nodes) do
        local owner = node.owner_link
        if owner and not owners[owner] and owner_count < 16 then
            owners[owner], owner_count = true, owner_count + 1
            if shared.readable(owner, 0x100) then
                local bytes = shared.a11y.safe_memory_read(owner, 0x100)
                if bytes and #bytes == 0x100 then
                    local previous, fields = trace.owner_samples[owner], {}
                    for offset = 0, 0xfc, 4 do
                        local value = memory.unpack("u32",bytes:sub(offset+1,offset+4))
                        local old = previous and memory.unpack("u32",previous:sub(offset+1,offset+4))
                        if (not previous and value ~= 0) or (previous and value ~= old) then
                            fields[#fields+1] = string.format("%x=%x",offset,value)
                        end
                    end
                    trace.owner_samples[owner] = bytes
                    if #fields > 0 then
                        lines[#lines+1] = "owner-candidate=" .. tostring(owner) .. " fields={" .. table.concat(fields,",") .. "}"
                    end
                end
            end
        end
    end
    local output = table.concat(lines, "\n") .. "\n\n"
    local file = io.open(shared.a11y.sider_dir .. "\\FLAccess-focus-trace.log", trace.started and "at" or "wt")
    if not file then return end
    file:write(output); file:close()
    trace.started, trace.bytes = true, (trace.bytes or 0) + #output
end

function shared.a11y.begin_focus_trace(action)
    if not shared.a11y.diagnostic_mode then return end
    local trace = shared.a11y.focus_trace or {sequence=0, bytes=0}
    if trace.sequence >= 120 or trace.bytes >= 2097152 then return end
    trace.sequence, trace.action, trace.input_frame = trace.sequence + 1, action, shared.frame
    trace.followups = {shared.frame + 4, shared.frame + 12}
    shared.a11y.focus_trace = trace
    shared.a11y.capture_focus_trace("input")
end

function shared.a11y.poll_focus_trace()
    if not shared.a11y.diagnostic_mode then shared.a11y.focus_trace=nil;return end
    local trace = shared.a11y.focus_trace
    if not trace or not trace.followups then return end
    while trace.followups[1] and shared.frame >= trace.followups[1] do
        local due = table.remove(trace.followups, 1)
        shared.a11y.capture_focus_trace("after-" .. tostring(due - trace.input_frame))
    end
end

-- Structured, opt-in evidence. These records never grant speech authority.
-- Capture changes throughout a session, not only its first 120 inputs.
function shared.a11y.start_component_capture(path)
    local file=path and io.open(path,"wt")
    if not file then return false end
    file:write("FLACCESS_COMPONENTS format=1 build=",tostring(shared.a11y.build),
        " started=",os.date("!%Y-%m-%dT%H:%M:%SZ"),"\n")
    file:close()
    shared.a11y.component_capture={active=true,path=path,bytes=0,sequence=0,nodes={},parents={}}
    return true
end

function shared.a11y.start_armed_component_capture()
    if not shared.a11y.sider_dir then return false end
    local marker=shared.a11y.sider_dir .. "\\FLAccess-components.capture"
    local file=io.open(marker,"rt")
    if not file then return false end
    local armed=file:read("*l")=="armed"
    file:close()
    if not armed or not shared.a11y.start_component_capture(shared.a11y.sider_dir .. "\\FLAccess-components.log") then return false end
    file=io.open(marker,"wt")
    if not file then shared.a11y.component_capture.active=false; return false end
    file:write("consumed\n");file:close()
    log("[FLAccess] component-capture=started policy=changes-only one-session")
    return true
end

function shared.a11y.component_capture_lines(capture)
    local snapshot=shared.a11y.native_windows
    local owner=shared.a11y.native_owner_token() or ""
    local lines,ordered,parents={}, {}, {}
    local generation=shared.a11y.ui_model and shared.a11y.ui_model.generation
    if capture.owner~=owner or capture.generation~=generation then
        capture.owner,capture.generation,capture.nodes,capture.parents=owner,generation,{},{}
    end
    lines[#lines+1]=string.format("SNAP sequence=%d frame=%d owner=%q generation=%s reason=%q action=%q keyboard=%s font=%s base=%s",
        capture.sequence,shared.frame,owner,tostring(shared.a11y.ui_model and shared.a11y.ui_model.generation),
        shared.a11y.ui_model and shared.a11y.ui_model.focus_reason or "",shared.a11y.diagnostic_last_input_action or "",
        tostring(shared.a11y.keyboard_window),tostring(shared.a11y.control_font_family),tostring(tonumber(shared.process_base_u64)))
    for _,window in ipairs(snapshot and snapshot.windows or {}) do
        local d=window.cursor_detail or {}
        lines[#lines+1]=string.format("WINDOW address=%s root=%s input=%s selected=%s group=%s index=%s status=%q owned_roots=%q type=%s impl=%s presentation=%s task_parent=%s task_child=%s",
            tostring(window.address),tostring(window.root),tostring(window.enabled),tostring(d.selected),
            tostring(d.group),tostring(d.item_index),d.status or "no-cursor",table.concat(window.owned_roots or {},","),
            tostring(shared.a11y.menu_read(window.address,"u64")),tostring(window.impl),
            tostring(window.impl and shared.a11y.menu_read(window.impl+0x90,"u64")),
            tostring(shared.a11y.menu_read(window.address+0x38,"u64")),
            tostring(shared.a11y.menu_read(window.address+0x40,"u64")))
        for _,item in ipairs(window.tree_evidence and window.tree_evidence.frontier or {}) do
            lines[#lines+1]="FRONTIER window=" .. tostring(window.address) .. " address=" .. tostring(item.address)
                .. " rva=" .. tostring(item.rva) .. " fields=" .. shared.a11y.native_node_summary(item.address)
        end
    end
    for _,line in ipairs(shared.a11y.component_link_capture_lines(snapshot)) do lines[#lines+1]=line end
    local list=shared.a11y.native_list_selection
    if list then
        lines[#lines+1]=string.format("LIST widget=%s identity=%q text=%q observed=%s committed=%s",
            tostring(list.widget),list.identity or "",shared.a11y.diagnostic_text(list.text),tostring(list.observed),tostring(list.committed))
    end
    for key,node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.nodes or {}) do
        local address=tonumber(node.address)
        if address then
            local member=snapshot and snapshot.members and snapshot.members[address]
            local selected=snapshot and snapshot.selected_members and snapshot.selected_members[address]
            ordered[#ordered+1]={key=key,node=node,member=member,selected=selected==true,
                rank=selected and 0 or member and member.active and 1 or not member and 2 or 3}
        end
    end
    table.sort(ordered,function(a,b)
        if a.rank~=b.rank then return a.rank<b.rank end
        if (a.node.last_seen or 0)~=(b.node.last_seen or 0) then return (a.node.last_seen or 0)>(b.node.last_seen or 0) end
        return a.key<b.key
    end)
    local live={}
    for index,item in ipairs(ordered) do
        if index>128 then break end
        local node,member=item.node,item.member
        local address=tonumber(node.address)
        local bound=shared.a11y.control_for_widget(item.key)
        local provisional=shared.control_rows_by_label_widget[item.key]
        local event=shared.a11y.engine_focus and shared.a11y.engine_focus.nodes and shared.a11y.engine_focus.nodes[item.key]
        local text,raw,font=shared.a11y.read_native_rendered_text(address)
        local path={}
        for _,entry in ipairs(member and member.owners or {}) do
            if entry.parents then
                local at,visited=address,{}
                for _=1,8 do
                    if not at or visited[at] then break end
                    visited[at]=true
                    path[#path+1]=tostring(at)
                    parents[at]=true
                    if at==entry.root then break end
                    at=entry.parents[at]
                end
                break
            end
        end
        -- membership=unknown is intentionally not reported as visible.
        local raw_hex=((raw or node.raw_text or ""):sub(1,128):gsub(".",function(byte) return string.format("%02x",byte:byte()) end))
        local line=string.format("NODE key=%q identity=%q type=%s flags=%s focus104=%s event_edge=%s name=%q text=%q rendered=%q rendered_read=%s raw=%q raw_hex=%q font=%s member=%q selected=%s label=%q value=%q relation=%q provisional=%q link38=%s link40=%s link50=%s path=%q",
            item.key,tostring(node.identity),tostring(shared.a11y.menu_read(address,"u64")),
            tostring(shared.a11y.menu_read(address+0xc,"u32")),tostring(shared.a11y.menu_read(address+0x104,"u32")),
            tostring(event and event.edge),node.name or "",shared.a11y.diagnostic_text(node.text),
            shared.a11y.diagnostic_text(text),tostring(text~=nil),shared.a11y.diagnostic_text(raw or node.raw_text),raw_hex,tostring(font or node.native_font),
            member and (member.active and "input-owner" or member.presented and "context-owner" or "inactive-owner") or "unknown",
            tostring(item.selected),bound and shared.a11y.diagnostic_text(bound.label) or "",
            bound and shared.a11y.diagnostic_text(bound.value) or "",
            bound and (bound.native_field and "native-field" or bound.structural and "named-pair" or "provisional") or "none",
            provisional and shared.a11y.diagnostic_text(provisional.label) or "",
            tostring(node.owner_link),tostring(shared.a11y.menu_read(address+0x40,"u64")),
            tostring(shared.a11y.menu_read(address+0x50,"u64")),table.concat(path,">"))
        live[item.key]=true
        if capture.nodes[item.key]~=line then lines[#lines+1]=line;capture.nodes[item.key]=line end
    end
    local removed={}
    for key in pairs(capture.nodes) do if not live[key] then removed[#removed+1]=key end end
    table.sort(removed)
    for _,key in ipairs(removed) do
        lines[#lines+1]=string.format("DROP key=%q reason=outside-sampled-model",key)
        capture.nodes[key]=nil
    end
    local addresses={}
    for at in pairs(parents) do addresses[#addresses+1]=at end
    table.sort(addresses)
    for index,at in ipairs(addresses) do
        if index>64 then break end
        local line="PARENT address=" .. tostring(at) .. " name=" .. string.format("%q",shared.a11y.widget_internal_name(at) or "")
            .. " flags=" .. tostring(shared.a11y.menu_read(at+0xc,"u32"))
            .. " focus104=" .. tostring(shared.a11y.menu_read(at+0x104,"u32"))
            .. " fields=" .. shared.a11y.native_node_summary(at)
        if capture.parents[at]~=line then lines[#lines+1]=line;capture.parents[at]=line end
    end
    lines[#lines+1]="END sampled=" .. tostring(math.min(#ordered,128)) .. " total=" .. tostring(#ordered)
    return lines
end

function shared.a11y.poll_component_capture()
    local capture=shared.a11y.component_capture
    if not capture or not capture.active or shared.frame-(capture.last_poll or -10000)<12 then return end
    capture.last_poll=shared.frame
    local signature=(shared.a11y.native_owner_token() or "") .. ":" .. tostring(shared.a11y.component_capture_dirty_frame)
        .. ":" .. tostring(shared.a11y.diagnostic_last_input_frame)
        .. ":" .. tostring(shared.a11y.native_cursor_identity)
        .. ":" .. tostring(shared.a11y.ui_model and shared.a11y.ui_model.generation)
    if signature==capture.signature then
        if not capture.followup_due or shared.frame<capture.followup_due then return end
        capture.followup_due=nil
    else
        capture.signature=signature
        capture.followup_due=shared.frame+36
    end
    capture.sequence=capture.sequence+1
    local output=table.concat(shared.a11y.component_capture_lines(capture),"\n") .. "\n"
    -- On reaching a limit, preserve the entire file and report it explicitly.
    if capture.bytes+#output>33554432 or capture.sequence>20000 then
        capture.active=false
        log("[FLAccess] component-capture=limit-reached bytes=" .. tostring(capture.bytes))
        return
    end
    local file=io.open(capture.path,"at")
    if not file then capture.active=false;log("[FLAccess] component-capture=write-failed");return end
    file:write(output);file:close();capture.bytes=capture.bytes+#output
end

function shared.announce_control(row)
    if shared.a11y.keyboard_window then return end
    if not row or not row.label then
        return
    end
    if row.label_widget and not shared.a11y.native_presentation_ready(row.label_widget) then return end
    if shared.a11y.read_context_state().kind == "dialog" then return end
    local spoken = shared.control_speech(row)
    local result=shared.a11y.selection_result({row=row,source="control",
        identity=row.identity or row.label_widget_key or row.label})
    if not result then return end
    local page=result.page
    if spoken ~= shared.last_controller_announcement or (page and page.identity~=shared.a11y.last_page_announcement)
            or shared.last_announced_control_row ~= row
            or not shared.a11y.read_context_state().selection_result
            or shared.a11y.read_context_state().selection_result.status=="discarded"
            or shared.a11y.read_context_state().selection_result.status=="failed"
            or shared.a11y.read_context_state().selection_result.signature~=result.signature then
        if shared.active_control_row ~= row then
            shared.last_spoken_controller_tooltip_key = nil
            shared.pending_controller_tooltip = nil
            shared.pending_controller_tooltip_label = nil
            shared.controller_tooltip_due_ms = nil
        end
        shared.last_controller_announcement = spoken
        shared.last_announced_control_row = row
        shared.last_announced_selector_label = row.label_widget_key or row.label
        shared.active_control_row = row
        shared.active_controller_label = row.label
        shared.active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
        if shared.a11y.read_tooltips and shared.latest_generic_tooltip
                and shared.latest_generic_tooltip_widget ~= row.label_widget
                and shared.active_control_focused_ms - shared.latest_generic_tooltip_ms <= 1000 then
            shared.pending_controller_tooltip = shared.latest_generic_tooltip
            shared.pending_controller_tooltip_label = row.label
            shared.controller_tooltip_due_ms = shared.active_control_focused_ms
        end
        if not shared.a11y.deliver_selection_result(result) then
            -- A temporary modal hold is not a delivered control announcement.
            shared.last_controller_announcement,shared.last_announced_control_row=nil,nil
        end
    end
end

function shared.announce_control_value(row, value)
    if not row or not value or value == "" then
        return
    end
    if shared.a11y.read_context_state().kind == "dialog" then return end
    row.value = value
    if shared.a11y.keyboard_window then return end
    local full = shared.control_speech(row)
    if row.label_widget and not shared.a11y.native_widget_allowed(row.label_widget) then return end
    local result=shared.a11y.selection_result({row=row,source="control",
        identity=row.identity or row.label_widget_key or row.label})
    if not result then return end
    if full == shared.last_controller_announcement
            and shared.last_announced_control_row == row then
        return
    end
    shared.last_controller_announcement = full
    shared.last_announced_control_row = row
    local row_key = row.label_widget_key or row.label
    if shared.active_control_row == row and shared.last_announced_selector_label == row_key then
        shared.a11y.deliver_selection_result(result,{value_only=true})
    else
        shared.active_control_row = row
        shared.last_announced_selector_label = row_key
        shared.a11y.deliver_selection_result(result)
    end
end

function shared.reset_stadium_screen()
    shared.a11y.stadium_value_index_by_widget = {}
    shared.a11y.stadium_rows = {}
    shared.a11y.stadium_started_frame = shared.frame
end

function shared.stadium_value_category(text)
    if text == "Dia" or text == "Noite"
            or text == "Day" or text == "Night" then
        return 2
    end
    if text == "Verão" or text == "Inverno" or text == "Primavera"
            or text == "Outono" or text == "Ensolarado"
            or text == "Chuva" or text == "Neve"
            or text == "Summer" or text == "Winter" or text == "Spring"
            or text == "Autumn" or text == "Fine" or text == "Rain"
            or text == "Snow" then
        return 3
    end
    if text == "Curta" or text == "Longa"
            or text == "Short" or text == "Long" then
        return 4
    end
    if text == "Seco" or text == "Molhado" or text == "Encharcado"
            or text == "Dry" or text == "Wet" or text == "Waterlogged" then
        return 5
    end
    return nil
end

function shared.stadium_control_for_entry(widget_key, entry)
    if not shared.a11y.stadium_active or not widget_key or not entry then
        return nil
    end
    local index = shared.a11y.stadium_value_index_by_widget[widget_key]
    if not index then
        index = shared.stadium_value_category(entry.text)
        if index and shared.a11y.stadium_rows[index]
                and shared.a11y.stadium_rows[index].value_widget_key ~= widget_key then
            index = nil
        end
    end
    if not index and not shared.a11y.stadium_rows[1] then
        -- The first focused value after opening this screen is the stadium.
        -- Unlike the remaining values, its text is an arbitrary stadium name.
        index = 1
    end
    if not index then
        -- "Aleatório" and "Normal" are shared by several rows. Assign a new
        -- value widget by the screen's verified top-to-bottom order and keep
        -- that ownership while its text changes laterally.
        for candidate = 2, 5 do
            if not shared.a11y.stadium_rows[candidate] then
                index = candidate
                break
            end
        end
    end
    if not index then
        return nil
    end
    shared.a11y.stadium_value_index_by_widget[widget_key] = index
    local labels = shared.stadium_labels[shared.a11y.ui_language] or shared.stadium_labels.en
    local row = shared.a11y.stadium_rows[index]
    if not row then
        row = {
            label = labels[index],
            role = "seletor",
            label_widget_key = "stadium:" .. tostring(index),
            value_widget_key = widget_key,
            is_control = true,
        }
        shared.a11y.stadium_rows[index] = row
    end
    row.value_widget_key = widget_key
    row.value = entry.text
    return row
end

function shared.announce_controller_row(label, value)
    if not label then
        return
    end
    local row = shared.controller_rows[label]
    if not row then
        row = {label = label, role = shared.selector_role(label)}
        shared.controller_rows[label] = row
    end
    if value and value ~= "" then
        row.value = value
    end
    row.is_control = true
    shared.announce_control(row)
end

function shared.a11y.read_msvc_string(object,raw)
    object=tonumber(object)
    if not object or object<0x10000 then return nil end
    local work=shared.a11y.snapshot_read_work or shared.a11y.render_read_work
    local key=tostring(object) .. ":" .. tostring(raw)
    if work and work.strings and work.strings[key]~=nil then return work.strings[key] or nil end
    if work then work.strings=work.strings or {};work.strings[key]=false end
    local function scalar(at)
        if work and shared.a11y.safe_memory_read==shared.a11y.production_memory_read then
            return shared.a11y.menu_read(at,"u64")
        end
        return tonumber(shared.read_u64(shared.a11y.safe_memory_read(at,8)))
    end
    local length=scalar(object+0x10)
    local capacity=scalar(object+0x18)
    if not length or not capacity or length>4096 or capacity<length or capacity>65536 then return nil end
    if length==0 then
        if work then work.strings[key]="" end
        return ""
    end
    local source=capacity>=16 and scalar(object) or object
    local text=source and shared.a11y.safe_memory_read(source,length)
    if not text then return nil end
    local result=raw and text or shared.clean_text(text)
    if work then work.strings=work.strings or {};work.strings[key]=result end
    return result
end

function shared.a11y.widget_internal_name(widget)
    -- The UI text widget contains another MSVC string at +0x18. In captured
    -- FL26 objects this is a stable engine-side name (teamName, btnH_str,
    -- ok_text, setName), not the localized caption. Read it only for
    -- structural field pairs; a name alone does not prove visibility or focus.
    if not widget or widget < 0x10000 then return nil end
    local name = shared.a11y.read_msvc_string(widget + 0x18)
    if name and #name <= 64 and name:match("^[%w_%.%-]+$") then
        return name
    end
    return nil
end

-- Bounded observations, independent of translated captions and render order.
-- +0x38 is deliberately not used: its ownership semantics remain unproven.
function shared.a11y.reset_read_context(reason)
    shared.a11y.last_roster_navigation=nil
    if reason == "transition" then shared.a11y.answer_chain = nil end
    local old = shared.a11y.read_context
    shared.a11y.deferred_modal_announcement,shared.a11y.deferred_speech=nil,nil
    shared.a11y.read_context = {
        generation=(old and old.generation or 0) + 1,
        kind="unknown", reason=reason, started_frame=shared.frame,
        cursor=1,
        title=nil, question=nil, selection=nil, help=nil,
    }
    if reason == "dialog-input" and old and (old.structural_question or old.structural_event) then
        shared.a11y.read_context.kind = "dialog"
        shared.a11y.read_context.structural_question = old.structural_question
        shared.a11y.read_context.structural_event = old.structural_event
        shared.a11y.read_context.owner_link = old.owner_link
        shared.a11y.read_context.baseline, shared.a11y.read_context.answer_owners = {},{}
        shared.a11y.read_context.expires_frame = shared.frame + 3600
    end
end

-- DialogAgreement's answer labels may use another SWF resource owner than
-- its question. The live typed window and native cursor prove that boundary.
function shared.a11y.native_confirmation_answer(node)
    local context=shared.a11y.read_context
    local snapshot=shared.a11y.native_windows
    local address=node and tonumber(node.address)
    if not context or not context.native_dialog or not address or node.key==context.message_key
            or node.text==context.question or not snapshot or not snapshot.selected_members
            or not snapshot.selected_members[address] or not shared.a11y.native_presentation_ready(address) then return false end
    for _,window in ipairs(snapshot.windows or {}) do
        if window.address==context.native_dialog and window.root==context.native_dialog_root
                and shared.a11y.native_dialog_window(window)
                and shared.a11y.record_contains(node,window,window.cursor_detail and window.cursor_detail.selected) then
            return true
        end
    end
    return false
end

function shared.a11y.is_structural_answer(text, key)
    local context = shared.a11y.read_context
    if not context or not (context.structural_question or context.structural_event)
            or not context.owner_link and not context.native_dialog then return false end
    local model = shared.a11y.ui_model
    for node_key, node in pairs(model and model.nodes or {}) do
        if (not key or node_key == key) and node.text == text
                and (shared.a11y.native_confirmation_answer(node)
                    or not context.native_dialog and node.name == "text" and node.owner_link == context.owner_link) then return true end
    end
    return false
end

function shared.a11y.capture_question_panel(node)
    if not shared.a11y.native_presentation_ready(node.address) then
        shared.a11y.defer_bound_guidance(node.address,node.text)
        return false
    end
    if (node.name ~= "question" and node.name ~= "eventMsg") or not node.owner_link or not node.text or node.text == "" then return false end
    shared.a11y.dashboard_review = false
    local context = shared.a11y.read_context_state()
    if (context.structural_question or context.structural_event) and context.message_key == node.key and context.question == node.text then
        return true
    end
    shared.a11y.open_read_dialog(node.text, node.key)
    context = shared.a11y.read_context_state()
    context.kind, context.owner_link = "dialog", node.owner_link
    context.structural_question, context.structural_event = node.name == "question", node.name == "eventMsg"
    for key, other in pairs(shared.a11y.ui_model.nodes) do
        if context.structural_question and other.name == "text" and other.owner_link == node.owner_link then
            context.answer_owners[key] = other.identity
            if #other.text >= 2 and #other.text <= 512 and not shared.ui_focus_widgets[key] then
                shared.ui_focus_widgets[key] = {address=other.address,text=other.text,last_seen=other.last_seen,identity=other.identity}
                shared.ui_focus_widget_count = shared.ui_focus_widget_count + 1
            end
        end
    end
    -- The localization resolver may have queued options before their widgets
    -- revealed the question layout. Replace that batch with the actual prompt.
    shared.a11y.native_speech_queue, shared.a11y.native_speech_first, shared.a11y.native_speech_last = {},1,0
    shared.a11y.modal_message_backlog = {}
    shared.a11y.pending_modal_button_text, shared.a11y.deferred_modal_announcement = nil,nil
    shared.recent_message_text, shared.recent_message_widget_key, shared.recent_message_frame = node.text,node.key,shared.frame
    shared.pending_message_text, shared.pending_message_key = node.text,node.key .. "\0" .. node.text
    shared.a11y.pending_message_widget_key = node.key
    shared.a11y.pending_message_owner=shared.a11y.native_owner_token()
    shared.pending_message_due_ms = tonumber(ffi.C.GetTickCount64()) + 40
    shared.a11y.clear_pending_tooltips()
    shared.a11y.transition_old_focus_texts, shared.a11y.transition_old_focus_nodes = nil,nil
    log(string.format("[FLAccess] question-panel owner=%s widget=%s",tostring(node.owner_link),node.key))
    return true
end

function shared.a11y.read_context_state()
    if not shared.a11y.read_context then shared.a11y.reset_read_context("initial") end
    return shared.a11y.read_context
end

function shared.a11y.open_read_dialog(text, key)
    local context = shared.a11y.read_context_state()
    if context.question == text and context.message_key == key then return end
    if context.message_key == key and context.question
            and text:sub(1, #context.question) == context.question then
        context.question = text
        if shared.a11y.text_asset_role(text) == "dialog" or text:match("%?$") then
            context.kind = "dialog"
        end
        return
    end
    local owners = context.message_key == key and context.answer_owners or nil
    local chain = shared.a11y.answer_chain
    if not owners and chain and chain.message_key == key
            and shared.frame - chain.frame <= 120 and shared.a11y.ui_model
            and chain.model_generation == shared.a11y.ui_model.generation then
        owners = chain.owners
    end
    shared.a11y.answer_chain = nil
    local baseline = {}
    for widget_key, entry in pairs(shared.ui_focus_widgets) do
        baseline[widget_key] = {text=entry.text, seen=entry.last_seen}
    end
    shared.a11y.reset_read_context("dialog")
    context = shared.a11y.read_context
    context.kind = (shared.a11y.text_asset_role(text) == "dialog" or text:match("%?$"))
        and "dialog" or "notice"
    context.question, context.message_key = text, key
    local native_owner=shared.a11y.native_owner_token()
    context.native_owner=native_owner ~= "" and native_owner or nil
    context.baseline = baseline
    context.answer_owners = owners or {}
    context.answer_queued = false
    context.expires_frame = shared.frame + 3600
    log(string.format("[FLAccess] reading-context kind=%s generation=%d", context.kind, context.generation))
end

function shared.a11y.set_read_title(text)
    shared.a11y.answer_chain = nil
    local context = shared.a11y.read_context_state()
    if context.native_dialog then return end
    if context.native_reading_panel and shared.a11y.reading_panel_is_current() then
        context.title=text
        return
    end
    if context.question or context.structural_question or context.structural_event then shared.a11y.reset_read_context("title") end
    context = shared.a11y.read_context_state()
    context.title, context.kind, context.pending_title = text, "menu", nil
end

function shared.a11y.set_read_help(text, label)
    local context = shared.a11y.read_context_state()
    if context.kind ~= "dialog" then
        context.help = {text=text, label=label, frame=shared.frame}
    end
end

function shared.a11y.commit_read_selection(text, identity, source, label, widget)
    local context = shared.a11y.read_context_state()
    if context.native_reading_panel and not shared.a11y.reading_panel_is_current() then
        shared.a11y.reset_read_context("reading-panel-selection-changed")
        context=shared.a11y.read_context_state()
    end
    if context.kind == "dialog" and source ~= "dialog-answer" then return false end
    if not text or text == "" or shared.is_noninteractive_text(text)
            or text == "No String" then return false end
    if context.pending_title then
        local title = context.pending_title
        shared.a11y.set_read_title(title)
        context = shared.a11y.read_context_state()
        shared.speak(title)
        shared.a11y.title_pending_first_item = title
        shared.a11y.title_pending_first_item_until_ms = tonumber(ffi.C.GetTickCount64()) + 2000
    end
    if context.selection and context.selection.identity ~= identity then
        context.selection_result=nil
        if context.help and context.help.label ~= label then context.help = nil end
        context.cursor = 1
    end
    context.selection = {text=text, identity=identity, source=source, label=label, frame=shared.frame,
        origin=widget and shared.a11y.capture_speech_origin(widget) or nil}
    if context.kind == "unknown" then context.kind = "menu" end
    return true
end

-- Producers supply observations; this boundary owns composition, review,
-- deduplication and delivery validity. Missing context is not a blank value.
function shared.a11y.selection_result(request)
    local address=request.widget or (request.row and request.row.label_widget)
    if address and not shared.a11y.native_presentation_ready(address) then return nil end
    local context=shared.a11y.read_context_state()
    if context.kind=="dialog" and request.source~="dialog-answer" then return nil end
    local key=address and memory.hex(address)
    local node=request.node or (key and shared.a11y.ui_model and shared.a11y.ui_model.nodes[key])
    if node and (shared.a11y.is_media_caption(node) or shared.a11y.is_menu_description(node)) then return nil end
    local row=request.row or (key and shared.a11y.control_for_widget(key))
    if row and not row.is_control and not request.row then row=nil end
    if request.text and not request.row then row=nil end
    local label=request.text or (row and row.label) or (node and node.text)
    if not label or shared.a11y.empty_selection_caption(label) or shared.a11y.unresolved_format(label) then return nil end
    -- A confirmed carousel caption owns selection; its incidental OK node
    -- must not interrupt the current league/club. Dialog answers are separate.
    if label=="OK" and request.source~="dialog-answer" and shared.a11y.native_list_has_focus()
            and shared.a11y.native_list_selection.text~="OK" then return nil end
    local value=row and row.value
    local music=shared.a11y.native_music_packet(node)
    local text=music and music.text or (row and shared.control_speech(row) or shared.a11y.engine_focus_speech(label,node))
    if request.text and not request.row then text=shared.a11y.engine_focus_speech(request.text,node) end
    if request.source=="dialog-answer" then
        text=label .. (shared.a11y.ui_language=="pt" and ", opção selecionada" or ", selected option")
    end
    if request.presentation then text=request.presentation end
    local assignment=shared.a11y.native_assignment_context(address)
    if assignment then text=shared.a11y.output_speech_text(text) .. ", " .. assignment.text end
    local spoken,page=shared.a11y.page_focus_speech(text,address)
    local owner=shared.a11y.native_owner_token()
    local identity=request.identity or (key and node and shared.a11y.engine_selection_identity(key,node)) or label
    local result={widget=address,key=key,node=node,row=row,label=label,value=value,
        text=text,spoken=spoken,page=page,assignment=assignment,music=music,owner=owner,generation=context.generation,
        source=request.source or "component",identity=identity,
        origin=address and shared.a11y.capture_speech_origin(address),
        value_origin=row and row.value_widget and shared.a11y.capture_speech_origin(row.value_widget),
        missing={}}
    result.roster=shared.a11y.native_player_roster_context(node)
    result.player_section=node and node.name and node.name:lower():find("playername",1,true)
        and ((result.roster and result.roster.section) or shared.a11y.player_component_section(node)) or nil
    result.caption_binding=address and shared.a11y.native_caption_selection_identity(address)
    if row and value==nil then result.missing[#result.missing+1]="value" end
    result.player_parts={}
    for _,part in ipairs(shared.a11y.player_row_details(node)) do
        result.player_parts[#result.player_parts+1]=shared.a11y.capture_speech_origin(part.address)
    end
    result.signature=shared.a11y.selection_result_signature(result)
    return result
end

function shared.a11y.selection_result_signature(result)
    return tostring(result.owner) .. ":" .. tostring(result.generation) .. ":"
        .. result.identity .. ":" .. result.text .. ":" .. (result.page and result.page.identity or "")
        .. ":" .. (result.assignment and result.assignment.identity or "")
        .. ":" .. (result.roster and result.roster.identity or "")
        .. ":" .. (result.caption_binding or "")
end

function shared.a11y.roster_navigation_speech(result,text)
    local previous=shared.a11y.last_roster_navigation
    if not result or not result.player_section or not previous
            or previous.owner~=result.owner or previous.generation~=result.generation
            or previous.section~=result.player_section then return text end
    local prefixes=shared.a11y.ui_language=="pt"
        and {starter="Titular. ",reserve="Reserva. ",unselected="Não relacionado. "}
        or {starter="Starter. ",reserve="Substitute. ",unselected="Not selected. "}
    local prefix=prefixes[result.player_section]
    local page=result.page and result.page.text .. ". " or ""
    if prefix and text:sub(1,#page+#prefix)==page .. prefix then
        return page .. text:sub(#page+#prefix+1)
    end
    return text
end

function shared.a11y.remember_roster_navigation(result)
    if not result then return end
    shared.a11y.last_roster_navigation=result and result.player_section and {
        owner=result.owner,generation=result.generation,section=result.player_section} or nil
end

function shared.a11y.selection_result_allowed(result)
    local context=shared.a11y.read_context_state()
    if context.generation~=result.generation or shared.a11y.native_owner_token()~=result.owner then return false end
    if not context.selection or context.selection.identity~=result.identity then return false end
    if context.selection_result and context.selection_result.signature~=result.signature then return false end
    if result.origin and not shared.a11y.speech_origin_allowed(result.origin) then return false end
    if result.value_origin and not shared.a11y.speech_origin_allowed(result.value_origin) then return false end
    for _,origin in ipairs(result.player_parts or {}) do
        if not shared.a11y.speech_origin_allowed(origin)
                or shared.a11y.read_native_rendered_text(origin.address)~=origin.text then return false end
    end
    for _,origin in ipairs({result.origin or false,result.value_origin or false}) do
        if origin and origin.text then
            local current=shared.a11y.read_native_rendered_text(origin.address)
            if current~=nil and current~=origin.text then return false end
        end
    end
    if result.row and (result.row.label~=result.label or result.row.value~=result.value) then return false end
    local current_page=shared.a11y.native_page_context(result.widget)
    if (result.page and result.page.identity or nil)~=(current_page and current_page.identity or nil) then return false end
    local music=shared.a11y.native_music_packet(result.node)
    if (result.music and result.music.signature or nil)~=(music and music.signature or nil) then return false end
    local assignment=shared.a11y.native_assignment_context(result.widget)
    if (result.assignment and result.assignment.identity or nil)~=(assignment and assignment.identity or nil) then return false end
    local roster=shared.a11y.native_player_roster_context(result.node)
    if (result.roster and result.roster.identity or nil)~=(roster and roster.identity or nil) then return false end
    if result.player_section and ((roster and roster.section) or shared.a11y.player_component_section(result.node))~=result.player_section then return false end
    if result.caption_binding~=(result.widget and shared.a11y.native_caption_selection_identity(result.widget)) then return false end
    if result.node and result.key and result.source=="engine-focus"
            and shared.a11y.engine_selection_identity(result.key,result.node)~=result.identity then return false end
    return true
end

function shared.a11y.deliver_selection_result(result,options)
    if not result or shared.a11y.keyboard_window then return false end
    options=options or {}
    local context=shared.a11y.read_context_state()
    local previous=context.selection_result
    if previous and previous.signature==result.signature
            and (previous.status=="queued" or previous.status=="delivered") and context.selection
            and context.selection.identity==result.identity then return true end
    if not shared.a11y.commit_read_selection(result.text,result.identity,result.source,result.label,result.widget) then return false end
    -- commit may open a pending title; bind to the resulting context generation.
    context=shared.a11y.read_context_state()
    result.generation=context.generation
    result.signature=shared.a11y.selection_result_signature(result)
    local before=shared.a11y.native_speech_last
    local spoken=options.value_only and result.value or result.spoken
    if not result.page and options.interrupt~=false then
        for index=shared.a11y.native_speech_first,shared.a11y.native_speech_last do
            local pending=shared.a11y.native_speech_queue[index]
            if pending and pending.page_context and not pending.selection_result
                    and shared.a11y.page_delivery_allowed(pending.page_context) then
                options.interrupt=false;break
            end
        end
    end
    result.attempt=previous and previous.signature==result.signature and (previous.attempt or 0)+1 or 1
    shared.speak(spoken,options.interrupt,options.modal,result.signature .. ":attempt=" .. tostring(result.attempt),result.widget)
    if shared.a11y.native_speech_last==before then
        local deferred=shared.a11y.deferred_speech
        if deferred and deferred.text==spoken and shared.a11y.deferred_modal_announcement==spoken then
            deferred.selection_result=result
            deferred.options={interrupt=false,value_only=options.value_only,modal=options.modal}
            context.selection_result=result
            result.status="deferred"
        end
        return false
    end
    context.selection_result=result
    result.status="queued"
    if result.page then shared.a11y.last_page_announcement=result.page.identity end
    if result.page then
        for index=shared.a11y.native_speech_first,before do
            local pending=shared.a11y.native_speech_queue[index]
            if pending and pending.page_context and not pending.selection_result
                    and pending.page_context.identity==result.page.identity then pending.superseded=true end
        end
    end
    for index=before+1,shared.a11y.native_speech_last do
        local entry=shared.a11y.native_speech_queue[index]
        entry.selection_result=result
        entry.page_context=result.page
    end
    log(string.format("[FLAccess] selection-result source=%s widget=%s label=%q value=%q missing=%q",
        result.source,tostring(result.widget),result.label,result.value or "",table.concat(result.missing,",")))
    return true
end

-- Deferral is still speech work: retain the same ownership/content evidence
-- rather than converting a composed selection into an unbound literal string.
function shared.a11y.defer_speech(text,identity,address)
    local context=shared.a11y.read_context_state()
    shared.a11y.deferred_modal_announcement=text
    shared.a11y.deferred_speech={text=text,identity=identity,owner=shared.a11y.native_owner_token(),
        generation=context.generation,selection_identity=context.selection and context.selection.identity,
        origin=address and shared.a11y.capture_speech_origin(address)}
end

function shared.a11y.drain_deferred_speech()
    local now=tonumber(ffi.C.GetTickCount64())
    if shared.pending_message_text or now<shared.modal_focus_hold_until_ms or now<(shared.a11y.screen_title_hold_until_ms or 0) then return false end
    local text,deferred=shared.a11y.deferred_modal_announcement,shared.a11y.deferred_speech
    shared.a11y.deferred_modal_announcement,shared.a11y.deferred_speech=nil,nil
    if not text then return false end
    local context=shared.a11y.read_context_state()
    local valid=deferred and deferred.text==text and deferred.owner==shared.a11y.native_owner_token()
        and deferred.generation==context.generation
        and (not deferred.selection_identity or (context.selection and context.selection.identity==deferred.selection_identity))
        and (not deferred.origin or shared.a11y.speech_origin_allowed(deferred.origin))
    if valid and deferred.origin and deferred.origin.text then
        local current=shared.a11y.read_native_rendered_text(deferred.origin.address)
        if current~=nil and current~=deferred.origin.text then valid=false end
    end
    if valid and deferred.selection_result then valid=shared.a11y.selection_result_allowed(deferred.selection_result) end
    if not valid then
        if deferred and deferred.selection_result then deferred.selection_result.status="discarded" end
        log("[FLAccess] deferred-speech-discard reason=context-or-content-changed")
        return false
    end
    if deferred.selection_result then return shared.a11y.deliver_selection_result(deferred.selection_result,deferred.options) end
    shared.speak(text,false,nil,deferred.identity,deferred.origin and deferred.origin.address)
    return true
end

-- Compatibility producers retain their established extraction. They submit
-- data here instead of bypassing the common validity and delivery decision.
function shared.a11y.offer_adapter_selection(text,identity,address,interrupt)
    return shared.a11y.deliver_selection_result(shared.a11y.selection_result({widget=address,
        text=text,presentation=text,identity=identity,source="adapter-focus"}),{interrupt=interrupt})
end

function shared.a11y.dialog_answer_candidate(key, entry, offset, activity)
    local context = shared.a11y.read_context_state()
    if context.kind ~= "dialog" or shared.frame > context.expires_frame
            or not entry or offset ~= 0x104
            or shared.pending_message_text or #shared.a11y.modal_message_backlog > 0 then return false end
    local role = shared.a11y.text_asset_role(entry.text)
    local scoped_node = shared.a11y.ui_model and shared.a11y.ui_model.nodes[key]
    if context.structural_event then
        local snapshot=shared.a11y.native_windows
        return scoped_node and scoped_node.key~=context.message_key and shared.is_modal_button(entry.text)
            and snapshot and snapshot.selected_members and snapshot.selected_members[tonumber(scoped_node.address)]
            and shared.a11y.native_presentation_ready(scoped_node.address)
            and scoped_node.owner_link==context.owner_link
    end
    if context.structural_question then
        local native=shared.a11y.native_confirmation_answer(scoped_node)
        return scoped_node and (native or not context.native_dialog and scoped_node.owner_link == context.owner_link and scoped_node.name == "text")
            and not shared.is_noninteractive_text(entry.text) and role ~= "technical" and role ~= "status"
            and (native or entry.last_seen >= context.started_frame or context.answer_owners[key] == scoped_node.identity)
    end
    if key == context.message_key or entry.text == context.question
            or role == "dialog" or role == "instruction" or role == "tooltip-or-description"
            or shared.is_noninteractive_text(entry.text) or shared.is_splash_text(entry.text) then return false end
    local previous = context.baseline[key]
    local changed = previous and previous.text ~= entry.text
    local introduced = not previous
    local fresh_edge = activity and activity >= context.started_frame
    local node = shared.a11y.ui_model and shared.a11y.ui_model.nodes[key]
    local owned = node and context.answer_owners[key] == node.identity
    local engine=shared.a11y.engine_focus
    local live_event=engine and engine.nodes[key]
    local native_focus=node and context.native_owner and engine
        and engine.owner==context.native_owner and shared.a11y.native_owner_token()==context.native_owner
        and live_event and live_event.edge>=context.started_frame
        and live_event.edge==activity and shared.a11y.native_widget_allowed(node.address)
    -- A background row may redraw with the dialog. Redraw alone is not an
    -- answer; require the primary selection edge or a newly introduced row.
    if not introduced and not changed and not fresh_edge and not owned then return false end
    if entry.last_seen < context.started_frame and not owned and not native_focus then return false end
    if role == "technical" or role == "status" then return false end
    return true
end

function shared.a11y.announce_read_answer(key, entry, offset, activity)
    if not shared.a11y.dialog_answer_candidate(key, entry, offset, activity) then return false end
    local context = shared.a11y.read_context
    local identity = tostring(context.generation) .. ":" .. shared.a11y.ui_focus_identity(key, entry.text)
    local text = entry.text .. (shared.a11y.ui_language == "pt" and ", opção selecionada" or ", selected option")
    shared.a11y.commit_read_selection(text, identity, "dialog-answer")
    context.selection.widget_key = key
    local node = shared.a11y.ui_model and shared.a11y.ui_model.nodes[key]
    if node then context.answer_owners[key] = node.identity end
    if context.structural_question and (shared.a11y.navigation_frame or -1) < context.started_frame then return true end
    if context.last_answer ~= identity then
        local queue = not context.answer_queued and tonumber(ffi.C.GetTickCount64()) < shared.modal_focus_hold_until_ms
        local before=shared.a11y.native_speech_last
        shared.a11y.deliver_selection_result(shared.a11y.selection_result({text=entry.text,widget=node and node.address,
            identity=identity,source="dialog-answer"}),{interrupt=not queue,modal=true})
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].reading_selection={generation=context.generation,identity=identity}
        end
        if shared.a11y.native_speech_last>before then
            context.last_answer, context.answer_queued = identity, true
        end
    end
    return true
end

function shared.a11y.reading_panel_is_current()
    local context=shared.a11y.read_context
    local snapshot=shared.a11y.native_windows
    local node=context and context.message_key and shared.a11y.ui_model and shared.a11y.ui_model.nodes[context.message_key]
    return context and context.native_reading_panel and context.native_owner==shared.a11y.native_owner_token()
        and node and snapshot and snapshot.members and snapshot.members[tonumber(node.address)]
        and snapshot.members[tonumber(node.address)].presented~=false
        and context.native_reading_panel==context.native_owner .. ":" .. node.identity .. ":" .. node.text
        and shared.a11y.native_presentation_ready(node.address) and shared.a11y.ui_node_matches_live(node)
end

function shared.a11y.capture_reading_panel(node)
    local snapshot=shared.a11y.native_windows
    local address=node and tonumber(node.address)
    if not node or node.name~="text_contents" or not node.text or node.text==""
            or shared.a11y.unresolved_format(node.text) or not snapshot or not snapshot.selected_members or not snapshot.selected_members[address]
            or not shared.a11y.native_presentation_ready(address) or not shared.a11y.ui_node_matches_live(node) then return false end
    local count=0
    for selected in pairs(snapshot.selected_members) do
        local other=shared.a11y.ui_model.nodes[memory.hex(selected)]
        if other and other.name=="text_contents" and shared.a11y.native_presentation_ready(selected) then count=count+1 end
    end
    if count~=1 then return false end
    local context=shared.a11y.read_context_state()
    if context.structural_question or context.structural_event then return false end
    local owner=shared.a11y.native_owner_token()
    if not owner or owner=="" then return false end
    local identity=owner .. ":" .. node.identity .. ":" .. node.text
    if context.native_reading_panel==identity then return true end
    local changing=context.native_reading_panel~=nil
    local title=context.title
    shared.reset_message_state()
    shared.a11y.reset_read_context("native-reading-panel")
    context=shared.a11y.read_context_state()
    context.kind,context.question,context.message_key="notice",node.text,node.key
    context.native_owner,context.native_reading_panel,context.title=owner,identity,title
    shared.modal_focus_hold_until_ms=0
    shared.a11y.clear_pending_tooltips()
    shared.speak(node.text,changing,true,identity,node.address)
    return true
end

function shared.a11y.poll_notice_actions()
    local context=shared.a11y.read_context_state()
    local node=context.message_key and shared.a11y.ui_model and shared.a11y.ui_model.nodes[context.message_key]
    local snapshot=shared.a11y.native_windows
    local bar=snapshot and snapshot.command_bar
    local message=node and snapshot and snapshot.members[tonumber(node.address)]
    if not context.question or not message or not bar then shared.a11y.notice_actions=nil;return end
    local identity=tostring(context.generation) .. ":" .. tostring(context.question) .. ":" .. tostring(shared.a11y.native_owner_token())
    if shared.a11y.notice_actions==identity then return end
    local count=0
    for _,pair in ipairs(bar.pairs or {}) do
        local member=snapshot.members[pair.caption]
        local same=false
        for _,owner in ipairs(member and member.owners or {}) do
            for _,other in ipairs(message.owners or {}) do
                if owner.enabled and other.enabled and owner.address==other.address and owner.root==other.root then same=true end
            end
        end
        local text=same and shared.a11y.read_native_rendered_text(pair.caption)
        if text and text~="" and not shared.a11y.unresolved_format(text) and shared.a11y.native_presentation_ready(pair.caption) then
            shared.speak(text,false,true,"notice-action:" .. identity .. ":" .. pair.caption,pair.caption)
            count=count+1
            if count>=4 then break end
        end
    end
    if count>0 then shared.a11y.notice_actions=identity end
end

function shared.a11y.process_read_dialog_focus(candidates)
    local context = shared.a11y.read_context_state()
    if context.kind ~= "dialog" then return false end
    if not context.structural_question and not context.structural_event
            and shared.a11y.native_control_help(context.question) then
        local help=context.question
        shared.reset_message_state()
        shared.a11y.reset_read_context("native-field-help")
        shared.a11y.set_read_help(help)
        shared.modal_focus_hold_until_ms=0
        return false
    end
    if shared.frame > context.expires_frame then
        shared.a11y.reset_read_context("dialog-expired")
        return false
    end
    local selected, reason = shared.a11y.resolve_primary_focus(candidates)
    local entry = selected and (shared.ui_focus_widgets[selected.key]
        or (shared.a11y.ui_model and shared.a11y.ui_model.nodes[selected.key]))
    if not selected or not shared.a11y.dialog_answer_candidate(selected.key, entry, 0x104, selected.edge) then
        context.candidate = nil
        local unresolved = shared.pending_message_text and "message-pending"
            or (selected and "context-ownership-unproven" or reason)
        if unresolved ~= context.unresolved_reason then
            context.unresolved_reason = unresolved
            log(string.format("[FLAccess] dialog-selection-unresolved reason=%s candidates=%d", unresolved, #candidates))
        end
        return true
    end
    local identity = shared.a11y.ui_focus_identity(selected.key, entry.text)
    if identity ~= context.candidate then
        context.candidate, context.candidate_frame = identity, shared.frame
    elseif shared.frame - context.candidate_frame >= 4 then
        shared.a11y.announce_read_answer(selected.key, entry, 0x104, selected.edge)
    end
    if shared.a11y.ui_model then shared.a11y.ui_model.focus_reason = "dialog:" .. reason end
    return true
end

function shared.a11y.entity_review_entries(nodes)
    local item=shared.a11y.native_list_selection
    local snapshot=shared.a11y.native_windows
    local owner=shared.a11y.native_owner_token()
    if shared.a11y.keyboard_window or shared.a11y.read_context_state().kind=="dialog" then return nil end
    local selection=shared.a11y.read_context_state().selection
    if selection and selection.origin and item and selection.origin.address~=item.widget then return nil end
    if not item or not owner or item.committed~=owner .. ":" .. item.identity .. ":" .. item.text
            or shared.a11y.widget_internal_name(item.widget)~="teamName"
            or shared.a11y.read_native_rendered_text(item.widget)~=item.text then return nil end
    local selected=snapshot and snapshot.members and snapshot.members[item.widget]
    if not selected or not selected.active then return nil end
    local anchor=shared.a11y.ui_model.nodes[memory.hex(item.widget)]
    local review={nodes={anchor},anchor=anchor,identity=item.committed,list_identity=item.committed}
    local windows={}
    for _,entry in ipairs(selected.owners or {}) do if entry.enabled then windows[entry.address]=true end end
    local players,roots={},{}
    local function belongs(node,root)
        local member=snapshot.members[tonumber(node.address)]
        for _,entry in ipairs(member and member.owners or {}) do
            if entry.enabled and windows[entry.address] and (not root or entry.root==root) then return entry.root end
        end
    end
    for _,node in ipairs(nodes) do
        if node.name and (node.name=="playerName" or node.name:match("^playerName_")) then
            local root=belongs(node)
            if root then roots[root]=true;players[#players+1]=node end
        end
    end
    if #players==0 then return {item.text},review end
    local root
    for value in pairs(roots) do if root then return {item.text},review end;root=value end
    local heading
    for _,node in ipairs(nodes) do
        if (node.name=="text_title" or node.name=="title" or node.name=="listHeader" or node.name=="header")
                and belongs(node,root) then
            if heading and heading.text~=node.text then heading=false;break end
            heading=node
        end
    end
    local result,seen={item.text},{[item.text]=true}
    if heading and not seen[heading.text] then
        result[#result+1],seen[heading.text]=heading.text,true
        review.nodes[#result]=heading
    end
    for _,node in ipairs(players) do
        if not shared.a11y.empty_selection_caption(node.text) then
            result[#result+1]=node.text
            review.nodes[#result]=node
        end
    end
    return result,review
end

-- Review a player list through the same indexed rows as its native cursor.
-- Repeated names stay separate; a detail panel or a second team cannot join it.

    shared.stage = 5
end
function component.init(ctx)
    component.install(ctx)

end
return component
