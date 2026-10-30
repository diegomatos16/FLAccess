function a11y.tooltip_selection_stamp()
    local parts={}
    for _,window in ipairs(a11y.native_windows and a11y.native_windows.windows or {}) do
        local d=window.enabled and window.cursor_detail
        if d and d.selected then
            parts[#parts+1]=table.concat({window.address,window.root or 0,d.group_index or -1,d.item_index or -1,d.selected},":")
        end
    end
    if #parts==0 then return nil end
    table.sort(parts);return table.concat(parts,"|")
end

function a11y.common_tooltip_allowed(stamp)
    if a11y.tooltip_selection_stamp()~=stamp.selection then return false end
    for _,part in ipairs(stamp.parts) do if not a11y.content_review_allowed(part) then return false end end
    return true
end

function a11y.poll_common_tooltip()
    local context=a11y.read_context_state()
    if not a11y.read_tooltips or context.structural_question or context.structural_event
            or a11y.keyboard_window or a11y.selected_message_packet() then return end
    local selection=a11y.tooltip_selection_stamp()
    if not selection then a11y.common_tooltip=nil;return end
    if not a11y.tooltip_dirty and a11y.tooltip_last_selection==selection then return end
    a11y.tooltip_dirty=false;a11y.tooltip_last_selection=selection
    local snapshot=a11y.native_windows
    local candidates,rank={},-1
    local input_owners={}
    local result=context.selection_result
    local member=result and snapshot.members and snapshot.members[tonumber(result.widget)]
    for _,owner in ipairs(member and member.owners or {}) do if owner.enabled then input_owners[owner.address]=true end end
    if not member then
        for _,window in ipairs(snapshot.windows or {}) do
            if window.enabled and window.cursor_detail and window.cursor_detail.selected then input_owners[window.address]=true end
        end
    end
    for _,node in pairs(a11y.ui_model and a11y.ui_model.nodes or {}) do
        local name=(node.name or ""):lower()
        local member=snapshot.members and snapshot.members[tonumber(node.address)]
        local owned=false
        for _,owner in ipairs(member and member.owners or {}) do if owner.enabled and input_owners[owner.address] then owned=true;break end end
        local body=name=="text_contents" or name=="question" or name=="eventmsg" or name=="messagebody" or name=="bodytext" or name=="padicon"
        if not body and owned and node.text and node.text~="" then
            local structural=name:find("tooltip",1,true) or name:find("description",1,true) or name:find("explanation",1,true)
            local native_help=a11y.native_control_help(node.text,node)
            local current_rank=native_help and 2 or structural and 1 or a11y.text_asset_role(node.text)=="tooltip-or-description" and 0 or -1
            if current_rank>=0 and current_rank>=rank and a11y.native_presentation_ready(node.address)
                    and a11y.ui_node_matches_live(node) and a11y.read_native_rendered_text(node.address)==node.text then
                if current_rank>rank then candidates={};rank=current_rank end
                candidates[#candidates+1]=node
            end
        end
    end
    if #candidates==0 then return end
    table.sort(candidates,function(a,b) return a.sequence<b.sequence end)
    local parts,texts,seen={}, {}, {}
    local owner=a11y.native_owner_token()
    for _,node in ipairs(candidates) do
        if not seen[node.text] then
            seen[node.text]=true;texts[#texts+1]=node.text
            parts[#parts+1]={key=node.key,text=node.text,identity=node.identity,owner=owner}
        end
    end
    local text=table.concat(texts," ")
    local previous=a11y.common_tooltip
    if previous and previous.selection==selection and previous.text==text and previous.status~="pending" then return end
    local stamp={selection=selection,text=text,parts=parts,status="pending",attempt=(previous and previous.attempt or 0)+1}
    a11y.common_tooltip=stamp
    pending_controller_tooltip,controller_tooltip_due_ms=nil,nil
    local before=a11y.native_speech_last
    speak(text,false,true,"tooltip:" .. selection .. ":" .. text .. ":" .. stamp.attempt)
    for index=before+1,a11y.native_speech_last do a11y.native_speech_queue[index].common_tooltip=stamp;stamp.status="queued" end
end

function a11y.finish_render_work()
    a11y.render_read_work=nil
    local metric=a11y.render_metric
    if not metric then return end
    if prism_started and a11y.render_speech_allowed then
        a11y.stop_nvda_if_requested()
        a11y.flush_native_speech(tonumber(ffi.C.GetTickCount64()))
    end
    a11y.render_speech_allowed=false
    a11y.render_metric,a11y.render_read_work=nil,nil
    local elapsed=tonumber(ffi.C.GetTickCount64())-metric.started
    local stats=a11y.render_stats or {frames=0,ms=0,max_ms=0,reads=0,speech_ms=0,speech_calls=0,focus_ms=0}
    stats.frames,stats.ms,stats.reads=stats.frames+1,stats.ms+elapsed,stats.reads+metric.reads
    stats.max_ms=math.max(stats.max_ms,elapsed)
    stats.focus_ms=stats.focus_ms+(metric.focus_ms or 0)
    stats.speech_ms=stats.speech_ms+(metric.speech_ms or 0)
    stats.speech_calls=stats.speech_calls+(metric.speech_calls or 0)
    a11y.render_stats=stats
    if stats.frames>=600 then
        log(string.format("[FLAccess] reader-work frames=%d mean-ms=%.3f max-ms=%d memory-copies-per-frame=%.1f speech-ms=%.3f speech-calls=%d focus-ms=%.3f",
            stats.frames,stats.ms/stats.frames,stats.max_ms,stats.reads/stats.frames,stats.speech_ms/stats.frames,stats.speech_calls,stats.focus_ms/stats.frames))
        a11y.render_stats=nil
    end
end

function m.display_frame(ctx)
    a11y.render_read_work={}
    a11y.render_speech_allowed=false
    a11y.render_metric={started=tonumber(ffi.C.GetTickCount64()),reads=0}
    frame = frame + 1
    a11y.current_frame = frame
    a11y.poll_direct_message_update()
    if not prism_started and frame >= 120 then
        prism_started = true
        start_native_prism(ctx)
    end
    if not game_is_foreground() then
        game_was_foreground = false
        a11y.nvda_stop_requested = false
        a11y.clear_speech_queue()
        a11y.finish_render_work()
        return
    end
    a11y.render_speech_allowed=true
    a11y.poll_native_windows()
    a11y.poll_native_texts()
    a11y.poll_native_country_selection()
    a11y.poll_keyboard_input()
    a11y.poll_information_context()
    a11y.poll_native_pause()
    a11y.poll_native_language()
    a11y.poll_presented_texts()
    a11y.poll_notice_actions()
    a11y.poll_surface_texts()
    a11y.poll_main_menu_choice()
    a11y.poll_loading(tonumber(ffi.C.GetTickCount64()))
    a11y.poll_skip_hint()
    a11y.poll_component_capture()
    if not game_was_foreground then
        game_was_foreground = true
        foreground_resume_frame = frame + 4
        ui_focus_candidate_key = nil
        last_ui_focus_announcement = nil
        a11y.finish_render_work()
        return
    end
    if frame < foreground_resume_frame then
        a11y.finish_render_work()
        return
    end
    if overlay_visible or sider_overlay_visible then
        a11y.finish_render_work()
        return
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    a11y.poll_attribute_input(now_ms)
    a11y.poll_focus_trace()
    a11y.record_game_plan_menu_probe()
    if a11y.game_plan_lineup_due_ms
            and now_ms >= a11y.game_plan_lineup_due_ms then
        a11y.read_visible_game_plan_lineup()
        a11y.game_plan_lineup_due_ms = nil
        a11y.game_plan_lineup_input = nil
    end
    local startup_busy = process_startup_speech(now_ms)
    if pending_message_text and not a11y.native_key_allowed(a11y.pending_message_widget_key) then
        pending_message_text, pending_message_key, pending_message_due_ms = nil, nil, nil
        a11y.pending_message_widget_key = nil
    end
    if not startup_busy and pending_message_due_ms
            and now_ms >= pending_message_due_ms then
        if pending_message_text and pending_message_text ~= ""
                and pending_message_key ~= last_announced_message_key then
            local context = a11y.read_context_state()
            local spoken_prompt = context.structural_question and context.question == pending_message_text
                and ((a11y.ui_language == "pt" and "Pergunta: " or "Question: ") .. pending_message_text)
                or pending_message_text
            local prompt_node=a11y.ui_model and a11y.ui_model.nodes[a11y.pending_message_widget_key]
            speak(spoken_prompt, nil, true, nil, prompt_node and prompt_node.address)
            a11y.dialog_button_queued_for_message = false
            modal_message_spoken_frame = frame
            last_announced_message_key = pending_message_key
            a11y.last_modal_message_text = pending_message_text
            local reading_time = #pending_message_text * 65 + 500
            if reading_time < 1800 then reading_time = 1800 end
            if reading_time > 10000 then reading_time = 10000 end
            -- Consecutive dialog pages are queued in Prism. Keep focus
            -- blocked until the entire queued reading finishes, not only
            -- until the most recently detected page would finish alone.
            modal_focus_hold_until_ms =
                math.max(now_ms, modal_focus_hold_until_ms) + reading_time
            if #a11y.modal_message_backlog == 0
                    and a11y.pending_modal_button_text
                    and not a11y.ignore_cup_group_focus(
                        a11y.pending_modal_button_text) then
                if a11y.deferred_modal_announcement
                        and a11y.deferred_modal_announcement:sub(
                            1, #a11y.pending_modal_button_text)
                                == a11y.pending_modal_button_text then
                    a11y.deferred_modal_announcement = nil
                end
                local button = a11y.pending_modal_button_text
                speak(button ..
                    ", botão selecionado", false, true)
                a11y.dialog_button_queued_for_message = true
            end
            if #a11y.modal_message_backlog == 0 then
                a11y.pending_modal_button_text = nil
            end
        end
        pending_message_text = nil
        pending_message_key = nil
        a11y.pending_message_widget_key = nil
        pending_message_due_ms = nil
        if #a11y.modal_message_backlog > 0 then
            local next_message = table.remove(a11y.modal_message_backlog, 1)
            pending_message_text = next_message.text
            pending_message_key = next_message.key
            a11y.pending_message_widget_key =
                next_message.key:match("^(.-)%z")
            pending_message_due_ms = now_ms + 40
        end
    end
    -- Startup and dialog work above can enqueue speech before later guards
    -- return early. Deliver it now instead of paying another render frame.
    if a11y.game_plan_attribute_due_ms then
        if not startup_busy and pending_message_text == nil
                and now_ms >= a11y.game_plan_attribute_due_ms then
            local attribute_summary = a11y.game_plan_attribute_summary()
            speak(attribute_summary)
            a11y.game_plan_attribute_due_ms = nil
            local attribute_reading_time = #attribute_summary * 55 + 500
            if attribute_reading_time < 2500 then
                attribute_reading_time = 2500
            end
            if attribute_reading_time > 9000 then
                attribute_reading_time = 9000
            end
            a11y.game_plan_attribute_hold_until_ms =
                now_ms + attribute_reading_time
        end
        a11y.finish_render_work()
        return
    end
    if now_ms < a11y.game_plan_attribute_hold_until_ms then
        a11y.finish_render_work()
        return
    end
    if now_ms <= a11y.game_plan_attribute_panel_until_ms then
        -- The game renders every player card while the attribute overlay is
        -- open. None of those background names represents a focus change.
        a11y.finish_render_work()
        return
    end
    local modal_focus_blocked = startup_busy
        or pending_message_text ~= nil
        or now_ms < modal_focus_hold_until_ms
        or now_ms < a11y.screen_title_hold_until_ms
    local dialog_active = frame <= a11y.confirmation_dialog_until_frame
        and dialog_is_active()
        and math.min(dialog_options.Sim.last_seen,
            dialog_options["Não"].last_seen)
                >= a11y.modal_dialog_start_frame - 5 or false
    a11y.process_game_plan_selected_heading(
        modal_focus_blocked or dialog_active)
    a11y.process_game_plan_basic_menu_heading(
        modal_focus_blocked or dialog_active)
    -- The specialized reader is enabled only by the current destructive-back
    -- confirmation. This reads its Sim/Não focus without allowing old dialog
    -- widgets to compete with later screens.
    if dialog_active then
        process_dialog_focus(
            modal_focus_blocked,
            now_ms < modal_focus_hold_until_ms)
    end
    -- Do not mix the current UI-state reader with the legacy localization
    -- fallback. Hidden widgets retain their old focus bit after a transition,
    -- so the fallback can overwrite a correct announcement with an item from
    -- the previous screen (for example "Partida local" on the league list).
    a11y.poll_native_pages(modal_focus_blocked or dialog_active)
    local focus_started=tonumber(ffi.C.GetTickCount64())
    scan_current_ui_focus(modal_focus_blocked, dialog_active)
    a11y.render_metric.focus_ms=tonumber(ffi.C.GetTickCount64())-focus_started
    a11y.poll_assignment_changes()
    a11y.poll_common_tooltip()
    a11y.poll_main_navigation_probe()

    -- Delayed speech is evaluated after focus. A newly focused item can then
    -- cancel an obsolete tooltip before it reaches the screen reader.
    process_delayed_speech(now_ms, modal_focus_blocked)
    if not modal_focus_blocked and a11y.deferred_modal_announcement then
        a11y.drain_deferred_speech()
    end
    -- Hooks and focus scanning enqueue only. Flush again after processing so
    -- confirmed navigation reaches Prism in this render frame rather than the
    -- next one. Prism calls remain serialized on display_frame.
    a11y.finish_render_work()
end

