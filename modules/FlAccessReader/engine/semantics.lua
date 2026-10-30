local function is_screen_title(text, widget)
    local role = a11y.text_asset_role(text)
    local widget_name = widget and a11y.widget_internal_name(widget) or nil
    if (widget_name == "title" or widget_name == "text_title")
            and #text <= 80 and not text:find("%", 1, true)
            and role ~= "control" and role ~= "dialog-button"
            and role ~= "status" and role ~= "technical"
            and not looks_like_message(text) then
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

local function announce_screen_title(text, widget_key, widget)
    local source=widget and a11y.ui_model and a11y.ui_model.nodes[memory.hex(widget)]
    if source and a11y.is_media_caption(source) then return end
    local language=a11y.native_language_context()
    if language and a11y.native_language_heading(widget)==language.label then
        a11y.poll_native_language();return
    end
    text=a11y.native_language_heading(widget) or text
    if not is_screen_title(text, widget) then
        return
    end
    local panel=a11y.read_context_state()
    if panel.native_reading_panel and panel.title==text and a11y.reading_panel_is_current() then return end
    if widget and not a11y.native_presentation_ready(widget) then
        a11y.defer_bound_guidance(widget,text)
        return
    end
    local title_name = widget and a11y.widget_internal_name(widget)
    local title_role = a11y.text_asset_role(text)
    if (title_name == "title" or title_name == "text_title")
            and (not title_role or title_role == "label-or-name") then
        -- An unknown overlay caption must not reset a working menu. Keep it
        -- pending only after an independently recognized context boundary.
        local member=a11y.native_windows and a11y.native_windows.members and a11y.native_windows.members[tonumber(widget)]
        if a11y.read_context_state().kind == "unknown" and member and (member.active or member.presented) then
            a11y.read_context.pending_title = text
        end
        return
    end
    if title_name == "title" or title_name == "text_title" then
        -- A caption is presentation, not proof of a new native scene. A late
        -- title must never erase controls already observed in that scene.
        if a11y.ui_model then a11y.ui_model.surface = text end
        -- A real submenu title ends the horizontal pre-match action reader.
        -- Its background System Settings caption may still be rendered.
        a11y.pre_match_active = false
        a11y.pre_match_entry_pending = false
    end
    a11y.transition_old_focus_texts = nil
    a11y.transition_guard_until_ms = 0
    -- Returning from group assignment to team selection ends the table mode.
    a11y.cup_group_table_active = false
    a11y.set_read_title(text)
    a11y.screen_title_hold_until_ms =
        tonumber(ffi.C.GetTickCount64()) + 500
    local key = text
    if key ~= last_screen_title_key
            or frame - a11y.last_screen_title_frame > 120 then
        last_screen_title_key = key
        a11y.last_screen_title_frame = frame
        a11y.title_pending_first_item = nil
        speak(text,not a11y.read_context_state().native_reading_panel,nil,nil,widget)
        a11y.title_pending_first_item = text
        a11y.title_pending_first_item_until_ms =
            tonumber(ffi.C.GetTickCount64()) + 2000
    end
end

function a11y.announce_skip_hint(text, node)
    if not text or frame - a11y.skip_hint_last_frame < 300
            or not a11y.game_is_foreground() then
        return false
    end
    local lower = text:lower()
    if node and (text == "Pular" or text == "Skip") then
        if not a11y.pending_skip_hint or a11y.pending_skip_hint.key ~= node.key then
            a11y.pending_skip_hint = {owner=node.owner_link,key=node.key,started=frame,
                text=text,native_owner=a11y.native_owner_token()}
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
    a11y.skip_hint_last_frame = frame
    -- Preserve the game's wording rather than inventing an instruction.
    local spoken=text:gsub("<Pular>","Pular"):gsub("<Skip>","Skip")
    speak(spoken,nil,nil,nil,node and node.address)
    return true
end

function a11y.spoken_control_icon(text)
    return text and (text:find("botão",1,true) or text:find("button",1,true)
        or text:find("tecla ",1,true) or text:find("key ",1,true)
        or text=="Options" or text=="Start" or text=="Menu" or text=="Esc" or text=="Enter")
end

function a11y.command_icon_for_node(source)
    local snapshot=a11y.native_windows
    -- GuideBar pairs follow the indexed nodes used by its presentation
    -- routine. They need not be sibling UI nodes.
    local bound_button
    for _,pair in ipairs(snapshot and snapshot.command_bar and snapshot.command_bar.pairs or {}) do
        if source and pair.caption==tonumber(source.address)
                and a11y.native_widget_allowed(pair.icon) and a11y.native_widget_allowed(pair.caption) then
            local caption=a11y.read_native_rendered_text(pair.caption)
            local icon=a11y.read_native_rendered_text(pair.icon)
            if caption==source.text and a11y.spoken_control_icon(icon) then
                if bound_button and bound_button~=icon then return nil end
                bound_button=icon
            end
        end
    end
    if bound_button then return bound_button end
    local member=source and snapshot and snapshot.members[tonumber(source.address)]
    if not member or not member.active then return nil end
    local nodes=a11y.presented_nodes()
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
                            if a11y.spoken_control_icon(node.text) then button=node.text end
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

function a11y.poll_skip_hint()
    local hint = a11y.pending_skip_hint
    if not hint then return end
    if hint.native_owner and hint.native_owner ~= a11y.native_owner_token() then
        a11y.pending_skip_hint=nil
        return
    end
    if not a11y.native_key_allowed(hint.key) then a11y.pending_skip_hint=nil; return end
    local button,ambiguous
    local source=a11y.ui_model and a11y.ui_model.nodes[hint.key]
    for _, node in pairs(a11y.ui_model and a11y.ui_model.nodes or {}) do
        local peers=source and a11y.component_peers(source.address,node.address)
        if (peers==true or (peers==nil and hint.owner and node.owner_link==hint.owner))
                and node.name == "padIcon" and a11y.ui_node_matches_live(node)
                and a11y.native_widget_allowed(node.address)
                and a11y.spoken_control_icon(node.text) then
            if button and button ~= node.text then ambiguous=true end
            button=node.text
        end
    end
    if ambiguous then button=nil end
    if not button and not ambiguous then button=a11y.command_icon_for_node(source) end
    if not button then
        if frame-hint.started < 12 then return end
        if not hint.label_spoken then
            hint.label_spoken=true
            local source=a11y.ui_model and a11y.ui_model.nodes[hint.key]
            speak(hint.text or (source and source.text),nil,nil,nil,source and source.address)
            a11y.component_evidence(source,"skip-button-unresolved")
            local parts={}
            for _,node in pairs(a11y.ui_model and a11y.ui_model.nodes or {}) do
                if node.name=="padIcon" and #parts<8 and a11y.native_widget_allowed(node.address) then
                    local _,native_raw,native_font=a11y.read_native_rendered_text(node.address)
                    parts[#parts+1]=string.format("%s raw=%q font=%s",node.key,
                        native_raw or node.raw_text or node.text or "",tostring(native_font or node.native_font))
                end
            end
            log("[FLAccess] skip-icon-unresolved widget=" .. hint.key .. " ambiguous=" .. tostring(ambiguous)
                .. " font-family=" .. tostring(a11y.control_font_family) .. " icons=" .. table.concat(parts," | "))
        end
        if frame-hint.started>120 then a11y.pending_skip_hint=nil end
        return
    end
    a11y.pending_skip_hint = nil
    if frame - a11y.skip_hint_last_frame < 300 then return end
    a11y.skip_hint_last_frame = frame
    local source=a11y.ui_model and a11y.ui_model.nodes[hint.key]
    speak((hint.text or (source and source.text) or "") .. ", " .. button,
        nil,nil,nil,source and source.address)
end

local function enqueue_startup_speech(text, duration_ms)
    if not text or text == "" or startup_speech.seen[text] then
        return
    end
    startup_speech.seen[text] = true
    startup_speech.last = startup_speech.last + 1
    startup_speech.queue[startup_speech.last] = {
        text = text,
        duration_ms = duration_ms or 1000,
    }
end

local function queue_startup_text(text, now_ms)
    local lower = text:lower()
    if lower:find("edit file", 1, true) then
        startup_speech.version = text
        startup_speech.version_due_ms = now_ms + 5000
        return true
    end
    if lower:find("smokepatch", 1, true)
            or lower:find("smoke patch", 1, true) then
        if startup_speech.version and not startup_speech.version_queued then
            enqueue_startup_speech(startup_speech.version, 1500)
            startup_speech.version_queued = true
        end
        return true
    end
    if is_plain_text(text) and not startup_complete then
        if startup_speech.version and not startup_speech.version_queued then
            enqueue_startup_speech(startup_speech.version, 1500)
            startup_speech.version_queued = true
        end
        enqueue_startup_speech(text, 900)
        return true
    end
    return false
end

local function process_startup_speech(now_ms)
    if startup_speech.version and not startup_speech.version_queued
            and startup_speech.version_due_ms
            and now_ms >= startup_speech.version_due_ms then
        enqueue_startup_speech(startup_speech.version, 1500)
        startup_speech.version_queued = true
    end
    if now_ms < startup_speech.next_ms then
        return true
    end
    local item = startup_speech.queue[startup_speech.first]
    if item then
        startup_speech.queue[startup_speech.first] = nil
        startup_speech.first = startup_speech.first + 1
        speak(item.text)
        startup_speech.next_ms = now_ms + item.duration_ms
        return true
    end
    return false
end

local function selector_role(label)
    if label == "Nome do treinador" or label == "Manager Name" or label == "Coach Name" then
        return "ativar para editar"
    end
    if label == "Nome dos ajustes" then
        return "campo de texto"
    end
    return "seletor"
end

local function control_speech(row)
    local spoken = row.label .. ", " .. (row.role or selector_role(row.label))
    if row.value and row.value ~= "" then
        spoken = spoken .. ", " .. row.value
    end
    return spoken
end

function a11y.track_control_focus(key)
    local row = a11y.control_for_widget(key)
    local owner = row or key
    if a11y.control_focus_owner ~= owner then
        a11y.control_focus_owner = owner
        last_controller_announcement, last_announced_control_row = nil, nil
        last_announced_selector_label = nil
    end
end

function a11y.secondary_focus_is_current(key, index)
    local model = a11y.ui_model
    local edge = ui_focus_activated[key] and ui_focus_activated[key][index] or -1
    return not model or not model.last_primary_edge or edge >= model.last_primary_edge
end

-- Investigation only: bounded observations, never used as visibility or focus authority.
function a11y.capture_focus_trace(stage)
    if not a11y.diagnostic_mode then return end
    local trace = a11y.focus_trace
    if not trace or not a11y.sider_dir or (trace.bytes or 0) >= 2097152 then return end
    local lines = {string.format("TRACE input=%d frame=%d stage=%s action=%s generation=%s reason=%s",
        trace.sequence, frame, stage, tostring(trace.action),
        tostring(a11y.ui_model and a11y.ui_model.generation),
        tostring(a11y.ui_model and a11y.ui_model.focus_reason))}
    local generation = a11y.ui_model and a11y.ui_model.generation
    if trace.sample_generation ~= generation then
        trace.samples, trace.owner_samples, trace.sample_generation = {}, {}, generation
    end
    trace.samples = trace.samples or {}
    local nodes = {}
    for _, node in pairs(a11y.ui_model and a11y.ui_model.nodes or {}) do nodes[#nodes + 1] = node end
    table.sort(nodes, function(left, right) return left.sequence > right.sequence end)
    for position, node in ipairs(nodes) do
        if position > 80 then break end
        if readable(node.address, 0x180) then
            local bytes = memory.read(node.address, 0x180)
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
                local row = a11y.control_for_widget(node.key)
                if not previous or #fields > 0 or previous.text ~= node.text then
                lines[#lines + 1] = string.format("node=%s identity=%s name=%q text=%q age=%d control=%s fields={%s}",
                    node.key, node.identity, node.name or "", node.text or "", frame-node.last_seen,
                    row and control_speech(row) or "none", table.concat(fields, ","))
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
            if readable(owner, 0x100) then
                local bytes = memory.read(owner, 0x100)
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
    local file = io.open(a11y.sider_dir .. "\\FLAccess-focus-trace.log", trace.started and "at" or "wt")
    if not file then return end
    file:write(output); file:close()
    trace.started, trace.bytes = true, (trace.bytes or 0) + #output
end

function a11y.begin_focus_trace(action)
    if not a11y.diagnostic_mode then return end
    local trace = a11y.focus_trace or {sequence=0, bytes=0}
    if trace.sequence >= 120 or trace.bytes >= 2097152 then return end
    trace.sequence, trace.action, trace.input_frame = trace.sequence + 1, action, frame
    trace.followups = {frame + 4, frame + 12}
    a11y.focus_trace = trace
    a11y.capture_focus_trace("input")
end

function a11y.poll_focus_trace()
    if not a11y.diagnostic_mode then a11y.focus_trace=nil;return end
    local trace = a11y.focus_trace
    if not trace or not trace.followups then return end
    while trace.followups[1] and frame >= trace.followups[1] do
        local due = table.remove(trace.followups, 1)
        a11y.capture_focus_trace("after-" .. tostring(due - trace.input_frame))
    end
end

-- Structured, opt-in evidence. These records never grant speech authority.
-- Capture changes throughout a session, not only its first 120 inputs.
function a11y.start_component_capture(path)
    local file=path and io.open(path,"wt")
    if not file then return false end
    file:write("FLACCESS_COMPONENTS format=1 build=",tostring(a11y.build),
        " started=",os.date("!%Y-%m-%dT%H:%M:%SZ"),"\n")
    file:close()
    a11y.component_capture={active=true,path=path,bytes=0,sequence=0,nodes={},parents={}}
    return true
end

function a11y.start_armed_component_capture()
    if not a11y.sider_dir then return false end
    local marker=a11y.sider_dir .. "\\FLAccess-components.capture"
    local file=io.open(marker,"rt")
    if not file then return false end
    local armed=file:read("*l")=="armed"
    file:close()
    if not armed or not a11y.start_component_capture(a11y.sider_dir .. "\\FLAccess-components.log") then return false end
    file=io.open(marker,"wt")
    if not file then a11y.component_capture.active=false; return false end
    file:write("consumed\n");file:close()
    log("[FLAccess] component-capture=started policy=changes-only one-session")
    return true
end

function a11y.component_capture_lines(capture)
    local snapshot=a11y.native_windows
    local owner=a11y.native_owner_token() or ""
    local lines,ordered,parents={}, {}, {}
    local generation=a11y.ui_model and a11y.ui_model.generation
    if capture.owner~=owner or capture.generation~=generation then
        capture.owner,capture.generation,capture.nodes,capture.parents=owner,generation,{},{}
    end
    lines[#lines+1]=string.format("SNAP sequence=%d frame=%d owner=%q generation=%s reason=%q action=%q keyboard=%s font=%s base=%s",
        capture.sequence,frame,owner,tostring(a11y.ui_model and a11y.ui_model.generation),
        a11y.ui_model and a11y.ui_model.focus_reason or "",a11y.diagnostic_last_input_action or "",
        tostring(a11y.keyboard_window),tostring(a11y.control_font_family),tostring(tonumber(process_base_u64)))
    for _,window in ipairs(snapshot and snapshot.windows or {}) do
        local d=window.cursor_detail or {}
        lines[#lines+1]=string.format("WINDOW address=%s root=%s input=%s selected=%s group=%s index=%s status=%q owned_roots=%q type=%s impl=%s presentation=%s task_parent=%s task_child=%s",
            tostring(window.address),tostring(window.root),tostring(window.enabled),tostring(d.selected),
            tostring(d.group),tostring(d.item_index),d.status or "no-cursor",table.concat(window.owned_roots or {},","),
            tostring(a11y.menu_read(window.address,"u64")),tostring(window.impl),
            tostring(window.impl and a11y.menu_read(window.impl+0x90,"u64")),
            tostring(a11y.menu_read(window.address+0x38,"u64")),
            tostring(a11y.menu_read(window.address+0x40,"u64")))
        for _,item in ipairs(window.tree_evidence and window.tree_evidence.frontier or {}) do
            lines[#lines+1]="FRONTIER window=" .. tostring(window.address) .. " address=" .. tostring(item.address)
                .. " rva=" .. tostring(item.rva) .. " fields=" .. a11y.native_node_summary(item.address)
        end
    end
    for _,line in ipairs(a11y.component_link_capture_lines(snapshot)) do lines[#lines+1]=line end
    local list=a11y.native_list_selection
    if list then
        lines[#lines+1]=string.format("LIST widget=%s identity=%q text=%q observed=%s committed=%s",
            tostring(list.widget),list.identity or "",a11y.diagnostic_text(list.text),tostring(list.observed),tostring(list.committed))
    end
    for key,node in pairs(a11y.ui_model and a11y.ui_model.nodes or {}) do
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
        local bound=a11y.control_for_widget(item.key)
        local provisional=control_rows_by_label_widget[item.key]
        local event=a11y.engine_focus and a11y.engine_focus.nodes and a11y.engine_focus.nodes[item.key]
        local text,raw,font=a11y.read_native_rendered_text(address)
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
            item.key,tostring(node.identity),tostring(a11y.menu_read(address,"u64")),
            tostring(a11y.menu_read(address+0xc,"u32")),tostring(a11y.menu_read(address+0x104,"u32")),
            tostring(event and event.edge),node.name or "",a11y.diagnostic_text(node.text),
            a11y.diagnostic_text(text),tostring(text~=nil),a11y.diagnostic_text(raw or node.raw_text),raw_hex,tostring(font or node.native_font),
            member and (member.active and "input-owner" or member.presented and "context-owner" or "inactive-owner") or "unknown",
            tostring(item.selected),bound and a11y.diagnostic_text(bound.label) or "",
            bound and a11y.diagnostic_text(bound.value) or "",
            bound and (bound.native_field and "native-field" or bound.structural and "named-pair" or "provisional") or "none",
            provisional and a11y.diagnostic_text(provisional.label) or "",
            tostring(node.owner_link),tostring(a11y.menu_read(address+0x40,"u64")),
            tostring(a11y.menu_read(address+0x50,"u64")),table.concat(path,">"))
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
        local line="PARENT address=" .. tostring(at) .. " name=" .. string.format("%q",a11y.widget_internal_name(at) or "")
            .. " flags=" .. tostring(a11y.menu_read(at+0xc,"u32"))
            .. " focus104=" .. tostring(a11y.menu_read(at+0x104,"u32"))
            .. " fields=" .. a11y.native_node_summary(at)
        if capture.parents[at]~=line then lines[#lines+1]=line;capture.parents[at]=line end
    end
    lines[#lines+1]="END sampled=" .. tostring(math.min(#ordered,128)) .. " total=" .. tostring(#ordered)
    return lines
end

function a11y.poll_component_capture()
    local capture=a11y.component_capture
    if not capture or not capture.active or frame-(capture.last_poll or -10000)<12 then return end
    capture.last_poll=frame
    local signature=(a11y.native_owner_token() or "") .. ":" .. tostring(a11y.component_capture_dirty_frame)
        .. ":" .. tostring(a11y.diagnostic_last_input_frame)
        .. ":" .. tostring(a11y.native_cursor_identity)
        .. ":" .. tostring(a11y.ui_model and a11y.ui_model.generation)
    if signature==capture.signature then
        if not capture.followup_due or frame<capture.followup_due then return end
        capture.followup_due=nil
    else
        capture.signature=signature
        capture.followup_due=frame+36
    end
    capture.sequence=capture.sequence+1
    local output=table.concat(a11y.component_capture_lines(capture),"\n") .. "\n"
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

local function announce_control(row)
    if a11y.keyboard_window then return end
    if not row or not row.label then
        return
    end
    if row.label_widget and not a11y.native_presentation_ready(row.label_widget) then return end
    if a11y.read_context_state().kind == "dialog" then return end
    local spoken = control_speech(row)
    local result=a11y.selection_result({row=row,source="control",
        identity=row.identity or row.label_widget_key or row.label})
    if not result then return end
    local page=result.page
    if spoken ~= last_controller_announcement or (page and page.identity~=a11y.last_page_announcement)
            or last_announced_control_row ~= row
            or not a11y.read_context_state().selection_result
            or a11y.read_context_state().selection_result.status=="discarded"
            or a11y.read_context_state().selection_result.status=="failed"
            or a11y.read_context_state().selection_result.signature~=result.signature then
        if active_control_row ~= row then
            last_spoken_controller_tooltip_key = nil
            pending_controller_tooltip = nil
            pending_controller_tooltip_label = nil
            controller_tooltip_due_ms = nil
        end
        last_controller_announcement = spoken
        last_announced_control_row = row
        last_announced_selector_label = row.label_widget_key or row.label
        active_control_row = row
        active_controller_label = row.label
        active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
        if a11y.read_tooltips and latest_generic_tooltip
                and latest_generic_tooltip_widget ~= row.label_widget
                and active_control_focused_ms - latest_generic_tooltip_ms <= 1000 then
            pending_controller_tooltip = latest_generic_tooltip
            pending_controller_tooltip_label = row.label
            controller_tooltip_due_ms = active_control_focused_ms
        end
        if not a11y.deliver_selection_result(result) then
            -- A temporary modal hold is not a delivered control announcement.
            last_controller_announcement,last_announced_control_row=nil,nil
        end
    end
end

local function announce_control_value(row, value)
    if not row or not value or value == "" then
        return
    end
    if a11y.read_context_state().kind == "dialog" then return end
    row.value = value
    if a11y.keyboard_window then return end
    local full = control_speech(row)
    if row.label_widget and not a11y.native_widget_allowed(row.label_widget) then return end
    local result=a11y.selection_result({row=row,source="control",
        identity=row.identity or row.label_widget_key or row.label})
    if not result then return end
    if full == last_controller_announcement
            and last_announced_control_row == row then
        return
    end
    last_controller_announcement = full
    last_announced_control_row = row
    local row_key = row.label_widget_key or row.label
    if active_control_row == row and last_announced_selector_label == row_key then
        a11y.deliver_selection_result(result,{value_only=true})
    else
        active_control_row = row
        last_announced_selector_label = row_key
        a11y.deliver_selection_result(result)
    end
end

local function reset_stadium_screen()
    a11y.stadium_value_index_by_widget = {}
    a11y.stadium_rows = {}
    a11y.stadium_started_frame = frame
end

local function stadium_value_category(text)
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

local function stadium_control_for_entry(widget_key, entry)
    if not a11y.stadium_active or not widget_key or not entry then
        return nil
    end
    local index = a11y.stadium_value_index_by_widget[widget_key]
    if not index then
        index = stadium_value_category(entry.text)
        if index and a11y.stadium_rows[index]
                and a11y.stadium_rows[index].value_widget_key ~= widget_key then
            index = nil
        end
    end
    if not index and not a11y.stadium_rows[1] then
        -- The first focused value after opening this screen is the stadium.
        -- Unlike the remaining values, its text is an arbitrary stadium name.
        index = 1
    end
    if not index then
        -- "Aleatório" and "Normal" are shared by several rows. Assign a new
        -- value widget by the screen's verified top-to-bottom order and keep
        -- that ownership while its text changes laterally.
        for candidate = 2, 5 do
            if not a11y.stadium_rows[candidate] then
                index = candidate
                break
            end
        end
    end
    if not index then
        return nil
    end
    a11y.stadium_value_index_by_widget[widget_key] = index
    local labels = stadium_labels[a11y.ui_language] or stadium_labels.en
    local row = a11y.stadium_rows[index]
    if not row then
        row = {
            label = labels[index],
            role = "seletor",
            label_widget_key = "stadium:" .. tostring(index),
            value_widget_key = widget_key,
            is_control = true,
        }
        a11y.stadium_rows[index] = row
    end
    row.value_widget_key = widget_key
    row.value = entry.text
    return row
end

local function announce_controller_row(label, value)
    if not label then
        return
    end
    local row = controller_rows[label]
    if not row then
        row = {label = label, role = selector_role(label)}
        controller_rows[label] = row
    end
    if value and value ~= "" then
        row.value = value
    end
    row.is_control = true
    announce_control(row)
end

function a11y.read_msvc_string(object,raw)
    object=tonumber(object)
    if not object or object<0x10000 then return nil end
    local work=a11y.render_read_work
    local key=tostring(object) .. ":" .. tostring(raw)
    if work and work.strings and work.strings[key]~=nil then return work.strings[key] or nil end
    local length=tonumber(read_u64(a11y.safe_memory_read(object+0x10,8)))
    local capacity=tonumber(read_u64(a11y.safe_memory_read(object+0x18,8)))
    if not length or not capacity or length>4096 or capacity<length or capacity>65536 then return nil end
    if length==0 then return "" end
    local source=capacity>=16 and read_u64(a11y.safe_memory_read(object,8)) or object
    local text=source and a11y.safe_memory_read(source,length)
    if not text then return nil end
    local result=raw and text or clean_text(text)
    if work then work.strings=work.strings or {};work.strings[key]=result end
    return result
end

function a11y.widget_internal_name(widget)
    -- The UI text widget contains another MSVC string at +0x18. In captured
    -- FL26 objects this is a stable engine-side name (teamName, btnH_str,
    -- ok_text, setName), not the localized caption. Read it only for
    -- structural field pairs; a name alone does not prove visibility or focus.
    if not widget or widget < 0x10000 then return nil end
    local name = a11y.read_msvc_string(widget + 0x18)
    if name and #name <= 64 and name:match("^[%w_%.%-]+$") then
        return name
    end
    return nil
end

-- Bounded observations, independent of translated captions and render order.
-- +0x38 is deliberately not used: its ownership semantics remain unproven.
function a11y.reset_read_context(reason)
    a11y.last_roster_navigation=nil
    if reason == "transition" then a11y.answer_chain = nil end
    local old = a11y.read_context
    a11y.deferred_modal_announcement,a11y.deferred_speech=nil,nil
    a11y.read_context = {
        generation=(old and old.generation or 0) + 1,
        kind="unknown", reason=reason, started_frame=frame,
        cursor=1,
        title=nil, question=nil, selection=nil, help=nil,
    }
    if reason == "dialog-input" and old and (old.structural_question or old.structural_event) then
        a11y.read_context.kind = "dialog"
        a11y.read_context.structural_question = old.structural_question
        a11y.read_context.structural_event = old.structural_event
        a11y.read_context.owner_link = old.owner_link
        a11y.read_context.baseline, a11y.read_context.answer_owners = {},{}
        a11y.read_context.expires_frame = frame + 3600
    end
end

function a11y.is_structural_answer(text, key)
    local context = a11y.read_context
    if not context or not (context.structural_question or context.structural_event) or not context.owner_link then return false end
    local model = a11y.ui_model
    for node_key, node in pairs(model and model.nodes or {}) do
        if (not key or node_key == key) and node.text == text and node.name == "text"
                and node.owner_link == context.owner_link then return true end
    end
    return false
end

function a11y.capture_question_panel(node)
    if not a11y.native_presentation_ready(node.address) then
        a11y.defer_bound_guidance(node.address,node.text)
        return false
    end
    if (node.name ~= "question" and node.name ~= "eventMsg") or not node.owner_link or not node.text or node.text == "" then return false end
    a11y.dashboard_review = false
    local context = a11y.read_context_state()
    if (context.structural_question or context.structural_event) and context.message_key == node.key and context.question == node.text then
        return true
    end
    a11y.open_read_dialog(node.text, node.key)
    context = a11y.read_context_state()
    context.kind, context.owner_link = "dialog", node.owner_link
    context.structural_question, context.structural_event = node.name == "question", node.name == "eventMsg"
    for key, other in pairs(a11y.ui_model.nodes) do
        if context.structural_question and other.name == "text" and other.owner_link == node.owner_link then
            context.answer_owners[key] = other.identity
            if #other.text >= 2 and #other.text <= 512 and not ui_focus_widgets[key] then
                ui_focus_widgets[key] = {address=other.address,text=other.text,last_seen=other.last_seen,identity=other.identity}
                ui_focus_widget_count = ui_focus_widget_count + 1
            end
        end
    end
    -- The localization resolver may have queued options before their widgets
    -- revealed the question layout. Replace that batch with the actual prompt.
    a11y.native_speech_queue, a11y.native_speech_first, a11y.native_speech_last = {},1,0
    a11y.modal_message_backlog = {}
    a11y.pending_modal_button_text, a11y.deferred_modal_announcement = nil,nil
    recent_message_text, recent_message_widget_key, recent_message_frame = node.text,node.key,frame
    pending_message_text, pending_message_key = node.text,node.key .. "\0" .. node.text
    a11y.pending_message_widget_key = node.key
    a11y.pending_message_owner=a11y.native_owner_token()
    pending_message_due_ms = tonumber(ffi.C.GetTickCount64()) + 40
    a11y.clear_pending_tooltips()
    a11y.transition_old_focus_texts, a11y.transition_old_focus_nodes = nil,nil
    log(string.format("[FLAccess] question-panel owner=%s widget=%s",tostring(node.owner_link),node.key))
    return true
end

function a11y.read_context_state()
    if not a11y.read_context then a11y.reset_read_context("initial") end
    return a11y.read_context
end

function a11y.open_read_dialog(text, key)
    local context = a11y.read_context_state()
    if context.question == text and context.message_key == key then return end
    if context.message_key == key and context.question
            and text:sub(1, #context.question) == context.question then
        context.question = text
        if a11y.text_asset_role(text) == "dialog" or text:match("%?$") then
            context.kind = "dialog"
        end
        return
    end
    local owners = context.message_key == key and context.answer_owners or nil
    local chain = a11y.answer_chain
    if not owners and chain and chain.message_key == key
            and frame - chain.frame <= 120 and a11y.ui_model
            and chain.model_generation == a11y.ui_model.generation then
        owners = chain.owners
    end
    a11y.answer_chain = nil
    local baseline = {}
    for widget_key, entry in pairs(ui_focus_widgets) do
        baseline[widget_key] = {text=entry.text, seen=entry.last_seen}
    end
    a11y.reset_read_context("dialog")
    context = a11y.read_context
    context.kind = (a11y.text_asset_role(text) == "dialog" or text:match("%?$"))
        and "dialog" or "notice"
    context.question, context.message_key = text, key
    local native_owner=a11y.native_owner_token()
    context.native_owner=native_owner ~= "" and native_owner or nil
    context.baseline = baseline
    context.answer_owners = owners or {}
    context.answer_queued = false
    context.expires_frame = frame + 3600
    log(string.format("[FLAccess] reading-context kind=%s generation=%d", context.kind, context.generation))
end

function a11y.set_read_title(text)
    a11y.answer_chain = nil
    local context = a11y.read_context_state()
    if context.native_reading_panel and a11y.reading_panel_is_current() then
        context.title=text
        return
    end
    if context.question or context.structural_question or context.structural_event then a11y.reset_read_context("title") end
    context = a11y.read_context_state()
    context.title, context.kind, context.pending_title = text, "menu", nil
end

function a11y.set_read_help(text, label)
    local context = a11y.read_context_state()
    if context.kind ~= "dialog" then
        context.help = {text=text, label=label, frame=frame}
    end
end

function a11y.commit_read_selection(text, identity, source, label, widget)
    local context = a11y.read_context_state()
    if context.native_reading_panel and not a11y.reading_panel_is_current() then
        a11y.reset_read_context("reading-panel-selection-changed")
        context=a11y.read_context_state()
    end
    if context.kind == "dialog" and source ~= "dialog-answer" then return false end
    if not text or text == "" or is_noninteractive_text(text)
            or text == "No String" then return false end
    if context.pending_title then
        local title = context.pending_title
        a11y.set_read_title(title)
        context = a11y.read_context_state()
        speak(title)
        a11y.title_pending_first_item = title
        a11y.title_pending_first_item_until_ms = tonumber(ffi.C.GetTickCount64()) + 2000
    end
    if context.selection and context.selection.identity ~= identity then
        context.selection_result=nil
        if context.help and context.help.label ~= label then context.help = nil end
        context.cursor = 1
    end
    context.selection = {text=text, identity=identity, source=source, label=label, frame=frame,
        origin=widget and a11y.capture_speech_origin(widget) or nil}
    if context.kind == "unknown" then context.kind = "menu" end
    return true
end

-- Producers supply observations; this boundary owns composition, review,
-- deduplication and delivery validity. Missing context is not a blank value.
function a11y.selection_result(request)
    local address=request.widget or (request.row and request.row.label_widget)
    if address and not a11y.native_presentation_ready(address) then return nil end
    local context=a11y.read_context_state()
    if context.kind=="dialog" and request.source~="dialog-answer" then return nil end
    local key=address and memory.hex(address)
    local node=request.node or (key and a11y.ui_model and a11y.ui_model.nodes[key])
    if node and (a11y.is_media_caption(node) or a11y.is_menu_description(node)) then return nil end
    local row=request.row or (key and a11y.control_for_widget(key))
    if row and not row.is_control and not request.row then row=nil end
    if request.text and not request.row then row=nil end
    local label=request.text or (row and row.label) or (node and node.text)
    if not label or a11y.empty_selection_caption(label) or a11y.unresolved_format(label) then return nil end
    local value=row and row.value
    local music=a11y.native_music_packet(node)
    local text=music and music.text or (row and control_speech(row) or a11y.engine_focus_speech(label,node))
    if request.text and not request.row then text=a11y.engine_focus_speech(request.text,node) end
    if request.source=="dialog-answer" then
        text=label .. (a11y.ui_language=="pt" and ", opção selecionada" or ", selected option")
    end
    if request.presentation then text=request.presentation end
    local assignment=a11y.native_assignment_context(address)
    if assignment then text=a11y.output_speech_text(text) .. ", " .. assignment.text end
    local spoken,page=a11y.page_focus_speech(text,address)
    local owner=a11y.native_owner_token()
    local identity=request.identity or (key and node and a11y.engine_selection_identity(key,node)) or label
    local result={widget=address,key=key,node=node,row=row,label=label,value=value,
        text=text,spoken=spoken,page=page,assignment=assignment,music=music,owner=owner,generation=context.generation,
        source=request.source or "component",identity=identity,
        origin=address and a11y.capture_speech_origin(address),
        value_origin=row and row.value_widget and a11y.capture_speech_origin(row.value_widget),
        missing={}}
    result.roster=a11y.native_player_roster_context(node)
    result.player_section=node and node.name and node.name:lower():find("playername",1,true)
        and ((result.roster and result.roster.section) or a11y.player_component_section(node)) or nil
    result.caption_binding=address and a11y.native_caption_selection_identity(address)
    if row and value==nil then result.missing[#result.missing+1]="value" end
    result.player_parts={}
    for _,part in ipairs(a11y.player_row_details(node)) do
        result.player_parts[#result.player_parts+1]=a11y.capture_speech_origin(part.address)
    end
    result.signature=a11y.selection_result_signature(result)
    return result
end

function a11y.selection_result_signature(result)
    return tostring(result.owner) .. ":" .. tostring(result.generation) .. ":"
        .. result.identity .. ":" .. result.text .. ":" .. (result.page and result.page.identity or "")
        .. ":" .. (result.assignment and result.assignment.identity or "")
        .. ":" .. (result.roster and result.roster.identity or "")
        .. ":" .. (result.caption_binding or "")
end

function a11y.roster_navigation_speech(result,text)
    local previous=a11y.last_roster_navigation
    if not result or not result.player_section or not previous
            or previous.owner~=result.owner or previous.generation~=result.generation
            or previous.section~=result.player_section then return text end
    local prefixes=a11y.ui_language=="pt"
        and {starter="Titular. ",reserve="Reserva. ",unselected="Não relacionado. "}
        or {starter="Starter. ",reserve="Substitute. ",unselected="Not selected. "}
    local prefix=prefixes[result.player_section]
    local page=result.page and result.page.text .. ". " or ""
    if prefix and text:sub(1,#page+#prefix)==page .. prefix then
        return page .. text:sub(#page+#prefix+1)
    end
    return text
end

function a11y.remember_roster_navigation(result)
    if not result then return end
    a11y.last_roster_navigation=result and result.player_section and {
        owner=result.owner,generation=result.generation,section=result.player_section} or nil
end

function a11y.selection_result_allowed(result)
    local context=a11y.read_context_state()
    if context.generation~=result.generation or a11y.native_owner_token()~=result.owner then return false end
    if not context.selection or context.selection.identity~=result.identity then return false end
    if context.selection_result and context.selection_result.signature~=result.signature then return false end
    if result.origin and not a11y.speech_origin_allowed(result.origin) then return false end
    if result.value_origin and not a11y.speech_origin_allowed(result.value_origin) then return false end
    for _,origin in ipairs(result.player_parts or {}) do
        if not a11y.speech_origin_allowed(origin)
                or a11y.read_native_rendered_text(origin.address)~=origin.text then return false end
    end
    for _,origin in ipairs({result.origin or false,result.value_origin or false}) do
        if origin and origin.text then
            local current=a11y.read_native_rendered_text(origin.address)
            if current~=nil and current~=origin.text then return false end
        end
    end
    if result.row and (result.row.label~=result.label or result.row.value~=result.value) then return false end
    local current_page=a11y.native_page_context(result.widget)
    if (result.page and result.page.identity or nil)~=(current_page and current_page.identity or nil) then return false end
    local music=a11y.native_music_packet(result.node)
    if (result.music and result.music.signature or nil)~=(music and music.signature or nil) then return false end
    local assignment=a11y.native_assignment_context(result.widget)
    if (result.assignment and result.assignment.identity or nil)~=(assignment and assignment.identity or nil) then return false end
    local roster=a11y.native_player_roster_context(result.node)
    if (result.roster and result.roster.identity or nil)~=(roster and roster.identity or nil) then return false end
    if result.player_section and ((roster and roster.section) or a11y.player_component_section(result.node))~=result.player_section then return false end
    if result.caption_binding~=(result.widget and a11y.native_caption_selection_identity(result.widget)) then return false end
    if result.node and result.key and result.source=="engine-focus"
            and a11y.engine_selection_identity(result.key,result.node)~=result.identity then return false end
    return true
end

function a11y.deliver_selection_result(result,options)
    if not result or a11y.keyboard_window then return false end
    options=options or {}
    local context=a11y.read_context_state()
    local previous=context.selection_result
    if previous and previous.signature==result.signature
            and (previous.status=="queued" or previous.status=="delivered") and context.selection
            and context.selection.identity==result.identity then return true end
    if not a11y.commit_read_selection(result.text,result.identity,result.source,result.label,result.widget) then return false end
    -- commit may open a pending title; bind to the resulting context generation.
    context=a11y.read_context_state()
    result.generation=context.generation
    result.signature=a11y.selection_result_signature(result)
    local before=a11y.native_speech_last
    local spoken=options.value_only and result.value or result.spoken
    if not result.page and options.interrupt~=false then
        for index=a11y.native_speech_first,a11y.native_speech_last do
            local pending=a11y.native_speech_queue[index]
            if pending and pending.page_context and not pending.selection_result
                    and a11y.page_delivery_allowed(pending.page_context) then
                options.interrupt=false;break
            end
        end
    end
    result.attempt=previous and previous.signature==result.signature and (previous.attempt or 0)+1 or 1
    speak(spoken,options.interrupt,options.modal,result.signature .. ":attempt=" .. tostring(result.attempt),result.widget)
    if a11y.native_speech_last==before then
        local deferred=a11y.deferred_speech
        if deferred and deferred.text==spoken and a11y.deferred_modal_announcement==spoken then
            deferred.selection_result=result
            deferred.options={interrupt=false,value_only=options.value_only,modal=options.modal}
            context.selection_result=result
            result.status="deferred"
        end
        return false
    end
    context.selection_result=result
    result.status="queued"
    if result.page then a11y.last_page_announcement=result.page.identity end
    if result.page then
        for index=a11y.native_speech_first,before do
            local pending=a11y.native_speech_queue[index]
            if pending and pending.page_context and not pending.selection_result
                    and pending.page_context.identity==result.page.identity then pending.superseded=true end
        end
    end
    for index=before+1,a11y.native_speech_last do
        local entry=a11y.native_speech_queue[index]
        entry.selection_result=result
        entry.page_context=result.page
    end
    log(string.format("[FLAccess] selection-result source=%s widget=%s label=%q value=%q missing=%q",
        result.source,tostring(result.widget),result.label,result.value or "",table.concat(result.missing,",")))
    return true
end

-- Deferral is still speech work: retain the same ownership/content evidence
-- rather than converting a composed selection into an unbound literal string.
function a11y.defer_speech(text,identity,address)
    local context=a11y.read_context_state()
    a11y.deferred_modal_announcement=text
    a11y.deferred_speech={text=text,identity=identity,owner=a11y.native_owner_token(),
        generation=context.generation,selection_identity=context.selection and context.selection.identity,
        origin=address and a11y.capture_speech_origin(address)}
end

function a11y.drain_deferred_speech()
    local now=tonumber(ffi.C.GetTickCount64())
    if pending_message_text or now<modal_focus_hold_until_ms or now<(a11y.screen_title_hold_until_ms or 0) then return false end
    local text,deferred=a11y.deferred_modal_announcement,a11y.deferred_speech
    a11y.deferred_modal_announcement,a11y.deferred_speech=nil,nil
    if not text then return false end
    local context=a11y.read_context_state()
    local valid=deferred and deferred.text==text and deferred.owner==a11y.native_owner_token()
        and deferred.generation==context.generation
        and (not deferred.selection_identity or (context.selection and context.selection.identity==deferred.selection_identity))
        and (not deferred.origin or a11y.speech_origin_allowed(deferred.origin))
    if valid and deferred.origin and deferred.origin.text then
        local current=a11y.read_native_rendered_text(deferred.origin.address)
        if current~=nil and current~=deferred.origin.text then valid=false end
    end
    if valid and deferred.selection_result then valid=a11y.selection_result_allowed(deferred.selection_result) end
    if not valid then
        if deferred and deferred.selection_result then deferred.selection_result.status="discarded" end
        log("[FLAccess] deferred-speech-discard reason=context-or-content-changed")
        return false
    end
    if deferred.selection_result then return a11y.deliver_selection_result(deferred.selection_result,deferred.options) end
    speak(text,false,nil,deferred.identity,deferred.origin and deferred.origin.address)
    return true
end

-- Compatibility producers retain their established extraction. They submit
-- data here instead of bypassing the common validity and delivery decision.
function a11y.offer_adapter_selection(text,identity,address,interrupt)
    return a11y.deliver_selection_result(a11y.selection_result({widget=address,
        text=text,presentation=text,identity=identity,source="adapter-focus"}),{interrupt=interrupt})
end

function a11y.dialog_answer_candidate(key, entry, offset, activity)
    local context = a11y.read_context_state()
    if context.kind ~= "dialog" or frame > context.expires_frame
            or not entry or offset ~= 0x104
            or pending_message_text or #a11y.modal_message_backlog > 0 then return false end
    local role = a11y.text_asset_role(entry.text)
    local scoped_node = a11y.ui_model and a11y.ui_model.nodes[key]
    if context.structural_event then
        local snapshot=a11y.native_windows
        return scoped_node and scoped_node.key~=context.message_key and is_modal_button(entry.text)
            and snapshot and snapshot.selected_members and snapshot.selected_members[tonumber(scoped_node.address)]
            and a11y.native_presentation_ready(scoped_node.address)
            and scoped_node.owner_link==context.owner_link
    end
    if context.structural_question then
        return scoped_node and scoped_node.owner_link == context.owner_link and scoped_node.name == "text"
            and not is_noninteractive_text(entry.text) and role ~= "technical" and role ~= "status"
            and (entry.last_seen >= context.started_frame or context.answer_owners[key] == scoped_node.identity)
    end
    if key == context.message_key or entry.text == context.question
            or role == "dialog" or role == "instruction" or role == "tooltip-or-description"
            or is_noninteractive_text(entry.text) or is_splash_text(entry.text) then return false end
    local previous = context.baseline[key]
    local changed = previous and previous.text ~= entry.text
    local introduced = not previous
    local fresh_edge = activity and activity >= context.started_frame
    local node = a11y.ui_model and a11y.ui_model.nodes[key]
    local owned = node and context.answer_owners[key] == node.identity
    local engine=a11y.engine_focus
    local live_event=engine and engine.nodes[key]
    local native_focus=node and context.native_owner and engine
        and engine.owner==context.native_owner and a11y.native_owner_token()==context.native_owner
        and live_event and live_event.edge>=context.started_frame
        and live_event.edge==activity and a11y.native_widget_allowed(node.address)
    -- A background row may redraw with the dialog. Redraw alone is not an
    -- answer; require the primary selection edge or a newly introduced row.
    if not introduced and not changed and not fresh_edge and not owned then return false end
    if entry.last_seen < context.started_frame and not owned and not native_focus then return false end
    if role == "technical" or role == "status" then return false end
    return true
end

function a11y.announce_read_answer(key, entry, offset, activity)
    if not a11y.dialog_answer_candidate(key, entry, offset, activity) then return false end
    local context = a11y.read_context
    local identity = tostring(context.generation) .. ":" .. a11y.ui_focus_identity(key, entry.text)
    local text = entry.text .. (a11y.ui_language == "pt" and ", opção selecionada" or ", selected option")
    a11y.commit_read_selection(text, identity, "dialog-answer")
    context.selection.widget_key = key
    local node = a11y.ui_model and a11y.ui_model.nodes[key]
    if node then context.answer_owners[key] = node.identity end
    if context.structural_question and (a11y.navigation_frame or -1) < context.started_frame then return true end
    if context.last_answer ~= identity then
        local queue = not context.answer_queued and tonumber(ffi.C.GetTickCount64()) < modal_focus_hold_until_ms
        local before=a11y.native_speech_last
        a11y.deliver_selection_result(a11y.selection_result({text=entry.text,widget=node and node.address,
            identity=identity,source="dialog-answer"}),{interrupt=not queue,modal=true})
        for index=before+1,a11y.native_speech_last do
            a11y.native_speech_queue[index].reading_selection={generation=context.generation,identity=identity}
        end
        if a11y.native_speech_last>before then
            context.last_answer, context.answer_queued = identity, true
        end
    end
    return true
end

function a11y.reading_panel_is_current()
    local context=a11y.read_context
    local snapshot=a11y.native_windows
    local node=context and context.message_key and a11y.ui_model and a11y.ui_model.nodes[context.message_key]
    return context and context.native_reading_panel and context.native_owner==a11y.native_owner_token()
        and node and snapshot and snapshot.members and snapshot.members[tonumber(node.address)]
        and snapshot.members[tonumber(node.address)].presented~=false
        and context.native_reading_panel==context.native_owner .. ":" .. node.identity .. ":" .. node.text
        and a11y.native_presentation_ready(node.address) and a11y.ui_node_matches_live(node)
end

function a11y.capture_reading_panel(node)
    local snapshot=a11y.native_windows
    local address=node and tonumber(node.address)
    if not node or node.name~="text_contents" or not node.text or node.text==""
            or a11y.unresolved_format(node.text) or not snapshot or not snapshot.selected_members or not snapshot.selected_members[address]
            or not a11y.native_presentation_ready(address) or not a11y.ui_node_matches_live(node) then return false end
    local count=0
    for selected in pairs(snapshot.selected_members) do
        local other=a11y.ui_model.nodes[memory.hex(selected)]
        if other and other.name=="text_contents" and a11y.native_presentation_ready(selected) then count=count+1 end
    end
    if count~=1 then return false end
    local context=a11y.read_context_state()
    if context.structural_question or context.structural_event then return false end
    local owner=a11y.native_owner_token()
    if not owner or owner=="" then return false end
    local identity=owner .. ":" .. node.identity .. ":" .. node.text
    if context.native_reading_panel==identity then return true end
    local changing=context.native_reading_panel~=nil
    local title=context.title
    reset_message_state()
    a11y.reset_read_context("native-reading-panel")
    context=a11y.read_context_state()
    context.kind,context.question,context.message_key="notice",node.text,node.key
    context.native_owner,context.native_reading_panel,context.title=owner,identity,title
    modal_focus_hold_until_ms=0
    a11y.clear_pending_tooltips()
    speak(node.text,changing,true,identity,node.address)
    return true
end

function a11y.poll_notice_actions()
    local context=a11y.read_context_state()
    local node=context.message_key and a11y.ui_model and a11y.ui_model.nodes[context.message_key]
    local snapshot=a11y.native_windows
    local bar=snapshot and snapshot.command_bar
    local message=node and snapshot and snapshot.members[tonumber(node.address)]
    if not context.question or not message or not bar then a11y.notice_actions=nil;return end
    local identity=tostring(context.generation) .. ":" .. tostring(context.question) .. ":" .. tostring(a11y.native_owner_token())
    if a11y.notice_actions==identity then return end
    local count=0
    for _,pair in ipairs(bar.pairs or {}) do
        local member=snapshot.members[pair.caption]
        local same=false
        for _,owner in ipairs(member and member.owners or {}) do
            for _,other in ipairs(message.owners or {}) do
                if owner.enabled and other.enabled and owner.address==other.address and owner.root==other.root then same=true end
            end
        end
        local text=same and a11y.read_native_rendered_text(pair.caption)
        if text and text~="" and not a11y.unresolved_format(text) and a11y.native_presentation_ready(pair.caption) then
            speak(text,false,true,"notice-action:" .. identity .. ":" .. pair.caption,pair.caption)
            count=count+1
            if count>=4 then break end
        end
    end
    if count>0 then a11y.notice_actions=identity end
end

function a11y.process_read_dialog_focus(candidates)
    local context = a11y.read_context_state()
    if context.kind ~= "dialog" then return false end
    if not context.structural_question and not context.structural_event
            and a11y.native_control_help(context.question) then
        local help=context.question
        reset_message_state()
        a11y.reset_read_context("native-field-help")
        a11y.set_read_help(help)
        modal_focus_hold_until_ms=0
        return false
    end
    if frame > context.expires_frame then
        a11y.reset_read_context("dialog-expired")
        return false
    end
    local selected, reason = a11y.resolve_primary_focus(candidates)
    local entry = selected and (ui_focus_widgets[selected.key]
        or (a11y.ui_model and a11y.ui_model.nodes[selected.key]))
    if not selected or not a11y.dialog_answer_candidate(selected.key, entry, 0x104, selected.edge) then
        context.candidate = nil
        local unresolved = pending_message_text and "message-pending"
            or (selected and "context-ownership-unproven" or reason)
        if unresolved ~= context.unresolved_reason then
            context.unresolved_reason = unresolved
            log(string.format("[FLAccess] dialog-selection-unresolved reason=%s candidates=%d", unresolved, #candidates))
        end
        return true
    end
    local identity = a11y.ui_focus_identity(selected.key, entry.text)
    if identity ~= context.candidate then
        context.candidate, context.candidate_frame = identity, frame
    elseif frame - context.candidate_frame >= 4 then
        a11y.announce_read_answer(selected.key, entry, 0x104, selected.edge)
    end
    if a11y.ui_model then a11y.ui_model.focus_reason = "dialog:" .. reason end
    return true
end

function a11y.entity_review_entries(nodes)
    local item=a11y.native_list_selection
    local snapshot=a11y.native_windows
    local owner=a11y.native_owner_token()
    if a11y.keyboard_window or a11y.read_context_state().kind=="dialog" then return nil end
    local selection=a11y.read_context_state().selection
    if selection and selection.origin and item and selection.origin.address~=item.widget then return nil end
    if not item or not owner or item.committed~=owner .. ":" .. item.identity .. ":" .. item.text
            or a11y.widget_internal_name(item.widget)~="teamName"
            or a11y.read_native_rendered_text(item.widget)~=item.text then return nil end
    local selected=snapshot and snapshot.members and snapshot.members[item.widget]
    if not selected or not selected.active then return nil end
    local anchor=a11y.ui_model.nodes[memory.hex(item.widget)]
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
        if not a11y.empty_selection_caption(node.text) then
            result[#result+1]=node.text
            review.nodes[#result]=node
        end
    end
    return result,review
end

-- Review a player list through the same indexed rows as its native cursor.
-- Repeated names stay separate; a detail panel or a second team cannot join it.
