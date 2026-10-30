function m.on_resolved_text(ctx, event_id, registers)
    local source = read_u64(registers.rax)
    local length = tonumber(read_u64(registers.r8))
    if not source or not length or length < 1 or length > 512 then
        return
    end

    local text=a11y.safe_memory_read(source,length)
    if not text then return end
    local zero = text:find("\0", 1, true)
    if zero then
        text = text:sub(1, zero - 1)
    end

    -- At this hook location, Sider's saved RSP is 64 bytes below the
    -- localization resolver caller's return address.
    local saved_rsp = read_u64(registers.rsp)
    local return_address=saved_rsp and read_u64(a11y.safe_memory_read(saved_rsp+64,8))
    if not return_address then return end
    local caller_rva = tonumber(return_address - process_base_u64)
    local text_id = tonumber(ffi.cast("uint32_t", read_u64(registers.rdi)))
    local resolved_text = clean_text(text)
    if resolved_text == "No String" or resolved_text == "/" then return end
    a11y.remember_player_style_text(text_id,resolved_text)
    a11y.detect_ui_language(resolved_text)
    -- Localization resolves words for hidden and future screens as well.
    -- Resolution alone must not open a dialog or announce a skip command.
    if caller_rva == 0xb22537 and resolved_text ~= "" then
        language_options[resolved_text] = true
    end
    local is_football_life_tooltip_part = text_id==13107593 or text_id==13107596
    -- The project description is passive information. Do not enqueue it as
    -- an automatic main-menu choice or make it hold navigation speech.
    if controller_labels[resolved_text] then
        local label = resolved_text
        local row = controller_rows[label] or {}
        controller_rows[label] = row
    end
    local controller_label = controller_tooltip_labels[text_id]
    if text_id == 13238441 then
        if active_controller_label == "Condição: Em casa" then
            controller_label = "Condição: Fora"
        else
            controller_label = "Condição: Em casa"
        end
    end
    if controller_label then
        active_controller_label = controller_label
        local row = controller_rows[controller_label]
        local value = controller_tooltip_values[text_id]
        if not value and row then
            value = row.value
        end
        announce_controller_row(controller_label, value)
        if a11y.read_tooltips then
            pending_controller_tooltip = clean_text(text)
            pending_controller_tooltip_label = controller_label
            controller_tooltip_due_ms = tonumber(ffi.C.GetTickCount64())
        end
    end
    if caller_rva == 0xe4901d then
        local widget=read_u64(a11y.safe_memory_read(saved_rsp+72,8))
        local spoken = clean_text(text)
        if widget >= 0x10000 and spoken ~= "" then
            local widget_key = memory.hex(widget)
            a11y.observe_ui_widget(widget,spoken)
            local previous_widget_text = standard_text_by_widget[widget_key]
            standard_text_by_widget[widget_key] = spoken
            local now_ms = tonumber(ffi.C.GetTickCount64())
            local is_game_plan_tactical_tooltip =
                a11y.game_plan_active
                and a11y.game_plan_active_tactical_label
                and frame - a11y.game_plan_active_tactical_frame <= 90
                and #spoken >= 35
                and not a11y.is_instruction_message(spoken)
                and not is_noninteractive_text(spoken)
            local is_active_tooltip = a11y.is_control_help(spoken)
                or is_game_plan_tactical_tooltip
                or (not a11y.is_instruction_message(spoken)
                    and active_control_row
                    and active_control_row.label_widget
                    and widget ~= active_control_row.label_widget
                    and now_ms - active_control_focused_ms <= 5000
                    and #spoken >= 35
                    and not is_noninteractive_text(spoken))
            if previous_widget_text ~= spoken then
                -- This localization call has a verified widget argument.
                -- Defer bound messages written before their window activates,
                -- just as the direct UI setter does.
                a11y.defer_bound_guidance(widget,spoken)
                announce_screen_title(spoken, widget_key, widget)
                -- Help for the focused control is a tooltip, not a modal
                -- message. Keep it out of the message queue so disabling
                -- tooltip reading suppresses every route to speech.
                if not is_active_tooltip then
                    remember_message_text(spoken, widget_key)
                end
                if not queue_startup_text(spoken, now_ms)
                        and is_plain_text(spoken)
                        and not is_noninteractive_text(spoken) then
                    speak(spoken,nil,nil,nil,widget)
                end
            end
            if is_modal_button(spoken) then
                last_modal_button_frame = frame
                register_dialog_option(spoken, widget, widget_key)
                if spoken ~= "OK" or not instruction_message_locked then
                    queue_recent_message()
                end
            end
            if a11y.read_tooltips and #spoken >= 35 and not is_noninteractive_text(spoken) then
                latest_generic_tooltip = spoken
                latest_generic_tooltip_widget = widget
                latest_generic_tooltip_ms = now_ms
            end
            if a11y.read_tooltips and is_active_tooltip then
                pending_controller_tooltip = spoken
                pending_controller_tooltip_label =
                    is_game_plan_tactical_tooltip
                        and a11y.game_plan_active_tactical_label
                        or (active_control_row and active_control_row.label)
                a11y.set_read_help(spoken, pending_controller_tooltip_label)
                active_controller_label = pending_controller_tooltip_label
                controller_tooltip_due_ms =
                    now_ms
            end
            if #spoken <= 60 and not audio_ids[text_id]
                    and not (a11y.widget_internal_name(widget) or ""):match("_value$")
                    and not non_control_labels[spoken]
                    and (controller_labels[spoken]
                        or not spoken:match("[%.%!%?]$"))
                    and not is_noninteractive_text(spoken)
                    and not is_splash_text(spoken)
                    and not looks_like_message(spoken, widget)
                    and not is_active_tooltip then
                local candidate_row = register_control_label(
                    spoken,
                    widget,
                    selector_role(spoken),
                    controller_labels[spoken] or false)
                bind_delayed_speed_slider(candidate_row)
            end
            if featured_initial_ids[text_id] or text_id==13107593 then
                main_menu_title_widget_key = widget_key
            end
            local is_main_menu_title = main_menu_title_widget_key == widget_key
                and ((text_id >= 60948000 and text_id <= 60949000) or text_id==13107593)
            if is_main_menu_title and (previous_widget_text ~= spoken
                    or featured_initial_ids[text_id]) then
                local is_initial_featured = featured_initial_ids[text_id]
                    and previous_widget_text == nil
                reset_navigation_generation()
                a11y.observe_ui_widget(widget,spoken)
                startup_complete = true
                startup_completed_frame = frame
                main_menu_focus_guard_until = frame + 4
                current_main_menu_title = spoken
                a11y.set_read_title(spoken)
                -- Speak now for navigation and retain a short fallback for the
                -- first main-menu frame, which can arrive just before Windows
                -- reports the game as foreground. Duplicate suppression keeps
                -- this from speaking twice during ordinary navigation.
                local title_needs_retry = not a11y.game_is_foreground()
                dynamic_text_candidate = title_needs_retry
                    and spoken .. ", item" or nil
                a11y.dynamic_text_origin=title_needs_retry and a11y.capture_speech_origin(widget) or nil
                dynamic_text_due_ms = title_needs_retry
                    and tonumber(ffi.C.GetTickCount64()) + 250 or nil
                main_menu_tooltip = nil
                main_menu_tooltip_due_ms = nil
                log(string.format(
                    "[FLAccess] main-menu-title widget=%s previous=%q text=%q",
                    widget_key,
                    previous_widget_text or "",
                    spoken))
                if not title_needs_retry then a11y.present_main_menu_choice(widget,spoken) end
            elseif main_menu_title_widget_key and not is_football_life_tooltip_part
                    and text_id >= 13107000 and text_id <= 13108000 then
                if a11y.read_tooltips then
                    main_menu_tooltip = spoken
                    a11y.main_menu_tooltip_choice=a11y.main_menu_choice_state
                    main_menu_tooltip_due_ms =
                        tonumber(ffi.C.GetTickCount64())
                end
            end
            if frame - last_widget_frame > 12 and widget_count > 0 then
                trace_log(string.format(
                    "[FLAccess] widget-generation-gap gap=%d",
                    frame - last_widget_frame))
            end
            last_widget_frame = frame
            local previous = widgets[text_id]
            if not previous then
                widget_count = widget_count + 1
            end
            widgets[text_id] = {
                address = widget,
                text = spoken,
                last_seen = frame,
            }
            if audio_ids[text_id] then
                last_audio_id = text_id
            end
            if not previous or previous.address ~= widget then
                trace_log(string.format(
                    "[FLAccess] widget id=%u text=%q address=%s",
                    text_id,
                    spoken,
                    memory.hex(widget)))
            end
        end
    end

    local key = tostring(text_id) .. "\0" .. text
    if seen[key] then
        return
    end
    seen[key] = true
    unique_count = unique_count + 1
    if unique_count > 4000 then
        return
    end
    trace_log(string.format(
        "[FLAccess] resolved id=%u text=%q length=%d caller_rva=%s",
        text_id,
        text,
        length,
        memory.hex(caller_rva)))
end

local function scan_dialog_focus()
    local yes = dialog_options["Sim"]
    local no = dialog_options["Não"]
    if not a11y.dialog_option_allowed(yes) or not a11y.dialog_option_allowed(no) then return nil,nil end
    if not yes or not no or yes.key == no.key
            or math.abs(yes.last_seen - no.last_seen) > 3
            or frame - math.max(yes.last_seen, no.last_seen) > 900 then
        return nil, nil
    end
    local function selected_at(offset)
        if not readable(yes.address + offset, 4)
                or not readable(no.address + offset, 4) then
            return nil
        end
        local yes_value = memory.unpack(
            "u32", memory.read(yes.address + offset, 4))
        local no_value = memory.unpack(
            "u32", memory.read(no.address + offset, 4))
        if yes_value == 1 and no_value ~= 1 then
            return "Sim"
        elseif no_value == 1 and yes_value ~= 1 then
            return "Não"
        end
        return nil
    end
    if dialog_preferred_offset then
        local selected = selected_at(dialog_preferred_offset)
        if selected then
            return selected, dialog_preferred_offset
        end
    end
    for _, offset in ipairs(dialog_focus_offsets) do
        local selected = selected_at(offset)
        if selected then
            return selected, offset
        end
    end
    return nil, nil
end

function a11y.dialog_option_allowed(option)
    return option and (not option.native_owner or option.native_owner==""
        or option.native_owner==a11y.native_owner_token())
        and a11y.native_presentation_ready(option.address)
end

local function dialog_is_active()
    local yes = dialog_options["Sim"]
    local no = dialog_options["Não"]
    return yes and no and yes.key ~= no.key
        and a11y.dialog_option_allowed(yes) and a11y.dialog_option_allowed(no)
        and math.abs(yes.last_seen - no.last_seen) <= 3
        and frame - math.max(yes.last_seen, no.last_seen) <= 900
end

function a11y.dismiss_dialog_for_focus(
        dialog_active, modal_focus_blocked, selected_entry, selected_activity)
    if not dialog_active or not selected_entry
            or is_modal_button(selected_entry.text) then
        return dialog_active, modal_focus_blocked, false
    end
    local yes = dialog_options["Sim"]
    local no = dialog_options["Não"]
    local last_button_seen = math.max(
        yes and yes.last_seen or -1,
        no and no.last_seen or -1)
    if not selected_activity or selected_activity <= last_button_seen + 3 then
        return dialog_active, modal_focus_blocked, false
    end

    -- Football Life leaves the old Sim/Não objects and their focus bits alive
    -- after closing this confirmation. A freshly activated non-button belongs
    -- to the destination screen and is the reliable dismissal signal.
    dialog_options = {}
    dialog_signature = nil
    dialog_preferred_offset = nil
    dialog_focus_candidate = nil
    dialog_focus_candidate_since = 0
    last_dialog_announcement = nil
    a11y.confirmation_dialog_until_frame = 0
    a11y.dialog_button_queued_for_message = false
    modal_focus_hold_until_ms = 0
    log(string.format(
        "[FLAccess] dialog-dismissed destination=%q",
        selected_entry.text))
    return false, false, true
end

local function process_dialog_focus(modal_focus_blocked, queue_after_message)
    if frame % 2 ~= 0
            or (modal_focus_blocked and not queue_after_message) then
        return
    end
    local dialog_selected, dialog_offset = scan_dialog_focus()
    local candidate = dialog_selected and
        (dialog_signature .. ":" .. dialog_selected) or nil
    if candidate ~= dialog_focus_candidate then
        dialog_focus_candidate = candidate
        dialog_focus_candidate_since = frame
    elseif candidate and frame - dialog_focus_candidate_since >= 4
            and candidate ~= last_dialog_announcement then
        last_dialog_announcement = candidate
        dialog_preferred_offset = dialog_offset
        log(string.format(
            "[FLAccess] dialog-focus offset=0x%x text=%q",
            dialog_offset,
            dialog_selected))
        local should_queue = queue_after_message
            and not a11y.dialog_button_queued_for_message
        a11y.commit_read_selection(dialog_selected .. ", botão selecionado",
            candidate, "dialog-answer")
        speak(dialog_selected .. ", botão selecionado", not should_queue)
        if should_queue then
            a11y.dialog_button_queued_for_message = true
        end
    end
end

