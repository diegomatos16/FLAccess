local function process_delayed_speech(now_ms, modal_focus_blocked)
    if a11y.read_context_state().kind == "dialog" then
        a11y.clear_pending_tooltips()
        dynamic_text_candidate, dynamic_text_due_ms = nil, nil
        return
    end
    if a11y.read_tooltips and not modal_focus_blocked and controller_tooltip_due_ms
            and now_ms >= controller_tooltip_due_ms then
        local tooltip_key = (pending_controller_tooltip_label or "") .. "\0" ..
            (pending_controller_tooltip or "")
        if active_controller_label == pending_controller_tooltip_label
                and pending_controller_tooltip
                and pending_controller_tooltip ~= ""
                and tooltip_key ~= last_spoken_controller_tooltip_key then
            last_spoken_controller_tooltip_key = tooltip_key
            speak(pending_controller_tooltip, false)
        end
        controller_tooltip_due_ms = nil
    end
    if not modal_focus_blocked and dynamic_text_due_ms
            and now_ms >= dynamic_text_due_ms then
        if dynamic_text_candidate and dynamic_text_candidate ~= ""
                and (not a11y.dynamic_text_origin or a11y.speech_origin_allowed(a11y.dynamic_text_origin)) then
            speak(dynamic_text_candidate, false,nil,nil,a11y.dynamic_text_origin and a11y.dynamic_text_origin.address)
        end
        a11y.dynamic_text_origin=nil
        dynamic_text_candidate = nil
        dynamic_text_due_ms = nil
    end
    if a11y.read_tooltips and not modal_focus_blocked and main_menu_tooltip_due_ms
            and now_ms >= main_menu_tooltip_due_ms then
        local state=a11y.main_menu_tooltip_choice
        if state and state==a11y.main_menu_choice_state and a11y.main_menu_choice_active(state)
                and state.status~="delivered" then return end
        if state and state.status=="delivered" and a11y.main_menu_choice_active(state)
                and main_menu_tooltip and main_menu_tooltip~="" then
            local before=a11y.native_speech_last
            speak(main_menu_tooltip,false,nil,"main-tooltip:" .. state.key .. ":" .. state.text)
            for index=before+1,a11y.native_speech_last do a11y.native_speech_queue[index].menu_tooltip=state end
        end
        main_menu_tooltip,main_menu_tooltip_due_ms,a11y.main_menu_tooltip_choice=nil,nil,nil
    end
end

local function log_focus_snapshot(counts, selected, selected_seen)
    local parts = {}
    for index, count in ipairs(counts) do
        if count > 0 and selected[index] then
            local entry = ui_focus_widgets[selected[index]]
            if entry then
                parts[#parts + 1] = string.format(
                    "0x%x=%q(age=%d,candidates=%d)",
                    ui_focus_offsets[index],
                    entry.text,
                    frame - (selected_seen[index] or frame),
                    count)
            end
        end
    end
    log("[FLAccess] focus-snapshot " .. table.concat(parts, " "))
end

function a11y.diagnostic_role(widget_key, entry)
    local row = control_rows_by_label_widget[widget_key]
        or control_row_by_value_widget[widget_key]
    if row then
        if row.native_slider then
            return "slider", row
        end
        return row.role or "control", row
    end
    if is_modal_button(entry.text) then
        return "dialog-button", nil
    end
    if a11y.game_plan_title_widgets[widget_key]
            and a11y.game_plan_screen_titles[entry.text] then
        return "screen-title", nil
    end
    if widget_key == a11y.game_plan_active_tactical_widget then
        return "tactical-control-heading", nil
    end
    if widget_key == a11y.game_plan_selected_heading_widget then
        return "selected-player-heading", nil
    end
    if a11y.game_plan_menu_items[entry.text] then
        return "menu-item", nil
    end
    if a11y.pre_match_actions[entry.text] then
        return "pre-match-action", nil
    end
    local asset_role = a11y.text_asset_role(entry.text)
    if asset_role and asset_role ~= "text" then
        return asset_role, nil
    end
    if a11y.is_instruction_message(entry.text) then
        return "instruction-dialog-text", nil
    end
    if looks_like_message(entry.text) then
        return "message-or-tooltip", nil
    end
    if is_noninteractive_text(entry.text) then
        return "noninteractive-text", nil
    end
    return "unknown-focusable", nil
end

function a11y.record_focus(kind, widget_key, entry, selected_offset,
        counts, selected, selected_seen, dense_virtual_list)
    if not a11y.diagnostic_mode or not entry then
        return
    end
    a11y.diagnostic_sequence = a11y.diagnostic_sequence + 1
    local role, row = a11y.diagnostic_role(widget_key, entry)
    local lines = {
        string.format(
            "EVENT %d frame=%d kind=%s widget=%s offset=0x%x age=%d dense_list=%s role=%s",
            a11y.diagnostic_sequence,
            frame,
            tostring(kind or "stable-focus"),
            widget_key,
            selected_offset or 0,
            frame - (entry.last_seen or frame),
            dense_virtual_list and "true" or "false",
            a11y.diagnostic_text(role)),
        string.format("text=%q", a11y.diagnostic_text(entry.text)),
    }
    local caller_rva = a11y.ui_text_caller_by_widget[widget_key]
    lines[#lines + 1] = "text_set_caller_rva=" ..
        (caller_rva and string.format("0x%x", caller_rva) or "unknown")
    lines[#lines + 1] = string.format(
        "screen_context heading=%q main_menu=%q recent_message=%q",
        a11y.diagnostic_text(recent_heading_text),
        a11y.diagnostic_text(current_main_menu_title),
        a11y.diagnostic_text(recent_message_text))
    if row then
        lines[#lines + 1] = string.format(
            "control label=%q value=%q type=%q label_widget=%s value_widget=%s native_slider=%s min=%s max=%s",
            a11y.diagnostic_text(row.label),
            a11y.diagnostic_text(row.value),
            a11y.diagnostic_text(row.role),
            tostring(row.label_widget_key or "nil"),
            tostring(row.value_widget_key or "nil"),
            row.native_slider and "true" or "false",
            tostring(row.minimum or "nil"),
            tostring(row.maximum or "nil"))
    end

    local address = entry.address
    lines[#lines + 1] = string.format(
        "widget_internal_name=%q source=msvc-string@+0x18",
        a11y.diagnostic_text(a11y.widget_internal_name(address)))
    if address and readable(address + 0x38, 8) then
        lines[#lines + 1] = "widget_relation_candidate=" ..
            a11y.diagnostic_hex(read_u64(memory.read(address + 0x38, 8))) ..
            " source=pointer@+0x38"
    end
    local raw = {}
    if address and readable(address, 0x40) then
        for offset = 0, 0x38, 8 do
            local value = read_u64(memory.read(address + offset, 8))
            raw[#raw + 1] = string.format(
                "+0x%02x=%s", offset, a11y.diagnostic_hex(value))
        end
        local vtable = read_u64(memory.read(address, 8))
        local vtable_key = a11y.diagnostic_hex(vtable)
        local class_id = a11y.diagnostic_class_ids[vtable_key]
        if not class_id then
            a11y.diagnostic_class_count = a11y.diagnostic_class_count + 1
            class_id = string.format(
                "class-%03d", a11y.diagnostic_class_count)
            a11y.diagnostic_class_ids[vtable_key] = class_id
        end
        local vtable_number = tonumber(vtable)
        local base_number = tonumber(process_base_u64)
        local rva = "outside-main-module"
        if vtable_number and base_number and vtable_number >= base_number
                and vtable_number < base_number + 0x40000000 then
            rva = string.format("0x%x", vtable_number - base_number)
        end
        lines[#lines + 1] = string.format(
            "object class=%s vtable=%s vtable_rva=%s raw_qwords={%s}",
            class_id,
            vtable_key,
            rva,
            table.concat(raw, ","))
    else
        lines[#lines + 1] = "object unreadable"
    end

    local focus_fields = {}
    for _, offset in ipairs(ui_focus_offsets) do
        local value = "unreadable"
        if address and readable(address + offset, 4) then
            value = tostring(memory.unpack(
                "u32", memory.read(address + offset, 4)))
        end
        focus_fields[#focus_fields + 1] = string.format(
            "+0x%x=%s", offset, value)
    end
    lines[#lines + 1] = "focus_fields={" ..
        table.concat(focus_fields, ",") .. "}"

    local banks = {}
    for index, count in ipairs(counts) do
        if count > 0 then
            local key = selected[index]
            local candidate = key and ui_focus_widgets[key] or nil
            banks[#banks + 1] = string.format(
                "+0x%x count=%d selected=%s text=%q age=%d",
                ui_focus_offsets[index],
                count,
                tostring(key or "nil"),
                a11y.diagnostic_text(candidate and candidate.text or ""),
                candidate and frame - (selected_seen[index] or frame) or -1)
        end
    end
    lines[#lines + 1] = "candidate_banks={" ..
        table.concat(banks, "; ") .. "}"

    local links = {}
    if address and readable(address, 0xf0) then
        for offset = 0, 0xe8, 8 do
            local pointer = read_u64(memory.read(address + offset, 8))
            local key = a11y.diagnostic_hex(pointer)
            local linked_text = ui_text_by_widget[key]
            if linked_text then
                links[#links + 1] = string.format(
                    "+0x%x=%s %q",
                    offset,
                    key,
                    a11y.diagnostic_text(linked_text))
                if #links >= 16 then
                    break
                end
            end
        end
    end
    lines[#lines + 1] = "known_widget_links={" ..
        table.concat(links, "; ") .. "}"

    local recent = {}
    for key, candidate in pairs(ui_focus_widgets) do
        local age = frame - (candidate.last_seen or frame)
        if age <= 120 then
            recent[#recent + 1] = {
                key = key,
                text = candidate.text,
                age = age,
            }
        end
    end
    table.sort(recent, function(left, right)
        if left.age == right.age then
            return left.key < right.key
        end
        return left.age < right.age
    end)
    local inventory = {}
    for index = 1, math.min(#recent, 40) do
        local candidate = recent[index]
        local observed = ui_focus_widgets[candidate.key]
        local candidate_address = observed and observed.address
        local relation = "unreadable"
        if candidate_address and readable(candidate_address + 0x38, 8) then
            relation = a11y.diagnostic_hex(read_u64(
                memory.read(candidate_address + 0x38, 8)))
        end
        inventory[#inventory + 1] = string.format(
            "%s %q age=%d name=%q relation=%s",
            candidate.key,
            a11y.diagnostic_text(candidate.text),
            candidate.age,
            a11y.diagnostic_text(a11y.widget_internal_name(candidate_address)),
            relation)
    end
    lines[#lines + 1] = string.format(
        "recent_screen_inventory count=%d shown=%d {%s}",
        #recent,
        #inventory,
        table.concat(inventory, "; "))

    local controls = {}
    for label, control in pairs(controller_rows) do
        controls[#controls + 1] = string.format(
            "%q type=%q value=%q label_widget=%s value_widget=%s created=%s value_frame=%s",
            a11y.diagnostic_text(label),
            a11y.diagnostic_text(control.role),
            a11y.diagnostic_text(control.value),
            tostring(control.label_widget_key or "nil"),
            tostring(control.value_widget_key or "nil"),
            tostring(control.created_frame or "nil"),
            tostring(control.value_frame or "nil"))
    end
    table.sort(controls)
    while #controls > 50 do
        table.remove(controls)
    end
    lines[#lines + 1] = "known_control_inventory={" ..
        table.concat(controls, "; ") .. "}"
    lines[#lines + 1] = ""
    a11y.diagnostic_write(lines)
end

function a11y.safe_record_focus(kind, selected_key, selected_entry,
        selected_offset, counts, selected, selected_seen, dense_virtual_list)
    -- Every memory access inside record_focus is guarded by readable().
    a11y.record_focus(
        kind,
        selected_key or "nil",
        selected_entry,
        selected_offset,
        counts,
        selected,
        selected_seen,
        dense_virtual_list)
end

function a11y.observe_diagnostic_focus(candidate_key, selected_key, selected_entry,
        selected_offset, counts, selected, selected_seen, dense_virtual_list)
    if not a11y.diagnostic_mode or not candidate_key or not selected_entry then
        return
    end
    local diagnostic_key = candidate_key .. ":" ..
        string.format("0x%x", selected_offset or 0)
    if diagnostic_key ~= a11y.diagnostic_candidate_key then
        a11y.diagnostic_candidate_key = diagnostic_key
        a11y.diagnostic_candidate_since = frame
        if frame - a11y.diagnostic_last_snapshot_frame >= 90 then
            a11y.diagnostic_last_snapshot_frame = frame
            a11y.safe_record_focus(
                "focus-snapshot",
                selected_key,
                selected_entry,
                selected_offset,
                counts,
                selected,
                selected_seen,
                dense_virtual_list)
        end
        return
    end
    if frame - a11y.diagnostic_candidate_since < 4
            or diagnostic_key == a11y.diagnostic_last_key then
        return
    end
    a11y.diagnostic_last_key = diagnostic_key
    a11y.safe_record_focus(
        "stable-focus",
        selected_key,
        selected_entry,
        selected_offset,
        counts,
        selected,
        selected_seen,
        dense_virtual_list)
end

-- Resolve one native reading authority before entering the compatibility scan.
-- Unknown components retain the compatibility path; no route guesses a label.
function a11y.dispatch_native_selection(modal_blocked,dialog_active)
    local route,handled="compatibility",false
    if a11y.selected_message_packet() then
        a11y.poll_selected_message();route,handled="selected-message",true
    elseif not dialog_active and a11y.poll_structured_record(modal_blocked) then
        route,handled="structured-record",true
    elseif a11y.process_engine_focus(modal_blocked) then
        route,handled="native-focus",true
    end
    local identity=tostring(a11y.native_owner_token()) .. ":" .. route
    if identity~=a11y.last_native_route then
        a11y.last_native_route=identity
        log("[FLAccess] reader-route kind=" .. route .. " owner=" .. tostring(a11y.native_owner_token()))
    end
    return handled
end

local function scan_current_ui_focus(modal_focus_blocked, dialog_active)
    if a11y.keyboard_window then return false end
    if a11y.native_windows_enabled and not a11y.native_presentation_ready() then return false end
    if a11y.dispatch_native_selection(modal_focus_blocked,dialog_active) then return true end
    if ui_focus_widget_count <= 0 then
        a11y.reset_focus_reuse_state()
        last_selected_ui_entry = nil
        return false
    end
    if frame < main_menu_focus_guard_until then
        return false
    end
    local counts = {}
    local selected = {}
    local selected_seen = {}
    local primary_candidates = {}
    for index = 1, #ui_focus_offsets do
        counts[index] = 0
        selected_seen[index] = -1
    end
    local command_owners = a11y.command_icon_owners()
    local game_plan_menu_bank_active = false
    local game_plan_menu_best_key
    local game_plan_menu_best_index
    local game_plan_menu_best_activation = -1
    for widget_key, entry in pairs(ui_focus_widgets) do
        if a11y.native_widget_allowed(entry.address) and not is_noninteractive_text(entry.text)
                and not (entry.text == "OK" and a11y.game_plan_active
                    and (a11y.game_plan_context ==
                            "Configurações táticas básicas"
                        or a11y.game_plan_context ==
                            "Basic Tactical Settings"))
                and readable(entry.address + 0xf0, 0x30) then
            local bytes = memory.read(entry.address + 0xf0, 0x30)
            local state = ui_focus_state[widget_key] or {}
            local activated = ui_focus_activated[widget_key] or {}
            ui_focus_state[widget_key] = state
            ui_focus_activated[widget_key] = activated
            for index, offset in ipairs(ui_focus_offsets) do
                local relative = offset - 0xf0
                local value = memory.unpack(
                    "u32", bytes:sub(relative + 1, relative + 4))
                local native = a11y.native_windows
                if index == 1 and native and native.cursor_members
                        and native.cursor_members[tonumber(entry.address)] then
                    value = native.selected_members[tonumber(entry.address)] and 1 or 0
                end
                if value == 1 and state[index] ~= 1 then
                    activated[index] = frame
                end
                state[index] = value
                local primary_flag = memory.unpack("u32", bytes:sub(0x15, 0x18)) == 1
                if native and native.cursor_members and native.cursor_members[tonumber(entry.address)] then
                    primary_flag = native.selected_members[tonumber(entry.address)] or false
                end
                if value == 1 and not a11y.is_command_legend(widget_key, primary_flag, command_owners) then
                    if index == 1 then
                        if a11y.ui_model then
                            a11y.ui_model.last_primary_edge = math.max(a11y.ui_model.last_primary_edge or -1,
                                activated[index] or -1)
                        end
                        primary_candidates[#primary_candidates + 1] = {
                            key=widget_key, edge=activated[index] or -1,
                        }
                    end
                    if a11y.game_plan_main_surface
                            and a11y.game_plan_menu_items[entry.text]
                            and (activated[index] or -1)
                                > game_plan_menu_best_activation then
                        game_plan_menu_best_activation = activated[index]
                        game_plan_menu_best_key = widget_key
                        game_plan_menu_best_index = index
                    end
                    if index == 5 and a11y.game_plan_active
                            and a11y.game_plan_menu_items[entry.text] then
                        game_plan_menu_bank_active = true
                    end
                    counts[index] = counts[index] + 1
                    local activity = math.max(
                        activated[index] or -1,
                        entry.last_seen or -1)
                    if activity > selected_seen[index] then
                        selected_seen[index] = activity
                        selected[index] = widget_key
                    end
                end
            end
        end
    end
    local selected_key
    local selected_offset
    local selected_offset_index
    local freshest_offset_index
    local freshest_seen = -1
    for index = 1, #ui_focus_offsets do
        if counts[index] > 0 and selected_seen[index] > freshest_seen then
            freshest_seen = selected_seen[index]
            freshest_offset_index = index
        end
    end
    -- League/club grids refresh several visible rows at 0x104 and 0x100.
    -- Prefer the freshest 0x100 row only while both banks belong to the same
    -- update cycle. Never lock a widget: recycled addresses caused stale
    -- leagues, players and pre-match items to leak into later screens.
    if not dialog_active and a11y.process_read_dialog_focus(primary_candidates) then return true end
    local dense_virtual_list = counts[1] >= 3 and counts[5] >= 3
    local game_plan_roster_offset_index = 10 -- 0xfc
    local primary_entry = selected[1] and ui_focus_widgets[selected[1]] or nil
    local context_entry = selected[5] and ui_focus_widgets[selected[5]] or nil
    local game_plan_roster_context = a11y.game_plan_active
        and a11y.game_plan_context
        and a11y.game_plan_edit_contexts[a11y.game_plan_context]
    local game_plan_settings_context = a11y.game_plan_active
        and game_plan_menu_bank_active
    local basic_settings_menu = a11y.game_plan_active
        and (a11y.game_plan_context == "Menu de configuração básica"
            or a11y.game_plan_context == "Basic Settings Menu")
    local edit_position_active = a11y.game_plan_active
        and (a11y.game_plan_context == "Escalação/Editar posição"
            or a11y.game_plan_context == "Team Sheet/Edit Position"
            or (frame - recent_heading_frame <= 120
                and (recent_heading_text == "Trocar ícone de jog."
                    or recent_heading_text == "Change Player Icon")))
    local recent_game_plan_player = edit_position_active
        and counts[game_plan_roster_offset_index] > 0
        and frame - selected_seen[game_plan_roster_offset_index] <= 30
    local game_plan_setting_offset_index
    local game_plan_setting_activation = -1
    local basic_menu_offset_index
    local basic_menu_activation = -1
    local game_plan_player_header_offset_index
    local game_plan_player_header_seen = -1
    if edit_position_active then
        for index = 1, #ui_focus_offsets do
            local entry = selected[index] and ui_focus_widgets[selected[index]] or nil
            if entry and entry.text:match("^%d+%s+%S")
                    and selected_seen[index] > game_plan_player_header_seen then
                game_plan_player_header_seen = selected_seen[index]
                game_plan_player_header_offset_index = index
            end
        end
    end
    if game_plan_settings_context then
        for index = 1, #ui_focus_offsets do
            local entry = selected[index] and ui_focus_widgets[selected[index]] or nil
            local activation = selected[index]
                and ui_focus_activated[selected[index]]
                and ui_focus_activated[selected[index]][index] or -1
            if entry and (a11y.game_plan_menu_items[entry.text]
                    or controller_labels[entry.text])
                    and activation > game_plan_setting_activation then
                game_plan_setting_activation = activation
                game_plan_setting_offset_index = index
            end
        end
    end
    if basic_settings_menu then
        for index = 1, #ui_focus_offsets do
            local entry = selected[index]
                and ui_focus_widgets[selected[index]] or nil
            local activation = selected[index]
                and ui_focus_activated[selected[index]]
                and ui_focus_activated[selected[index]][index] or -1
            if entry and not a11y.game_plan_title_widgets[selected[index]]
                    and (a11y.game_plan_menu_items[entry.text]
                    or (a11y.game_plan_basic_prompt_active
                        and a11y.game_plan_basic_prompt_items[entry.text]))
                    and (activation > basic_menu_activation
                        or (activation == basic_menu_activation
                            and selected_seen[index] >
                                (basic_menu_offset_index
                                    and selected_seen[basic_menu_offset_index]
                                    or -1))) then
                basic_menu_activation = activation
                basic_menu_offset_index = index
            end
        end
    end
    local primary_is_game_plan_control = primary_entry
        and (a11y.game_plan_menu_items[primary_entry.text]
            or a11y.game_plan_basic_prompt_items[primary_entry.text]
            or primary_entry.text:match("%(%s*[%d%-]+%s*%)")
            or primary_entry.text:match("^%d[%d%-]+$"))
    if a11y.game_plan_main_surface and game_plan_menu_best_key
            and frame - game_plan_menu_best_activation <= 120 then
        -- Player cards can refresh after the focused command and replace the
        -- per-bank freshest entry. Select the command by its focus edge.
        selected[game_plan_menu_best_index] = game_plan_menu_best_key
        selected_seen[game_plan_menu_best_index] =
            game_plan_menu_best_activation
        selected_offset_index = game_plan_menu_best_index
    elseif basic_settings_menu then
        -- Team and player cards keep their focus flags behind this menu.
        -- Only its actual commands and an open Use/Do not use dialog are
        -- eligible. Text can update without a 0->1 focus edge, so a stale
        -- activation alone cannot make the whole menu permanently silent.
        if basic_menu_offset_index
                and (frame - basic_menu_activation <= 120
                    or (selected[basic_menu_offset_index]
                        and frame - (ui_focus_widgets[
                            selected[basic_menu_offset_index]].last_seen
                            or frame) <= 12)) then
            selected_offset_index = basic_menu_offset_index
        else
            if a11y.diagnostic_mode and frame - a11y.navigation_frame <= 2
                    and selected[1] then
                a11y.record_focus("unresolved-game-plan",
                    selected[1], ui_focus_widgets[selected[1]],
                    ui_focus_offsets[1], counts, selected, selected_seen,
                    dense_virtual_list)
            end
            return false
        end
    elseif a11y.game_plan_active and primary_is_game_plan_control then
        -- Menus and formation lists expose the real selection at 0x104.
        -- Player cards at 0xfc keep animating behind them.
        selected_offset_index = 1
    elseif edit_position_active and game_plan_player_header_offset_index then
        -- The numbered heading is the only object tied to the selected
        -- footballer. The 0xfc bank contains every card being redrawn.
        selected_offset_index = game_plan_player_header_offset_index
    elseif edit_position_active then
        -- Silence is preferable to announcing a random background player
        -- while the selected-player heading is temporarily unavailable.
        return false
    elseif game_plan_settings_context then
        -- While this menu opens, 0x100 contains every visible entry and old
        -- players. A submenu may use a different bank, so prefer the control
        -- whose focus bit was most recently activated; fall back to 0x104.
        if game_plan_setting_offset_index
                and frame - game_plan_setting_activation <= 90 then
            selected_offset_index = game_plan_setting_offset_index
        elseif counts[1] > 0 then
            selected_offset_index = 1
        end
    elseif recent_game_plan_player then
        selected_offset_index = game_plan_roster_offset_index
    elseif dense_virtual_list then
        -- 0x104 is the actual selected row. 0x100 is the previous row: for
        -- example, while the game selects LaLiga 2 it still exposes LaLiga at
        -- 0x100. This applies to clubs and also avoids stale "Confirmar" rows.
        selected_offset_index = 1
    elseif counts[1] > 0 then
        -- Ordinary menus, pre-match actions and settings consistently expose
        -- their real selection at 0x104. Player names and hidden selectors on
        -- nearby offsets are refreshed continuously and otherwise steal the
        -- "freshest" heuristic even while their focus bits are stale.
        selected_offset_index = 1
    elseif ui_focus_preferred_offset_index
            and counts[ui_focus_preferred_offset_index] > 0 then
        selected_offset_index = ui_focus_preferred_offset_index
    elseif freshest_offset_index then
        selected_offset_index = freshest_offset_index
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    if modal_focus_blocked or now_ms < modal_focus_hold_until_ms + 1500 then
        local freshest_button_seen = -1
        for index = 1, #ui_focus_offsets do
            local button_entry = selected[index]
                and ui_focus_widgets[selected[index]] or nil
            if button_entry and is_modal_button(button_entry.text)
                    and selected_seen[index] >= freshest_seen - 3
                    and selected_seen[index] > freshest_button_seen then
                freshest_button_seen = selected_seen[index]
                selected_offset_index = index
            end
        end
    end
    if selected_offset_index then
        local selection_reason = "legacy-adapter"
        if selected_offset_index == 1 and not a11y.game_plan_active
                and not a11y.pre_match_active and not a11y.cup_group_table_active
                and not modal_focus_blocked and not dialog_active then
            local resolved, reason = a11y.resolve_primary_focus(primary_candidates)
            selection_reason = reason
            if not resolved then
                if a11y.diagnostic_mode
                        and frame - a11y.diagnostic_last_snapshot_frame >= 60 then
                    a11y.safe_record_focus("unresolved-structural",
                        selected[1], ui_focus_widgets[selected[1]],
                        0x104, counts, selected, selected_seen, dense_virtual_list)
                end
                last_selected_ui_entry = nil
                a11y.reset_focus_reuse_state()
                return false
            end
            selected[1] = resolved.key
        end
        if a11y.ui_model then a11y.ui_model.focus_reason = selection_reason end
        selected_key = selected[selected_offset_index]
        selected_offset = ui_focus_offsets[selected_offset_index]
    end
    local selected_entry = selected_key and ui_focus_widgets[selected_key] or nil
    if selected_entry and selected_offset ~= 0x104
            and not a11y.game_plan_active and not a11y.pre_match_active
            and not a11y.stadium_active and not a11y.cup_group_table_active
            and not is_modal_button(selected_entry.text)
            and not (control_rows_by_label_widget[selected_key]
                and control_rows_by_label_widget[selected_key].is_control)
            and not (control_row_by_value_widget[selected_key]
                and control_row_by_value_widget[selected_key].is_control) then
        -- Other state banks also belong to noninteractive overlays (the
        -- captured music artist was at 0x114/0x100). Only mapped controls or
        -- a verified adapter can grant those banks focus authority.
        a11y.reset_focus_reuse_state()
        last_selected_ui_entry = nil
        return false
    end
    if selected_entry and selected_offset ~= 0x104
            and not a11y.game_plan_active and not a11y.pre_match_active
            and not a11y.stadium_active and not a11y.cup_group_table_active
            and not dialog_active and not modal_focus_blocked
            and not a11y.secondary_focus_is_current(selected_key, selected_offset_index) then
        if a11y.ui_model then a11y.ui_model.focus_reason = "stale-secondary-focus" end
        a11y.reset_focus_reuse_state()
        last_selected_ui_entry = nil
        return false
    end
    a11y.track_control_focus(selected_key)
    last_selected_ui_entry = selected_entry
    local preserved_pre_match_row = selected_key
        and control_rows_by_label_widget[selected_key] or nil
    if not (a11y.pre_match_active and preserved_pre_match_row
            and a11y.pre_match_actions[preserved_pre_match_row.label]) then
        preserved_pre_match_row = nil
    end
    local inferred_pre_match_text
    local selected_activity = selected_offset_index
        and selected_seen[selected_offset_index] or nil
    local recent_navigation = frame - a11y.navigation_frame <= 20
    if a11y.pre_match_active and not preserved_pre_match_row
            and selected_entry
            and not a11y.pre_match_actions[selected_entry.text]
            and selected_activity
            and ((recent_navigation
                    and ((a11y.navigation_action == "left"
                            and (a11y.pre_match_last_action == "Início"
                                or a11y.pre_match_last_action == "Kick Off"))
                        or (a11y.navigation_action == "right"
                            and (a11y.pre_match_last_action == "Uniforme"
                                or a11y.pre_match_last_action == "Uniform"))))
                or (frame - selected_activity > 30
                    and (a11y.pre_match_last_action == "Uniforme"
                        or a11y.pre_match_last_action == "Uniform"
                        or a11y.pre_match_last_action == "Início"
                        or a11y.pre_match_last_action == "Kick Off"
                        or a11y.pre_match_last_action == "Plano de jogo"
                        or a11y.pre_match_last_action == "Game Plan"))) then
        inferred_pre_match_text = a11y.ui_language == "pt"
            and "Estádio" or "Stadium"
    end
    local selected_focus_text = preserved_pre_match_row
        and preserved_pre_match_row.label
        or inferred_pre_match_text
        or (selected_entry and selected_entry.text or nil)
    local primary_edge = selected_key and ui_focus_activated[selected_key]
        and ui_focus_activated[selected_key][1] or -1
    if a11y.transition_focus_blocked(selected_key, selected_entry, selected_offset, primary_edge, now_ms) then
        return false
    end
    local selected_formation_inside = selected_focus_text
        and selected_focus_text:match("%((.-)%)") or nil
    local selected_compact_formation = selected_formation_inside
        and selected_formation_inside:gsub("%s+", "") or nil
    local selected_is_formation = selected_focus_text and
        ((selected_compact_formation
                and selected_compact_formation:match("^%d[%d%-]+$"))
            or selected_focus_text:match("^%d[%d%-]+$"))
    if a11y.game_plan_active and selected_focus_text
            and a11y.game_plan_menu_items[selected_focus_text]
            and selected_activity and frame - selected_activity <= 12
            and not a11y.game_plan_edit_contexts[a11y.game_plan_context]
            and a11y.game_plan_context ~= "Configurações táticas básicas"
            and a11y.game_plan_context ~= "Basic Tactical Settings" then
        a11y.game_plan_last_menu_focus = selected_focus_text
    end
    if a11y.pre_match_active and selected_focus_text
            and not a11y.pre_match_actions[selected_focus_text]
            and not inferred_pre_match_text
            and not is_modal_button(selected_focus_text) then
        -- Game Plan widgets continue toggling focus bits behind pre-match.
        -- Ignore them without replacing the current candidate; otherwise the
        -- real horizontal action never survives the debounce interval.
        return false
    end
    if a11y.game_plan_main_surface and selected_focus_text
            and not a11y.game_plan_menu_items[selected_focus_text]
            and not is_modal_button(selected_focus_text) then
        -- Player names and both teams' formations are display-only on the
        -- overview. The five bottom commands are the only actionable focus.
        return false
    end
    if selected_focus_text
            and a11y.game_plan_basic_prompt_items[selected_focus_text]
            and not a11y.game_plan_basic_prompt_active then
        -- A closed Basic Settings prompt survives in the widget pool. Its
        -- stale focus flag used to say "Usar, selecionado" between players.
        return false
    end
    if a11y.ignore_cup_group_focus(selected_focus_text) then
        return false
    end
    if selected_focus_text == "OK" and last_screen_title_key
            and not pending_message_text
            and now_ms < a11y.screen_title_hold_until_ms + 2000 then
        -- Title and lone OK commonly precede a notice whose paragraph is
        -- created later. Give that text hook time to claim speech priority.
        return false
    end
    local candidate_key = selected_entry and
        a11y.ui_focus_identity(selected_key, selected_focus_text) or nil
    if not candidate_key and not modal_focus_blocked and not dialog_active then
        if a11y.ui_model then a11y.ui_model.focus_reason = "no-selection" end
        a11y.reset_focus_reuse_state()
    end
    if pending_message_text ~= nil then
        -- The game's focus widget may be ready before its dialog text hook.
        -- Let the paragraph enter Prism first, then queue its button.
        a11y.capture_pending_modal_button(selected_key, selected_entry, selected_offset,
            selected_key and ui_focus_activated[selected_key] and ui_focus_activated[selected_key][1])
        ui_focus_candidate_key = candidate_key
        ui_focus_candidate_since = frame
        return selected_entry ~= nil
    end
    local pre_match_action = selected_focus_text and a11y.pre_match_active
        and a11y.pre_match_actions[selected_focus_text] or false
    local dialog_dismissed
    dialog_active, modal_focus_blocked, dialog_dismissed =
        a11y.dismiss_dialog_for_focus(
            dialog_active,
            modal_focus_blocked,
            selected_entry,
            selected_activity)
    -- Let fresh destination focus expire a closed dialog, but leave an
    -- active dialog exclusively to its own reader (including Sim/Não).
    if dialog_active then return selected_entry ~= nil end
    local fast_known_focus = selected_key
        and (control_rows_by_label_widget[selected_key]
            or control_row_by_value_widget[selected_key]
            or controller_labels[selected_focus_text]
            or a11y.fast_focus_items[selected_focus_text])
    local focus_debounce_frames = (selected_focus_text
            and is_modal_button(selected_focus_text) and 10)
        or pre_match_action and 4
        or (game_plan_roster_context and selected_offset == 0xfc and 18)
        or (recent_navigation and selected_offset == 0x104
            and selected_activity and frame - selected_activity <= 2
            and 0)
        -- 0x104 is the verified active-focus bank on ordinary PES menus.
        -- Hidden widgets may retain bits elsewhere, but cannot enter this
        -- fast path unless the selection resolver chose this exact bank.
        or (selected_offset == 0x104 and 4)
        or (fast_known_focus and 4)
        or 12
    a11y.observe_diagnostic_focus(
        candidate_key,
        selected_key,
        selected_entry,
        selected_offset,
        counts,
        selected,
        selected_seen,
        dense_virtual_list)
    if edit_position_active and selected_focus_text
            and selected_focus_text:match("^%d+%s+%S") then
        -- Player headings are updated in place. Their dedicated delayed
        -- reader follows that update directly; the generic focus debounce
        -- would otherwise miss fast navigation or repeat the same player.
        return selected_entry ~= nil
    end
    local selected_is_modal_button = selected_entry
        and is_modal_button(selected_entry.text)
    local selected_is_known_control = selected_key
        and (control_rows_by_label_widget[selected_key]
            or control_row_by_value_widget[selected_key])
    local selected_is_startup_item = selected_is_modal_button
        or selected_is_known_control
        or (selected_entry and language_options[selected_entry.text])
    local changed_after_message = modal_focus_blocked
        and selected_offset_index
        and selected_seen[selected_offset_index] > modal_message_spoken_frame + 2
    -- Keep the initial item silent after an instructional paragraph. There is
    -- no reliable NVDA completion callback here. A real arrow movement changes
    -- the focus after the paragraph began and is announced immediately.
    -- A focus seen while a title/dialog speaks has not been announced yet.
    -- Do not mark it as read: the same row must still be available afterward.
    local startup_focus_allowed = selected_entry and (
        (startup_complete and frame - startup_completed_frame >= 12)
        or selected_is_startup_item)
    if dialog_dismissed and pre_match_action and startup_focus_allowed then
        a11y.pre_match_entry_pending = false
        a11y.pre_match_last_action = selected_focus_text
        last_ui_focus_announcement = candidate_key
        ui_focus_candidate_key = candidate_key
        ui_focus_candidate_since = frame
        a11y.commit_read_selection(ui_focus_speech(selected_focus_text), candidate_key, "adapter-focus")
        if a11y.pre_match_notice_text then
            speak(a11y.pre_match_notice_text)
            a11y.offer_adapter_selection(ui_focus_speech(selected_focus_text),candidate_key,selected_entry.address,false)
        else
            a11y.offer_adapter_selection(ui_focus_speech(selected_focus_text),candidate_key,selected_entry.address)
        end
        return true
    end
    if a11y.pre_match_entry_pending and pre_match_action
            and startup_focus_allowed then
        if frame > a11y.pre_match_entry_guard_until_frame then
            a11y.pre_match_entry_pending = false
        elseif modal_message_spoken_frame == frame
                and pending_message_text == nil then
            a11y.pre_match_entry_pending = false
            a11y.pre_match_last_action = selected_focus_text
            last_ui_focus_announcement = candidate_key
            ui_focus_candidate_key = candidate_key
            ui_focus_candidate_since = frame
            a11y.commit_read_selection(ui_focus_speech(selected_focus_text), candidate_key, "adapter-focus")
            a11y.offer_adapter_selection(ui_focus_speech(selected_focus_text),candidate_key,selected_entry.address,false)
            return true
        else
            ui_focus_candidate_key = candidate_key
            ui_focus_candidate_since = frame
            return true
        end
    end
    if candidate_key ~= ui_focus_candidate_key then
        log_focus_snapshot(counts, selected, selected_seen)
        ui_focus_candidate_key = candidate_key
        ui_focus_candidate_since = frame
        local game_plan_menu_navigation = recent_navigation
            and a11y.game_plan_active
            and ((a11y.game_plan_basic_prompt_active
                    and a11y.game_plan_basic_prompt_items[selected_focus_text])
                or ((a11y.navigation_action == "up"
                        or a11y.navigation_action == "down")
                    and selected_is_formation
                    and (a11y.game_plan_context == "Alterar formação"
                        or a11y.game_plan_context == "Change Formation"))
                or (a11y.game_plan_menu_items[selected_focus_text]
                    and not a11y.game_plan_edit_contexts[
                        a11y.game_plan_context]
                    and a11y.game_plan_context ~=
                        "Configurações táticas básicas"
                    and a11y.game_plan_context ~=
                        "Basic Tactical Settings"
                    and not a11y.game_plan_formation_active))
        if game_plan_menu_navigation and startup_focus_allowed
                and candidate_key ~= last_ui_focus_announcement then
            -- Known Game Plan rows are authoritative and often exist for only
            -- one render frame between animated player-card refreshes.
            last_ui_focus_announcement = candidate_key
            ui_focus_preferred_offset_index = selected_offset_index
            local announcement = a11y.game_plan_focus_speech(
                selected_focus_text, selected_key)
            if announcement then
                a11y.commit_read_selection(announcement, candidate_key, "adapter-focus")
                a11y.offer_adapter_selection(announcement,candidate_key,selected_entry.address)
            end
        elseif pre_match_action and startup_focus_allowed
                and (not dialog_active or selected_is_modal_button)
                and candidate_key ~= last_ui_focus_announcement then
            -- Pre-match recreates unrelated widgets continuously, resetting
            -- the generic debounce before it can finish. Its six known action
            -- strings already identify the selected command reliably.
            last_ui_focus_announcement = candidate_key
            ui_focus_preferred_offset_index = selected_offset_index
            a11y.pre_match_last_action = selected_focus_text
            a11y.commit_read_selection(ui_focus_speech(selected_focus_text), candidate_key, "adapter-focus")
            a11y.offer_adapter_selection(ui_focus_speech(selected_focus_text),candidate_key,selected_entry.address)
        end
    elseif candidate_key
            and frame - ui_focus_candidate_since >= focus_debounce_frames
            and (not modal_focus_blocked or changed_after_message
                or pre_match_action)
            and startup_focus_allowed
            and (not dense_virtual_list or a11y.game_plan_active
                or a11y.cup_group_table_active
                or selected_is_startup_item)
            and (not dialog_active or selected_is_modal_button)
            and candidate_key ~= last_ui_focus_announcement then
        last_ui_focus_announcement = candidate_key
        if selected_key ~= main_menu_title_widget_key then
            dynamic_text_candidate = nil
            dynamic_text_due_ms = nil
            main_menu_tooltip = nil
            main_menu_tooltip_due_ms = nil
        end
        log(string.format(
            "[FLAccess] ui-focus offset=0x%x widget=%s text=%q reason=%s identity=%s",
            selected_offset,
            selected_key,
            selected_entry.text,
            a11y.ui_model and a11y.ui_model.focus_reason or "legacy-adapter",
            candidate_key))
        ui_focus_preferred_offset_index = selected_offset_index
        a11y.commit_read_selection(ui_focus_speech(selected_focus_text), candidate_key,
            selected_offset == 0x104 and "primary-focus" or "adapter-focus")
        local selected_control = control_rows_by_label_widget[selected_key]
            or (controller_labels[selected_entry.text]
                and controller_rows[selected_entry.text])
        if preserved_pre_match_row then
            selected_control = nil
        end
        if selected_control
                and selected_control.label ~= selected_entry.text then
            selected_control = nil
        end
        local selected_value_control =
            control_row_by_value_widget[selected_key]
        local stadium_control = selected_offset == 0x104
            and stadium_control_for_entry(selected_key, selected_entry) or nil
        local handled_control = false
        local now_ms = tonumber(ffi.C.GetTickCount64())
        local tactical_row
        if a11y.game_plan_active
                and (a11y.game_plan_context ==
                        "Configurações táticas básicas"
                    or a11y.game_plan_context ==
                        "Basic Tactical Settings")
                and a11y.game_plan_active_tactical_label
                and frame - a11y.game_plan_active_tactical_frame <= 90 then
            tactical_row = controller_rows[
                a11y.game_plan_active_tactical_label]
        end
        local formation_inside = selected_focus_text:match("%((.-)%)")
        local compact_formation = formation_inside
            and formation_inside:gsub("%s+", "") or nil
        local formation_context = a11y.game_plan_context == "Alterar formação"
            or a11y.game_plan_context == "Change Formation"
        local formation_text = a11y.game_plan_active and formation_context
            and ((compact_formation
                    and compact_formation:match("^%d[%d%-]+$"))
                or selected_focus_text:match("^%d[%d%-]+$"))
        if formation_text then
            a11y.game_plan_formation_active = true
        end
        if selected_control and selected_control.native_slider then
            active_control_row = selected_control
            active_controller_label = selected_control.label
            a11y.game_plan_active_tactical_label = selected_control.label
            a11y.game_plan_active_tactical_value = selected_control.value
            a11y.game_plan_active_tactical_frame = frame
            announce_control(selected_control)
            handled_control = true
        elseif tactical_row then
            -- A single live heading contains authoritative label and value.
            -- Ignore stale focus bits belonging to the other rendered rows.
            announce_control(tactical_row)
            handled_control = true
        elseif formation_text then
            local announcement = a11y.game_plan_focus_speech(
                selected_focus_text,
                selected_key)
            if announcement then
                a11y.offer_adapter_selection(announcement,candidate_key,selected_entry.address)
            end
            handled_control = true
        elseif a11y.game_plan_formation_active then
            -- Formation lists redraw player names and old tactical values in
            -- the same focus banks. Only the formation row is interactive.
            handled_control = true
        elseif a11y.game_plan_active
                and not a11y.game_plan_edit_contexts[a11y.game_plan_context]
                and a11y.game_plan_context ~= "Configurações táticas básicas"
                and a11y.game_plan_context ~= "Basic Tactical Settings"
                and a11y.game_plan_menu_items[selected_focus_text] then
            local announcement = a11y.game_plan_focus_speech(
                selected_focus_text,
                selected_key)
            if announcement then
                a11y.offer_adapter_selection(announcement,candidate_key,selected_entry.address)
            end
            handled_control = true
        elseif stadium_control then
            if active_control_row == stadium_control then
                announce_control_value(stadium_control, selected_entry.text)
            else
                announce_control(stadium_control)
            end
            handled_control = true
        elseif focused_control_hint
                and now_ms - focused_control_hint_ms <= 1500
                and selected_entry.text ~= focused_control_hint
                and a11y.valid_control_value(
                    selected_entry.address, selected_entry.text) then
            local hinted_row = controller_rows[focused_control_hint] or {
                label = focused_control_hint,
                role = "seletor",
                label_widget_key = "hint:" .. focused_control_hint,
                is_control = true,
            }
            hinted_row.value = selected_entry.text
            controller_rows[focused_control_hint] = hinted_row
            announce_control(hinted_row)
            focused_control_hint = nil
            handled_control = true
        elseif selected_control and (selected_control.is_control
                or (selected_control.value
                    and selected_control.value ~= ""
                    and not is_modal_button(selected_control.value)
                    and not non_control_labels[selected_control.label])) then
            announce_control(selected_control)
            handled_control = true
        elseif selected_value_control and (selected_value_control.is_control
                or (selected_value_control.value
                    and selected_value_control.value ~= ""
                    and not is_modal_button(selected_value_control.value)
                    and not non_control_labels[selected_value_control.label]))
                and a11y.valid_control_value(
                    selected_entry.address, selected_entry.text) then
            announce_control_value(
                selected_value_control,
                selected_entry.text)
            handled_control = true
        elseif active_control_row
                and not active_control_row.native_slider
                and not active_control_row.external_value
                and not a11y.game_plan_active
                and now_ms - active_control_focused_ms <= 500
                and selected_entry.address ~= active_control_row.label_widget
                and not control_rows_by_label_widget[selected_key]
                and a11y.valid_control_value(
                    selected_entry.address, selected_entry.text) then
            local attached = attach_control_value(
                active_control_row,
                selected_entry.address,
                selected_entry.text)
            if attached then
                announce_control_value(active_control_row, selected_entry.text)
                handled_control = true
            end
        end
        if not handled_control then
                if pre_match_action then
                    a11y.pre_match_last_action = selected_focus_text
                end
                local announcement = a11y.cup_group_team_speech(
                    selected_focus_text,
                    selected_key) or a11y.game_plan_focus_speech(
                        selected_focus_text,
                        selected_key)
                if announcement then
                    a11y.commit_read_selection(announcement, candidate_key, "adapter-focus")
                    a11y.offer_adapter_selection(announcement,candidate_key,selected_entry.address)
                end
                -- Modal scheduling belongs to the common speech boundary.
        end
    end
    return selected_entry ~= nil
end

