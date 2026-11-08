-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 3, "FLAccess reader: missing or reordered component speech_queue")
function shared.a11y.update_speech_state(entry,outcome,now_ms,error_code,fragmented)
    if not entry then return end
    if entry.superseded and outcome=="discarded" then
        -- A newer navigation publication owns retry state. Discarding an old
        -- one must not clear a shared list's current committed identity.
        if entry.fragment_group then entry.fragment_group.finished=true end
        if entry.selection_result then entry.selection_result.status="discarded" end
        return
    end
    local group=entry.fragment_group
    if group then
        if group.finished then return end
        if outcome=="delivered" and entry.suppress_delivery_state then return end
        group.finished=true
    elseif entry.suppress_delivery_state then return end
    local status=outcome=="delivered" and "delivered" or "pending"
    if outcome=="failed" and error_code==13 then status=fragmented and "fragmenting" or "failed-content" end
    for _,tag in ipairs({"selected_message","structured_record","ml_date","fixture_notice"}) do
        local origin=entry[tag]
        if origin and origin.state then
            origin.state.status=status
            if outcome=="failed" then origin.state.retry_after=(now_ms or 0)+750 end
        end
    end
    if entry.loading_state then entry.loading_state.announced=outcome=="delivered" or status=="fragmenting" end
    if entry.common_tooltip then
        entry.common_tooltip.status=status
        if status=="pending" then shared.a11y.tooltip_dirty=true end
    end
    if entry.native_list and entry.native_list.state then
        local item=entry.native_list.state
        item.speech_status=status
        if status=="pending" or status=="failed-content" then item.committed=nil end
    end
    if entry.selection_result then
        entry.selection_result.status=outcome=="delivered" and "delivered" or outcome=="failed" and "failed" or "discarded"
    end
    if entry.menu_choice then
        local choice=entry.menu_choice
        if outcome=="delivered" then
            choice.delivered=true
            shared.a11y.main_menu_delivery={key=choice.key,text=choice.text,
                anchor=shared.a11y.main_menu_choice_anchor(choice),choice=choice}
        end
        choice.status=choice.delivered and "delivered" or status
    end
    if entry.menu_tooltip and entry.menu_tooltip_text==entry.menu_tooltip.description then
        entry.menu_tooltip.tooltip_status=status
    end
    if outcome=="delivered" then
        local field=entry.visualization
        if field and field.state then
            field.state.review_group=field.group_title and tostring(field.group_key) .. ":" .. field.group_title or nil
        end
        shared.a11y.remember_roster_navigation(entry.selection_result)
        if entry.selection_result and entry.selection_result.cup_group then
            shared.a11y.last_cup_group=entry.selection_result.cup_group.identity
        end
        if entry.page_context then shared.a11y.last_page_delivery=entry.page_context.identity end
        if entry.assignment_change then
            local change=entry.assignment_change
            shared.a11y.assignment_delivered=shared.a11y.assignment_delivered or {}
            shared.a11y.assignment_delivered[change.key]={signature=change.signature}
        end
    end
end

function shared.a11y.clear_speech_queue(preserved_entry)
    for index=shared.a11y.native_speech_first,shared.a11y.native_speech_last do
        local entry=shared.a11y.native_speech_queue[index]
        if entry~=preserved_entry then shared.a11y.update_speech_state(entry,"discarded") end
    end
    shared.a11y.native_speech_queue = preserved_entry and {preserved_entry} or {}
    shared.a11y.native_speech_first = 1
    shared.a11y.native_speech_last = preserved_entry and 1 or 0
end

function shared.a11y.speech_entry_allowed(entry)
    return entry ~= nil
        and not entry.superseded
        and (not entry.competition_fixture
            or (shared.a11y.competition_fixture() or {}).signature==entry.competition_fixture)
        and (not entry.match_session or (shared.core_context and (shared.core_context.match_playing or entry.pause_header or entry.match_card)
            and shared.core_context.gameplay.announcement_session==entry.match_session
            and not shared.overlay_visible and not shared.sider_overlay_visible))
        and (not entry.controlled_actor or (shared.a11y.controlled_player
            and shared.core_context.gameplay.controlled_entry==entry
            and shared.core_context.gameplay.current_controlled_actor==entry.controlled_actor))
        and (not shared.a11y.player_search_context or not shared.a11y.player_search_context()
            or shared.a11y.player_search_ready() or entry.loading_state or entry.search_loading)
        and (not entry.search_loading or (shared.a11y.search_loading_notice==entry.search_loading
            and shared.a11y.player_search_context() and not shared.a11y.player_search_ready()))
        and (not entry.fragment_group or not entry.fragment_group.finished)
        and (not entry.content_review or shared.a11y.content_review_allowed(entry.content_review))
        and (not entry.common_tooltip or shared.a11y.common_tooltip_allowed(entry.common_tooltip))
        and (not entry.selected_message or shared.a11y.selected_message_allowed(entry.selected_message))
        and (not entry.structured_record or shared.a11y.structured_record_allowed(entry.structured_record))
        and (not entry.ml_date or shared.a11y.ml_date_allowed(entry.ml_date))
        and (not entry.loading_state or (shared.a11y.loading_notice==entry.loading_state and shared.a11y.loading_context()==entry.loading_state.address))
        and (not entry.menu_choice or (shared.a11y.main_menu_choice_active(entry.menu_choice)
            and entry.menu_choice_attempt==entry.menu_choice.attempt))
        and (not entry.menu_tooltip or (shared.a11y.main_menu_choice_active(entry.menu_tooltip) and entry.menu_tooltip.status=="delivered"))
        and (not entry.presentation_owner or entry.presentation_owner == shared.a11y.native_owner_token())
        and (not entry.origin or shared.a11y.speech_origin_allowed(entry.origin))
        and (not entry.engine_focus or shared.a11y.engine_focus_delivery_allowed(entry.engine_focus))
        and (not entry.native_list or shared.a11y.native_list_delivery_allowed(entry.native_list))
        and (not entry.reading_selection or shared.a11y.reading_selection_delivery_allowed(entry.reading_selection))
        and (not entry.page_context or shared.a11y.page_delivery_allowed(entry.page_context))
        and (not entry.selection_result or shared.a11y.selection_result_allowed(entry.selection_result))
        and (not entry.roster_review or shared.a11y.roster_review_allowed(entry.roster_review))
        and (not entry.player_details or shared.a11y.player_details_allowed(entry.player_details))
        and (not entry.visualization or shared.a11y.visualization_allowed(entry.visualization))
        and (not entry.static_presentation or shared.a11y.read_native_rendered_text(entry.static_presentation.address)==entry.static_presentation.text)
        and (not entry.information_header or (shared.a11y.native_information_context() or {}).identity==entry.information_header)
        and (not entry.pause_header or (shared.a11y.native_pause_context() or {}).identity==entry.pause_header)
        and (not entry.assignment_change or shared.a11y.assignment_change_allowed(entry.assignment_change))
        and (not entry.language_header or ((shared.a11y.native_language_context() or {}).identity==entry.language_header
            and entry.language_generation==shared.a11y.language_generation))
end

function shared.a11y.queue_speech_fragments(entry)
    if entry.fragmented then return false end
    local characters=shared.a11y.utf8_characters(entry.text)
    if table.concat(characters)~=entry.text then return false end
    local limit=math.max(24,math.min(160,math.floor(#entry.text/2)))
    local parts,current={},""
    for word in entry.text:gmatch("%S+%s*") do
        if #current>0 and #current+#word>limit then parts[#parts+1]=current;current="" end
        current=current .. word
    end
    if #current>0 then parts[#parts+1]=current end
    if #parts<2 then return false end
    local at=shared.a11y.native_speech_first
    for index=shared.a11y.native_speech_last,at+1,-1 do
        shared.a11y.native_speech_queue[index+#parts]=shared.a11y.native_speech_queue[index]
    end
    local group={}
    for index,part in ipairs(parts) do
        local clone={}
        for key,value in pairs(entry) do clone[key]=value end
        clone.text,clone.fragmented,clone.interrupt=part,true,index==1 and entry.interrupt or false
        clone.suppress_delivery_state=index<#parts
        clone.fragment_group=group
        clone.mode=clone.interrupt and "interrupt" or "queue"
        shared.a11y.native_speech_queue[at+index]=clone
    end
    shared.a11y.native_speech_last=shared.a11y.native_speech_last+#parts
    log("[FLAccess] speech-fragments count=" .. #parts .. " reason=backend-content-conversion")
    return true
end

function shared.a11y.coalesce_pending_navigation()
    local newest
    local replaced=0
    for index=shared.a11y.native_speech_last,shared.a11y.native_speech_first,-1 do
        local entry=shared.a11y.native_speech_queue[index]
        local identity=entry and entry.identity or ""
        local navigation=entry and (entry.selection_result or entry.native_list or entry.structured_record
            or entry.menu_choice or entry.visualization or identity:sub(1,7)=="review:")
        if navigation and not entry.superseded then
            local publication=entry.fragment_group or entry
            if not newest then newest=publication
            elseif newest~=publication then entry.superseded=true;replaced=replaced+1 end
        end
    end
    if shared.a11y.render_metric then
        shared.a11y.render_metric.queue_replaced=(shared.a11y.render_metric.queue_replaced or 0)+replaced
    end
    return replaced
end

function shared.a11y.flush_native_speech(now_ms)
    if shared.a11y.native_speech_first > shared.a11y.native_speech_last then return end
    shared.a11y.coalesce_pending_navigation()
    shared.a11y.render_read_work=nil -- no memory snapshot may cross Prism IPC
    if not shared.a11y.initialize_native_prism() or not shared.a11y.refresh_native_prism(now_ms) then
        if shared.a11y.prism_failed then shared.a11y.clear_speech_queue() end
        if shared.a11y.render_metric then shared.a11y.render_read_work={} end
        return
    end
    while shared.a11y.native_speech_first <= shared.a11y.native_speech_last do
        local entry=shared.a11y.native_speech_queue[shared.a11y.native_speech_first]
        local allowed=shared.a11y.native_read_phase(shared.a11y.speech_entry_allowed,entry)
        local metric=shared.a11y.render_metric
        -- Invalidated items cost no IPC budget. Valid text continues next frame
        -- after two attempts, so a paragraph cannot monopolize this callback.
        if allowed and metric and (metric.speech_calls or 0)>=2 then
            shared.a11y.render_read_work={}
            return
        end
        if allowed and entry.controlled_actor and shared.core_context.gameplay.control_earcon_pending(entry,now_ms) then
            if metric then shared.a11y.render_read_work={} end
            return
        end
        if not allowed then
            shared.a11y.update_speech_state(entry,"discarded")
            if not entry or not entry.superseded then
                log("[FLAccess] speech-discard reason=origin-or-focus-changed sequence=" .. tostring(entry and entry.sequence))
            end
        else
            local spoken=entry.origin and entry.origin.text==entry.text and entry.text or shared.a11y.output_speech_text(entry.text)
            spoken=shared.a11y.roster_navigation_speech(entry.selection_result,spoken)
            local native_text=shared.a11y.to_c_string(spoken)
            local started=metric and tonumber(ffi.C.GetTickCount64())
            if metric then metric.speech_calls=(metric.speech_calls or 0)+1 end
            local a11y=shared.a11y
            local backend_name=a11y.prism_backend_name
            local error_code
            if entry.tts_preview and a11y.speak_tts_preview(spoken) then
                error_code,backend_name=0,"SAPI preview"
                a11y.tts_preview_playing=true
            else
                if a11y.tts_preview_playing then
                    if a11y.prism_functions.backend_stop then a11y.prism_functions.backend_stop(a11y.tts_preview_backend) end
                    a11y.tts_preview_playing=false
                end
                if entry.tts_preview then
                    spoken=a11y.strings().tts_unavailable
                    native_text=a11y.to_c_string(spoken)
                end
                error_code=a11y.prism_functions.backend_speak(a11y.prism_backend,native_text,entry.interrupt)
            end
            if error_code~=0 and error_code~=13 and now_ms>=(shared.a11y.prism_recovery_after or 0)
                    and (not metric or metric.speech_calls<2) then
                shared.a11y.prism_recovery_after=now_ms+750
                local failed_name=shared.a11y.prism_backend_name
                if shared.a11y.select_prism_backend(failed_name) then
                    backend_name=a11y.prism_backend_name
                    if metric then metric.speech_calls=metric.speech_calls+1 end
                    error_code=shared.a11y.prism_functions.backend_speak(shared.a11y.prism_backend,native_text,entry.interrupt)
                end
            end
            if metric then metric.speech_ms=(metric.speech_ms or 0)+tonumber(ffi.C.GetTickCount64())-started end
            if error_code==0 then
                shared.a11y.update_speech_state(entry,"delivered",now_ms)
                log(string.format("[FLAccess] speech sequence=%d backend=%q mode=%s text=%q",
                    entry.sequence,backend_name,entry.mode,spoken))
            else
                local fragmented=error_code==13 and shared.a11y.queue_speech_fragments(entry)
                shared.a11y.update_speech_state(entry,"failed",now_ms,error_code,fragmented)
                log(string.format("[FLAccess] native-prism-speak-failed backend=%q error=%d text=%q",
                    shared.a11y.prism_backend_name or "none",error_code,spoken))
            end
        end
        shared.a11y.native_speech_queue[shared.a11y.native_speech_first]=nil
        shared.a11y.native_speech_first=shared.a11y.native_speech_first+1
    end
    shared.a11y.clear_speech_queue()
    if shared.a11y.render_metric then shared.a11y.render_read_work={} end
end

function shared.a11y.stop_nvda_if_requested()
    if not shared.a11y.nvda_stop_requested then return end
    shared.a11y.nvda_stop_requested = false
    if shared.a11y.prism_backend_name == "NVDA" and shared.a11y.prism_backend
            and shared.a11y.prism_functions
            and shared.a11y.prism_functions.backend_stop then
        local result = shared.a11y.prism_functions.backend_stop(
            shared.a11y.prism_backend)
        if result ~= 0 then
            log(string.format("[FLAccess] nvda-stop-failed error=%d", result))
        end
    end
end


    shared.stage = 4
end
function component.init(ctx)
    component.install(ctx)

end
return component
