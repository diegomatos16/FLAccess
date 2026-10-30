function a11y.native_control_help(text,source_node)
    local model,snapshot=a11y.ui_model,a11y.native_windows
    if not model or not snapshot then return nil end
    local base=tonumber(process_base_u64)
    if not base then return nil end
    local bucket=model.texts and model.texts[text]
    local candidates=source_node and {[source_node.key]=source_node} or (bucket and bucket.nodes or {})
    for _,node in pairs(candidates) do
        local member=snapshot.members[tonumber(node.address)]
        if node.text==text and member and member.active
                and node.name~="question" and node.name~="eventMsg"
                and a11y.native_presentation_ready(node.address) and a11y.ui_node_matches_live(node) then
            local help_owner={}
            for _,entry in ipairs(member.owners or {}) do
                local at=tonumber(node.address)
                local visited={}
                for _=1,8 do
                    if not at or visited[at] or not entry.enabled then break end
                    visited[at]=true
                    -- RTTI-proven NodeRectHelpBox, including its delegated text.
                    if a11y.menu_read(at,"u64")==base+0x27c17a0 then help_owner[entry.address]=true;break end
                    at=entry.parents and entry.parents[at]
                end
            end
            for _,window in ipairs(snapshot.windows or {}) do
                if window.enabled and help_owner[window.address] then return node end
            end
        end
    end
end

function a11y.is_control_help(text)
    if a11y.common_tooltip and a11y.common_tooltip.text==text
            and a11y.tooltip_selection_stamp()==a11y.common_tooltip.selection then return true end
    if a11y.native_control_help(text) then return true end
    -- The lexicon calls ordinary option explanations "instruction" too.
    -- Classify them as help only in an observed control surface. Tutorials
    -- and confirmation paragraphs retain their modal path.
    local role = a11y.text_asset_role(text)
    if role ~= "tooltip-or-description" and (role ~= "instruction"
            or not (text:match("^Escolha ") or text:match("^Choose "))) then
        return false
    end
    for key, row in pairs(control_rows_by_label_widget) do
        if row.is_control and a11y.ui_model.nodes[key] then return true end
    end
    return false
end

function a11y.invalidate_structural_pair(stem)
    local model = a11y.ui_model
    for key in pairs(model and model.names[stem .. "_item"] or {}) do
        local row = control_rows_by_label_widget[key]
        -- Repeated internal names are normal in separate native components.
        -- Invalidate only a binding whose own structural proof was lost.
        if row and row.value_widget
                and a11y.structural_control_row(row.value_widget) ~= row then
            if row.value_widget_key and control_row_by_value_widget[row.value_widget_key] == row then
                control_row_by_value_widget[row.value_widget_key] = nil
            end
            row.value, row.value_widget, row.value_widget_key = nil, nil, nil
        end
    end
end

local function formatted_slider_value(row, value)
    if row.minimum == 0 and row.maximum == 15 then
        return tostring(value) .. " de 15"
    end
    return tostring(value)
end

local function bind_delayed_speed_slider(row)
    if not row or row.label ~= "Velocidade do jogo" then
        return
    end
    local best_key
    local best
    for key, candidate in pairs(unmapped_sliders) do
        if frame - (candidate.last_frame or frame) <= 60
                and (not best
                    or (candidate.last_frame or 0) > (best.last_frame or 0)) then
            best_key = key
            best = candidate
        end
    end
    if not best then
        return
    end
    row.role = "controle deslizante"
    row.native_slider = true
    row.minimum = best.minimum or -2
    row.maximum = best.maximum or 2
    row.is_control = true
    row.value = formatted_slider_value(row, best.value or 0)
    slider_rows[best_key] = {
        id = nil,
        text = row.label,
        control = row,
    }
    unmapped_sliders[best_key] = nil
    log(string.format(
        "[FLAccess] slider-map-delayed text=%q object=%s value=%d min=%d max=%d",
        row.label,
        best_key,
        best.value or 0,
        row.minimum,
        row.maximum))
end

function m.on_slider_init(ctx, event_id, registers)
    local slider = read_u64(registers.rcx)
    local maximum = tonumber(ffi.cast("int32_t", read_u64(registers.rdx)))
    local minimum = tonumber(ffi.cast("int32_t", read_u64(registers.r8)))
    local value = tonumber(ffi.cast("int32_t", read_u64(registers.r9)))
    local pending = pending_control_row
    local pending_is_fresh = pending
        and frame - (pending.created_frame or frame) <= 2
    local mapped_id = last_audio_id
    local mapped_entry = mapped_id and widgets[mapped_id] or nil
    local key = memory.hex(slider)
    if minimum >= -1000 and maximum <= 1000 and minimum < maximum then
        unmapped_sliders[key] = {
            minimum = minimum,
            maximum = maximum,
            value = value,
            last_frame = frame,
        }
    end
    if not mapped_entry and pending_is_fresh then
        mapped_entry = {
            text = pending.label,
            address = pending.label_widget,
        }
    end
    if mapped_entry and minimum >= -1000 and maximum <= 1000
            and minimum < maximum then
        local control = (not mapped_id and pending_is_fresh) and pending
            or register_control_label(
            mapped_entry.text,
            mapped_entry.address,
            "controle deslizante",
            true)
        control.role = "controle deslizante"
        control.native_slider = true
        control.minimum = minimum
        control.maximum = maximum
        control.is_control = true
        control.value = formatted_slider_value(control, value)
        slider_rows[key] = {
            id = mapped_id,
            text = mapped_entry.text,
            control = control,
        }
        unmapped_sliders[key] = nil
        if mapped_id then
            slider_values[mapped_id] = value
        end
        if a11y.game_plan_context == "Configurações táticas básicas"
                or a11y.game_plan_context == "Basic Tactical Settings" then
            active_control_row = control
            active_controller_label = control.label
            active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
            a11y.game_plan_active_tactical_label = control.label
            a11y.game_plan_active_tactical_value = control.value
            a11y.game_plan_active_tactical_widget = control.label_widget_key
            a11y.game_plan_active_tactical_frame = frame
            last_spoken_controller_tooltip_key = nil
        end
        log(string.format(
            "[FLAccess] slider-map id=%s text=%q object=%s value=%d min=%d max=%d",
            mapped_id and tostring(mapped_id) or "dynamic",
            mapped_entry.text,
            key,
            value,
            minimum,
            maximum))
        a11y.record_slider(
            "init", key, value, control, minimum, maximum)
        pending_control_row = nil
        last_audio_id = nil
    end
end

function m.on_slider_set(ctx, event_id, registers)
    local slider = read_u64(registers.rcx)
    local value = tonumber(ffi.cast("int32_t", read_u64(registers.rdx)))
    local key = memory.hex(slider)
    local row = slider_rows[key]
    if not row then
        local pending = unmapped_sliders[key] or {}
        pending.value = value
        pending.last_frame = frame
        unmapped_sliders[key] = pending
    end
    if row then
        if row.id then
            slider_values[row.id] = value
        end
        local full_value = formatted_slider_value(row.control, value)
        row.control.value = full_value
        if a11y.read_context_state().kind == "dialog" then return end
        local focused = active_control_row == row.control
            or (row.id and is_focused(row.id))
            or is_widget_focused(row.control.label_widget)
        if focused then
            a11y.commit_read_selection(control_speech(row.control),
                row.control.identity or row.control.label_widget_key or key,
                "control", row.control.label)
            if active_control_row == row.control then
                -- Preserve the range for the complete focus announcement, but
                -- lateral changes should say only the newly selected value.
                local full = control_speech(row.control)
                if last_announced_control_row ~= row.control then
                    announce_control(row.control)
                elseif full ~= last_controller_announcement then
                    last_controller_announcement = full
                    speak(tostring(value))
                end
            else
                announce_control(row.control)
            end
        end
    end
    a11y.record_slider(
        "set",
        key,
        value,
        row and row.control or nil,
        row and row.control.minimum or nil,
        row and row.control.maximum or nil)
    trace_log(string.format(
        "[FLAccess] slider-set value=%d object=%s id=%s text=%q",
        value,
        key,
        row and tostring(row.id) or "none",
        row and row.text or ""))
end

local function language_value(registers)
    local controller = read_u64(registers.rcx)
    local index = tonumber(ffi.cast("uint32_t", read_u64(registers.rdx)))
    if not controller or controller < 0x10000 or index > 255
            or not readable(controller + 0x90, 8) then
        return nil, controller, index
    end
    local first = read_u64(memory.read(controller + 0x90, 8))
    return a11y.read_msvc_string(first + index * 0x20), controller, index
end

local function language_value_at(controller, index)
    if not controller or controller < 0x10000 or not index or index > 255
            or not readable(controller + 0x90, 8) then
        return nil
    end
    local first = read_u64(memory.read(controller + 0x90, 8))
    return a11y.read_msvc_string(first + index * 0x20)
end

local function speak_language(registers, label, update_ui_language)
    local value, controller, index = language_value(registers)
    log(string.format(
        "[FLAccess] language-set label=%q object=%s index=%d value=%q",
        label,
        memory.hex(controller or 0),
        index or -1,
        value or ""))
    if value and value ~= "" then
        if update_ui_language then
            a11y.set_ui_language_from_name(value)
        end
        local key = "language:" .. memory.hex(controller or 0)
        local row = language_control_by_controller[key] or {
            label = label,
            role = "seletor",
            label_widget_key = key,
            is_control = true,
            external_value = true,
        }
        row.label = label
        row.value = value
        language_control_by_controller[key] = row
        announce_control(row)
    end
end

function m.on_game_text_language_set(ctx, event_id, registers)
    speak_language(registers, "Texto do jogo", true)
end

function m.on_commentary_language_set(ctx, event_id, registers)
    speak_language(registers, "Idioma do comentário", false)
end

function a11y.language_setting_label(controller)
    local base=tonumber(process_base_u64)
    local vt=controller and a11y.menu_read(controller,"u64")
    local setter=vt and a11y.menu_read(vt+0x258,"u64")
    if not base then return nil end
    if setter==base+COMMENTARY_LANGUAGE_SET_RVA then
        return a11y.ui_language=="pt" and "Idioma do comentário" or "Commentary language"
    elseif setter==base+GAME_TEXT_LANGUAGE_SET_RVA then
        return a11y.ui_language=="pt" and "Texto do jogo" or "Game text"
    end
end

function a11y.native_language_context()
    local found
    for _,window in ipairs(a11y.native_windows and a11y.native_windows.windows or {}) do
        local label=window.enabled and window.root and window.root>=0x10000
            and a11y.language_setting_label(window.address)
        local flags=label and a11y.menu_read(window.root+0xc,"u32")
        if flags and flags%8==7 and math.floor(flags/256)%2==1 then
            if found then return nil end
            found={window=window.address,root=window.root,label=label,
                identity=tostring(window.address) .. ":" .. tostring(window.root) .. ":" .. label}
        end
    end
    return found
end

function a11y.poll_native_language()
    local context=a11y.native_language_context()
    if not context then a11y.language_announced,a11y.language_active=nil,nil;return end
    if a11y.language_active~=context.identity then
        a11y.language_active=context.identity
        a11y.language_generation=(a11y.language_generation or 0)+1
        a11y.language_announced=nil
    end
    if a11y.language_announced==context.identity or a11y.read_context_state().kind=="dialog" then return end
    local before=a11y.native_speech_last
    a11y.set_read_title(context.label)
    speak(context.label,true,nil,"language-header:" .. context.identity .. ":" .. tostring(a11y.language_generation))
    if a11y.native_speech_last>before then
        a11y.language_announced=context.identity
        a11y.title_pending_first_item=context.label
        a11y.title_pending_first_item_until_ms=tonumber(ffi.C.GetTickCount64())+2000
        for index=before+1,a11y.native_speech_last do
            a11y.native_speech_queue[index].language_header=context.identity
            a11y.native_speech_queue[index].language_generation=a11y.language_generation
        end
    end
end

function a11y.native_language_heading(widget)
    local name=widget and a11y.widget_internal_name(widget)
    if name~="title" and name~="text_title" then return nil end
    local snapshot=a11y.native_windows
    local member=widget and snapshot and snapshot.members and snapshot.members[tonumber(widget)]
    local label
    for _,owner in ipairs(member and member.owners or {}) do
        if owner.enabled then
            local current=a11y.language_setting_label(owner.address)
            if current then
                if label and label~=current then return nil end
                label=current
            end
        end
    end
    return label
end

function m.on_game_text_language_nav(ctx, event_id, registers)
    local controller = read_u64(registers.rbx)
    local index = tonumber(ffi.cast("uint32_t", read_u64(registers.rax)))
    local value = language_value_at(controller, index)
    log(string.format(
        "[FLAccess] language-nav object=%s index=%d value=%q",
        memory.hex(controller or 0),
        index or -1,
        value or ""))
    if value and value ~= "" then
        local key = "language:" .. memory.hex(controller or 0)
        -- Shared navigation belongs to both language controllers. Their
        -- virtual commit method identifies the setting even before confirm.
        local label=a11y.language_setting_label(controller)
        if not label then return end
        local row = language_control_by_controller[key] or {
            label = label,
            role = "seletor",
            label_widget_key = key,
            is_control = true,
            external_value = true,
        }
        row.label=label
        language_control_by_controller[key] = row
        -- This startup screen has only one control. Repeating its label is
        -- useful context: a bare language name does not tell a screen-reader
        -- user whether it changes commentary, menus, or the game's text.
        row.value = value
        announce_control(row)
    end
end

function m.on_ui_text_set(ctx, event_id, registers)
    local widget=tonumber(read_u64(registers.rcx))
    local raw=a11y.read_msvc_string(read_u64(registers.rdx),true)
    if raw~=nil then a11y.on_observed_ui_text(widget,clean_text(raw),raw,registers) end
end

-- Existing caption-based adapters remain isolated from native component
-- discovery. Do not extend these cases to cover new screens; obtain native
-- owner/selection evidence in the common reader instead.
function a11y.observe_compatibility_context(widget_key, text)
    if a11y.native_pause_context() then return false,false end
    local normal_game_plan_marker = text == "Escalação/Editar posição"
        or text == "Team Sheet/Edit Position"
    if normal_game_plan_marker and not a11y.game_plan_active
            and (not a11y.pre_match_active
                or a11y.game_plan_entry_requested) then
        -- The normal Game Plan screen does not expose its visible "Plano de
        -- jogo" caption through the dedicated title widget used by submenus.
        -- Its Team Sheet/Edit Position command is unique to this surface and
        -- therefore provides a safe structural entry marker.
        a11y.game_plan_active = true
        a11y.game_plan_entry_requested = false
        a11y.game_plan_main_surface = true
        a11y.game_plan_context = a11y.ui_language == "pt"
            and "Plano de jogo normal" or "Normal Game Plan"
        a11y.game_plan_pending_title = a11y.game_plan_context
        a11y.game_plan_announced_context = nil
        a11y.game_plan_last_focus_text = nil
        a11y.game_plan_last_focus_widget = nil
        a11y.game_plan_last_menu_focus = text
        a11y.game_plan_selected_heading = nil
        a11y.game_plan_selected_heading_widget = nil
        a11y.game_plan_selected_heading_frame = -10000
        a11y.game_plan_selected_heading_due_frame = nil
        a11y.game_plan_last_announced_heading = nil
        a11y.game_plan_last_player_section = nil
        a11y.game_plan_attribute_panel_until_ms = 0
        a11y.game_plan_attribute_locked_name = nil
        a11y.game_plan_attribute_due_ms = nil
        a11y.game_plan_attribute_hold_until_ms = 0
        a11y.game_plan_formation_active = false
        a11y.game_plan_lineup_generation_frame = frame
        a11y.pre_match_active = false
        a11y.pre_match_entry_pending = false
        -- Control widgets are aggressively recycled between screens. Do not
        -- let the last selector on the previous screen claim a Game Plan
        -- command (for example "Agressiva, Gestão de dados") as its value.
        a11y.reset_control_tracking_state()
        focused_control_hint = nil
        a11y.reset_focus_reuse_state()
        -- This default command can exist for only one render frame before the
        -- first-use tutorial opens. Capture and announce it synchronously so
        -- a quick confirmation still enters Edit Position with the right
        -- semantic context.
        local initial_announcement = a11y.game_plan_focus_speech(
            text,
            widget_key)
        if initial_announcement then
            speak(initial_announcement)
        end
    end
    local tactical_label, tactical_value =
        text:match("^(.+)%s+:%s+(.+)$")
    if tactical_label and tactical_value then
        local short_or_long_pass = tactical_value == "Passe curto"
            or tactical_value == "Passe longo"
            or tactical_value == "Short-pass"
            or tactical_value == "Long-pass"
            or tactical_value == "Short Pass"
            or tactical_value == "Long Pass"
        if short_or_long_pass and not a11y.game_plan_tactical_labels[
                tactical_label] then
            -- The second row exposes its current advanced-instruction value
            -- (for example "Provocador") where its label should be.
            tactical_label = a11y.ui_language == "pt"
                and "Construção" or "Build Up"
        end
    end
    local tactical_heading = a11y.game_plan_active
        and tactical_label and tactical_value
        and a11y.game_plan_tactical_labels[tactical_label]
    if tactical_heading then
        local entering_tactical = a11y.game_plan_context ~=
            "Configurações táticas básicas"
            and a11y.game_plan_context ~= "Basic Tactical Settings"
        if entering_tactical then
            a11y.game_plan_basic_prompt_active = false
            a11y.game_plan_formation_active = false
            a11y.reset_focus_reuse_state()
            a11y.game_plan_last_focus_text = nil
            a11y.game_plan_announced_context = nil
        end
        a11y.game_plan_context = a11y.ui_language == "pt"
            and "Configurações táticas básicas" or "Basic Tactical Settings"
        local tactical_changed = tactical_label ~=
                a11y.game_plan_active_tactical_label
            or tactical_value ~= a11y.game_plan_active_tactical_value
        local horizontal_value_change = tactical_label ==
                a11y.game_plan_active_tactical_label
            and (a11y.diagnostic_last_input_action == "left"
                or a11y.diagnostic_last_input_action == "right")
            and frame - a11y.diagnostic_last_input_frame <= 12
        a11y.game_plan_active_tactical_label = tactical_label
        a11y.game_plan_active_tactical_value = tactical_value
        a11y.game_plan_active_tactical_widget = widget_key
        a11y.game_plan_active_tactical_frame = frame
        local row = controller_rows[tactical_label] or {
            label = tactical_label,
            role = a11y.ui_language == "pt" and "seletor" or "selector",
            label_widget_key = "game-plan-tactical:" .. tactical_label,
            is_control = true,
        }
        row.value = tactical_value
        row.is_control = true
        controller_rows[tactical_label] = row
        if tactical_changed then
            active_control_row = row
            active_controller_label = tactical_label
            active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
            last_controller_announcement = control_speech(row)
            last_announced_control_row = row
            last_announced_selector_label = row.label_widget_key
            last_spoken_controller_tooltip_key = nil
            speak(horizontal_value_change
                and tactical_value or last_controller_announcement)
            if pending_controller_tooltip
                    and frame - a11y.game_plan_tactical_navigation_frame <= 30 then
                pending_controller_tooltip_label = tactical_label
                controller_tooltip_due_ms =
                    tonumber(ffi.C.GetTickCount64())
            end
        end
    end
    local numbered_player_heading = a11y.game_plan_active
        and text:match("^%d+%s+%S") ~= nil
    local game_plan_player_heading = numbered_player_heading
        and a11y.game_plan_edit_contexts[a11y.game_plan_context]
    if game_plan_player_heading then
        a11y.record_game_plan_heading(text, widget_key)
    end
    if a11y.game_plan_active or a11y.game_plan_roster_contexts[text] then
        a11y.game_plan_attribute_text_events[
            #a11y.game_plan_attribute_text_events + 1] = {
                text = text,
                frame = frame,
                widget = widget_key,
            }
        while #a11y.game_plan_attribute_text_events > 256 do
            table.remove(a11y.game_plan_attribute_text_events, 1)
        end
    end
    local root_game_plan_title = text == "Menu de configuração básica"
        or text == "Basic Settings Menu"
    if root_game_plan_title then
        -- This widget is redrawn on every real transition back to the Basic
        -- Settings menu. Refusing it because the previous context differed
        -- left Formation active and silenced the menu after returning.
        a11y.game_plan_title_widgets[widget_key] = true
    end
    local authoritative_game_plan_title =
        a11y.game_plan_roster_contexts[text]
        and a11y.game_plan_title_widgets[widget_key]
    if authoritative_game_plan_title then
        local previous_game_plan_context = a11y.game_plan_context
        local entering_basic_menu = root_game_plan_title
            and a11y.game_plan_context ~= text
        local entering_edit = a11y.game_plan_edit_contexts[text]
            and not a11y.game_plan_edit_contexts[a11y.game_plan_context]
        local entering_lineup = (a11y.game_plan_edit_contexts[text]
                or text == "Plano de jogo normal"
                or text == "Normal Game Plan")
            and a11y.game_plan_context ~= text
        if entering_basic_menu then
            a11y.game_plan_basic_menu_heading_widget = nil
            a11y.game_plan_basic_menu_heading_text = nil
            a11y.game_plan_basic_menu_heading_due_frame = nil
            a11y.game_plan_basic_prompt_active = false
        end
        a11y.game_plan_active = true
        a11y.game_plan_main_surface = text == "Plano de jogo normal"
            or text == "Normal Game Plan"
        a11y.game_plan_context = text
        a11y.game_plan_pending_title = text
        if previous_game_plan_context ~= text then
            a11y.game_plan_formation_active = false
            a11y.game_plan_last_menu_focus = nil
            a11y.reset_focus_reuse_state()
            a11y.game_plan_last_focus_text = nil
            a11y.game_plan_last_focus_widget = nil
            a11y.game_plan_announced_context = nil
            a11y.game_plan_last_announced_heading = nil
            a11y.game_plan_selected_heading_due_frame = nil
        end
        if text ~= "Configurações táticas básicas"
                and text ~= "Basic Tactical Settings" then
            a11y.game_plan_active_tactical_label = nil
            a11y.game_plan_active_tactical_value = nil
            a11y.game_plan_active_tactical_widget = nil
            a11y.game_plan_last_player_section = nil
        end
        if entering_edit then
            a11y.game_plan_last_player_section = nil
            a11y.game_plan_last_announced_heading = nil
            a11y.game_plan_observed_lineup = {}
        end
        if entering_lineup then
            a11y.game_plan_lineup_generation_frame = frame
        end
        a11y.pre_match_active = false
        a11y.pre_match_entry_pending = false
        a11y.stadium_active = false
        a11y.cup_group_table_active = false
    elseif text == "Configurações do sistema"
            or text == "System Settings" then
        if not a11y.pre_match_active then
            a11y.pre_match_entry_pending = true
            a11y.pre_match_entry_guard_until_frame = frame + 120
            a11y.pre_match_last_action = nil
        end
        a11y.pre_match_active = true
        a11y.leave_game_plan()
        a11y.stadium_active = false
        a11y.cup_group_table_active = false
    elseif text == "Altura da grama" or text == "Grass Length" then
        if not a11y.stadium_active
                or frame - a11y.stadium_last_marker_frame > 120 then
            reset_stadium_screen()
        end
        a11y.stadium_last_marker_frame = frame
        a11y.stadium_active = true
        a11y.leave_game_plan()
        a11y.pre_match_active = false
    end
    return tactical_heading, game_plan_player_heading
end

