-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 10, "FLAccess reader: missing or reordered component controls")
function shared.a11y.native_control_help(text,source_node)
    local model,snapshot=shared.a11y.ui_model,shared.a11y.native_windows
    if not model or not snapshot then return nil end
    local base=tonumber(shared.process_base_u64)
    if not base then return nil end
    local bucket=model.texts and model.texts[text]
    local candidates=source_node and {[source_node.key]=source_node} or (bucket and bucket.nodes or {})
    for _,node in pairs(candidates) do
        local member=snapshot.members[tonumber(node.address)]
        if node.text==text and member and member.active
                and node.name~="question" and node.name~="eventMsg"
                and shared.a11y.native_presentation_ready(node.address) and shared.a11y.ui_node_matches_live(node) then
            local help_owner={}
            for _,entry in ipairs(member.owners or {}) do
                local at=tonumber(node.address)
                local visited={}
                for _=1,8 do
                    if not at or visited[at] or not entry.enabled then break end
                    visited[at]=true
                    -- RTTI-proven NodeRectHelpBox, including its delegated text.
                    if shared.a11y.menu_read(at,"u64")==base+0x27c17a0 then help_owner[entry.address]=true;break end
                    at=entry.parents and entry.parents[at]
                end
            end
            for _,window in ipairs(snapshot.windows or {}) do
                if window.enabled and help_owner[window.address] then return node end
            end
        end
    end
end

function shared.a11y.is_control_help(text)
    if shared.a11y.common_tooltip and shared.a11y.common_tooltip.text==text
            and shared.a11y.tooltip_selection_stamp()==shared.a11y.common_tooltip.selection then return true end
    if shared.a11y.native_control_help(text) then return true end
    -- The lexicon calls ordinary option explanations "instruction" too.
    -- Classify them as help only in an observed control surface. Tutorials
    -- and confirmation paragraphs retain their modal path.
    local role = shared.a11y.text_asset_role(text)
    if role ~= "tooltip-or-description" and (role ~= "instruction"
            or not (text:match("^Escolha ") or text:match("^Choose "))) then
        return false
    end
    for key, row in pairs(shared.control_rows_by_label_widget) do
        if row.is_control and shared.a11y.ui_model.nodes[key] then return true end
    end
    return false
end

function shared.a11y.invalidate_structural_pair(stem)
    local model = shared.a11y.ui_model
    for key in pairs(model and model.names[stem .. "_item"] or {}) do
        local row = shared.control_rows_by_label_widget[key]
        -- Repeated internal names are normal in separate native components.
        -- Invalidate only a binding whose own structural proof was lost.
        if row and row.value_widget
                and shared.a11y.structural_control_row(row.value_widget) ~= row then
            if row.value_widget_key and shared.control_row_by_value_widget[row.value_widget_key] == row then
                shared.control_row_by_value_widget[row.value_widget_key] = nil
            end
            row.value, row.value_widget, row.value_widget_key = nil, nil, nil
        end
    end
end

function shared.formatted_slider_value(row, value)
    if row.minimum == 0 and row.maximum == 15 then
        return tostring(value) .. " de 15"
    end
    return tostring(value)
end

function shared.bind_delayed_speed_slider(row)
    if not row or row.label ~= "Velocidade do jogo" then
        return
    end
    local best_key
    local best
    for key, candidate in pairs(shared.unmapped_sliders) do
        if shared.frame - (candidate.last_frame or shared.frame) <= 60
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
    row.value = shared.formatted_slider_value(row, best.value or 0)
    shared.slider_rows[best_key] = {
        id = nil,
        text = row.label,
        control = row,
    }
    shared.unmapped_sliders[best_key] = nil
    log(string.format(
        "[FLAccess] slider-map-delayed text=%q object=%s value=%d min=%d max=%d",
        row.label,
        best_key,
        best.value or 0,
        row.minimum,
        row.maximum))
end

function shared.m.on_slider_init(ctx, event_id, registers)
    local slider = shared.read_u64(registers.rcx)
    local maximum = tonumber(ffi.cast("int32_t", shared.read_u64(registers.rdx)))
    local minimum = tonumber(ffi.cast("int32_t", shared.read_u64(registers.r8)))
    local value = tonumber(ffi.cast("int32_t", shared.read_u64(registers.r9)))
    local pending = shared.pending_control_row
    local pending_is_fresh = pending
        and shared.frame - (pending.created_frame or shared.frame) <= 2
    local mapped_id = shared.last_audio_id
    local mapped_entry = mapped_id and shared.widgets[mapped_id] or nil
    local key = memory.hex(slider)
    if minimum >= -1000 and maximum <= 1000 and minimum < maximum then
        shared.unmapped_sliders[key] = {
            minimum = minimum,
            maximum = maximum,
            value = value,
            last_frame = shared.frame,
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
            or shared.register_control_label(
            mapped_entry.text,
            mapped_entry.address,
            "controle deslizante",
            true)
        control.role = "controle deslizante"
        control.native_slider = true
        control.minimum = minimum
        control.maximum = maximum
        control.is_control = true
        control.value = shared.formatted_slider_value(control, value)
        shared.slider_rows[key] = {
            id = mapped_id,
            text = mapped_entry.text,
            control = control,
        }
        shared.unmapped_sliders[key] = nil
        if mapped_id then
            shared.slider_values[mapped_id] = value
        end
        if shared.a11y.game_plan_context == "Configurações táticas básicas"
                or shared.a11y.game_plan_context == "Basic Tactical Settings" then
            shared.active_control_row = control
            shared.active_controller_label = control.label
            shared.active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
            shared.a11y.game_plan_active_tactical_label = control.label
            shared.a11y.game_plan_active_tactical_value = control.value
            shared.a11y.game_plan_active_tactical_widget = control.label_widget_key
            shared.a11y.game_plan_active_tactical_frame = shared.frame
            shared.last_spoken_controller_tooltip_key = nil
        end
        log(string.format(
            "[FLAccess] slider-map id=%s text=%q object=%s value=%d min=%d max=%d",
            mapped_id and tostring(mapped_id) or "dynamic",
            mapped_entry.text,
            key,
            value,
            minimum,
            maximum))
        shared.a11y.record_slider(
            "init", key, value, control, minimum, maximum)
        shared.pending_control_row = nil
        shared.last_audio_id = nil
    end
end

function shared.m.on_slider_set(ctx, event_id, registers)
    local slider = shared.read_u64(registers.rcx)
    local value = tonumber(ffi.cast("int32_t", shared.read_u64(registers.rdx)))
    local key = memory.hex(slider)
    local row = shared.slider_rows[key]
    if not row then
        local pending = shared.unmapped_sliders[key] or {}
        pending.value = value
        pending.last_frame = shared.frame
        shared.unmapped_sliders[key] = pending
    end
    if row then
        if row.id then
            shared.slider_values[row.id] = value
        end
        local full_value = shared.formatted_slider_value(row.control, value)
        row.control.value = full_value
        if shared.a11y.read_context_state().kind == "dialog" then return end
        local focused = shared.active_control_row == row.control
            or (row.id and shared.is_focused(row.id))
            or shared.is_widget_focused(row.control.label_widget)
        if focused then
            shared.a11y.commit_read_selection(shared.control_speech(row.control),
                row.control.identity or row.control.label_widget_key or key,
                "control", row.control.label)
            if shared.active_control_row == row.control then
                -- Preserve the range for the complete focus announcement, but
                -- lateral changes should say only the newly selected value.
                local full = shared.control_speech(row.control)
                if shared.last_announced_control_row ~= row.control then
                    shared.announce_control(row.control)
                elseif full ~= shared.last_controller_announcement then
                    shared.last_controller_announcement = full
                    shared.speak(tostring(value))
                end
            else
                shared.announce_control(row.control)
            end
        end
    end
    shared.a11y.record_slider(
        "set",
        key,
        value,
        row and row.control or nil,
        row and row.control.minimum or nil,
        row and row.control.maximum or nil)
    shared.trace_log(string.format(
        "[FLAccess] slider-set value=%d object=%s id=%s text=%q",
        value,
        key,
        row and tostring(row.id) or "none",
        row and row.text or ""))
end

function shared.language_value(registers)
    local controller = shared.read_u64(registers.rcx)
    local index = tonumber(ffi.cast("uint32_t", shared.read_u64(registers.rdx)))
    if not controller or controller < 0x10000 or index > 255
            or not shared.readable(controller + 0x90, 8) then
        return nil, controller, index
    end
    local first = shared.read_u64(memory.read(controller + 0x90, 8))
    return shared.a11y.read_msvc_string(first + index * 0x20), controller, index
end

function shared.language_value_at(controller, index)
    if not controller or controller < 0x10000 or not index or index > 255
            or not shared.readable(controller + 0x90, 8) then
        return nil
    end
    local first = shared.read_u64(memory.read(controller + 0x90, 8))
    return shared.a11y.read_msvc_string(first + index * 0x20)
end

function shared.speak_language(registers, label, update_ui_language)
    local value, controller, index = shared.language_value(registers)
    log(string.format(
        "[FLAccess] language-set label=%q object=%s index=%d value=%q",
        label,
        memory.hex(controller or 0),
        index or -1,
        value or ""))
    if value and value ~= "" then
        if update_ui_language then
            shared.a11y.set_ui_language_from_name(value)
        end
        local key = "language:" .. memory.hex(controller or 0)
        local row = shared.language_control_by_controller[key] or {
            label = label,
            role = "seletor",
            label_widget_key = key,
            is_control = true,
            external_value = true,
        }
        row.label = label
        row.value = value
        shared.language_control_by_controller[key] = row
        shared.announce_control(row)
    end
end

function shared.m.on_game_text_language_set(ctx, event_id, registers)
    shared.speak_language(registers, "Texto do jogo", true)
end

function shared.m.on_commentary_language_set(ctx, event_id, registers)
    shared.speak_language(registers, "Idioma do comentário", false)
end

function shared.a11y.language_setting_label(controller)
    local base=tonumber(shared.process_base_u64)
    local vt=controller and shared.a11y.menu_read(controller,"u64")
    local setter=vt and shared.a11y.menu_read(vt+0x258,"u64")
    if not base then return nil end
    if setter==base+shared.COMMENTARY_LANGUAGE_SET_RVA then
        return shared.a11y.ui_language=="pt" and "Idioma do comentário" or "Commentary language"
    elseif setter==base+shared.GAME_TEXT_LANGUAGE_SET_RVA then
        return shared.a11y.ui_language=="pt" and "Texto do jogo" or "Game text"
    end
end

function shared.a11y.native_language_context()
    local found
    for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
        local label=window.enabled and window.root and window.root>=0x10000
            and shared.a11y.language_setting_label(window.address)
        local flags=label and shared.a11y.menu_read(window.root+0xc,"u32")
        if flags and flags%8==7 and math.floor(flags/256)%2==1 then
            if found then return nil end
            found={window=window.address,root=window.root,label=label,
                identity=tostring(window.address) .. ":" .. tostring(window.root) .. ":" .. label}
        end
    end
    return found
end

function shared.a11y.poll_native_language()
    local context=shared.a11y.native_language_context()
    if not context then shared.a11y.language_announced,shared.a11y.language_active=nil,nil;return end
    if shared.a11y.language_active~=context.identity then
        shared.a11y.language_active=context.identity
        shared.a11y.language_generation=(shared.a11y.language_generation or 0)+1
        shared.a11y.language_announced=nil
    end
    if shared.a11y.language_announced==context.identity or shared.a11y.read_context_state().kind=="dialog" then return end
    local before=shared.a11y.native_speech_last
    shared.a11y.set_read_title(context.label)
    shared.speak(context.label,true,nil,"language-header:" .. context.identity .. ":" .. tostring(shared.a11y.language_generation))
    if shared.a11y.native_speech_last>before then
        shared.a11y.language_announced=context.identity
        shared.a11y.title_pending_first_item=context.label
        shared.a11y.title_pending_first_item_until_ms=tonumber(ffi.C.GetTickCount64())+2000
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].language_header=context.identity
            shared.a11y.native_speech_queue[index].language_generation=shared.a11y.language_generation
        end
    end
end

function shared.a11y.native_language_heading(widget)
    local name=widget and shared.a11y.widget_internal_name(widget)
    if name~="title" and name~="text_title" then return nil end
    local snapshot=shared.a11y.native_windows
    local member=widget and snapshot and snapshot.members and snapshot.members[tonumber(widget)]
    local label
    for _,owner in ipairs(member and member.owners or {}) do
        if owner.enabled then
            local current=shared.a11y.language_setting_label(owner.address)
            if current then
                if label and label~=current then return nil end
                label=current
            end
        end
    end
    return label
end

function shared.m.on_game_text_language_nav(ctx, event_id, registers)
    local controller = shared.read_u64(registers.rbx)
    local index = tonumber(ffi.cast("uint32_t", shared.read_u64(registers.rax)))
    local value = shared.language_value_at(controller, index)
    log(string.format(
        "[FLAccess] language-nav object=%s index=%d value=%q",
        memory.hex(controller or 0),
        index or -1,
        value or ""))
    if value and value ~= "" then
        local key = "language:" .. memory.hex(controller or 0)
        -- Shared navigation belongs to both language controllers. Their
        -- virtual commit method identifies the setting even before confirm.
        local label=shared.a11y.language_setting_label(controller)
        if not label then return end
        local row = shared.language_control_by_controller[key] or {
            label = label,
            role = "seletor",
            label_widget_key = key,
            is_control = true,
            external_value = true,
        }
        row.label=label
        shared.language_control_by_controller[key] = row
        -- This startup screen has only one control. Repeating its label is
        -- useful context: a bare language name does not tell a screen-reader
        -- user whether it changes commentary, menus, or the game's text.
        row.value = value
        shared.announce_control(row)
    end
end

function shared.m.on_ui_text_set(ctx, event_id, registers)
    local widget=tonumber(shared.read_u64(registers.rcx))
    local raw=shared.a11y.read_msvc_string(shared.read_u64(registers.rdx),true)
    if raw~=nil then
        local text=shared.clean_text(raw)
        local known=shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(widget)]
        local list_field=known and (known.name=="playerName" or known.name=="teamName"
            or known.name=="leagueName" or known.name=="allOver" or known.name=="noSetting")
        if list_field and not shared.a11y.diagnostic_mode and known.text==text and known.raw_text==raw
                and shared.a11y.native_windows and shared.a11y.ui_node_matches_live(known)
                and shared.a11y.native_widget_allowed(widget) then
            -- Native cursor polling owns selection changes. Re-rendering an
            -- unchanged list cell does not require rebinding its controls.
            known.last_seen=shared.frame
            return
        end
        shared.a11y.on_observed_ui_text(widget,text,raw,registers)
    end
end

-- Text setters run outside display_frame too. Give each synchronous callback
-- its own scalar cache; never retain register pointers or memory across calls.
local observe_text_set=shared.m.on_ui_text_set
function shared.m.on_ui_text_set(ctx,event_id,registers)
    if shared.a11y.standings_repaint(tonumber(shared.read_u64(registers.rcx))) then
        shared.a11y.standings_text_skipped=(shared.a11y.standings_text_skipped or 0)+1
        return
    end
    local previous_work=shared.a11y.render_read_work
    local previous_metric=shared.a11y.render_metric
    local started=tonumber(ffi.C.GetTickCount64())
    if not previous_work then shared.a11y.render_read_work={} end
    if not previous_metric then shared.a11y.render_metric={reads=0} end
    observe_text_set(ctx,event_id,registers)
    local metric=shared.a11y.render_metric
    local stats=shared.a11y.text_hook_stats or {calls=0,ms=0,reads=0,max_ms=0}
    local elapsed=tonumber(ffi.C.GetTickCount64())-started
    stats.calls,stats.ms=stats.calls+1,stats.ms+elapsed
    stats.max_ms=math.max(stats.max_ms,elapsed)
    if not previous_metric then stats.reads=stats.reads+(metric and metric.reads or 0) end
    shared.a11y.text_hook_stats=stats
    if not previous_work then shared.a11y.render_read_work=nil end
    if not previous_metric then shared.a11y.render_metric=nil end
end

-- Existing caption-based adapters remain isolated from native component
-- discovery. Do not extend these cases to cover new screens; obtain native
-- owner/selection evidence in the common reader instead.
function shared.a11y.observe_compatibility_context(widget_key, text)
    if shared.a11y.native_pause_context() then return false,false end
    local normal_game_plan_marker = text == "Escalação/Editar posição"
        or text == "Team Sheet/Edit Position"
    if normal_game_plan_marker and not shared.a11y.game_plan_active
            and (not shared.a11y.pre_match_active
                or shared.a11y.game_plan_entry_requested) then
        -- The normal Game Plan screen does not expose its visible "Plano de
        -- jogo" caption through the dedicated title widget used by submenus.
        -- Its Team Sheet/Edit Position command is unique to this surface and
        -- therefore provides a safe structural entry marker.
        shared.a11y.game_plan_active = true
        shared.a11y.game_plan_entry_requested = false
        shared.a11y.game_plan_main_surface = true
        shared.a11y.game_plan_context = shared.a11y.ui_language == "pt"
            and "Plano de jogo normal" or "Normal Game Plan"
        shared.a11y.game_plan_pending_title = shared.a11y.game_plan_context
        shared.a11y.game_plan_announced_context = nil
        shared.a11y.game_plan_last_focus_text = nil
        shared.a11y.game_plan_last_focus_widget = nil
        shared.a11y.game_plan_last_menu_focus = text
        shared.a11y.game_plan_selected_heading = nil
        shared.a11y.game_plan_selected_heading_widget = nil
        shared.a11y.game_plan_selected_heading_frame = -10000
        shared.a11y.game_plan_selected_heading_due_frame = nil
        shared.a11y.game_plan_last_announced_heading = nil
        shared.a11y.game_plan_last_player_section = nil
        shared.a11y.game_plan_attribute_panel_until_ms = 0
        shared.a11y.game_plan_attribute_locked_name = nil
        shared.a11y.game_plan_attribute_due_ms = nil
        shared.a11y.game_plan_attribute_hold_until_ms = 0
        shared.a11y.game_plan_formation_active = false
        shared.a11y.game_plan_lineup_generation_frame = shared.frame
        shared.a11y.pre_match_active = false
        shared.a11y.pre_match_entry_pending = false
        -- Control widgets are aggressively recycled between screens. Do not
        -- let the last selector on the previous screen claim a Game Plan
        -- command (for example "Agressiva, Gestão de dados") as its value.
        shared.a11y.reset_control_tracking_state()
        shared.focused_control_hint = nil
        shared.a11y.reset_focus_reuse_state()
        -- This default command can exist for only one render frame before the
        -- first-use tutorial opens. Capture and announce it synchronously so
        -- a quick confirmation still enters Edit Position with the right
        -- semantic context.
        local initial_announcement = shared.a11y.game_plan_focus_speech(
            text,
            widget_key)
        if initial_announcement then
            shared.speak(initial_announcement)
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
        if short_or_long_pass and not shared.a11y.game_plan_tactical_labels[
                tactical_label] then
            -- The second row exposes its current advanced-instruction value
            -- (for example "Provocador") where its label should be.
            tactical_label = shared.a11y.ui_language == "pt"
                and "Construção" or "Build Up"
        end
    end
    local tactical_heading = shared.a11y.game_plan_active
        and tactical_label and tactical_value
        and shared.a11y.game_plan_tactical_labels[tactical_label]
    if tactical_heading then
        local entering_tactical = shared.a11y.game_plan_context ~=
            "Configurações táticas básicas"
            and shared.a11y.game_plan_context ~= "Basic Tactical Settings"
        if entering_tactical then
            shared.a11y.game_plan_basic_prompt_active = false
            shared.a11y.game_plan_formation_active = false
            shared.a11y.reset_focus_reuse_state()
            shared.a11y.game_plan_last_focus_text = nil
            shared.a11y.game_plan_announced_context = nil
        end
        shared.a11y.game_plan_context = shared.a11y.ui_language == "pt"
            and "Configurações táticas básicas" or "Basic Tactical Settings"
        local tactical_changed = tactical_label ~=
                shared.a11y.game_plan_active_tactical_label
            or tactical_value ~= shared.a11y.game_plan_active_tactical_value
        local horizontal_value_change = tactical_label ==
                shared.a11y.game_plan_active_tactical_label
            and (shared.a11y.diagnostic_last_input_action == "left"
                or shared.a11y.diagnostic_last_input_action == "right")
            and shared.frame - shared.a11y.diagnostic_last_input_frame <= 12
        shared.a11y.game_plan_active_tactical_label = tactical_label
        shared.a11y.game_plan_active_tactical_value = tactical_value
        shared.a11y.game_plan_active_tactical_widget = widget_key
        shared.a11y.game_plan_active_tactical_frame = shared.frame
        local row = shared.controller_rows[tactical_label] or {
            label = tactical_label,
            role = shared.a11y.ui_language == "pt" and "seletor" or "selector",
            label_widget_key = "game-plan-tactical:" .. tactical_label,
            is_control = true,
        }
        row.value = tactical_value
        row.is_control = true
        shared.controller_rows[tactical_label] = row
        if tactical_changed then
            shared.active_control_row = row
            shared.active_controller_label = tactical_label
            shared.active_control_focused_ms = tonumber(ffi.C.GetTickCount64())
            shared.last_controller_announcement = shared.control_speech(row)
            shared.last_announced_control_row = row
            shared.last_announced_selector_label = row.label_widget_key
            shared.last_spoken_controller_tooltip_key = nil
            shared.speak(horizontal_value_change
                and tactical_value or shared.last_controller_announcement)
            if shared.pending_controller_tooltip
                    and shared.frame - shared.a11y.game_plan_tactical_navigation_frame <= 30 then
                shared.pending_controller_tooltip_label = tactical_label
                shared.controller_tooltip_due_ms =
                    tonumber(ffi.C.GetTickCount64())
            end
        end
    end
    local numbered_player_heading = shared.a11y.game_plan_active
        and text:match("^%d+%s+%S") ~= nil
        and not text:match("^%d+[%d.,]*%s+[mM]$")
    local game_plan_player_heading = numbered_player_heading
        and shared.a11y.game_plan_edit_contexts[shared.a11y.game_plan_context]
    if game_plan_player_heading then
        shared.a11y.record_game_plan_heading(text, widget_key)
    end
    if shared.a11y.game_plan_active or shared.a11y.game_plan_roster_contexts[text] then
        shared.a11y.game_plan_attribute_text_events[
            #shared.a11y.game_plan_attribute_text_events + 1] = {
                text = text,
                frame = shared.frame,
                widget = widget_key,
            }
        while #shared.a11y.game_plan_attribute_text_events > 256 do
            table.remove(shared.a11y.game_plan_attribute_text_events, 1)
        end
    end
    local root_game_plan_title = text == "Menu de configuração básica"
        or text == "Basic Settings Menu"
    if root_game_plan_title then
        -- This widget is redrawn on every real transition back to the Basic
        -- Settings menu. Refusing it because the previous context differed
        -- left Formation active and silenced the menu after returning.
        shared.a11y.game_plan_title_widgets[widget_key] = true
    end
    local authoritative_game_plan_title =
        shared.a11y.game_plan_roster_contexts[text]
        and shared.a11y.game_plan_title_widgets[widget_key]
    if authoritative_game_plan_title then
        local previous_game_plan_context = shared.a11y.game_plan_context
        local entering_basic_menu = root_game_plan_title
            and shared.a11y.game_plan_context ~= text
        local entering_edit = shared.a11y.game_plan_edit_contexts[text]
            and not shared.a11y.game_plan_edit_contexts[shared.a11y.game_plan_context]
        local entering_lineup = (shared.a11y.game_plan_edit_contexts[text]
                or text == "Plano de jogo normal"
                or text == "Normal Game Plan")
            and shared.a11y.game_plan_context ~= text
        if entering_basic_menu then
            shared.a11y.game_plan_basic_menu_heading_widget = nil
            shared.a11y.game_plan_basic_menu_heading_text = nil
            shared.a11y.game_plan_basic_menu_heading_due_frame = nil
            shared.a11y.game_plan_basic_prompt_active = false
        end
        shared.a11y.game_plan_active = true
        shared.a11y.game_plan_main_surface = text == "Plano de jogo normal"
            or text == "Normal Game Plan"
        shared.a11y.game_plan_context = text
        shared.a11y.game_plan_pending_title = text
        if previous_game_plan_context ~= text then
            shared.a11y.game_plan_formation_active = false
            shared.a11y.game_plan_last_menu_focus = nil
            shared.a11y.reset_focus_reuse_state()
            shared.a11y.game_plan_last_focus_text = nil
            shared.a11y.game_plan_last_focus_widget = nil
            shared.a11y.game_plan_announced_context = nil
            shared.a11y.game_plan_last_announced_heading = nil
            shared.a11y.game_plan_selected_heading_due_frame = nil
        end
        if text ~= "Configurações táticas básicas"
                and text ~= "Basic Tactical Settings" then
            shared.a11y.game_plan_active_tactical_label = nil
            shared.a11y.game_plan_active_tactical_value = nil
            shared.a11y.game_plan_active_tactical_widget = nil
            shared.a11y.game_plan_last_player_section = nil
        end
        if entering_edit then
            shared.a11y.game_plan_last_player_section = nil
            shared.a11y.game_plan_last_announced_heading = nil
            shared.a11y.game_plan_observed_lineup = {}
        end
        if entering_lineup then
            shared.a11y.game_plan_lineup_generation_frame = shared.frame
        end
        shared.a11y.pre_match_active = false
        shared.a11y.pre_match_entry_pending = false
        shared.a11y.stadium_active = false
        shared.a11y.cup_group_table_active = false
    elseif text == "Configurações do sistema"
            or text == "System Settings" then
        if not shared.a11y.pre_match_active then
            shared.a11y.pre_match_entry_pending = true
            shared.a11y.pre_match_entry_guard_until_frame = shared.frame + 120
            shared.a11y.pre_match_last_action = nil
        end
        shared.a11y.pre_match_active = true
        shared.a11y.leave_game_plan()
        shared.a11y.stadium_active = false
        shared.a11y.cup_group_table_active = false
    elseif text == "Altura da grama" or text == "Grass Length" then
        if not shared.a11y.stadium_active
                or shared.frame - shared.a11y.stadium_last_marker_frame > 120 then
            shared.reset_stadium_screen()
        end
        shared.a11y.stadium_last_marker_frame = shared.frame
        shared.a11y.stadium_active = true
        shared.a11y.leave_game_plan()
        shared.a11y.pre_match_active = false
    end
    return tactical_heading, game_plan_player_heading
end


    shared.stage = 11
end
function component.init(ctx)
    component.install(ctx)

end
return component
