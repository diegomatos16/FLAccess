function a11y.read_native_rendered_text(address)
    address=tonumber(address)
    if not address then return nil end
    local work=a11y.render_read_work
    local previous=work and work.rendered and work.rendered[address]
    if previous then return previous[1],previous[2],previous[3] end
    local base=tonumber(process_base_u64)
    if not base or a11y.menu_read(address,"u64")~=base+0x27b5260 then return nil end
    local renderer=a11y.menu_read(address+0xa8,"u64")
    local vtable=renderer and a11y.menu_read(renderer,"u64")
    -- e29e40 copies a C string into renderer+38. Both known renderer
    -- vtables use this setter; validate its slot before reading the field.
    local setter=vtable and a11y.menu_read(vtable+0x10,"u64")
    -- Factory e2edf0 builds a proxy whose e2fa60 setter calls e29e40 on
    -- the SAME object, retaining the same text at +38. Read both contracts.
    if setter~=base+0xe29e40 and setter~=base+0xe2fa60 then return nil end
    local raw=a11y.read_native_c_string(a11y.menu_read(renderer+0x38,"u64"),2048)
    if raw==nil then return nil end
    local text,font=clean_text(raw),a11y.menu_read(renderer+8,"u32")
    if work then work.rendered=work.rendered or {};work.rendered[address]={text,raw,font} end
    return text,raw,font
end

function a11y.poll_native_texts(review)
    local snapshot=a11y.native_windows
    if not a11y.native_windows_enabled or not snapshot or not snapshot.members then return end
    local selected,others={},{}
    for address,member in pairs(snapshot.members) do
        if member.active or member.presented then
            others[#others+1]=address
            if snapshot.selected_members and snapshot.selected_members[address] then selected[#selected+1]=address end
        end
    end
    table.sort(selected);table.sort(others)
    local work,seen={},{}
    for index,address in ipairs(selected) do
        if not review and index>24 then break end
        work[#work+1],seen[address]=address,true
    end
    -- A proven field's value can live inside a delegate outside the cursor's
    -- indexed label subtree. Refresh it together with its selected label.
    for index,address in ipairs(selected) do
        if not review and index>24 then break end
        local key=memory.hex(address)
        local row=a11y.control_for_widget(key)
        local value=row and tonumber(row.value_widget)
        if value and not seen[value] and snapshot.members[value] and snapshot.members[value].active then
            work[#work+1],seen[value]=value,true
        end
    end
    local cursor=a11y.native_text_scan_cursor or 0
    for index=1,(review and #others or math.min(24,#others)) do
        local address=others[(cursor+index-1)%#others+1]
        if not seen[address] then work[#work+1]=address;seen[address]=true end
    end
    a11y.native_text_scan_cursor=#others>0 and (cursor+24)%#others or 0
    for _,address in ipairs(work) do
        if a11y.native_presentation_ready(address) then
            local text,raw,font=a11y.read_native_rendered_text(address)
            local key=memory.hex(address)
            local node=a11y.ui_model and a11y.ui_model.nodes[key]
            if text~=nil and (not node or node.text~=text or not a11y.ui_node_matches_live(node)) then
                a11y.on_observed_ui_text(address,text,raw,nil,review)
                node=a11y.ui_model and a11y.ui_model.nodes[key]
            end
            if node and raw then node.raw_text,node.native_font=raw,font end
        end
    end
end

function a11y.presented_nodes()
    local result={}
    local snapshot=a11y.native_windows
    for _,node in pairs(a11y.ui_model and a11y.ui_model.nodes or {}) do
        local member=snapshot and snapshot.members and snapshot.members[tonumber(node.address)]
        if member and (member.active or member.presented) and node.text and node.text~="" and not a11y.unresolved_format(node.text)
                and a11y.native_presentation_ready(node.address)
                and a11y.ui_node_matches_live(node) then result[#result+1]=node end
    end
    table.sort(result,function(a,b)
        if (a.sequence or 0)~=(b.sequence or 0) then return (a.sequence or 0)<(b.sequence or 0) end
        return a.key<b.key
    end)
    return result
end

function a11y.present_companion_heading(nodes)
    local context=a11y.read_context_state()
    if context.kind=="dialog" or a11y.reading_panel_is_current() or a11y.keyboard_window then return end
    local snapshot=a11y.native_windows
    local base=tonumber(process_base_u64)
    local found
    for _,window in ipairs(snapshot and snapshot.windows or {}) do
        local detail=window.cursor_detail
        if window.enabled and detail and detail.status=="no-text" and base
                and detail.selected_type==base+0x27cb508 then
            local label,ambiguous
            for _,node in ipairs(nodes) do
                local row=control_rows_by_label_widget[node.key]
                if node.name=="text_item" and (not row or not row.value or row.value=="") then
                    local member=snapshot.members[tonumber(node.address)]
                    for _,owner in ipairs(member and member.owners or {}) do
                        if owner.enabled and owner.address==window.address then
                            if label and label~=node then ambiguous=true end
                            label=node;break
                        end
                    end
                end
            end
            if label and not ambiguous then
                if found and found~=label then return end
                found=label
            end
        end
    end
    if not found then a11y.companion_candidate=nil;return end
    local identity=(a11y.native_owner_token() or "") .. ":" .. found.identity .. ":" .. found.text
    if a11y.companion_candidate~=identity then
        a11y.companion_candidate,a11y.companion_candidate_frame=identity,frame
    elseif frame-(a11y.companion_candidate_frame or frame)>=3 and a11y.companion_spoken~=identity then
        a11y.companion_spoken=identity
        a11y.present_bound_heading(found.address,found.text)
    end
end

function a11y.poll_static_presentations(nodes)
    local snapshot=a11y.native_windows
    if not snapshot or a11y.keyboard_window or a11y.read_context_state().kind=="dialog" then return end
    for _ in pairs(snapshot.selected_members or {}) do return end
    local owner=a11y.native_owner_token()
    if a11y.static_presentation_owner~=owner then
        a11y.static_presentation_owner,a11y.static_presentation_seen=owner,{}
    end
    local seen=a11y.static_presentation_seen or {}
    a11y.static_presentation_seen=seen
    for _,node in ipairs(nodes) do
        local stem=node.name and node.name:match("^(.-)_value$")
        if stem and node.text:find("%a") and not a11y.empty_selection_caption(node.text) then
            local member=snapshot.members[tonumber(node.address)]
            local readonly=false
            for _,entry in ipairs(member and member.owners or {}) do
                for _,window in ipairs(snapshot.windows or {}) do
                    local d=window.cursor_detail
                    if entry.enabled and window.enabled and entry.address==window.address
                            and (not d or d.status=="no-cursor") then readonly=true end
                end
            end
            local label=a11y.scoped_ui_name(stem .. "_item",node.address)
            local identity=node.identity .. ":" .. node.text
            if readonly and not label and not seen[identity] then
                local before=a11y.native_speech_last
                speak(node.text,false,nil,"presentation:" .. identity,node.address)
                if a11y.native_speech_last>before then
                    seen[identity]=true
                    for index=before+1,a11y.native_speech_last do
                        a11y.native_speech_queue[index].static_presentation={address=node.address,text=node.text}
                    end
                end
            end
        end
    end
end

function a11y.poll_presented_texts()
    if a11y.keyboard_window then return end
    local owner=a11y.native_owner_token()
    if a11y.presentation_seen_owner==owner and a11y.presentation_seen
            and frame-(a11y.presentation_frame or -10000)<6 then return end
    a11y.presentation_frame=frame
    local old=a11y.presentation_seen_owner==owner and a11y.presentation_seen or {}
    local seen,titles,messages={}, {}, {}
    local nodes=a11y.presented_nodes()
    for _,node in ipairs(nodes) do
        a11y.rebind_presented_control(node)
        a11y.capture_reading_panel(node)
        local identity=tostring(node.identity or node.key) .. ":" .. node.text
        seen[node.key]=identity
        if old[node.key]~=identity then
            a11y.announce_skip_hint(node.text,node)
            if is_screen_title(node.text,node.address) then titles[#titles+1]=node
            elseif node.name=="question" or node.name=="eventMsg"
                    or a11y.text_asset_role(node.text)=="dialog" then messages[#messages+1]=node end
        end
    end
    a11y.presentation_seen,a11y.presentation_seen_owner=seen,owner
    if #titles==0 and #messages==0 then
        a11y.present_companion_heading(nodes)
        a11y.poll_static_presentations(nodes)
    end
    -- Never choose by table iteration when several independent prompts arrive.
    if #titles==1 then
        local node=titles[1]
        local role=a11y.text_asset_role(node.text)
        local member=a11y.native_windows and a11y.native_windows.members[tonumber(node.address)]
        if (not role or role=="label-or-name") and member and member.active
                and (node.name=="title" or node.name=="text_title")
                and a11y.read_context_state().kind~="dialog" then
            -- A single presented native heading needs no catalogue entry.
            -- Present it without resetting the scene or its working controls.
            a11y.present_bound_heading(node.address,node.text)
        else announce_screen_title(node.text,node.key,node.address) end
    end
    if #messages==1 then
        local node=messages[1]
        if not a11y.capture_question_panel(node) then
            remember_message_text(node.text,node.key)
            queue_recent_message()
        end
    end
end

function a11y.native_owner_token()
    local snapshot = a11y.native_windows
    if not snapshot or not snapshot.windows then return nil end
    if snapshot.owner_token then return snapshot.owner_token end
    local owners = {}
    for _, window in ipairs(snapshot.windows) do
        if window.enabled and (window.primary or window.root==nil or window.root>=0x10000 or (window.owned_roots and #window.owned_roots>0)) then
            owners[#owners+1]=tostring(window.address) .. ":" .. tostring(window.root or 0)
        end
    end
    table.sort(owners)
    return table.concat(owners,",")
end

function a11y.capture_speech_origin(address)
    if not address then return nil end
    local origin = {address=tonumber(address),owner=a11y.native_owner_token()}
    local node = a11y.ui_model and a11y.ui_model.nodes[memory.hex(address)]
    if node then origin.identity,origin.text=node.identity,node.text end
    if a11y.native_windows_enabled then origin.native_type=a11y.menu_read(origin.address,"u64") end
    return origin
end

function a11y.speech_origin_allowed(origin)
    if not origin then return true end
    if origin.owner and a11y.native_owner_token() ~= origin.owner then return false end
    if origin.native_type and a11y.menu_read(origin.address,"u64") ~= origin.native_type then return false end
    if origin.identity then
        local node=a11y.ui_model and a11y.ui_model.nodes[memory.hex(origin.address)]
        if not node or node.identity ~= origin.identity or node.text ~= origin.text then return false end
    end
    return a11y.native_presentation_ready(origin.address)
end

function a11y.apply_menu_flow(data, name)
    local metadata = data:match('"data"%s*:%s*{(.-)}')
    if not metadata or metadata:match('"type"%s*:%s*"(.-)"') ~= "menu" then return false end
    local home = metadata:match('"mark"%s*:%s*"(.-)"') == "home"
    if a11y.menu_flow_name ~= name or a11y.dashboard_review ~= home then
        a11y.menu_flow_name = name
        a11y.dashboard_review, a11y.dashboard_texts = home, {}
        log("[FLAccess] menu-flow=" .. tostring(name) .. " review=" .. tostring(home))
    end
    return true
end

function m.data_ready(ctx, filename, data, size, total_size, offset)
    local path = filename:gsub("\\", "/")
    local capture=a11y.component_capture
    if capture and capture.active and offset==0
            and (path:lower():find("common/menu/",1,true)
                or path:lower():find("common/script/flow/",1,true)) then
        local line=string.format("RESOURCE frame=%d name=%q size=%s total=%s\n",frame,path,tostring(size),tostring(total_size))
        if capture.bytes+#line<=33554432 then
            local file=io.open(capture.path,"at")
            if file then file:write(line);file:close();capture.bytes=capture.bytes+#line end
        end
    end
    if path:match("common/menu/font/ext_fnt%.bin$") and size<=4194304 and readable(data,size) then
        a11y.observe_control_font(memory.read(data,size),offset,total_size)
    end
    if path:find("common/script/flow/",1,true) and path:match("%.json$")
            and offset == 0 and size == total_size and size <= 65536
            and readable(data, size) then
        a11y.apply_menu_flow(memory.read(data, size), path)
    end
end

function a11y.record_dashboard_text(node)
    if not a11y.dashboard_review or not node or not node.text or node.text == ""
            or node.name == "padIcon" or node.name == "title"
            or node.name == "question" or node.name == "eventMsg"
            or is_noninteractive_text(node.text) or node.text:find("%%") then return end
    a11y.dashboard_texts = a11y.dashboard_texts or {}
    for _, item in ipairs(a11y.dashboard_texts) do
        if item.address == node.address then
            item.text,item.identity,item.owner=node.text,node.identity,a11y.native_owner_token()
            return
        end
    end
    if #a11y.dashboard_texts < 70 then
        a11y.dashboard_texts[#a11y.dashboard_texts+1] = {address=node.address,text=node.text,
            identity=node.identity,owner=a11y.native_owner_token()}
    end
end

function a11y.utf8_characters(text)
    local result={}
    for value in (text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do result[#result+1]=value end
    return result
end

function a11y.read_keyboard_text(node)
    if not a11y.keyboard_window or not node
            or (node.keyboard_owner~=a11y.keyboard_window and not a11y.native_widget_allowed(node.address))
            or (node.name~="textWord" and node.name~="inputText" and node.name~="textInput")
            or node.text==a11y.keyboard_text then return false end
    local old=a11y.keyboard_text
    a11y.keyboard_text=node.text
    if old==nil then return true end
    local before,after=a11y.utf8_characters(old),a11y.utf8_characters(node.text)
    local prefix,suffix=0,0
    while prefix<#before and prefix<#after and before[prefix+1]==after[prefix+1] do prefix=prefix+1 end
    while suffix<#before-prefix and suffix<#after-prefix
            and before[#before-suffix]==after[#after-suffix] do suffix=suffix+1 end
    local removed,inserted={},{}
    for index=prefix+1,#before-suffix do removed[#removed+1]=before[index] end
    for index=prefix+1,#after-suffix do inserted[#inserted+1]=after[index] end
    local spoken=table.concat(removed)
    if #inserted>0 and a11y.keyboard_echo_insertions then
        spoken=spoken .. (#spoken>0 and ". " or "") .. table.concat(inserted)
    end
    if spoken~="" then
        a11y.keyboard_edit_sequence=(a11y.keyboard_edit_sequence or 0)+1
        speak(spoken,true,true,"edit:" .. tostring(a11y.keyboard_edit_sequence))
    end
    return true
end

function a11y.read_native_keyboard_state()
    local window=a11y.keyboard_window
    local base=tonumber(process_base_u64)
    if not window or not base or a11y.menu_read(window,"u64")~=base+0x27c3eb0 then return nil end
    -- KeyboardPopup owns its editing state at +110. d42b90 copies the full
    -- MSVC string at state+8; e7b330 uses state+0 as the UTF-8 cursor index.
    -- The input node at popup+90 can belong to the disabled window underneath.
    local text=a11y.read_msvc_string(window+0x118)
    if text==nil then return nil end
    local caret=a11y.menu_read(window+0x110,"u32")
    local characters=a11y.utf8_characters(text)
    if not caret or caret>#characters then caret=nil end
    return {address=window,keyboard_owner=window,name="inputText",text=text,caret=caret,
        input=a11y.menu_read(window+0x90,"u64")}
end


function m.on_keyboard_input_set(ctx, event_id, registers)
    -- Observe the native input node, not the coach field behind the popup.
    -- The hook runs before the setter: read its stored string on render frames.
    local address = tonumber(read_u64(registers.rcx))
    if not address or a11y.menu_read(address,"u64") ~= tonumber(process_base_u64)+0x27c3a38 then return end
    if address ~= a11y.keyboard_input_address then
        log("[FLAccess] native-input address=" .. memory.hex(address) .. " source=NodeRectTextInput string-offset=0x118 cursor=unverified")
    end
    a11y.keyboard_input_address = address
end

function a11y.poll_keyboard_input()
    if not a11y.keyboard_window then return end
    local native=a11y.read_native_keyboard_state()
    if native then
        local previous=a11y.keyboard_text
        a11y.read_keyboard_text(native)
        if previous==native.text and native.caret~=nil and a11y.keyboard_caret~=nil
                and native.caret~=a11y.keyboard_caret then
            local characters=a11y.utf8_characters(native.text)
            speak(characters[native.caret+1] or (a11y.ui_language=="pt" and "Fim do texto." or "End of text."),
                true,true,"caret:" .. tostring(a11y.keyboard_window) .. ":" .. tostring(native.caret))
        end
        a11y.keyboard_caret=native.caret
        return
    end
    -- A recognized popup with unavailable state must wait; another input
    -- widget elsewhere cannot stand in for its edit buffer.
    if a11y.menu_read(a11y.keyboard_window,"u64")==tonumber(process_base_u64)+0x27c3eb0 then return end
    -- Compatibility fallback for a verified input without the popup layout.
    if not a11y.keyboard_input_address then return end
    local address=a11y.keyboard_input_address
    if a11y.menu_read(address,"u64")~=tonumber(process_base_u64)+0x27c3a38 then return end
    local text=a11y.read_msvc_string(address+0x118)
    if text~=nil then a11y.read_keyboard_text({address=address,name="inputText",text=text}) end
end

function a11y.main_menu_choice_current(state)
    local node=state and a11y.ui_model and a11y.ui_model.nodes[state.key]
    if not node or node.identity~=state.node_identity or node.text~=state.text
            or not a11y.ui_node_matches_live(node) then return false end
    local rendered=a11y.read_native_rendered_text(state.address)
    return rendered==nil or rendered==state.text
end

function a11y.main_menu_choice_active(state)
    if state~=a11y.main_menu_choice_state or not a11y.main_menu_choice_current(state)
            or a11y.read_context_state().kind=="dialog" or not a11y.native_presentation_ready(state.address) then return false end
    local snapshot=a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[state.address]
    if #state.scopes==0 then return state.observed_owner==a11y.native_owner_token() end
    for _,old in ipairs(state.scopes) do
        for _,owner in ipairs(member and member.owners or {}) do
            if owner.enabled and owner.address==old.address and owner.root==old.root then return true end
        end
    end
    return false
end

function a11y.queue_main_menu_choice(state)
    if not a11y.main_menu_choice_active(state) then state.status="suspended";return end
    if state.status=="delivered" or state.status=="queued" then return end
    a11y.title_pending_first_item=nil
    a11y.set_read_title(state.text)
    local before=a11y.native_speech_last
    state.attempt=(state.attempt or 0)+1
    speak(state.text,true,nil,"main-menu-choice:" .. state.key .. ":" .. state.text
        .. ":attempt=" .. state.attempt,state.address)
    if a11y.native_speech_last>before then
        state.status="queued"
        for index=before+1,a11y.native_speech_last do
            a11y.native_speech_queue[index].menu_choice=state
            a11y.native_speech_queue[index].menu_choice_attempt=state.attempt
        end
    end
end

function a11y.present_main_menu_choice(widget,text)
    local node=a11y.ui_model and a11y.ui_model.nodes[memory.hex(widget)]
    if not node then return end
    local state=a11y.main_menu_choice_state
    if not state or state.key~=node.key or state.node_identity~=node.identity or state.text~=text then
        local member=a11y.native_windows and a11y.native_windows.members and a11y.native_windows.members[tonumber(widget)]
        state={key=node.key,address=tonumber(widget),node_identity=node.identity,text=text,status="pending",
            scopes={},observed_owner=a11y.native_owner_token()}
        for _,owner in ipairs(member and member.owners or {}) do state.scopes[#state.scopes+1]={address=owner.address,root=owner.root} end
        a11y.main_menu_choice_state=state
    end
    a11y.queue_main_menu_choice(state)
end

function a11y.poll_main_menu_choice()
    a11y.poll_main_menu_caption()
    local state=a11y.main_menu_choice_state
    if not state then return end
    if not a11y.main_menu_choice_current(state) then a11y.main_menu_choice_state=nil;return end
    if #state.scopes==0 then
        local member=a11y.native_windows and a11y.native_windows.members and a11y.native_windows.members[state.address]
        for _,owner in ipairs(member and member.owners or {}) do
            if owner.enabled and owner.root and owner.root>=0x10000 then
                state.scopes[#state.scopes+1]={address=owner.address,root=owner.root}
            end
        end
        if #state.scopes>0 then state.observed_owner=a11y.native_owner_token();state.status="pending" end
    end
    if not a11y.main_menu_choice_active(state) then state.status="suspended";return end
    if state.status=="suspended" then state.status="pending" end
    if state.status=="queued" then
        local queued=false
        for index=a11y.native_speech_first,a11y.native_speech_last do
            local entry=a11y.native_speech_queue[index]
            if entry and entry.menu_choice==state and a11y.speech_entry_allowed(entry) then queued=true end
        end
        if not queued then state.status="pending" end
    end
    a11y.queue_main_menu_choice(state)
end

-- Main menu presents every choice through the same text_item/text_value pair.
-- Some modded labels bypass localization; poll these exact bound nodes instead
-- of running a separate first-item publisher or scanning every observed text.
function a11y.main_menu_text_owner(node)
    if not node or (node.name~="text_item" and node.name~="text_value") then return nil end
    local base=tonumber(process_base_u64)
    for _,window in ipairs(a11y.native_windows and a11y.native_windows.windows or {}) do
        if base and window.enabled and a11y.menu_read(window.address,"u64")==base+0x266ddd8
                and a11y.record_contains(node,window,window.root) then return window end
    end
end

function a11y.poll_main_menu_caption()
    local names=a11y.ui_model and a11y.ui_model.names or {}
    local caption,owner
    for _,node in pairs(names.text_item or {}) do
        local window=a11y.main_menu_text_owner(node)
        if window and a11y.ui_node_matches_live(node) and a11y.native_presentation_ready(node.address)
                and a11y.read_native_rendered_text(node.address)==node.text and not a11y.empty_selection_caption(node.text) then
            if caption then return end
            caption,owner=node,window
        end
    end
    if not caption then return end
    main_menu_title_widget_key=caption.key
    a11y.present_main_menu_choice(caption.address,caption.text)
    local state=a11y.main_menu_choice_state
    local description
    for _,node in pairs(names.text_value or {}) do
        if a11y.record_contains(node,owner,owner.root) and a11y.native_presentation_ready(node.address)
                and a11y.ui_node_matches_live(node) and a11y.read_native_rendered_text(node.address)==node.text then
            if description then return end
            description=node.text
        end
    end
    if state and description and description~="" and state.description~=description and a11y.read_tooltips then
        state.description=description
        main_menu_tooltip,main_menu_tooltip_due_ms=description,tonumber(ffi.C.GetTickCount64())
        a11y.main_menu_tooltip_choice=state
    end
end

function a11y.loading_context()
    local base=tonumber(process_base_u64)
    local at=base and a11y.menu_read(base+0x36f9a68,"u64")
    if at and at>=0x10000 and a11y.menu_read(at,"u64")==base+0x27b55b8
            and a11y.menu_read(base+0x27b55b8+8,"u64")==base+0xe4a630 then return at end
end

function a11y.poll_loading(now)
    local at=a11y.loading_context()
    if not at then a11y.loading_notice=nil;return end
    local state=a11y.loading_notice
    if not state or state.address~=at then state={address=at,started=now};a11y.loading_notice=state end
    if not state.announced and now-state.started>=3000 then
        local before=a11y.native_speech_last
        speak(a11y.ui_language=="pt" and "Carregando tela" or "Loading screen",true,true,"loading:" .. at .. ":" .. state.started)
        for index=before+1,a11y.native_speech_last do a11y.native_speech_queue[index].loading_state=state end
        if a11y.native_speech_last>before then state.announced=true end
    end
end

function a11y.main_navigation_signature(include_types)
    local parts={}
    for index,window in ipairs(a11y.native_windows and a11y.native_windows.windows or {}) do
        if index>16 then break end
        local detail=window.cursor_detail
        parts[#parts+1]=table.concat({tostring(window.address),tostring(window.root or 0),
            tostring(window.enabled),tostring(include_types and a11y.menu_read(window.address,"u64") or "not-sampled"),
            tostring(detail and detail.group_index),tostring(detail and detail.item_index),
            tostring(detail and detail.selected)},":")
    end
    return table.concat(parts,"|")
end

function a11y.poll_main_navigation_probe()
    local state=a11y.main_menu_choice_state
    if not state and not a11y.dashboard_review then a11y.main_navigation_probe,a11y.main_navigation_last=nil,nil;return end
    local probe=a11y.main_navigation_probe
    local count=a11y.main_navigation_log_count or 0
    if count>=64 then a11y.main_navigation_probe=nil;return end
    -- Idle frames reuse snapshot fields only. Native type reads are limited to
    -- the two observations following an input edge, within the log budget.
    local signature=a11y.main_navigation_signature(probe~=nil)
    if probe and count<64 then
        local phase=probe.observed and "next-render" or "input-observation"
        log(string.format("[FLAccess] main-navigation frame=%d input=%q source=%q phase=%s title=%q speech=%s overlay=%s before=%q current=%q",
            frame,probe.action,probe.source,phase,state and state.text or "main-flow",tostring(state and state.status or "unbound-title"),
            tostring(overlay_visible or sider_overlay_visible),probe.before or "unknown",signature))
        a11y.main_navigation_log_count=count+1
        if probe.observed then a11y.main_navigation_probe=nil else probe.observed=true end
    end
    a11y.main_navigation_last=signature
end

function a11y.present_bound_heading(widget,text)
    local language=a11y.native_language_context()
    if language and a11y.native_language_heading(widget)==language.label then
        a11y.poll_native_language();return
    end
    if not a11y.native_presentation_ready(widget) then a11y.defer_bound_guidance(widget,text,"heading");return end
    text=a11y.native_language_heading(widget) or text
    a11y.set_read_title(text)
    speak(text,not a11y.read_context_state().native_reading_panel,nil,nil,widget)
    a11y.title_pending_first_item=text
    a11y.title_pending_first_item_until_ms=tonumber(ffi.C.GetTickCount64())+2000
end

function a11y.defer_bound_guidance(widget,text,kind)
    if a11y.native_presentation_ready(widget) or a11y.is_control_help(text) then return end
    local title=is_screen_title(text,widget)
    local node=a11y.ui_model and a11y.ui_model.nodes[memory.hex(widget)]
    local panel=node and (node.name=="question" or node.name=="eventMsg")
    if not kind and not title and not panel and not looks_like_message(text,widget) then return end
    a11y.pending_surface_texts=a11y.pending_surface_texts or {}
    local origin=a11y.capture_speech_origin(widget)
    if origin.owner=="" or not a11y.native_presentation_ready() then origin.owner=nil end
    local member=a11y.native_windows and a11y.native_windows.members
        and a11y.native_windows.members[tonumber(widget)]
    if member and not member.active and member.owners and #member.owners>0 then
        -- A proven future owner can bind on activation. Unknown ownership
        -- must not turn an old pending caption into a new-window title.
        origin.target_windows={}
        for _,owner in ipairs(member.owners) do origin.target_windows[owner.address]=true end
        origin.owner=nil
    end
    a11y.pending_surface_texts[memory.hex(widget)]={text=text,frame=frame,
        address=tonumber(widget),kind=kind or (panel and "panel" or title and "title" or "message"),
        origin=origin}
end

function a11y.poll_surface_texts()
    for key, item in pairs(a11y.pending_surface_texts or {}) do
        local node = a11y.ui_model and a11y.ui_model.nodes[key]
        local bound=true
        if item.origin and item.origin.target_windows then
            bound=false
            local member=node and a11y.native_windows and a11y.native_windows.members
                and a11y.native_windows.members[tonumber(node.address)]
            for _,owner in ipairs(member and member.owners or {}) do
                if owner.enabled and item.origin.target_windows[owner.address] then bound=true end
            end
        end
        if not node or node.text ~= item.text or frame-item.frame > 600
                or not a11y.ui_node_matches_live(node)
                or (item.origin and item.origin.owner
                    and item.origin.owner ~= a11y.native_owner_token()) then
            a11y.pending_surface_texts[key]=nil
        elseif bound and a11y.native_presentation_ready(node.address) then
            a11y.pending_surface_texts[key]=nil
            if item.kind=="menu-choice" then a11y.present_main_menu_choice(node.address,node.text)
            elseif item.kind == "heading" then a11y.present_bound_heading(node.address,node.text)
            elseif item.kind == "panel" then a11y.capture_question_panel(node)
            elseif item.kind == "message" then remember_message_text(node.text,key); queue_recent_message()
            else announce_screen_title(node.text,key,node.address) end
        end
    end
end

function a11y.ui_owner_link(widget)
    if not readable(widget + 0x38, 8) then return nil end
    local bytes = a11y.safe_memory_read(widget+0x38,8)
    if not bytes or #bytes ~= 8 then return nil end
    local pointer = tonumber(read_u64(bytes))
    if pointer and pointer >= 0x10000 and pointer <= 0x7fffffffffff then return pointer end
end

-- nil means no structural evidence; false means known different components.
function a11y.component_peers(left,right)
    local snapshot=a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[tonumber(left)]
    local known=false
    for _,owner in ipairs(member and member.owners or {}) do
        if owner.enabled and owner.parents then
            local lp,rp=owner.parents[tonumber(left)],owner.parents[tonumber(right)]
            if lp and rp then
                known=true
                if lp==rp and lp~=owner.root then return true end
            end
        end
    end
    if known then return false end
end

function a11y.scoped_ui_name(name,address)
    local found,known
    for _,node in pairs(a11y.ui_model and a11y.ui_model.names[name] or {}) do
        local peer=a11y.component_peers(address,node.address)
        if peer~=nil then known=true end
        if peer and a11y.native_widget_allowed(node.address) and a11y.ui_node_matches_live(node) then
            if found then return nil end
            found=node
        end
    end
    if found then return found end
    if known then return nil end
    return a11y.unique_ui_name(name)
end

function a11y.command_icon_owners()
    local owners = {}
    for _, node in pairs(a11y.ui_model and a11y.ui_model.nodes or {}) do
        if node.name == "padIcon" and node.owner_link then owners[node.owner_link] = true end
    end
    return owners
end

function a11y.is_command_legend(key, primary_focused, owners)
    local node = a11y.ui_model and a11y.ui_model.nodes[key]
    if not node then return false end
    if node.name == "padIcon" then return true end
    -- This observed layout family puts command captions and padIcon children
    -- under the same link. A caption with real primary focus remains eligible.
    return not primary_focused and node.name == "text" and node.owner_link ~= nil
        and owners[node.owner_link] == true
        and a11y.text_asset_role(node.text) == "dialog-button"
end

function a11y.ui_focus_identity(key, text)
    local node = a11y.ui_model and a11y.ui_model.nodes[key]
    -- Text is also needed for virtualized items whose data replaces a widget.
    return (node and node.identity or key) .. ":" .. text
end

local function ui_focus_speech(text)
    if is_plain_text(text) or is_splash_text(text)
            or looks_like_message(text) then
        return text
    end
    if language_options[text] then
        return text .. ", opção selecionada"
    end
    if text == "Em casa" or text == "Fora" or text == "Neutro" then
        return text .. ", opção selecionada"
    end
    if text == "Concordo." or text == "I agree." then
        return text:sub(1, -2) .. ", botão selecionado"
    end
    if text == "Sim" or text == "Não"
            or a11y.game_plan_basic_prompt_items[text] then
        return text .. ", botão selecionado"
    end
    local parenthesized_formation = text:match("%((.-)%)")
    local effective_formation = parenthesized_formation
        and parenthesized_formation:gsub("%s+", "") or nil
    if effective_formation and not effective_formation:match("^%d[%d%-]+$") then
        effective_formation = nil
    end
    if effective_formation then
        local default_suffix = (text:find("Padrão", 1, true)
                or text:find("Default", 1, true))
            and (a11y.ui_language == "pt" and ", padrão" or ", default")
            or ""
        if a11y.ui_language == "pt" then
            return effective_formation .. default_suffix
        end
        return effective_formation .. default_suffix
    elseif text:match("^%d[%d%-]+$") then
        if a11y.ui_language == "pt" then
            return text
        end
        return text
    end
    return text .. ", item selecionado"
end

function a11y.engine_focus_speech(text,node)
    local spoken=ui_focus_speech(text)
    if node and node.name and node.name:lower():find("playername",1,true) then
        spoken=a11y.output_speech_text(spoken)
        for _,detail in ipairs(a11y.player_row_details(node)) do
            spoken=spoken .. ", " .. detail.text
        end
        local section=a11y.player_component_section(node)
        local prefixes=a11y.ui_language=="pt"
            and {starter="Titular. ",reserve="Reserva. ",unselected="Não relacionado. "}
            or {starter="Starter. ",reserve="Substitute. ",unselected="Not selected. "}
        if section then spoken=(prefixes[section] or "") .. spoken end
    end
    return spoken
end

-- The indexed player row can dispatch focus to its name, rating and optional
-- caption together (real dev 21 packet 902). Only direct native siblings
-- compose a row; equal text/resource names elsewhere grant no relationship.
