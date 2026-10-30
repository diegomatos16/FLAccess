function a11y.update_speech_state(entry,outcome,now_ms,error_code,fragmented)
    if not entry then return end
    local group=entry.fragment_group
    if group then
        if group.finished then return end
        if outcome=="delivered" and entry.suppress_delivery_state then return end
        group.finished=true
    elseif entry.suppress_delivery_state then return end
    local status=outcome=="delivered" and "delivered" or "pending"
    if outcome=="failed" and error_code==13 then status=fragmented and "fragmenting" or "failed-content" end
    for _,tag in ipairs({"selected_message","structured_record"}) do
        local origin=entry[tag]
        if origin and origin.state then
            origin.state.status=status
            if outcome=="failed" then origin.state.retry_after=(now_ms or 0)+750 end
        end
    end
    if entry.loading_state then entry.loading_state.announced=outcome=="delivered" or status=="fragmenting" end
    if entry.common_tooltip then
        entry.common_tooltip.status=status
        if status=="pending" then a11y.tooltip_dirty=true end
    end
    if entry.native_list and entry.native_list.state then
        local item=entry.native_list.state
        item.speech_status=status
        if status=="pending" or status=="failed-content" then item.committed=nil end
    end
    if entry.selection_result then
        entry.selection_result.status=outcome=="delivered" and "delivered" or outcome=="failed" and "failed" or "discarded"
    end
    if entry.menu_choice then entry.menu_choice.status=status end
    if outcome=="delivered" then
        a11y.remember_roster_navigation(entry.selection_result)
        if entry.page_context then a11y.last_page_delivery=entry.page_context.identity end
        if entry.assignment_change then
            local change=entry.assignment_change
            a11y.assignment_delivered=a11y.assignment_delivered or {}
            a11y.assignment_delivered[change.key]={signature=change.signature}
        end
    end
end

function a11y.clear_speech_queue(preserved_entry)
    for index=a11y.native_speech_first,a11y.native_speech_last do
        local entry=a11y.native_speech_queue[index]
        if entry~=preserved_entry then a11y.update_speech_state(entry,"discarded") end
    end
    a11y.native_speech_queue = preserved_entry and {preserved_entry} or {}
    a11y.native_speech_first = 1
    a11y.native_speech_last = preserved_entry and 1 or 0
end

function a11y.speech_entry_allowed(entry)
    return entry ~= nil
        and not entry.superseded
        and (not entry.fragment_group or not entry.fragment_group.finished)
        and (not entry.content_review or a11y.content_review_allowed(entry.content_review))
        and (not entry.common_tooltip or a11y.common_tooltip_allowed(entry.common_tooltip))
        and (not entry.selected_message or a11y.selected_message_allowed(entry.selected_message))
        and (not entry.structured_record or a11y.structured_record_allowed(entry.structured_record))
        and (not entry.loading_state or (a11y.loading_notice==entry.loading_state and a11y.loading_context()==entry.loading_state.address))
        and (not entry.menu_choice or (a11y.main_menu_choice_active(entry.menu_choice)
            and entry.menu_choice_attempt==entry.menu_choice.attempt))
        and (not entry.menu_tooltip or (a11y.main_menu_choice_active(entry.menu_tooltip) and entry.menu_tooltip.status=="delivered"))
        and (not entry.presentation_owner or entry.presentation_owner == a11y.native_owner_token())
        and (not entry.origin or a11y.speech_origin_allowed(entry.origin))
        and (not entry.engine_focus or a11y.engine_focus_delivery_allowed(entry.engine_focus))
        and (not entry.native_list or a11y.native_list_delivery_allowed(entry.native_list))
        and (not entry.reading_selection or a11y.reading_selection_delivery_allowed(entry.reading_selection))
        and (not entry.page_context or a11y.page_delivery_allowed(entry.page_context))
        and (not entry.selection_result or a11y.selection_result_allowed(entry.selection_result))
        and (not entry.roster_review or a11y.roster_review_allowed(entry.roster_review))
        and (not entry.player_details or a11y.player_details_allowed(entry.player_details))
        and (not entry.visualization or a11y.visualization_allowed(entry.visualization))
        and (not entry.static_presentation or a11y.read_native_rendered_text(entry.static_presentation.address)==entry.static_presentation.text)
        and (not entry.information_header or (a11y.native_information_context() or {}).identity==entry.information_header)
        and (not entry.pause_header or (a11y.native_pause_context() or {}).identity==entry.pause_header)
        and (not entry.assignment_change or a11y.assignment_change_allowed(entry.assignment_change))
        and (not entry.language_header or ((a11y.native_language_context() or {}).identity==entry.language_header
            and entry.language_generation==a11y.language_generation))
end

function a11y.queue_speech_fragments(entry)
    if entry.fragmented then return false end
    local characters=a11y.utf8_characters(entry.text)
    if table.concat(characters)~=entry.text then return false end
    local limit=math.max(24,math.min(160,math.floor(#entry.text/2)))
    local parts,current={},""
    for word in entry.text:gmatch("%S+%s*") do
        if #current>0 and #current+#word>limit then parts[#parts+1]=current;current="" end
        current=current .. word
    end
    if #current>0 then parts[#parts+1]=current end
    if #parts<2 then return false end
    local at=a11y.native_speech_first
    for index=a11y.native_speech_last,at+1,-1 do
        a11y.native_speech_queue[index+#parts]=a11y.native_speech_queue[index]
    end
    local group={}
    for index,part in ipairs(parts) do
        local clone={}
        for key,value in pairs(entry) do clone[key]=value end
        clone.text,clone.fragmented,clone.interrupt=part,true,index==1 and entry.interrupt or false
        clone.suppress_delivery_state=index<#parts
        clone.fragment_group=group
        clone.mode=clone.interrupt and "interrupt" or "queue"
        a11y.native_speech_queue[at+index]=clone
    end
    a11y.native_speech_last=a11y.native_speech_last+#parts
    log("[FLAccess] speech-fragments count=" .. #parts .. " reason=backend-content-conversion")
    return true
end

function a11y.flush_native_speech(now_ms)
    if a11y.native_speech_first > a11y.native_speech_last then return end
    a11y.render_read_work=nil -- no memory snapshot may cross Prism IPC
    if not a11y.initialize_native_prism() or not a11y.refresh_native_prism(now_ms) then
        if a11y.prism_failed then a11y.clear_speech_queue() end
        if a11y.render_metric then a11y.render_read_work={} end
        return
    end
    while a11y.native_speech_first <= a11y.native_speech_last do
        local entry=a11y.native_speech_queue[a11y.native_speech_first]
        local allowed=a11y.speech_entry_allowed(entry)
        local metric=a11y.render_metric
        -- Invalidated items cost no IPC budget. Valid text continues next frame
        -- after two attempts, so a paragraph cannot monopolize this callback.
        if allowed and metric and (metric.speech_calls or 0)>=2 then
            a11y.render_read_work={}
            return
        end
        if not allowed then
            a11y.update_speech_state(entry,"discarded")
            log("[FLAccess] speech-discard reason=origin-or-focus-changed sequence=" .. tostring(entry and entry.sequence))
        else
            local spoken=entry.origin and entry.origin.text==entry.text and entry.text or a11y.output_speech_text(entry.text)
            spoken=a11y.roster_navigation_speech(entry.selection_result,spoken)
            local native_text=a11y.to_c_string(spoken)
            local started=metric and tonumber(ffi.C.GetTickCount64())
            if metric then metric.speech_calls=(metric.speech_calls or 0)+1 end
            local error_code=a11y.prism_functions.backend_speak(a11y.prism_backend,native_text,entry.interrupt)
            if error_code~=0 and error_code~=13 and now_ms>=(a11y.prism_recovery_after or 0)
                    and (not metric or metric.speech_calls<2) then
                a11y.prism_recovery_after=now_ms+750
                local failed_name=a11y.prism_backend_name
                if a11y.select_prism_backend(failed_name) then
                    if metric then metric.speech_calls=metric.speech_calls+1 end
                    error_code=a11y.prism_functions.backend_speak(a11y.prism_backend,native_text,entry.interrupt)
                end
            end
            if metric then metric.speech_ms=(metric.speech_ms or 0)+tonumber(ffi.C.GetTickCount64())-started end
            if error_code==0 then
                a11y.update_speech_state(entry,"delivered",now_ms)
                log(string.format("[FLAccess] speech sequence=%d backend=%q mode=%s text=%q",
                    entry.sequence,a11y.prism_backend_name,entry.mode,spoken))
            else
                local fragmented=error_code==13 and a11y.queue_speech_fragments(entry)
                a11y.update_speech_state(entry,"failed",now_ms,error_code,fragmented)
                log(string.format("[FLAccess] native-prism-speak-failed backend=%q error=%d text=%q",
                    a11y.prism_backend_name or "none",error_code,spoken))
            end
        end
        a11y.native_speech_queue[a11y.native_speech_first]=nil
        a11y.native_speech_first=a11y.native_speech_first+1
    end
    a11y.clear_speech_queue()
    if a11y.render_metric then a11y.render_read_work={} end
end

function a11y.stop_nvda_if_requested()
    if not a11y.nvda_stop_requested then return end
    a11y.nvda_stop_requested = false
    if a11y.prism_backend_name == "NVDA" and a11y.prism_backend
            and a11y.prism_functions
            and a11y.prism_functions.backend_stop then
        local result = a11y.prism_functions.backend_stop(
            a11y.prism_backend)
        if result ~= 0 then
            log(string.format("[FLAccess] nvda-stop-failed error=%d", result))
        end
    end
end

