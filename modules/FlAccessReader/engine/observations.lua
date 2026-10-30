function a11y.on_observed_ui_text(widget,text,raw,registers,review)
    if not text or not widget or widget < 0x10000 then
        return
    end
    if text == "" then
        local empty_key = memory.hex(widget)
        for index = #(a11y.dashboard_texts or {}), 1, -1 do
            if a11y.dashboard_texts[index].address == widget then
                table.remove(a11y.dashboard_texts, index)
            end
        end
        a11y.forget_ui_widget(empty_key)
        ui_text_by_widget[empty_key] = nil
        if last_selected_ui_entry and last_selected_ui_entry.address == widget then
            a11y.reset_focus_reuse_state()
        end
        return
    end
    if text == "No String" or text == "/" then
        -- Construction placeholders are neither a surface change nor focus.
        -- Clearing all ownership here used to erase freshly mapped sliders.
        a11y.forget_ui_widget(memory.hex(widget))
        ui_text_by_widget[memory.hex(widget)] = nil
        return
    end

    local widget_key = memory.hex(widget)
    local observed_node = a11y.observe_ui_widget(widget, text)
    observed_node.raw_text=raw or text
    if a11y.unresolved_format(text) then return end
    a11y.poll_native_windows()
    a11y.record_dashboard_text(observed_node)
    if a11y.main_menu_text_owner(observed_node) then
        if not review and observed_node.name=="text_item" then
            main_menu_title_widget_key=observed_node.key
            a11y.present_main_menu_choice(widget,text)
        end
        return
    end
    if review then
        a11y.capture_structural_control(widget,text)
        return
    end
    -- Input feedback is owned by the actual native input node. A retained
    -- textWord from the background is not an edit event.
    if observed_node.name == "padIcon" then return end
    local structural_prompt = a11y.capture_question_panel(observed_node)
    if not structural_prompt and a11y.capture_reading_panel(observed_node) then return end
    if a11y.diagnostic_mode and registers then
        local saved_rsp = read_u64(registers.rsp)
        if saved_rsp and readable(saved_rsp + 64, 8) then
            local return_address = read_u64(memory.read(saved_rsp + 64, 8))
            local caller_number = tonumber(return_address)
            local base_number = tonumber(process_base_u64)
            if caller_number and base_number and caller_number >= base_number
                    and caller_number < base_number + 0x40000000 then
                a11y.ui_text_caller_by_widget[widget_key] =
                    caller_number - base_number
            else
                a11y.ui_text_caller_by_widget[widget_key] = nil
            end
        end
    end
    local previous = ui_text_by_widget[widget_key]
    ui_text_by_widget[widget_key] = text
    if previous ~= text then
        a11y.announce_skip_hint(text, observed_node)
    end
    if not a11y.cup_group_table_active
            and a11y.is_cup_group_header(widget, text) then
        -- Captured headers arrive before the trailing grid OK and before the
        -- explanatory paragraph. Identify the table while that OK is still
        -- a background cell, not after it has already reached speech.
        a11y.activate_cup_group_table(false)
    end
    local tactical_heading, game_plan_player_heading =
        a11y.observe_compatibility_context(widget_key, text)
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if a11y.game_plan_active
            and (text == "Altura (cm)" or text == "Height (cm)") then
        local panel_was_closed = now_ms > a11y.game_plan_attribute_panel_until_ms
        a11y.game_plan_attribute_last_marker_frame = frame
        local opened_by_y = a11y.diagnostic_last_input_action == "Y"
            and frame - a11y.diagnostic_last_input_frame <= 90
            and a11y.game_plan_selected_heading ~= nil
        if panel_was_closed and opened_by_y then
            a11y.game_plan_attribute_locked_name =
                a11y.normalized_player_name(
                    a11y.game_plan_selected_heading
                        or a11y.game_plan_last_focus_text)
            a11y.game_plan_player_record = nil
            a11y.game_plan_player_name =
                a11y.game_plan_attribute_locked_name
            a11y.game_plan_player_attributes = {}
            local player = a11y.player_for_text(
                a11y.game_plan_attribute_locked_name)
            if player then
                a11y.game_plan_player_record = player.pointer
                a11y.game_plan_player_name =
                    a11y.game_plan_attribute_locked_name or player.name
                a11y.game_plan_player_attributes = player.attributes
            end
            a11y.game_plan_attribute_due_ms = now_ms + 300
            a11y.game_plan_attribute_opened_ms = now_ms
        end
        if opened_by_y then
            a11y.game_plan_attribute_panel_until_ms = now_ms + 30000
        end
    end
    local tooltip_control_label = control_label_from_tooltip(text)
    -- A pause between text writes is not a new focus. The same Informações
    -- widget can redraw after a pause while the selection never moved.
    if previous ~= text and not a11y.native_presentation_ready(widget) then
        local title = is_screen_title(text,widget)
        local role = a11y.text_asset_role(text)
        if title or ((a11y.is_instruction_message(text) or looks_like_message(text,widget))
                and not a11y.is_control_help(text)) then
            a11y.defer_bound_guidance(widget,text)
        end
    end
    if previous ~= text and a11y.native_presentation_ready(widget) then
        announce_screen_title(text, widget_key, widget)
        local tactical_tooltip = a11y.game_plan_active
            and a11y.game_plan_active_tactical_label
            and frame - a11y.game_plan_active_tactical_frame <= 90
            and looks_like_message(text, widget)
            and not a11y.is_instruction_message(text)
            and not tactical_heading
        if tactical_tooltip then
            if a11y.read_tooltips then
                pending_controller_tooltip = text
                pending_controller_tooltip_label =
                    a11y.game_plan_active_tactical_label
                active_controller_label =
                    a11y.game_plan_active_tactical_label
                controller_tooltip_due_ms = now_ms
            end
        elseif tooltip_control_label or a11y.is_control_help(text) then
            focused_control_hint = tooltip_control_label
            focused_control_hint_ms = now_ms
            latest_generic_tooltip = text
            latest_generic_tooltip_widget = widget
            latest_generic_tooltip_ms = now_ms
            a11y.set_read_help(text, tooltip_control_label)
            if a11y.read_tooltips then
                pending_controller_tooltip = text
                pending_controller_tooltip_label = tooltip_control_label
                    or active_controller_label
                controller_tooltip_due_ms = now_ms
            end
        elseif not game_plan_player_heading and not tactical_heading and not structural_prompt then
            remember_message_text(text, widget_key)
        end
        if not queue_startup_text(text, now_ms)
                and is_plain_text(text)
                and not is_noninteractive_text(text) then
            speak(text)
        end
        if #text >= 4 and #text <= 50
                and not is_modal_button(text)
                and not is_plain_text(text)
                and not is_splash_text(text)
                and not is_noninteractive_text(text)
                and not text:match("^Usuário %d+$") then
            recent_heading_text = text
            recent_heading_frame = frame
        end
    end
    if is_modal_button(text) then
        last_modal_button_frame = frame
        if text ~= "OK" or not instruction_message_locked then
            queue_recent_message()
        end
    end
    if text == "Sim" or text == "Não" then
        register_dialog_option(text, widget, widget_key)
    end
    local structural_node = a11y.ui_model and a11y.ui_model.nodes[widget_key]
    if #text >= 2 and (#text <= 50 or (#text <= 160
            and structural_node and structural_node.role == "control-label")
            or (a11y.read_context_state().kind == "dialog" and #text <= 512
                and text ~= a11y.read_context.question
                and widget_key ~= a11y.read_context.message_key
                and (a11y.is_structural_answer(text,widget_key) or
                    (a11y.text_asset_role(text) ~= "dialog" and a11y.text_asset_role(text) ~= "instruction"))))
            and not text:find("%%") and not text:match("^%d+$")
            and text ~= "-" and text:match("[%w]")
            and not is_noninteractive_text(text)
            and a11y.widget_internal_name(widget) ~= "title"
            and a11y.widget_internal_name(widget) ~= "text_title"
            and widget_key ~= main_menu_title_widget_key
            and text ~= main_menu_tooltip
            and text ~= pending_controller_tooltip then
        local previous_focus = ui_focus_widgets[widget_key]
        if a11y.focus_widget_reused(previous_focus, text) then
            a11y.reset_focus_reuse_state()
        end
        if not ui_focus_widgets[widget_key] then
            if ui_focus_widget_count >= 300 then
                local oldest_key
                local oldest_frame = frame + 1
                for candidate_key, candidate in pairs(ui_focus_widgets) do
                    if (candidate.last_seen or 0) < oldest_frame then
                        oldest_key = candidate_key
                        oldest_frame = candidate.last_seen or 0
                    end
                end
                if oldest_key then
                    a11y.forget_ui_widget(oldest_key)
                end
            end
            ui_focus_widget_count = ui_focus_widget_count + 1
        end
        ui_focus_widgets[widget_key] = {
            address = widget,
            text = text,
            last_seen = frame,
            identity = a11y.observe_ui_widget(widget, text).identity,
        }
    end

    local label_row = control_rows_by_label_widget[widget_key]
    if label_row and text ~= label_row.label then
        if label_row.value_widget_key
                and control_row_by_value_widget[label_row.value_widget_key]
                    == label_row then
            control_row_by_value_widget[label_row.value_widget_key] = nil
        end
        if controller_rows[label_row.label] == label_row then
            controller_rows[label_row.label] = nil
        end
        control_rows_by_label_widget[widget_key] = nil
        if active_control_row == label_row then
            active_control_row = nil
        end
        label_row = nil
    end

    -- A field pair needs no localization ID, known caption, or screen name.
    label_row = a11y.capture_structural_control(widget, text) or label_row
    local value_row
    local structural_row = a11y.structural_control_row(widget)
    if structural_row and attach_control_value(
            structural_row, widget, text) then
        value_row = structural_row
        pending_control_row = nil
    elseif label_row and text == label_row.label then
        pending_control_row = label_row
    elseif active_control_row
            and not active_control_row.native_slider
            and not active_control_row.external_value
            and not a11y.game_plan_active
            and now_ms - active_control_focused_ms <= 500
            and widget ~= active_control_row.label_widget
            and not label_row
            and is_widget_focused(widget) then
        if attach_control_value(active_control_row, widget, text) then
            value_row = active_control_row
        end
        pending_control_row = nil
    elseif pending_control_row and not a11y.game_plan_active
            and frame - (pending_control_row.created_frame or frame) <= 2
            and widget ~= pending_control_row.label_widget then
        if attach_control_value(pending_control_row, widget, text) then
            value_row = pending_control_row
        end
        pending_control_row = nil
    else
        value_row = control_row_by_value_widget[widget_key]
        if value_row and not value_row.native_slider then
            if not attach_control_value(value_row, widget, text) then
                value_row = nil
            end
        elseif value_row and value_row.native_slider then
            value_row = nil
        end
    end
    local tactical_context = a11y.game_plan_context ==
            "Configurações táticas básicas"
        or a11y.game_plan_context == "Basic Tactical Settings"
    if value_row and active_control_row == value_row and previous ~= text
            and not tactical_context then
        announce_control_value(value_row, text)
    end

    local seen_key = widget_key .. "\0" .. text
    if not ui_text_seen[seen_key] and ui_text_unique_count < 6000 then
        ui_text_seen[seen_key] = true
        ui_text_unique_count = ui_text_unique_count + 1
        trace_log(string.format(
            "[FLAccess] ui-text widget=%s previous=%q text=%q",
            widget_key,
            previous or "",
            text))
    end

end

function a11y.empty_selection_caption(text)
    local value=(text or ""):gsub("%s","")
    return value=="" or value=="-" or value=="–" or value=="—"
end

function a11y.observe_native_list_selection(text,identity,widget)
    if a11y.empty_selection_caption(text) or not widget or widget<0x10000 then return end
    local previous=a11y.native_list_selection
    local name,link=a11y.widget_internal_name(widget),a11y.ui_owner_link(widget)
    if previous and previous.identity==identity and previous.text==text and previous.widget==widget
            and previous.name==name and previous.link==link then
        previous.observed=frame
        return
    end
    a11y.native_list_selection={text=text,identity=identity,widget=widget,observed=frame,
        name=name,link=link}
end

-- The base carousel exposes 0x50 caption records. NationalitySelect instead
-- overrides its country renderer with filtered IDs; keep both layouts separate.
-- Its outer cursor selects the carousel, not an individual country caption.
-- C9D900/C9D860 select country IDs from the continent's filtered uint16 vector.
-- This override does not populate the generic carousel's 0x50 caption records.
function a11y.filtered_country_id(window,parent)
    local key=a11y.menu_read(parent,"u32")
    local offset,index=a11y.menu_read(parent+0x64,"u32"),a11y.menu_read(parent+0x68,"u32")
    local head=a11y.menu_read(window+0x170,"u64")
    if not key or key>4 or not offset or not index or not head or head<0x10000 then return nil end
    local at=a11y.menu_read(head+8,"u64")
    local seen={}
    for _=1,64 do
        if not at or at<0x10000 or at==head or seen[at] or a11y.menu_read(at+0x19,"u8")~=0 then return nil end
        seen[at]=true
        local current=a11y.menu_read(at+0x20,"u32")
        if current==nil then return nil end
        if current==key then
            local first,last=a11y.menu_read(at+0x28,"u64"),a11y.menu_read(at+0x30,"u64")
            if not first or first<0x10000 or not last or last<first or (last-first)%2~=0
                    or last-first>1024 or offset+index>=(last-first)/2 then return nil end
            local id=a11y.menu_read(first+(offset+index)*2,"u16")
            if not id or id>=0x1ff then return nil end
            return id,first+(offset+index)*2
        end
        at=a11y.menu_read(at+(current<key and 0x10 or 0),"u64")
    end
end

-- Read-only equivalent of CBBA20 -> 14BB0B0 -> 14B8060. Require an exact
-- native ID match; the game's missing-ID fallback to its first record is unsafe
-- for speech. Names come from the current database, not a hardcoded country map.
function a11y.country_name(id)
    local base=tonumber(process_base_u64)
    local manager=base and a11y.menu_read(base+0x3705e10,"u64")
    local database=manager and a11y.menu_read(manager+0x48,"u64")
    local count=database and a11y.menu_read(database+0x184b5e0,"u32")
    if not count or count<1 or count>512 then return nil end
    local low,high=0,count
    local first=database+0x1843f20
    while low<high do
        local mid=math.floor((low+high)/2)
        local packed=a11y.menu_read(first+mid*0x4c+0x48,"u32")
        if not packed then return nil end
        if packed%512<id then low=mid+1 else high=mid end
    end
    if low>=count then return nil end
    local record=first+low*0x4c
    local packed=a11y.menu_read(record+0x48,"u32")
    if not packed or packed%512~=id then return nil end
    local text=a11y.read_native_c_string(record,0x48)
    return text and text~="" and clean_text(text) or nil
end

function a11y.native_country_selection()
    local base=tonumber(process_base_u64)
    local snapshot=a11y.native_windows
    if not base or not snapshot then return nil end
    local work=a11y.render_read_work
    if work and work.country_selection~=nil then return work.country_selection or nil end
    local found
    for _,window in ipairs(snapshot.windows or {}) do
        local at=window.address
        local vt=window.enabled and a11y.menu_read(at,"u64")
        if vt==base+0x271f4d0 and a11y.menu_read(vt+0xd8,"u64")==base+0xc9d990
                and a11y.menu_read(vt+0x268,"u64")==base+0xc97190
                and a11y.menu_read(at+0x9b,"u8")==1 then
            local first,last=a11y.menu_read(at+0x100,"u64"),a11y.menu_read(at+0x108,"u64")
            local scroll,index=a11y.menu_read(at+0x118,"u32"),a11y.menu_read(at+0x11c,"u32")
            if first and first>=0x10000 and last and last>=first and (last-first)%0x70==0
                    and last-first<=512*0x70 and scroll and index and scroll+index<(last-first)/0x70 then
                local parent=first+(scroll+index)*0x70
                local special=a11y.menu_read(at+0x180,"u8")
                local category=a11y.menu_read(parent,"u32")
                local text,record
                if special==0 and category and category<=4 then
                    local id,cell=a11y.filtered_country_id(at,parent)
                    text,record=id and a11y.country_name(id),cell
                elseif special~=nil then
                    local children,finish=a11y.menu_read(parent+8,"u64"),a11y.menu_read(parent+0x10,"u64")
                    local offset,selected=a11y.menu_read(parent+0x64,"u32"),a11y.menu_read(parent+0x68,"u32")
                    if children and children>=0x10000 and finish and finish>=children and (finish-children)%0x50==0
                            and finish-children<=512*0x50 and offset and selected and offset+selected<(finish-children)/0x50 then
                        record=children+(offset+selected)*0x50
                        text=a11y.read_msvc_string(record+0x28)
                    end
                end
                if text and not a11y.empty_selection_caption(text) then
                    if found then return nil end
                    found={text=text,native_only=true,
                        identity="country:" .. at .. ":" .. window.root .. ":" .. parent .. ":" .. record}
                end
            end
        end
    end
    if work then work.country_selection=found or false end
    return found
end

function a11y.poll_native_country_selection()
    local context=a11y.read_context_state()
    if context.kind=="dialog" and (context.structural_question or context.structural_event or not a11y.native_country_active()) then return end
    local item=a11y.native_list_selection
    local current=a11y.native_country_selection()
    if current then
        if current.native_only then
            if not item or item.identity~=current.identity or item.text~=current.text then
                a11y.native_list_selection={text=current.text,identity=current.identity,native_only=true,observed=frame}
            end
        else a11y.observe_native_list_selection(current.text,current.identity,current.widget) end
        a11y.native_list_selection.country=true
    elseif a11y.native_list_selection and a11y.native_list_selection.country then
        a11y.native_list_selection=nil
    end
end

function a11y.native_list_delivery_allowed(origin)
    local item=a11y.native_list_selection
    if item and item.country then
        local current=a11y.native_country_selection()
        if not current or current.identity~=item.identity or current.text~=item.text then return false end
        if item.native_only then
            return item.identity==origin.identity and item.text==origin.text and a11y.native_owner_token()==origin.owner
        end
    end
    return item and item.identity==origin.identity and item.text==origin.text
        and item.widget==origin.widget and a11y.native_owner_token()==origin.owner
end

function a11y.native_country_active()
    local base=tonumber(process_base_u64)
    if not base then return false end
    for _,window in ipairs(a11y.native_windows and a11y.native_windows.windows or {}) do
        if window.enabled and (window.vtable or a11y.menu_read(window.address,"u64"))==base+0x271f4d0
                and a11y.menu_read(window.address,"u64")==base+0x271f4d0
                and a11y.menu_read(window.address+0x9b,"u8")==1 then return true end
    end
    return false
end

function a11y.process_native_list_focus(modal_blocked)
    local item=a11y.native_list_selection
    local context=a11y.read_context_state()
    if item and (item.nested or item.country) and context.kind=="dialog" and not context.structural_question and not context.structural_event
            and a11y.native_country_active() then
        a11y.reset_read_context("native-nested-selection")
        modal_focus_hold_until_ms=0;modal_blocked=false
        a11y.screen_title_hold_until_ms=0
    end
    if not item or (not item.committed and frame-(item.observed or -10000)>120) or modal_blocked or a11y.keyboard_window
            or a11y.read_context_state().kind=="dialog" then return false end
    if item.country and item.native_only then
        local current=a11y.native_country_selection()
        if not current or current.identity~=item.identity or current.text~=item.text then return false end
        local identity=(a11y.native_owner_token() or "") .. ":" .. item.identity .. ":" .. item.text
        if item.committed~=identity and item.speech_status~="failed-content" then
            a11y.commit_read_selection(item.text,identity,"native-list")
            local before=a11y.native_speech_last
            item.attempt=(item.attempt or 0)+1
            speak(item.text,true,true,"native-country:" .. identity .. ":" .. item.attempt)
            for index=before+1,a11y.native_speech_last do
                a11y.native_speech_queue[index].native_list={identity=item.identity,text=item.text,owner=a11y.native_owner_token(),state=item}
                item.committed=identity
            end
        end
        return true
    end
    local snapshot=a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[item.widget]
    if not member or not member.active or not a11y.native_presentation_ready(item.widget) then return false end
    if snapshot.cursor_members and snapshot.cursor_members[item.widget]
            and not snapshot.selected_members[item.widget] then return false end
    if (item.name and a11y.widget_internal_name(item.widget)~=item.name)
            or (item.link and a11y.ui_owner_link(item.widget)~=item.link) then
        a11y.native_list_selection=nil;return false
    end
    -- Callbacks capture data before setters finish. Verify the actual rendered
    -- caption in the frame, then let this native component own its selection.
    local text=a11y.read_native_rendered_text(item.widget)
    if text~=item.text then
        if frame-item.observed>120 then a11y.native_list_selection=nil;return false end
        return true -- wait; a cached old caption cannot take over
    end
    local owner=a11y.native_owner_token()
    if not owner then return false end
    local identity=owner .. ":" .. item.identity .. ":" .. text
    if tonumber(ffi.C.GetTickCount64())<(a11y.screen_title_hold_until_ms or 0) then return true end
    local node=a11y.ui_model and a11y.ui_model.nodes[memory.hex(item.widget)]
    if not node or node.text~=text then a11y.on_observed_ui_text(item.widget,text,text,nil,true) end
    local before=a11y.native_speech_last
    a11y.deliver_selection_result(a11y.selection_result({text=text,widget=item.widget,
        identity=identity,source="native-list"}),{interrupt=true})
    if a11y.native_speech_last>before then
        item.committed=identity
        for index=before+1,a11y.native_speech_last do
            a11y.native_speech_queue[index].native_list={identity=item.identity,text=text,widget=item.widget,owner=owner,state=item}
        end
        log(string.format("[FLAccess] native-list-commit text=%q widget=%s",text,memory.hex(item.widget)))
    end
    return true
end

-- The league/team carousel renders nine records around its selection. At this
-- call site r13 is the visible-cell index (0..8) and r15 is the corresponding
-- data record. Cell 4 is the real selected record, independent of scroll
-- direction and of the widget addresses recycled by the UI.
function m.on_list_item_render(ctx, event_id, registers)
    if a11y.read_context_state().kind == "dialog" then return end
    local visible_index = tonumber(read_u64(registers.r13))
    if visible_index ~= 4 then
        return
    end

    local record = tonumber(read_u64(registers.r15))
    if not record or record < 0x10000 or not readable(record + 0x20, 0x20) then
        return
    end

    local text = a11y.read_msvc_string(record + 0x20)
    if not text or text == "" or is_noninteractive_text(text) then
        return
    end
    if a11y.game_plan_context == "Configurações táticas básicas"
            or a11y.game_plan_context == "Basic Tactical Settings"
            or a11y.game_plan_edit_contexts[a11y.game_plan_context] then
        -- This renderer is shared by carousels and game-plan background
        -- lists. Tactical headings and player headings are authoritative.
        return
    end
    local formation_context = a11y.game_plan_context == "Alterar formação"
        or a11y.game_plan_context == "Change Formation"
    local formation_inside = text:match("%((.-)%)")
    local compact_formation = formation_inside
        and formation_inside:gsub("%s+", "") or nil
    local formation_value = (compact_formation
            and compact_formation:match("^%d[%d%-]+$"))
        or text:match("^%d[%d%-]+$")
    if a11y.game_plan_active and formation_context and formation_value then
        a11y.game_plan_formation_active = true
    elseif a11y.game_plan_active then
        -- Both teams' formations are permanently rendered on the normal Game
        -- Plan pitch. They are display data, not the focused bottom command.
        return
    end

    -- r12 is the exact text node assigned immediately before c97408.
    a11y.observe_native_list_selection(text,"list:" .. memory.hex(record),tonumber(read_u64(registers.r12)))
end

-- Shared nested-carousel caption setter. Here RSI is the selected 0x50 child
-- record and RDI is its actual kind-19 text node. Capture before the setter;
-- process_native_list_focus verifies the rendered copy after it completes.
function m.on_nested_list_caption(ctx,event_id,registers)
    local context=a11y.read_context_state()
    if context.kind=="dialog" and (context.structural_question or context.structural_event or not a11y.native_country_active()) then return end
    local record=tonumber(read_u64(registers.rsi))
    local widget=tonumber(read_u64(registers.rdi))
    if not record or record<0x10000 or not widget or widget<0x10000 then return end
    local text=a11y.read_msvc_string(record+0x28)
    if text and not a11y.empty_selection_caption(text) then
        a11y.observe_native_list_selection(text,"nested-list:" .. memory.hex(record),widget)
        a11y.native_list_selection.nested=true
    end
end

-- Club selection uses a separate nine-cell renderer. r14 is its visible-cell
-- index and the game itself treats cell 4 as selected. Both native and
-- alternate/modded club-name branches build the displayed MSVC string in the
-- same stack slot immediately before assigning it to the UI widget.
function m.on_team_item_text(ctx, event_id, registers)
    if a11y.read_context_state().kind == "dialog" then return end
    local visible_index = tonumber(read_u64(registers.r14))
    if visible_index ~= 4 then
        return
    end

    local saved_rbp = tonumber(read_u64(registers.rbp))
    if not saved_rbp or saved_rbp < 0x10000 then
        return
    end
    local text = a11y.read_msvc_string(saved_rbp - 0x19)
    if not text or text == "" or is_noninteractive_text(text) then
        return
    end
    if a11y.game_plan_active then
        return
    end

    -- Both string branches pass this rdi node to e48bf0 after the hook.
    a11y.observe_native_list_selection(text,"team:" .. text,tonumber(read_u64(registers.rdi)))
end

function m.on_player_record_copy(ctx, event_id, registers)
    local operation = tonumber(ffi.cast("uint32_t", read_u64(registers.rax)))
    if operation == 2 then
        a11y.capture_player_record(read_u64(registers.rdx), "copy")
    end
end

function m.on_player_record_lookup(ctx, event_id, registers)
    a11y.capture_player_record(read_u64(registers.rax), "lookup")
end

