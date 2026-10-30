function a11y.overlay_text()
    local s = a11y.strings()
    local tooltip = string.format(
        s.tooltip_option,
        a11y.read_tooltips and s.yes or s.no)
    local diagnostic = string.format(
        s.diagnostic_option,
        a11y.diagnostic_mode and s.yes or s.no)
    if a11y.selected_option == 1 then
        tooltip = "---> " .. tooltip .. " <---"
    else
        diagnostic = "---> " .. diagnostic .. " <---"
    end
    return table.concat({
        string.format(s.title, a11y.runtime_version),
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

function a11y.selected_option_text()
    local s = a11y.strings()
    if a11y.selected_option == 2 then
        return string.format(
            s.diagnostic_option,
            a11y.diagnostic_mode and s.yes or s.no)
    end
    return string.format(
        s.tooltip_option,
        a11y.read_tooltips and s.yes or s.no)
end

function m.overlay_on(ctx)
    return a11y.overlay_text()
end

function m.show(ctx)
    overlay_visible = true
    pending_message_text = nil
    pending_message_key = nil
    pending_message_due_ms = nil
    a11y.pending_modal_button_text = nil
    a11y.modal_message_backlog = {}
    a11y.deferred_modal_announcement = nil
    a11y.clear_pending_tooltips()
    dynamic_text_candidate = nil
    dynamic_text_due_ms = nil
    local s = a11y.strings()
    speak(string.format(
        s.opened,
        a11y.runtime_version,
        a11y.selected_option_text()))
end

function m.hide(ctx)
    overlay_visible = false
    sider_overlay_visible = false
end

function m.global_key_down(ctx, vkey)
    if a11y.buffer_key(vkey) then return end

end

function m.global_gamepad_input(ctx, inputs)
    local vertical = inputs and inputs.RSy
    if vertical == 1 then
        a11y.review_right_stick(-1)
    elseif vertical == -1 then
        a11y.review_right_stick(1)
    elseif vertical == 0 then
        a11y.review_right_stick(0)
    end
end

function m.key_down(ctx, vkey)
    if a11y.keyboard_window then return end
    if a11y.buffer_key(vkey) then return end
    local s = a11y.strings()
    if vkey == 0x20 then
        overlay_visible = false
        sider_overlay_visible = false
        return
    end
    if vkey == a11y.previous_option_key then
        a11y.selected_option = a11y.selected_option - 1
        if a11y.selected_option < 1 then
            a11y.selected_option = a11y.option_count
        end
        speak(a11y.selected_option_text())
        return
    elseif vkey == a11y.next_option_key then
        a11y.selected_option = a11y.selected_option + 1
        if a11y.selected_option > a11y.option_count then
            a11y.selected_option = 1
        end
        speak(a11y.selected_option_text())
        return
    end
    if vkey ~= a11y.restore_key
            and vkey ~= a11y.previous_value_key
            and vkey ~= a11y.next_value_key then
        return
    end

    if a11y.selected_option == 2 then
        local enabled = vkey ~= a11y.restore_key and not a11y.diagnostic_mode
        if not a11y.set_diagnostic(enabled, "Sider panel") then
            speak(s.diagnostic_failed)
            return
        end
        speak(string.format(
            s.diagnostic_changed,
            a11y.diagnostic_mode and s.yes or s.no))
        if a11y.diagnostic_mode then
            speak(s.diagnostic_file)
        end
        return
    end

    a11y.read_tooltips = vkey == a11y.restore_key
        and true or not a11y.read_tooltips
    if not a11y.read_tooltips then
        a11y.clear_pending_tooltips()
    end
    a11y.save_config()
    speak(string.format(
        s.tooltip_changed,
        a11y.read_tooltips and s.yes or s.no))
end

function a11y.readable_sider_module(module_name)
    return tostring(module_name or a11y.strings().module)
        :gsub("[\\/]", " ")
        :gsub("%.lua$", "")
        :gsub("[_%-]+", " ")
end

function a11y.overlay_lines(text)
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

function a11y.clean_overlay_line(line)
    return tostring(line or "")
        :gsub("^%-%-%->%s*", "")
        :gsub("%s*<%-%-%-$", "")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

function a11y.selected_overlay_line(text)
    for _, line in ipairs(a11y.overlay_lines(text)) do
        if line:find("--->", 1, true) then
            return a11y.clean_overlay_line(line)
        end
    end
    return nil
end

function a11y.is_static_overlay_instruction(line)
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

function a11y.changed_overlay_text(previous, current)
    local previous_selected = a11y.selected_overlay_line(previous)
    local current_selected = a11y.selected_overlay_line(current)
    if current_selected and current_selected ~= previous_selected then
        return current_selected
    end

    local old_counts = {}
    for _, line in ipairs(a11y.overlay_lines(previous)) do
        local clean = a11y.clean_overlay_line(line)
        old_counts[clean] = (old_counts[clean] or 0) + 1
    end
    local changed = {}
    for _, line in ipairs(a11y.overlay_lines(current)) do
        local clean = a11y.clean_overlay_line(line)
        if old_counts[clean] and old_counts[clean] > 0 then
            old_counts[clean] = old_counts[clean] - 1
        elseif clean ~= "" and not a11y.is_static_overlay_instruction(clean) then
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

function a11y.full_overlay_text(text)
    local lines = a11y.overlay_lines(text)
    for index, line in ipairs(lines) do
        lines[index] = a11y.clean_overlay_line(line)
    end
    return table.concat(lines, ". ")
end

function m.on_sider_overlay_content(ctx, module_name, text, visible)
    sider_overlay_visible = visible == true
    if not visible then
        overlay_visible = false
        a11y.last_sider_overlay_module = nil
        speak(a11y.strings().closed)
        return
    end

    -- Our own panel is already announced by m.show, which also preserves
    -- compatibility with an unmodified Sider.
    if module_name == "FLAccess.lua" then
        a11y.sider_overlay_text_by_module[module_name] = text
        a11y.last_sider_overlay_module = module_name
        return
    end
    local source = tostring(module_name or "")
    local previous = a11y.sider_overlay_text_by_module[source]
    local module_changed = source ~= a11y.last_sider_overlay_module
    local announcement
    if previous == nil then
        announcement = a11y.full_overlay_text(text)
    elseif previous ~= text then
        announcement = a11y.changed_overlay_text(previous, text)
    elseif module_changed then
        announcement = a11y.selected_overlay_line(text)
    end
    a11y.sider_overlay_text_by_module[source] = text
    a11y.last_sider_overlay_module = source

    local prefix = module_changed
        and (a11y.strings().sider .. ". " .. a11y.readable_sider_module(source)) or nil
    if prefix and announcement and announcement ~= "" then
        speak(prefix .. ". " .. announcement)
    elseif prefix then
        speak(prefix)
    elseif announcement and announcement ~= "" then
        speak(announcement)
    end
end

function a11y.reset_widget_tracking_state()
    a11y.reset_ui_model()
    widgets = {}
    widget_count = 0
    slider_rows = {}
    slider_values = {}
    unmapped_sliders = {}
    ui_text_by_widget = {}
    ui_focus_widgets = {}
    ui_focus_widget_count = 0
    ui_focus_state = {}
    ui_focus_activated = {}
    ui_focus_candidate_key = nil
    ui_focus_candidate_since = 0
    last_ui_focus_announcement = nil
    ui_focus_preferred_offset_index = nil
    last_selected_ui_entry = nil
end

function a11y.reset_dialog_and_message_state()
    dialog_options = {}
    dialog_signature = nil
    dialog_preferred_offset = nil
    dialog_focus_candidate = nil
    dialog_focus_candidate_since = 0
    last_dialog_announcement = nil
    reset_message_state()
end

function a11y.reset_menu_tracking_state()
    standard_text_by_widget = {}
    dynamic_text_candidate = nil
    dynamic_text_due_ms = nil
    main_menu_title_widget_key = nil
    current_main_menu_title = nil
    main_menu_tooltip = nil
    main_menu_tooltip_due_ms = nil
    main_menu_focus_guard_until = 0
    last_screen_title_key = nil
end

function a11y.clear_control_tracking_state()
    controller_rows = {}
    control_rows_by_label_widget = {}
    control_row_by_value_widget = {}
    pending_control_row = nil
    active_control_row = nil
    active_control_focused_ms = 0
    active_controller_label = nil
    last_controller_announcement = nil
    last_announced_control_row = nil
    last_announced_selector_label = nil
    pending_controller_tooltip = nil
    pending_controller_tooltip_label = nil
    controller_tooltip_due_ms = nil
    last_spoken_controller_tooltip_key = nil
    latest_generic_tooltip = nil
    latest_generic_tooltip_widget = nil
    latest_generic_tooltip_ms = 0
    language_control_by_controller = {}
end

function a11y.reset_control_tracking_state()
    a11y.main_menu_choice_state,a11y.main_menu_tooltip_choice=nil,nil
    a11y.reset_ui_model()
    a11y.clear_control_tracking_state()
end

function a11y.reset_selection_tracking_state()
    a11y.player_detail_review=nil
    a11y.player_review_stick_direction=nil
    last_audio_id = nil
    a11y.last_page_announcement=nil;a11y.last_page_delivery=nil
    a11y.roster_limits=nil
end

function a11y.reset_game_plan_tracking_state()
    a11y.leave_game_plan()
    a11y.game_plan_entry_requested = false
    a11y.game_plan_attribute_last_marker_frame = -10000
    a11y.game_plan_attribute_index = 0
    a11y.game_plan_attribute_items = {}
    a11y.game_plan_attribute_text_events = {}
    a11y.game_plan_player_record = nil
    a11y.game_plan_player_name = nil
    a11y.game_plan_player_attributes = {}
    a11y.game_plan_player_cache = {}
    a11y.game_plan_attribute_opened_ms = 0
    a11y.game_plan_last_focus_widget = nil
    a11y.game_plan_last_focus_frame = -10000
    a11y.game_plan_pending_title = nil
    a11y.game_plan_title_widgets = {}
    a11y.game_plan_basic_menu_heading_widget = nil
    a11y.game_plan_basic_menu_heading_text = nil
    a11y.game_plan_lineup_generation_frame = -10000
    a11y.game_plan_observed_lineup = {}
    a11y.lineup_keyboard_o_down = false
    a11y.lineup_right_stick_x = 0
    a11y.game_plan_selected_heading = nil
    a11y.game_plan_selected_heading_widget = nil
    a11y.game_plan_selected_heading_frame = -10000
    a11y.game_plan_last_announced_heading = nil
    a11y.game_plan_tactical_navigation_frame = -10000
    a11y.navigation_frame = -10000
    a11y.navigation_action = nil
    a11y.game_plan_formation_active = false
end

function m.context_reset(ctx)
    a11y.last_native_route,a11y.render_speech_allowed=nil,false
    a11y.common_tooltip,a11y.tooltip_last_selection,a11y.tooltip_dirty=nil,nil,true
    a11y.render_metric,a11y.render_stats=nil,nil
    a11y.render_read_work,a11y.structured_record_announced,a11y.prism_recovery_after=nil,nil,nil
    a11y.loading_notice,a11y.selected_message_announced=nil,nil
    a11y.main_navigation_probe,a11y.main_navigation_last,a11y.main_navigation_log_count=nil,nil,0
    a11y.main_menu_choice_state,a11y.main_menu_tooltip_choice=nil,nil
    a11y.assignment_monitor,a11y.assignment_delivered,a11y.assignment_attempt=nil,nil,0
    a11y.language_announced,a11y.language_active=nil,nil
    a11y.information_announced,a11y.pause_announced=nil,nil
    a11y.visualization_player,a11y.visualization_review=nil,nil
    a11y.static_presentation_owner,a11y.static_presentation_seen=nil,nil
    a11y.engine_focus=nil
    a11y.companion_candidate,a11y.companion_spoken=nil,nil
    a11y.native_list_selection=nil
    -- Sider also resets its team context while constructing an edit menu.
    -- Keep only deferred guidance now proven active, not queued old controls.
    local active_guidance = {}
    for key, item in pairs(a11y.pending_surface_texts or {}) do
        if item.address and frame-item.frame <= 600
                and a11y.native_widget_allowed(item.address) then active_guidance[key]=item end
    end
    a11y.screen_title_hold_until_ms = 0
    a11y.dashboard_review, a11y.dashboard_texts, a11y.menu_flow_name = false, {}, nil
    a11y.keyboard_window, a11y.keyboard_text, a11y.pending_skip_hint, a11y.keyboard_caret = nil, nil, nil, nil
    a11y.presentation_seen,a11y.presentation_seen_owner,a11y.presentation_frame = nil,nil,nil
    a11y.native_text_scan_cursor=nil
    a11y.keyboard_input_address, a11y.pending_surface_texts = nil, {}
    -- A screen transition invalidates announcements captured on the old
    -- screen, including commands still waiting for the render-thread flush.
    a11y.clear_speech_queue()
    a11y.deferred_modal_announcement = nil
    last_spoken_text = nil
    last_spoken_ms = 0
    a11y.reset_widget_tracking_state()
    a11y.reset_dialog_and_message_state()
    a11y.reset_menu_tracking_state()
    a11y.clear_control_tracking_state()
    a11y.reset_selection_tracking_state()
    a11y.pre_match_active = false
    a11y.reset_game_plan_tracking_state()
    a11y.stadium_active = false
    a11y.stadium_last_marker_frame = -10000
    reset_stadium_screen()
    a11y.pre_match_notice_text = nil
    a11y.pre_match_entry_pending = false
    a11y.pre_match_entry_guard_until_frame = 0
    a11y.pre_match_last_action = nil
    a11y.cup_group_table_active = false
    a11y.cup_group_cell_by_widget = {}
    a11y.cup_group_current_cell = nil
    a11y.cup_group_last_announced = nil
    a11y.cup_group_last_navigation_frame = -10000
    a11y.screen_title_hold_until_ms = 0
    last_widget_frame = frame
    a11y.pending_surface_texts = active_guidance
    for _, item in pairs(active_guidance) do a11y.observe_ui_widget(item.address,item.text) end
    log("[FLAccess] context-reset")
end

local function install_probe(ctx)
    local target = process_base + RESOLVED_TEXT_RVA
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[FLAccess] probe=%s reused-existing-hook target=%s",
            VERSION,
            memory.hex(target)))
        return
    end
    memory.guard(target, #ORIGINAL_PROLOGUE, "b", ORIGINAL_PROLOGUE)

    local event_id = ctx.get_event_id("custom:flaccess_resolved_text")
    local codecave = memory.allocate_codecave(96)
    local resume = target + #ORIGINAL_PROLOGUE

    local event_trigger =
        "\x53" ..
        "\x51" ..
        "\x48\xbb" .. memory.pack("u64", ctx.custom_evt_rbx) ..
        "\x66\xb9" .. memory.pack("u16", event_id) ..
        "\xff\xd3" ..
        "\x48\x83\xc4\x10"

    local return_to_game =
        ORIGINAL_PROLOGUE ..
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", resume)

    memory.write(codecave, event_trigger .. return_to_game)
    memory.write(
        target,
        "\xff\x25\x00\x00\x00\x00" .. memory.pack("u64", codecave) .. "\x90")

    log(string.format(
        "[FLAccess] probe=%s target=%s codecave=%s mode=resolved-text",
        VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

local function install_event_probe(ctx, rva, prologue, event_name, label)
    local target = process_base + rva
    if memory.read(target, 6) == "\xff\x25\x00\x00\x00\x00" then
        log(string.format(
            "[FLAccess] %s=%s reused-existing-hook target=%s",
            label,
            VERSION,
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
        VERSION,
        memory.hex(target),
        memory.hex(codecave)))
end

local function install_slider_probes(ctx)
    install_event_probe(
        ctx, SLIDER_INIT_RVA, SLIDER_INIT_PROLOGUE,
        "custom:flaccess_slider_init", "slider-init-probe")
    install_event_probe(
        ctx, SLIDER_SET_RVA, SLIDER_SET_PROLOGUE,
        "custom:flaccess_slider_set", "slider-set-probe")
end

local function install_selector_probes(ctx)
    install_event_probe(ctx,0xe48af0,
        "\x48\x89\x5c\x24\x08\x48\x89\x74\x24\x10\x57\x48\x83\xec\x20",
        "custom:flaccess_ui_focus_event","ui-focus-event-probe")
    install_event_probe(ctx, 0xe7a990,
        "\x48\x8b\xc4\x55\x57\x41\x56\x48\x8d\x68\xd8\x48\x81\xec\x10\x01\x00\x00",
        "custom:flaccess_keyboard_input_set", "keyboard-input-probe")
    install_event_probe(
        ctx, UI_TEXT_SET_RVA, UI_TEXT_SET_PROLOGUE,
        "custom:flaccess_ui_text_set", "ui-text-set-probe")
    install_event_probe(
        ctx, GAME_TEXT_LANGUAGE_SET_RVA, LANGUAGE_SET_PROLOGUE,
        "custom:flaccess_game_text_language_set", "game-text-language-probe")
    install_event_probe(
        ctx, COMMENTARY_LANGUAGE_SET_RVA, LANGUAGE_SET_PROLOGUE,
        "custom:flaccess_commentary_language_set", "commentary-language-probe")
    install_event_probe(
        ctx, GAME_TEXT_LANGUAGE_NAV_RVA, LANGUAGE_NAV_PROLOGUE,
        "custom:flaccess_game_text_language_nav", "game-text-language-nav-probe")
end

local function install_list_probe(ctx)
    install_event_probe(ctx,0xc978b5,
        "\x90\x45\x33\xc9\x45\x33\xc0\x48\x8d\x54\x24\x30\x48\x8b\xcf",
        "custom:flaccess_nested_list_caption","nested-list-caption-probe")
    install_event_probe(
        ctx, LIST_ITEM_RENDER_RVA, LIST_ITEM_RENDER_PROLOGUE,
        "custom:flaccess_list_item_render", "list-item-render-probe")
    install_event_probe(
        ctx, TEAM_ITEM_TEXT_A_RVA, TEAM_ITEM_TEXT_PROLOGUE,
        "custom:flaccess_team_item_text", "team-item-text-a-probe")
    install_event_probe(
        ctx, TEAM_ITEM_TEXT_B_RVA, TEAM_ITEM_TEXT_PROLOGUE,
        "custom:flaccess_team_item_text", "team-item-text-b-probe")
end

function a11y.install_player_record_probes(ctx)
    -- At this instruction EBX is the returned match-rule squad boundary.
    -- The complete 14-byte span is LEA/MOV/NOP, without RIP-relative operands.
    install_event_probe(ctx,0x8f8392,
        "\x48\x8d\x4c\x24\x30\xba\x0d\x00\x00\x00\x0f\x1f\x40\x00",
        "custom:flaccess_roster_rule_boundary","roster-rule-boundary-probe")
    install_event_probe(
        ctx, 0xc6d770,
        "\x0f\x10\x02\x0f\x11\x01\x0f\x10\x4a\x10\x0f\x11\x49\x10",
        "custom:flaccess_player_record_copy", "player-record-copy-probe")
    install_event_probe(
        ctx, 0x8e1e47,
        "\x48\x8b\x40\x2c\x48\x89\x02\x48\x8b\xc2\xc3\xcc\xcc\xcc",
        "custom:flaccess_player_record_lookup", "player-record-lookup-probe")
end


function m.init(ctx)
    if not ctx.custom_evt_rbx then
        error("Sider custom events are unavailable")
    end
    process_base = memory.get_process_info().base
    process_base_u64 = ffi.cast("uint64_t", process_base)
    a11y.sider_dir = ctx.sider_dir
    log("[FLAccess] runtime=" .. a11y.runtime_version .. " build=" .. tostring(a11y.build) .. " module=" .. ctx.sider_dir .. "\\modules\\FlAccessReader\\FlAccessReader.lua")
    -- Fail open on another executable version. This is a read-only signature
    -- check of the singleton getter; no instruction is patched here.
    a11y.native_windows_enabled = memory.read(process_base + 0xe7157f, 7)
        == "\x48\x8b\x05\x8a\x86\x88\x02"
    a11y.native_windows, a11y.native_windows_frame = nil, nil
    a11y.native_tree_cache, a11y.native_cursor_identity, a11y.native_cursor_log_count = nil,nil,0
    a11y.native_cursor_detail_identity,a11y.native_cursor_detail_count = nil,0
    a11y.presentation_seen,a11y.presentation_seen_owner,a11y.presentation_frame = nil,nil,nil
    a11y.native_text_scan_cursor=nil
    log("[FLAccess] native-window-reader=" .. tostring(a11y.native_windows_enabled))
    local xinput_file = io.open(ctx.sider_dir .. "\\..\\xinput1_3.dll", "rb")
    if xinput_file then
        xinput_file:close()
        a11y.xinput = ffi.load("xinput1_3")
        a11y.xinput_state = ffi.new("FLACCESS_XINPUT_STATE[1]")
    end
    a11y.config_path = ctx.sider_dir .. "\\modules\\FlAccessReader\\FlAccessReader.ini"
    a11y.diagnostic_path = ctx.sider_dir .. "\\FLAccess-diagnostic.log"
    a11y.diagnostic_mode = false
    if not a11y.load_config() then
        a11y.save_config()
    end
    a11y.load_text_assets()
    a11y.load_player_style_schema()
    a11y.load_player_style_assets()
    a11y.start_armed_component_capture()
    ctx.register("custom:flaccess_resolved_text", m.on_resolved_text)
    ctx.register("custom:flaccess_slider_init", m.on_slider_init)
    ctx.register("custom:flaccess_slider_set", m.on_slider_set)
    ctx.register("custom:flaccess_ui_text_set", m.on_ui_text_set)
    ctx.register("custom:flaccess_ui_focus_event",m.on_ui_focus_event)
    ctx.register("custom:flaccess_keyboard_input_set", m.on_keyboard_input_set)
    ctx.register("custom:flaccess_list_item_render", m.on_list_item_render)
    ctx.register("custom:flaccess_nested_list_caption", m.on_nested_list_caption)
    ctx.register("custom:flaccess_team_item_text", m.on_team_item_text)
    ctx.register("custom:flaccess_game_text_language_set", m.on_game_text_language_set)
    ctx.register("custom:flaccess_commentary_language_set", m.on_commentary_language_set)
    ctx.register("custom:flaccess_game_text_language_nav", m.on_game_text_language_nav)
    ctx.register("custom:flaccess_player_record_copy", m.on_player_record_copy)
    ctx.register("custom:flaccess_player_record_lookup", m.on_player_record_lookup)
    ctx.register("custom:flaccess_roster_rule_boundary",m.on_roster_rule_boundary)
    ctx.register("display_frame", m.display_frame)
    ctx.register("livecpk_data_ready", m.data_ready)
    ctx.register("context_reset", m.context_reset)
    ctx.register("overlay_on", m.overlay_on)
    ctx.register("overlay_content", m.on_sider_overlay_content)
    ctx.register("key_down", m.key_down)
    ctx.register("show", m.show)
    ctx.register("hide", m.hide)
    install_probe(ctx)
    install_slider_probes(ctx)
    install_selector_probes(ctx)
    install_list_probe(ctx)
    a11y.install_player_record_probes(ctx)
end

return m
