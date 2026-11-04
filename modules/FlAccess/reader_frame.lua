-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 14, "FLAccess reader: missing or reordered component frame")
function shared.a11y.tooltip_selection_stamp()
    local parts={}
    for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
        local d=window.enabled and window.cursor_detail
        if d and d.selected then
            parts[#parts+1]=table.concat({window.address,window.root or 0,d.group_index or -1,d.item_index or -1,d.selected},":")
        end
    end
    if #parts==0 then return nil end
    table.sort(parts);return table.concat(parts,"|")
end

function shared.a11y.common_tooltip_allowed(stamp)
    if shared.a11y.tooltip_selection_stamp()~=stamp.selection then return false end
    for _,part in ipairs(stamp.parts) do if not shared.a11y.content_review_allowed(part) then return false end end
    return true
end

function shared.a11y.poll_common_tooltip()
    if shared.a11y.main_menu_choice_active(shared.a11y.main_menu_choice_state) then return end
    local context=shared.a11y.read_context_state()
    if not shared.a11y.read_tooltips or context.structural_question or context.structural_event
            or shared.a11y.keyboard_window or shared.a11y.selected_message_packet() then return end
    local selection=shared.a11y.tooltip_selection_stamp()
    if not selection then shared.a11y.common_tooltip=nil;return end
    if not shared.a11y.tooltip_dirty and shared.a11y.tooltip_last_selection==selection then return end
    shared.a11y.tooltip_dirty=false;shared.a11y.tooltip_last_selection=selection
    local snapshot=shared.a11y.native_windows
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
    for _,node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.nodes or {}) do
        local name=(node.name or ""):lower()
        local member=snapshot.members and snapshot.members[tonumber(node.address)]
        local owned=false
        for _,owner in ipairs(member and member.owners or {}) do if owner.enabled and input_owners[owner.address] then owned=true;break end end
        local body=name=="text_contents" or name=="question" or name=="eventmsg" or name=="messagebody" or name=="bodytext" or name=="padicon"
        if not body and owned and node.text and node.text~="" then
            local structural=name:find("tooltip",1,true) or name:find("description",1,true) or name:find("explanation",1,true)
            local native_help=shared.a11y.native_control_help(node.text,node)
            local current_rank=native_help and 2 or structural and 1 or shared.a11y.text_asset_role(node.text)=="tooltip-or-description" and 0 or -1
            if current_rank>=0 and current_rank>=rank and shared.a11y.native_presentation_ready(node.address)
                    and shared.a11y.ui_node_matches_live(node) and shared.a11y.read_native_rendered_text(node.address)==node.text then
                if current_rank>rank then candidates={};rank=current_rank end
                candidates[#candidates+1]=node
            end
        end
    end
    if #candidates==0 then return end
    table.sort(candidates,function(a,b) return a.sequence<b.sequence end)
    local parts,texts,seen={}, {}, {}
    local owner=shared.a11y.native_owner_token()
    for _,node in ipairs(candidates) do
        if not seen[node.text] then
            seen[node.text]=true;texts[#texts+1]=node.text
            parts[#parts+1]={key=node.key,text=node.text,identity=node.identity,owner=owner}
        end
    end
    local text=table.concat(texts," ")
    local previous=shared.a11y.common_tooltip
    if previous and previous.selection==selection and previous.text==text and previous.status~="pending" then return end
    local stamp={selection=selection,text=text,parts=parts,status="pending",attempt=(previous and previous.attempt or 0)+1}
    shared.a11y.common_tooltip=stamp
    shared.pending_controller_tooltip,shared.controller_tooltip_due_ms=nil,nil
    local before=shared.a11y.native_speech_last
    shared.speak(text,false,true,"tooltip:" .. selection .. ":" .. text .. ":" .. stamp.attempt)
    for index=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[index].common_tooltip=stamp;stamp.status="queued" end
end

function shared.a11y.finish_render_work()
    shared.a11y.render_read_work=nil
    local metric=shared.a11y.render_metric
    if not metric then return end
    if shared.prism_started and shared.a11y.render_speech_allowed then
        shared.a11y.stop_nvda_if_requested()
        shared.a11y.flush_native_speech(tonumber(ffi.C.GetTickCount64()))
    end
    shared.a11y.render_speech_allowed=false
    shared.a11y.render_metric,shared.a11y.render_read_work=nil,nil
    local elapsed=tonumber(ffi.C.GetTickCount64())-metric.started
    local stats=shared.a11y.render_stats or {frames=0,ms=0,max_ms=0,reads=0,speech_ms=0,speech_calls=0,focus_ms=0}
    stats.frames,stats.ms,stats.reads=stats.frames+1,stats.ms+elapsed,stats.reads+metric.reads
    stats.max_ms=math.max(stats.max_ms,elapsed)
    stats.focus_ms=stats.focus_ms+(metric.focus_ms or 0)
    stats.speech_ms=stats.speech_ms+(metric.speech_ms or 0)
    stats.speech_calls=stats.speech_calls+(metric.speech_calls or 0)
    stats.window_refresh=stats.window_refresh or {}
    local refresh=metric.window_refresh or "none"
    stats.window_refresh[refresh]=(stats.window_refresh[refresh] or 0)+1
    for _,name in ipairs({"windows_ms","texts_ms","presentation_ms","capture_ms"}) do
        stats[name]=(stats[name] or 0)+(metric[name] or 0)
    end
    shared.a11y.render_stats=stats
    if stats.frames>=600 then
        log(string.format("[FLAccess] reader-work frames=%d mean-ms=%.3f max-ms=%d memory-copies-per-frame=%.1f speech-ms=%.3f speech-calls=%d focus-ms=%.3f windows-ms=%.3f texts-ms=%.3f presentation-ms=%.3f capture-ms=%.3f",
            stats.frames,stats.ms/stats.frames,stats.max_ms,stats.reads/stats.frames,stats.speech_ms/stats.frames,stats.speech_calls,stats.focus_ms/stats.frames,
            stats.windows_ms/stats.frames,stats.texts_ms/stats.frames,stats.presentation_ms/stats.frames,stats.capture_ms/stats.frames))
        shared.a11y.render_stats=nil
        local refreshes={}
        for reason,count in pairs(stats.window_refresh) do refreshes[#refreshes+1]=reason .. "=" .. count end
        table.sort(refreshes)
        log("[FLAccess] window-refresh " .. table.concat(refreshes," "))
    end
end

function shared.a11y.profile_reader_phase(name,fn)
    local started=tonumber(ffi.C.GetTickCount64())
    fn()
    shared.a11y.render_metric[name]=tonumber(ffi.C.GetTickCount64())-started
end

function shared.m.display_frame(ctx)
    shared.a11y.render_read_work={}
    shared.a11y.render_speech_allowed=false
    shared.a11y.render_metric={started=tonumber(ffi.C.GetTickCount64()),reads=0}
    shared.frame = shared.frame + 1
    shared.a11y.current_frame = shared.frame
    shared.a11y.poll_direct_message_update()
    if not shared.prism_started and shared.frame >= 120 then
        shared.prism_started = true
        shared.start_native_prism(ctx)
    end
    if not shared.game_is_foreground() then
        shared.game_was_foreground = false
        shared.a11y.nvda_stop_requested = false
        shared.a11y.clear_speech_queue()
        shared.a11y.finish_render_work()
        return
    end
    shared.a11y.render_speech_allowed=true
    shared.a11y.profile_reader_phase("windows_ms",shared.a11y.poll_native_windows)
    shared.a11y.poll_native_confirmation()
    shared.a11y.profile_reader_phase("texts_ms",shared.a11y.poll_native_texts)
    shared.a11y.poll_native_country_selection()
    shared.a11y.poll_keyboard_input()
    shared.a11y.poll_information_context()
    shared.a11y.poll_native_pause()
    shared.a11y.poll_native_language()
    shared.a11y.profile_reader_phase("presentation_ms",shared.a11y.poll_presented_texts)
    shared.a11y.poll_notice_actions()
    shared.a11y.poll_surface_texts()
    shared.a11y.poll_main_menu_choice()
    shared.a11y.poll_loading(tonumber(ffi.C.GetTickCount64()))
    shared.a11y.poll_skip_hint()
    shared.a11y.profile_reader_phase("capture_ms",shared.a11y.poll_component_capture)
    if not shared.game_was_foreground then
        shared.game_was_foreground = true
        shared.foreground_resume_frame = shared.frame + 4
        shared.ui_focus_candidate_key = nil
        shared.last_ui_focus_announcement = nil
        shared.a11y.finish_render_work()
        return
    end
    if shared.frame < shared.foreground_resume_frame then
        shared.a11y.finish_render_work()
        return
    end
    if shared.overlay_visible or shared.sider_overlay_visible then
        shared.a11y.finish_render_work()
        return
    end
    local now_ms = tonumber(ffi.C.GetTickCount64())
    shared.a11y.poll_attribute_input(now_ms)
    shared.a11y.poll_focus_trace()
    shared.a11y.record_game_plan_menu_probe()
    if shared.a11y.game_plan_lineup_due_ms
            and now_ms >= shared.a11y.game_plan_lineup_due_ms then
        shared.a11y.read_visible_game_plan_lineup()
        shared.a11y.game_plan_lineup_due_ms = nil
        shared.a11y.game_plan_lineup_input = nil
    end
    local startup_busy = shared.process_startup_speech(now_ms)
    if shared.pending_message_text and not shared.a11y.native_key_allowed(shared.a11y.pending_message_widget_key) then
        shared.pending_message_text, shared.pending_message_key, shared.pending_message_due_ms = nil, nil, nil
        shared.a11y.pending_message_widget_key = nil
    end
    if not startup_busy and shared.pending_message_due_ms
            and now_ms >= shared.pending_message_due_ms then
        if shared.pending_message_text and shared.pending_message_text ~= ""
                and shared.pending_message_key ~= shared.last_announced_message_key then
            local context = shared.a11y.read_context_state()
            local spoken_prompt = context.structural_question and context.question == shared.pending_message_text
                and ((shared.a11y.ui_language == "pt" and "Pergunta: " or "Question: ") .. shared.pending_message_text)
                or shared.pending_message_text
            local prompt_node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[shared.a11y.pending_message_widget_key]
            shared.speak(spoken_prompt, nil, true, nil, prompt_node and prompt_node.address)
            shared.a11y.dialog_button_queued_for_message = false
            shared.modal_message_spoken_frame = shared.frame
            shared.last_announced_message_key = shared.pending_message_key
            shared.a11y.last_modal_message_text = shared.pending_message_text
            local reading_time = #shared.pending_message_text * 65 + 500
            if reading_time < 1800 then reading_time = 1800 end
            if reading_time > 10000 then reading_time = 10000 end
            -- Consecutive dialog pages are queued in Prism. Keep focus
            -- blocked until the entire queued reading finishes, not only
            -- until the most recently detected page would finish alone.
            shared.modal_focus_hold_until_ms =
                math.max(now_ms, shared.modal_focus_hold_until_ms) + reading_time
            if #shared.a11y.modal_message_backlog == 0
                    and shared.a11y.pending_modal_button_text
                    and not shared.a11y.ignore_cup_group_focus(
                        shared.a11y.pending_modal_button_text) then
                if shared.a11y.deferred_modal_announcement
                        and shared.a11y.deferred_modal_announcement:sub(
                            1, #shared.a11y.pending_modal_button_text)
                                == shared.a11y.pending_modal_button_text then
                    shared.a11y.deferred_modal_announcement = nil
                end
                local button = shared.a11y.pending_modal_button_text
                shared.speak(button ..
                    ", botão selecionado", false, true)
                shared.a11y.dialog_button_queued_for_message = true
            end
            if #shared.a11y.modal_message_backlog == 0 then
                shared.a11y.pending_modal_button_text = nil
            end
        end
        shared.pending_message_text = nil
        shared.pending_message_key = nil
        shared.a11y.pending_message_widget_key = nil
        shared.pending_message_due_ms = nil
        if #shared.a11y.modal_message_backlog > 0 then
            local next_message = table.remove(shared.a11y.modal_message_backlog, 1)
            shared.pending_message_text = next_message.text
            shared.pending_message_key = next_message.key
            shared.a11y.pending_message_widget_key =
                next_message.key:match("^(.-)%z")
            shared.pending_message_due_ms = now_ms + 40
        end
    end
    -- Startup and dialog work above can enqueue speech before later guards
    -- return early. Deliver it now instead of paying another render frame.
    if shared.a11y.game_plan_attribute_due_ms then
        if not startup_busy and shared.pending_message_text == nil
                and now_ms >= shared.a11y.game_plan_attribute_due_ms then
            local attribute_summary = shared.a11y.game_plan_attribute_summary()
            shared.speak(attribute_summary)
            shared.a11y.game_plan_attribute_due_ms = nil
            local attribute_reading_time = #attribute_summary * 55 + 500
            if attribute_reading_time < 2500 then
                attribute_reading_time = 2500
            end
            if attribute_reading_time > 9000 then
                attribute_reading_time = 9000
            end
            shared.a11y.game_plan_attribute_hold_until_ms =
                now_ms + attribute_reading_time
        end
        shared.a11y.finish_render_work()
        return
    end
    if now_ms < shared.a11y.game_plan_attribute_hold_until_ms then
        shared.a11y.finish_render_work()
        return
    end
    if now_ms <= shared.a11y.game_plan_attribute_panel_until_ms then
        -- The game renders every player card while the attribute overlay is
        -- open. None of those background names represents a focus change.
        shared.a11y.finish_render_work()
        return
    end
    local modal_focus_blocked = startup_busy
        or shared.pending_message_text ~= nil
        or now_ms < shared.modal_focus_hold_until_ms
        or now_ms < shared.a11y.screen_title_hold_until_ms
    local dialog_active = shared.frame <= shared.a11y.confirmation_dialog_until_frame
        and shared.dialog_is_active()
        and math.min(shared.dialog_options.Sim.last_seen,
            shared.dialog_options["Não"].last_seen)
                >= shared.a11y.modal_dialog_start_frame - 5 or false
    if not (shared.core_context and shared.core_context.match_playing) then
        shared.a11y.process_game_plan_selected_heading(modal_focus_blocked or dialog_active)
        shared.a11y.process_game_plan_basic_menu_heading(modal_focus_blocked or dialog_active)
    end
    -- The specialized reader is enabled only by the current destructive-back
    -- confirmation. This reads its Sim/Não focus without allowing old dialog
    -- widgets to compete with later screens.
    if dialog_active then
        shared.process_dialog_focus(
            modal_focus_blocked,
            now_ms < shared.modal_focus_hold_until_ms)
    end
    -- Do not mix the current UI-state reader with the legacy localization
    -- fallback. Hidden widgets retain their old focus bit after a transition,
    -- so the fallback can overwrite a correct announcement with an item from
    -- the previous screen (for example "Partida local" on the league list).
    shared.a11y.poll_native_pages(modal_focus_blocked or dialog_active)
    local focus_started=tonumber(ffi.C.GetTickCount64())
    shared.scan_current_ui_focus(modal_focus_blocked, dialog_active)
    shared.a11y.render_metric.focus_ms=tonumber(ffi.C.GetTickCount64())-focus_started
    shared.a11y.poll_assignment_changes()
    shared.a11y.poll_common_tooltip()
    shared.a11y.poll_main_navigation_probe()

    -- Delayed speech is evaluated after focus. A newly focused item can then
    -- cancel an obsolete tooltip before it reaches the screen reader.
    shared.process_delayed_speech(now_ms, modal_focus_blocked)
    if not modal_focus_blocked and shared.a11y.deferred_modal_announcement then
        shared.a11y.drain_deferred_speech()
    end
    if not modal_focus_blocked and not dialog_active then shared.a11y.poll_ml_date() end
    -- Hooks and focus scanning enqueue only. Flush again after processing so
    -- confirmed navigation reaches Prism in this render frame rather than the
    -- next one. Prism calls remain serialized on display_frame.
    shared.a11y.finish_render_work()
end


    shared.stage = 15
end
function component.init(ctx)
    component.install(ctx)

end
return component
