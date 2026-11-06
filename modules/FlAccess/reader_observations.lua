-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 11, "FLAccess reader: missing or reordered component observations")
    assert(shared.a11y.lists_ready,"reader_lists must precede observations")
function shared.a11y.on_observed_ui_text(widget,text,raw,registers,review)
    if not text or not widget or widget < 0x10000 then
        return
    end
    if text == "" then
        local empty_key = memory.hex(widget)
        for index = #(shared.a11y.dashboard_texts or {}), 1, -1 do
            if shared.a11y.dashboard_texts[index].address == widget then
                table.remove(shared.a11y.dashboard_texts, index)
            end
        end
        shared.a11y.forget_ui_widget(empty_key)
        shared.ui_text_by_widget[empty_key] = nil
        if shared.last_selected_ui_entry and shared.last_selected_ui_entry.address == widget then
            shared.a11y.reset_focus_reuse_state()
        end
        return
    end
    if text == "No String" or text == "/" then
        -- Construction placeholders are neither a surface change nor focus.
        -- Clearing all ownership here used to erase freshly mapped sliders.
        shared.a11y.forget_ui_widget(memory.hex(widget))
        shared.ui_text_by_widget[memory.hex(widget)] = nil
        return
    end

    local widget_key = memory.hex(widget)
    local observed_node = shared.a11y.observe_ui_widget(widget, text)
    observed_node.raw_text=raw or text
    if shared.a11y.unresolved_format(text) then return end
    shared.a11y.poll_native_windows()
    if not shared.a11y.selection_diagnostic or review then shared.a11y.record_dashboard_text(observed_node) end
    local main_state=shared.a11y.main_menu_choice_state
    local bound_main=observed_node.name=="text_item" and main_state
        and main_state.address==tonumber(widget)
        and shared.a11y.main_menu_choice_active(main_state)
    if shared.a11y.main_menu_text_owner(observed_node) or bound_main then
        if not review and observed_node.name=="text_item" then
            shared.main_menu_title_widget_key=observed_node.key
            shared.a11y.present_main_menu_choice(widget,text)
        end
        return
    end
    if review then
        shared.a11y.capture_structural_control(widget,text)
        return
    end
    local snapshot=shared.a11y.native_windows
    local selected=snapshot and snapshot.selected_members or {}
    local row=shared.a11y.control_for_widget(widget_key)
    local current_value=row and row.label_widget and selected[tonumber(row.label_widget)]
    local context=shared.a11y.read_context_state()
    local name=observed_node.name or ""
    local contextual=name=="question" or name=="eventMsg" or name=="text_contents"
        or name=="messageBody" or name=="bodyText" or name=="title" or name=="text_title" or name=="headline"
    if not review and snapshot and snapshot.selection_only and context.kind~="dialog"
            and not selected[tonumber(widget)] and not current_value and not contextual then
        -- Retain the actual text/name for future selection and exploration.
        -- Off-selection redraws do not rebuild controls or publish focus.
        shared.a11y.passive_text_observations=(shared.a11y.passive_text_observations or 0)+1
        return
    end
    shared.a11y.active_text_observations=(shared.a11y.active_text_observations or 0)+1

    -- Input feedback is owned by the actual native input node. A retained
    -- textWord from the background is not an edit event.
    if observed_node.name == "padIcon" then return end
    local structural_prompt = shared.a11y.capture_question_panel(observed_node)
    if not structural_prompt and shared.a11y.capture_reading_panel(observed_node) then return end
    if shared.a11y.diagnostic_mode and registers then
        local saved_rsp = shared.read_u64(registers.rsp)
        if saved_rsp and shared.readable(saved_rsp + 64, 8) then
            local return_address = shared.read_u64(memory.read(saved_rsp + 64, 8))
            local caller_number = tonumber(return_address)
            local base_number = tonumber(shared.process_base_u64)
            if caller_number and base_number and caller_number >= base_number
                    and caller_number < base_number + 0x40000000 then
                shared.a11y.ui_text_caller_by_widget[widget_key] =
                    caller_number - base_number
            else
                shared.a11y.ui_text_caller_by_widget[widget_key] = nil
            end
        end
    end
    local previous = shared.ui_text_by_widget[widget_key]
    shared.ui_text_by_widget[widget_key] = text
    if previous ~= text then
        shared.a11y.announce_skip_hint(text, observed_node)
    end
    if not shared.a11y.cup_group_table_active
            and shared.a11y.is_cup_group_header(widget, text) then
        -- Captured headers arrive before the trailing grid OK and before the
        -- explanatory paragraph. Identify the table while that OK is still
        -- a background cell, not after it has already reached speech.
        shared.a11y.activate_cup_group_table(false)
    end
    local tactical_heading, game_plan_player_heading =
        shared.a11y.observe_compatibility_context(widget_key, text)
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if shared.a11y.game_plan_active
            and (text == "Altura (cm)" or text == "Height (cm)") then
        local panel_was_closed = now_ms > shared.a11y.game_plan_attribute_panel_until_ms
        shared.a11y.game_plan_attribute_last_marker_frame = shared.frame
        local opened_by_y = shared.a11y.diagnostic_last_input_action == "Y"
            and shared.frame - shared.a11y.diagnostic_last_input_frame <= 90
            and shared.a11y.game_plan_selected_heading ~= nil
        if panel_was_closed and opened_by_y then
            shared.a11y.game_plan_attribute_locked_name =
                shared.a11y.normalized_player_name(
                    shared.a11y.game_plan_selected_heading
                        or shared.a11y.game_plan_last_focus_text)
            shared.a11y.game_plan_player_record = nil
            shared.a11y.game_plan_player_name =
                shared.a11y.game_plan_attribute_locked_name
            shared.a11y.game_plan_player_attributes = {}
            local player = shared.a11y.player_for_text(
                shared.a11y.game_plan_attribute_locked_name)
            if player then
                shared.a11y.game_plan_player_record = player.pointer
                shared.a11y.game_plan_player_name =
                    shared.a11y.game_plan_attribute_locked_name or player.name
                shared.a11y.game_plan_player_attributes = player.attributes
            end
            shared.a11y.game_plan_attribute_due_ms = nil -- details are requested through exploration
            shared.a11y.game_plan_attribute_opened_ms = now_ms
        end
        if opened_by_y then
            shared.a11y.game_plan_attribute_panel_until_ms = now_ms + 30000
        end
    end
    local tooltip_control_label = shared.control_label_from_tooltip(text)
    -- A pause between text writes is not a new focus. The same Informações
    -- widget can redraw after a pause while the selection never moved.
    if previous ~= text and not shared.a11y.native_presentation_ready(widget) then
        local title = shared.is_screen_title(text,widget)
        local role = shared.a11y.text_asset_role(text)
        if title or ((shared.a11y.is_instruction_message(text) or shared.looks_like_message(text,widget))
                and not shared.a11y.is_control_help(text)) then
            shared.a11y.defer_bound_guidance(widget,text)
        end
    end
    if previous ~= text and shared.a11y.native_presentation_ready(widget) then
        shared.announce_screen_title(text, widget_key, widget)
        local tactical_tooltip = shared.a11y.game_plan_active
            and shared.a11y.game_plan_active_tactical_label
            and shared.frame - shared.a11y.game_plan_active_tactical_frame <= 90
            and shared.looks_like_message(text, widget)
            and not shared.a11y.is_instruction_message(text)
            and not tactical_heading
        if tactical_tooltip then
            if shared.a11y.read_tooltips then
                shared.pending_controller_tooltip = text
                shared.pending_controller_tooltip_label =
                    shared.a11y.game_plan_active_tactical_label
                shared.active_controller_label =
                    shared.a11y.game_plan_active_tactical_label
                shared.controller_tooltip_due_ms = now_ms
            end
        elseif tooltip_control_label or shared.a11y.is_control_help(text) then
            shared.focused_control_hint = tooltip_control_label
            shared.focused_control_hint_ms = now_ms
            shared.latest_generic_tooltip = text
            shared.latest_generic_tooltip_widget = widget
            shared.latest_generic_tooltip_ms = now_ms
            shared.a11y.set_read_help(text, tooltip_control_label)
            if shared.a11y.read_tooltips then
                shared.pending_controller_tooltip = text
                shared.pending_controller_tooltip_label = tooltip_control_label
                    or shared.active_controller_label
                shared.controller_tooltip_due_ms = now_ms
            end
        elseif not game_plan_player_heading and not tactical_heading and not structural_prompt then
            shared.remember_message_text(text, widget_key)
        end
        if not shared.queue_startup_text(text, now_ms)
                and shared.is_plain_text(text)
                and not shared.is_noninteractive_text(text) then
            shared.speak(text)
        end
        if #text >= 4 and #text <= 50
                and not shared.is_modal_button(text)
                and not shared.is_plain_text(text)
                and not shared.is_splash_text(text)
                and not shared.is_noninteractive_text(text)
                and not text:match("^Usuário %d+$") then
            shared.recent_heading_text = text
            shared.recent_heading_frame = shared.frame
        end
    end
    if shared.is_modal_button(text) then
        shared.last_modal_button_frame = shared.frame
        if text ~= "OK" or not shared.instruction_message_locked then
            shared.queue_recent_message()
        end
    end
    if text == "Sim" or text == "Não" then
        shared.register_dialog_option(text, widget, widget_key)
    end
    local structural_node = shared.a11y.ui_model and shared.a11y.ui_model.nodes[widget_key]
    if #text >= 2 and (#text <= 50 or (#text <= 160
            and structural_node and structural_node.role == "control-label")
            or (shared.a11y.read_context_state().kind == "dialog" and #text <= 512
                and text ~= shared.a11y.read_context.question
                and widget_key ~= shared.a11y.read_context.message_key
                and (shared.a11y.is_structural_answer(text,widget_key) or
                    (shared.a11y.text_asset_role(text) ~= "dialog" and shared.a11y.text_asset_role(text) ~= "instruction"))))
            and not text:find("%%") and not text:match("^%d+$")
            and text ~= "-" and text:match("[%w]")
            and not shared.is_noninteractive_text(text)
            and shared.a11y.widget_internal_name(widget) ~= "title"
            and shared.a11y.widget_internal_name(widget) ~= "text_title"
            and widget_key ~= shared.main_menu_title_widget_key
            and text ~= shared.main_menu_tooltip
            and text ~= shared.pending_controller_tooltip then
        local previous_focus = shared.ui_focus_widgets[widget_key]
        if shared.a11y.focus_widget_reused(previous_focus, text) then
            shared.a11y.reset_focus_reuse_state()
        end
        if not shared.ui_focus_widgets[widget_key] then
            if shared.ui_focus_widget_count >= 300 then
                local oldest_key
                local oldest_frame = shared.frame + 1
                for candidate_key, candidate in pairs(shared.ui_focus_widgets) do
                    if (candidate.last_seen or 0) < oldest_frame then
                        oldest_key = candidate_key
                        oldest_frame = candidate.last_seen or 0
                    end
                end
                if oldest_key then
                    shared.a11y.forget_ui_widget(oldest_key)
                end
            end
            shared.ui_focus_widget_count = shared.ui_focus_widget_count + 1
        end
        shared.ui_focus_widgets[widget_key] = {
            address = widget,
            text = text,
            last_seen = shared.frame,
            identity = shared.a11y.observe_ui_widget(widget, text).identity,
        }
    end

    local label_row = shared.control_rows_by_label_widget[widget_key]
    if label_row and text ~= label_row.label then
        if label_row.value_widget_key
                and shared.control_row_by_value_widget[label_row.value_widget_key]
                    == label_row then
            shared.control_row_by_value_widget[label_row.value_widget_key] = nil
        end
        if shared.controller_rows[label_row.label] == label_row then
            shared.controller_rows[label_row.label] = nil
        end
        shared.control_rows_by_label_widget[widget_key] = nil
        if shared.active_control_row == label_row then
            shared.active_control_row = nil
        end
        label_row = nil
    end

    -- A field pair needs no localization ID, known caption, or screen name.
    label_row = shared.a11y.capture_structural_control(widget, text) or label_row
    local value_row
    local structural_row = shared.a11y.structural_control_row(widget)
    if structural_row and shared.attach_control_value(
            structural_row, widget, text) then
        value_row = structural_row
        shared.pending_control_row = nil
    elseif label_row and text == label_row.label then
        shared.pending_control_row = label_row
    elseif shared.active_control_row
            and not shared.active_control_row.native_slider
            and not shared.active_control_row.external_value
            and not shared.a11y.game_plan_active
            and now_ms - shared.active_control_focused_ms <= 500
            and widget ~= shared.active_control_row.label_widget
            and not label_row
            and shared.is_widget_focused(widget) then
        if shared.attach_control_value(shared.active_control_row, widget, text) then
            value_row = shared.active_control_row
        end
        shared.pending_control_row = nil
    elseif shared.pending_control_row and not shared.a11y.game_plan_active
            and shared.frame - (shared.pending_control_row.created_frame or shared.frame) <= 2
            and widget ~= shared.pending_control_row.label_widget then
        if shared.attach_control_value(shared.pending_control_row, widget, text) then
            value_row = shared.pending_control_row
        end
        shared.pending_control_row = nil
    else
        value_row = shared.control_row_by_value_widget[widget_key]
        if value_row and not value_row.native_slider then
            if not shared.attach_control_value(value_row, widget, text) then
                value_row = nil
            end
        elseif value_row and value_row.native_slider then
            value_row = nil
        end
    end
    local tactical_context = shared.a11y.game_plan_context ==
            "Configurações táticas básicas"
        or shared.a11y.game_plan_context == "Basic Tactical Settings"
    if value_row and shared.active_control_row == value_row and previous ~= text
            and not tactical_context then
        shared.announce_control_value(value_row, text)
    end

    local seen_key = widget_key .. "\0" .. text
    if not shared.ui_text_seen[seen_key] and shared.ui_text_unique_count < 6000 then
        shared.ui_text_seen[seen_key] = true
        shared.ui_text_unique_count = shared.ui_text_unique_count + 1
        shared.trace_log(string.format(
            "[FLAccess] ui-text widget=%s previous=%q text=%q",
            widget_key,
            previous or "",
            text))
    end

end

function shared.m.on_player_record_copy(ctx, event_id, registers)
    local operation = tonumber(ffi.cast("uint32_t", shared.read_u64(registers.rax)))
    if operation == 2 then
        shared.a11y.capture_player_record(shared.read_u64(registers.rdx), "copy")
    end
end

function shared.m.on_player_record_lookup(ctx, event_id, registers)
    shared.a11y.capture_player_record(shared.read_u64(registers.rax), "lookup")
end


    shared.stage = 12
end
function component.init(ctx)
    component.install(ctx)

end
return component
