-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 15, "FLAccess reader: missing or reordered component lifecycle")
function shared.a11y.overlay_text()
    local s = shared.a11y.strings()
    local tooltip = string.format(
        s.tooltip_option,
        shared.a11y.read_tooltips and s.yes or s.no)
    local diagnostic = string.format(
        s.diagnostic_option,
        shared.a11y.diagnostic_mode and s.yes or s.no)
    if shared.a11y.selected_option == 1 then
        tooltip = "---> " .. tooltip .. " <---"
    else
        diagnostic = "---> " .. diagnostic .. " <---"
    end
    return table.concat({
        string.format(s.title, shared.a11y.runtime_version),
        s.menu_reading,
        s.speech_output,
        tooltip,
        diagnostic,
        "",
        s.navigate_options,
        s.change_option,
        s.restore_defaults,
        s.close_sider,
        s.next_module,
        s.previous_module,
    }, "\n")
end

function shared.a11y.selected_option_text()
    local s = shared.a11y.strings()
    if shared.a11y.selected_option == 2 then
        return string.format(
            s.diagnostic_option,
            shared.a11y.diagnostic_mode and s.yes or s.no)
    end
    return string.format(
        s.tooltip_option,
        shared.a11y.read_tooltips and s.yes or s.no)
end

function shared.m.overlay_on(ctx)
    return shared.a11y.overlay_text()
end

function shared.m.show(ctx)
    shared.overlay_visible = true
    shared.pending_message_text = nil
    shared.pending_message_key = nil
    shared.pending_message_due_ms = nil
    shared.a11y.pending_modal_button_text = nil
    shared.a11y.modal_message_backlog = {}
    shared.a11y.deferred_modal_announcement = nil
    shared.a11y.clear_pending_tooltips()
    shared.dynamic_text_candidate = nil
    shared.dynamic_text_due_ms = nil
    local s = shared.a11y.strings()
    shared.speak(string.format(
        s.opened,
        shared.a11y.runtime_version,
        shared.a11y.selected_option_text()))
end

function shared.m.hide(ctx)
    shared.overlay_visible = false
    shared.sider_overlay_visible = false
end

function shared.m.global_key_down(ctx, vkey)
    if shared.a11y.buffer_key(vkey) then return end

end

function shared.m.global_gamepad_input(ctx, inputs)
    local vertical = inputs and inputs.RSy
    if vertical == 1 then
        shared.a11y.review_right_stick(-1)
    elseif vertical == -1 then
        shared.a11y.review_right_stick(1)
    elseif vertical == 0 then
        shared.a11y.review_right_stick(0)
    end
end

function shared.m.key_down(ctx, vkey)
    if shared.a11y.keyboard_window then return end
    if shared.a11y.buffer_key(vkey) then return end
    local s = shared.a11y.strings()
    if vkey == 0x20 then
        shared.overlay_visible = false
        shared.sider_overlay_visible = false
        return
    end
    if vkey == shared.a11y.previous_option_key then
        shared.a11y.selected_option = shared.a11y.selected_option - 1
        if shared.a11y.selected_option < 1 then
            shared.a11y.selected_option = shared.a11y.option_count
        end
        shared.speak(shared.a11y.selected_option_text())
        return
    elseif vkey == shared.a11y.next_option_key then
        shared.a11y.selected_option = shared.a11y.selected_option + 1
        if shared.a11y.selected_option > shared.a11y.option_count then
            shared.a11y.selected_option = 1
        end
        shared.speak(shared.a11y.selected_option_text())
        return
    end
    if vkey ~= shared.a11y.restore_key
            and vkey ~= shared.a11y.previous_value_key
            and vkey ~= shared.a11y.next_value_key then
        return
    end

    if shared.a11y.selected_option == 2 then
        local enabled = vkey ~= shared.a11y.restore_key and not shared.a11y.diagnostic_mode
        if not shared.a11y.set_diagnostic(enabled, "Sider panel") then
            shared.speak(s.diagnostic_failed)
            return
        end
        shared.speak(string.format(
            s.diagnostic_changed,
            shared.a11y.diagnostic_mode and s.yes or s.no))
        if shared.a11y.diagnostic_mode then
            shared.speak(s.diagnostic_file)
        end
        return
    end

    shared.a11y.read_tooltips = vkey == shared.a11y.restore_key
        and true or not shared.a11y.read_tooltips
    if not shared.a11y.read_tooltips then
        shared.a11y.clear_pending_tooltips()
    end
    shared.a11y.save_config()
    shared.speak(string.format(
        s.tooltip_changed,
        shared.a11y.read_tooltips and s.yes or s.no))
end

function shared.a11y.readable_sider_module(module_name)
    return tostring(module_name or shared.a11y.strings().module)
        :gsub("[\\/]", " ")
        :gsub("%.lua$", "")
        :gsub("[_%-]+", " ")
end

function shared.a11y.overlay_lines(text)
    local result = {}
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            result[#result + 1] = line
        end
    end
    return result
end

function shared.a11y.clean_overlay_line(line)
    local lower=tostring(line or ""):lower():gsub("^%-%-%->%s*","")
    if lower:match("^%s*[%w_ %-]*address%s*:") or lower:match("^%s*memory%s*:")
            or lower:match("^%s*endere[^:]*:") then return "" end
    return tostring(line or "")
        :gsub("%([^%)]*0[xX]%x+[^%)]*%)", "")
        :gsub("0[xX]%x+", "")
        :gsub("^%-%-%->%s*", "")
        :gsub("%s*<%-%-%-$", "")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

function shared.a11y.selected_overlay_line(text)
    for _, line in ipairs(shared.a11y.overlay_lines(text)) do
        if line:find("--->", 1, true) then
            return shared.a11y.clean_overlay_line(line)
        end
    end
    return nil
end

function shared.a11y.is_static_overlay_instruction(line)
    local lower = line:lower()
    return lower:match("^version%s") ~= nil
        or lower:match("^keys:") ~= nil
        or lower:match("^gamepad:") ~= nil
        or lower:match("^press%s") ~= nil
        or lower:match("commands:$") ~= nil
        or lower:find("subcommands:", 1, true) ~= nil
        or lower:find("to manually select", 1, true) ~= nil
        or lower:find("to set current", 1, true) ~= nil
        or lower:find("to use your favorite", 1, true) ~= nil
end

function shared.a11y.changed_overlay_text(previous, current)
    local previous_selected = shared.a11y.selected_overlay_line(previous)
    local current_selected = shared.a11y.selected_overlay_line(current)
    if current_selected and current_selected ~= previous_selected then
        return current_selected
    end

    local old_counts = {}
    for _, line in ipairs(shared.a11y.overlay_lines(previous)) do
        local clean = shared.a11y.clean_overlay_line(line)
        old_counts[clean] = (old_counts[clean] or 0) + 1
    end
    local changed = {}
    for _, line in ipairs(shared.a11y.overlay_lines(current)) do
        local clean = shared.a11y.clean_overlay_line(line)
        if old_counts[clean] and old_counts[clean] > 0 then
            old_counts[clean] = old_counts[clean] - 1
        elseif clean ~= "" and not shared.a11y.is_static_overlay_instruction(clean) then
            changed[#changed + 1] = clean
        end
    end
    if #changed == 0 then
        return current_selected
    end
    while #changed > 3 do
        table.remove(changed, 1)
    end
    return table.concat(changed, ". ")
end

function shared.a11y.full_overlay_text(text)
    local lines = shared.a11y.overlay_lines(text)
    for index, line in ipairs(lines) do
        lines[index] = shared.a11y.clean_overlay_line(line)
    end
    return table.concat(lines, ". ")
end

function shared.m.on_sider_overlay_content(ctx, module_name, text, visible)
    shared.sider_overlay_visible = visible == true
    if not visible then
        shared.overlay_visible = false
        shared.a11y.last_sider_overlay_module = nil
        shared.speak(shared.a11y.strings().closed)
        return
    end

    -- Our own panel is already announced by m.show, which also preserves
    -- compatibility with an unmodified Sider.
    if module_name == "FLAccess.lua" then
        shared.a11y.sider_overlay_text_by_module[module_name] = text
        shared.a11y.last_sider_overlay_module = module_name
        return
    end
    local source = tostring(module_name or "")
    local previous = shared.a11y.sider_overlay_text_by_module[source]
    local module_changed = source ~= shared.a11y.last_sider_overlay_module
    local announcement
    if previous == nil then
        announcement = shared.a11y.full_overlay_text(text)
    elseif previous ~= text then
        announcement = shared.a11y.changed_overlay_text(previous, text)
    elseif module_changed then
        announcement = shared.a11y.selected_overlay_line(text)
    end
    shared.a11y.sider_overlay_text_by_module[source] = text
    shared.a11y.last_sider_overlay_module = source

    local prefix = module_changed
        and (shared.a11y.strings().sider .. ". " .. shared.a11y.readable_sider_module(source)) or nil
    if prefix and announcement and announcement ~= "" then
        shared.speak(prefix .. ". " .. announcement)
    elseif prefix then
        shared.speak(prefix)
    elseif announcement and announcement ~= "" then
        shared.speak(announcement)
    end
end

function shared.a11y.reset_widget_tracking_state()
    shared.a11y.reset_ui_model()
    shared.widgets = {}
    shared.widget_count = 0
    shared.slider_rows = {}
    shared.slider_values = {}
    shared.unmapped_sliders = {}
    shared.ui_text_by_widget = {}
    shared.ui_focus_widgets = {}
    shared.ui_focus_widget_count = 0
    shared.ui_focus_state = {}
    shared.ui_focus_activated = {}
    shared.ui_focus_candidate_key = nil
    shared.ui_focus_candidate_since = 0
    shared.last_ui_focus_announcement = nil
    shared.ui_focus_preferred_offset_index = nil
    shared.last_selected_ui_entry = nil
end

function shared.a11y.reset_dialog_and_message_state()
    shared.dialog_options = {}
    shared.dialog_signature = nil
    shared.dialog_preferred_offset = nil
    shared.dialog_focus_candidate = nil
    shared.dialog_focus_candidate_since = 0
    shared.last_dialog_announcement = nil
    shared.reset_message_state()
end

function shared.a11y.reset_menu_tracking_state()
    shared.standard_text_by_widget = {}
    shared.dynamic_text_candidate = nil
    shared.dynamic_text_due_ms = nil
    shared.main_menu_title_widget_key = nil
    shared.current_main_menu_title = nil
    shared.main_menu_tooltip = nil
    shared.main_menu_tooltip_due_ms = nil
    shared.main_menu_focus_guard_until = 0
    shared.last_screen_title_key = nil
end

function shared.a11y.clear_control_tracking_state()
    shared.controller_rows = {}
    shared.control_rows_by_label_widget = {}
    shared.control_row_by_value_widget = {}
    shared.pending_control_row = nil
    shared.active_control_row = nil
    shared.active_control_focused_ms = 0
    shared.active_controller_label = nil
    shared.last_controller_announcement = nil
    shared.last_announced_control_row = nil
    shared.last_announced_selector_label = nil
    shared.pending_controller_tooltip = nil
    shared.pending_controller_tooltip_label = nil
    shared.controller_tooltip_due_ms = nil
    shared.last_spoken_controller_tooltip_key = nil
    shared.latest_generic_tooltip = nil
    shared.latest_generic_tooltip_widget = nil
    shared.latest_generic_tooltip_ms = 0
    shared.language_control_by_controller = {}
end

function shared.a11y.reset_control_tracking_state()
    shared.a11y.main_menu_choice_state,shared.a11y.main_menu_tooltip_choice,shared.a11y.main_menu_delivery=nil,nil,nil
    shared.a11y.reset_ui_model()
    shared.a11y.clear_control_tracking_state()
end

function shared.a11y.reset_selection_tracking_state()
    shared.a11y.player_detail_review=nil
    shared.a11y.player_review_stick_direction=nil
    shared.last_audio_id = nil
    shared.a11y.last_page_announcement=nil;shared.a11y.last_page_delivery=nil
    shared.a11y.roster_limits=nil
end

function shared.a11y.reset_game_plan_tracking_state()
    shared.a11y.leave_game_plan()
    shared.a11y.game_plan_entry_requested = false
    shared.a11y.game_plan_attribute_last_marker_frame = -10000
    shared.a11y.game_plan_attribute_index = 0
    shared.a11y.game_plan_attribute_items = {}
    shared.a11y.game_plan_attribute_text_events = {}
    shared.a11y.game_plan_player_record = nil
    shared.a11y.game_plan_player_name = nil
    shared.a11y.game_plan_player_attributes = {}
    shared.a11y.game_plan_player_cache = {}
    shared.a11y.game_plan_attribute_opened_ms = 0
    shared.a11y.game_plan_last_focus_widget = nil
    shared.a11y.game_plan_last_focus_frame = -10000
    shared.a11y.game_plan_pending_title = nil
    shared.a11y.game_plan_title_widgets = {}
    shared.a11y.game_plan_basic_menu_heading_widget = nil
    shared.a11y.game_plan_basic_menu_heading_text = nil
    shared.a11y.game_plan_lineup_generation_frame = -10000
    shared.a11y.game_plan_observed_lineup = {}
    shared.a11y.lineup_keyboard_o_down = false
    shared.a11y.lineup_right_stick_x = 0
    shared.a11y.game_plan_selected_heading = nil
    shared.a11y.game_plan_selected_heading_widget = nil
    shared.a11y.game_plan_selected_heading_frame = -10000
    shared.a11y.game_plan_last_announced_heading = nil
    shared.a11y.game_plan_tactical_navigation_frame = -10000
    shared.a11y.navigation_frame = -10000
    shared.a11y.navigation_action = nil
    shared.a11y.game_plan_formation_active = false
end

function shared.m.context_reset(ctx)
    shared.a11y.last_native_route,shared.a11y.render_speech_allowed=nil,false
    shared.a11y.common_tooltip,shared.a11y.tooltip_last_selection,shared.a11y.tooltip_dirty=nil,nil,true
    shared.a11y.render_metric,shared.a11y.render_stats=nil,nil
    shared.a11y.render_read_work,shared.a11y.structured_record_announced,shared.a11y.prism_recovery_after=nil,nil,nil
    shared.a11y.loading_notice,shared.a11y.selected_message_announced=nil,nil
    shared.a11y.main_navigation_probe,shared.a11y.main_navigation_last,shared.a11y.main_navigation_log_count=nil,nil,0
    shared.a11y.main_menu_choice_state,shared.a11y.main_menu_tooltip_choice,shared.a11y.main_menu_delivery=nil,nil,nil
    shared.a11y.assignment_monitor,shared.a11y.assignment_delivered,shared.a11y.assignment_attempt=nil,nil,0
    shared.a11y.language_announced,shared.a11y.language_active=nil,nil
    shared.a11y.information_announced,shared.a11y.pause_announced=nil,nil
    shared.a11y.visualization_player,shared.a11y.visualization_review=nil,nil
    shared.a11y.static_presentation_owner,shared.a11y.static_presentation_seen=nil,nil
    shared.a11y.engine_focus=nil
    shared.a11y.companion_candidate,shared.a11y.companion_spoken=nil,nil
    shared.a11y.native_list_selection=nil
    -- Sider also resets its team context while constructing an edit menu.
    -- Keep only deferred guidance now proven active, not queued old controls.
    local active_guidance = {}
    for key, item in pairs(shared.a11y.pending_surface_texts or {}) do
        if item.address and shared.frame-item.frame <= 600
                and shared.a11y.native_widget_allowed(item.address) then active_guidance[key]=item end
    end
    shared.a11y.screen_title_hold_until_ms = 0
    shared.a11y.dashboard_review, shared.a11y.dashboard_texts, shared.a11y.menu_flow_name = false, {}, nil
    shared.a11y.keyboard_window, shared.a11y.keyboard_text, shared.a11y.pending_skip_hint, shared.a11y.keyboard_caret = nil, nil, nil, nil
    shared.a11y.presentation_seen,shared.a11y.presentation_seen_owner,shared.a11y.presentation_frame = nil,nil,nil
    shared.a11y.native_text_scan_cursor=nil
    shared.a11y.keyboard_input_address, shared.a11y.pending_surface_texts = nil, {}
    -- A screen transition invalidates announcements captured on the old
    -- screen, including commands still waiting for the render-thread flush.
    shared.a11y.clear_speech_queue()
    shared.a11y.deferred_modal_announcement = nil
    shared.last_spoken_text = nil
    shared.last_spoken_ms = 0
    shared.a11y.reset_widget_tracking_state()
    shared.a11y.reset_dialog_and_message_state()
    shared.a11y.reset_menu_tracking_state()
    shared.a11y.clear_control_tracking_state()
    shared.a11y.reset_selection_tracking_state()
    shared.a11y.pre_match_active = false
    shared.a11y.reset_game_plan_tracking_state()
    shared.a11y.stadium_active = false
    shared.a11y.stadium_last_marker_frame = -10000
    shared.reset_stadium_screen()
    shared.a11y.pre_match_notice_text = nil
    shared.a11y.pre_match_entry_pending = false
    shared.a11y.pre_match_entry_guard_until_frame = 0
    shared.a11y.pre_match_last_action = nil
    shared.a11y.cup_group_table_active = false
    shared.a11y.cup_group_cell_by_widget = {}
    shared.a11y.cup_group_current_cell = nil
    shared.a11y.cup_group_last_announced = nil
    shared.a11y.cup_group_last_navigation_frame = -10000
    shared.a11y.screen_title_hold_until_ms = 0
    shared.last_widget_frame = shared.frame
    shared.a11y.pending_surface_texts = active_guidance
    for _, item in pairs(active_guidance) do shared.a11y.observe_ui_widget(item.address,item.text) end
    log("[FLAccess] context-reset")
end

function shared.install_probe(ctx)
    local target = shared.process_base + shared.RESOLVED_TEXT_RVA
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[FLAccess] probe=%s reused-existing-hook target=%s",
            shared.VERSION,
            memory.hex(target)))
        return
    end
    memory.guard(target, #shared.ORIGINAL_PROLOGUE, "b", shared.ORIGINAL_PROLOGUE)

    local event_id = ctx.get_event_id("custom:flaccess_resolved_text")
    local codecave = memory.allocate_codecave(96)
    local resume = target + #shared.ORIGINAL_PROLOGUE

    local event_trigger =
        "\x53" ..
        "\x51" ..
        "\x48\xbb" .. memory.pack("u64", ctx.custom_evt_rbx) ..
        "\x66\xb9" .. memory.pack("u16", event_id) ..
        "\xff\xd3" ..
        "\x48\x83\xc4\x10"

    local return_to_game =
        shared.ORIGINAL_PROLOGUE ..
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", resume)

    memory.write(codecave, event_trigger .. return_to_game)
    memory.write(
        target,
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", codecave) .. "\x90")

    log(string.format(
        "[FLAccess] probe=%s target=%s codecave=%s mode=resolved-text",
        shared.VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

function shared.install_event_probe(ctx, rva, prologue, event_name, label)
    local target = shared.process_base + rva
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[FLAccess] %s=%s reused-existing-hook target=%s",
            label,
            shared.VERSION,
            memory.hex(target)))
        return
    end
    memory.guard(target, #prologue, "b", prologue)

    local event_id = ctx.get_event_id(event_name)
    local codecave = memory.allocate_codecave(96)
    local resume = target + #prologue
    local event_trigger =
        "\x53" ..
        "\x51" ..
        "\x48\xbb" .. memory.pack("u64", ctx.custom_evt_rbx) ..
        "\x66\xb9" .. memory.pack("u16", event_id) ..
        "\xff\xd3" ..
        "\x48\x83\xc4\x10"
    local return_to_game =
        prologue ..
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", resume)

    memory.write(codecave, event_trigger .. return_to_game)
    if #prologue < 14 then
        error(label .. " prologue is too short for an absolute jump")
    end
    memory.write(
        target,
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", codecave) ..
            string.rep("\x90", #prologue - 14))
    log(string.format(
        "[FLAccess] %s=%s target=%s codecave=%s",
        label,
        shared.VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

function shared.install_slider_probes(ctx)
    shared.install_event_probe(
        ctx, shared.SLIDER_INIT_RVA, shared.SLIDER_INIT_PROLOGUE,
        "custom:flaccess_slider_init", "slider-init-probe")
    shared.install_event_probe(
        ctx, shared.SLIDER_SET_RVA, shared.SLIDER_SET_PROLOGUE,
        "custom:flaccess_slider_set", "slider-set-probe")
end

function shared.install_selector_probes(ctx)
    shared.install_event_probe(ctx,0xe48af0,
        "\x48\x89\x5c\x24\x08\x48\x89\x74\x24\x10\x57\x48\x83\xec\x20",
        "custom:flaccess_ui_focus_event","ui-focus-event-probe")
    shared.install_event_probe(ctx, 0xe7a990,
        "\x48\x8b\xc4\x55\x57\x41\x56\x48\x8d\x68\xd8\x48\x81\xec\x10\x01\x00\x00",
        "custom:flaccess_keyboard_input_set", "keyboard-input-probe")
    shared.install_event_probe(
        ctx, shared.UI_TEXT_SET_RVA, shared.UI_TEXT_SET_PROLOGUE,
        "custom:flaccess_ui_text_set", "ui-text-set-probe")
    shared.install_event_probe(
        ctx, shared.GAME_TEXT_LANGUAGE_SET_RVA, shared.LANGUAGE_SET_PROLOGUE,
        "custom:flaccess_game_text_language_set", "game-text-language-probe")
    shared.install_event_probe(
        ctx, shared.COMMENTARY_LANGUAGE_SET_RVA, shared.LANGUAGE_SET_PROLOGUE,
        "custom:flaccess_commentary_language_set", "commentary-language-probe")
    shared.install_event_probe(
        ctx, shared.GAME_TEXT_LANGUAGE_NAV_RVA, shared.LANGUAGE_NAV_PROLOGUE,
        "custom:flaccess_game_text_language_nav", "game-text-language-nav-probe")
end

function shared.install_list_probe(ctx)
    shared.install_event_probe(ctx,0xc978b5,
        "\x90\x45\x33\xc9\x45\x33\xc0\x48\x8d\x54\x24\x30\x48\x8b\xcf",
        "custom:flaccess_nested_list_caption","nested-list-caption-probe")
    shared.install_event_probe(
        ctx, shared.LIST_ITEM_RENDER_RVA, shared.LIST_ITEM_RENDER_PROLOGUE,
        "custom:flaccess_list_item_render", "list-item-render-probe")
    shared.install_event_probe(
        ctx, shared.TEAM_ITEM_TEXT_A_RVA, shared.TEAM_ITEM_TEXT_PROLOGUE,
        "custom:flaccess_team_item_text", "team-item-text-a-probe")
    shared.install_event_probe(
        ctx, shared.TEAM_ITEM_TEXT_B_RVA, shared.TEAM_ITEM_TEXT_PROLOGUE,
        "custom:flaccess_team_item_text", "team-item-text-b-probe")
end

function shared.a11y.install_player_record_probes(ctx)
    -- At this instruction EBX is the returned match-rule squad boundary.
    -- The complete 14-byte span is LEA/MOV/NOP, without RIP-relative operands.
    shared.install_event_probe(ctx,0x8f8392,
        "\x48\x8d\x4c\x24\x30\xba\x0d\x00\x00\x00\x0f\x1f\x40\x00",
        "custom:flaccess_roster_rule_boundary","roster-rule-boundary-probe")
    shared.install_event_probe(
        ctx, 0xc6d770,
        "\x0f\x10\x02\x0f\x11\x01\x0f\x10\x4a\x10\x0f\x11\x49\x10",
        "custom:flaccess_player_record_copy", "player-record-copy-probe")
    shared.install_event_probe(
        ctx, 0x8e1e47,
        "\x48\x8b\x40\x2c\x48\x89\x02\x48\x8b\xc2\xc3\xcc\xcc\xcc",
        "custom:flaccess_player_record_lookup", "player-record-lookup-probe")
end


function shared.m.init(ctx)
    if not ctx.custom_evt_rbx then
        error("Sider custom events are unavailable")
    end
    shared.process_base = memory.get_process_info().base
    shared.process_base_u64 = ffi.cast("uint64_t", shared.process_base)
    shared.a11y.sider_dir = ctx.sider_dir
    log("[FLAccess] runtime=" .. shared.a11y.runtime_version .. " build=" .. tostring(shared.a11y.build) .. " module=" .. ctx.sider_dir .. "\\modules\\FlAccess\\reader_lifecycle.lua")
    -- Fail open on another executable version. This is a read-only signature
    -- check of the singleton getter; no instruction is patched here.
    shared.a11y.native_windows_enabled = memory.read(shared.process_base + 0xe7157f, 7)
        == "\x48\x8b\x05\x8a\x86\x88\x02"
    shared.a11y.native_windows, shared.a11y.native_windows_frame = nil, nil
    shared.a11y.native_tree_cache, shared.a11y.native_cursor_identity, shared.a11y.native_cursor_log_count = nil,nil,0
    shared.a11y.native_cursor_detail_identity,shared.a11y.native_cursor_detail_count = nil,0
    shared.a11y.presentation_seen,shared.a11y.presentation_seen_owner,shared.a11y.presentation_frame = nil,nil,nil
    shared.a11y.native_text_scan_cursor=nil
    log("[FLAccess] native-window-reader=" .. tostring(shared.a11y.native_windows_enabled))
    local xinput_file = io.open(ctx.sider_dir .. "\\..\\xinput1_3.dll", "rb")
    if xinput_file then
        xinput_file:close()
        shared.a11y.xinput = ffi.load("xinput1_3")
        shared.a11y.xinput_state = ffi.new("FLACCESS_XINPUT_STATE[1]")
    end
    shared.a11y.config_path = ctx.sider_dir .. "\\modules\\FlAccess\\FlAccess.ini"
    shared.a11y.diagnostic_path = ctx.sider_dir .. "\\FLAccess-diagnostic.log"
    shared.a11y.diagnostic_mode = false
    if not shared.a11y.load_config() then
        shared.a11y.save_config()
    end
    shared.a11y.load_text_assets()
    shared.a11y.load_player_style_schema()
    shared.a11y.load_player_style_assets()
    shared.a11y.start_armed_component_capture()
    ctx.register("custom:flaccess_resolved_text", shared.m.on_resolved_text)
    ctx.register("custom:flaccess_slider_init", shared.m.on_slider_init)
    ctx.register("custom:flaccess_slider_set", shared.m.on_slider_set)
    ctx.register("custom:flaccess_ui_text_set", shared.m.on_ui_text_set)
    ctx.register("custom:flaccess_ui_focus_event",shared.m.on_ui_focus_event)
    ctx.register("custom:flaccess_keyboard_input_set", shared.m.on_keyboard_input_set)
    ctx.register("custom:flaccess_list_item_render", shared.m.on_list_item_render)
    ctx.register("custom:flaccess_nested_list_caption", shared.m.on_nested_list_caption)
    ctx.register("custom:flaccess_team_item_text", shared.m.on_team_item_text)
    ctx.register("custom:flaccess_game_text_language_set", shared.m.on_game_text_language_set)
    ctx.register("custom:flaccess_commentary_language_set", shared.m.on_commentary_language_set)
    ctx.register("custom:flaccess_game_text_language_nav", shared.m.on_game_text_language_nav)
    ctx.register("custom:flaccess_player_record_copy", shared.m.on_player_record_copy)
    ctx.register("custom:flaccess_player_record_lookup", shared.m.on_player_record_lookup)
    ctx.register("custom:flaccess_roster_rule_boundary",shared.m.on_roster_rule_boundary)
    ctx.register("display_frame", shared.m.display_frame)
    ctx.register("livecpk_data_ready", shared.m.data_ready)
    ctx.register("context_reset", shared.m.context_reset)
    ctx.register("overlay_on", shared.m.overlay_on)
    ctx.register("overlay_content", shared.m.on_sider_overlay_content)
    ctx.register("key_down", shared.m.key_down)
    ctx.register("show", shared.m.show)
    ctx.register("hide", shared.m.hide)
    shared.install_probe(ctx)
    shared.install_slider_probes(ctx)
    shared.install_selector_probes(ctx)
    shared.install_list_probe(ctx)
    shared.a11y.install_player_record_probes(ctx)
end



    shared.stage = 16
end
function component.init(ctx)
    component.install(ctx)
    ctx.flaccess.reader.m.init(ctx)
end
return component
