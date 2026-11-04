-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 5, "FLAccess reader: missing or reordered component review")
    assert(shared.a11y.records_ready, "FLAccess reader_records must load before review")
function shared.a11y.player_list_review_entries(nodes)
    local snapshot=shared.a11y.native_windows
    if not snapshot or shared.a11y.keyboard_window or shared.a11y.read_context_state().kind=="dialog" then return nil end
    local found
    for _,window in ipairs(snapshot.windows or {}) do
        local d=window.cursor_detail
        if window.enabled and d and d.group and d.selected then
            local rows,anchor={},nil
            for index=0,255 do
                local row=shared.a11y.menu_child(d.group,index)
                if not row or row<0x10000 then break end
                rows[row]=index
            end
            local entries,has_rows={},false
            for _,node in ipairs(nodes) do
                if node.name=="playerName" and not shared.a11y.empty_selection_caption(node.text) then
                    local member=snapshot.members[tonumber(node.address)]
                    local index,ambiguous
                    for _,owner in ipairs(member and member.owners or {}) do
                        if owner.enabled and owner.address==window.address and owner.root==window.root then
                            local at,seen=tonumber(node.address),{}
                            for _=1,12 do
                                at=owner.parents and owner.parents[at]
                                if not at or seen[at] then break end
                                seen[at]=true
                                if rows[at]~=nil then
                                    if index and index~=rows[at] then ambiguous=true end
                                    index=rows[at]
                                    if at==d.selected then anchor=node end
                                    break
                                end
                            end
                        end
                    end
                    if index and not ambiguous then
                        if entries[index] and entries[index]~=node then return nil end
                        entries[index]=node
                        has_rows=true
                    end
                end
            end
            if anchor then
                if found then return nil end
                local texts,ordered={},{}
                texts[1]=anchor.text
                ordered[1]=anchor
                for _,detail in ipairs(shared.a11y.player_row_details(anchor)) do
                    texts[#texts+1]=detail.name=="allOver" and ((shared.a11y.ui_language=="pt" and "Força geral: " or "Overall rating: ") .. detail.text) or detail.text
                    ordered[#ordered+1]=anchor
                end
                found={texts=texts,nodes=ordered,anchor=anchor,
                    selection={window=window.address,root=window.root,group=d.group,selected=d.selected},
                    identity=tostring(window.address) .. ":" .. tostring(d.group) .. ":" .. anchor.identity .. ":" .. anchor.text}
            elseif has_rows or shared.a11y.widget_internal_name(d.group)=="p_list" then
                -- A recognized player list with an unavailable selected record
                -- must not leak other rows or the surrounding detail table.
                return {},{identity="player-unresolved:" .. window.address .. ":" .. d.group .. ":" .. d.selected,nodes={}}
            end
        end
    end
    if found then return found.texts,found end
end

function shared.a11y.roster_review_allowed(review)
    if review.generation~=shared.a11y.read_context_state().generation then return false end
    if review.selection then
        local found=false
        for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
            local d=window.cursor_detail
            if window.enabled and window.address==review.selection.window and window.root==review.selection.root
                    and d and d.group==review.selection.group and d.selected==review.selection.selected then found=true end
        end
        if not found then return false end
    end
    for _,origin in ipairs({review.origin,review.anchor}) do
        if not shared.a11y.speech_origin_allowed(origin)
                or shared.a11y.read_native_rendered_text(origin.address)~=origin.text then return false end
    end
    local node=shared.a11y.ui_model.nodes[memory.hex(review.origin.address)]
    if not node or shared.a11y.engine_selection_identity(node.key,node)~=review.identity then return false end
    for _,origin in ipairs(review.parts) do
        if not shared.a11y.speech_origin_allowed(origin)
                or shared.a11y.read_native_rendered_text(origin.address)~=origin.text then return false end
    end
    if review.list_identity then
        local item=shared.a11y.native_list_selection
        if not item or item.committed~=review.list_identity then return false end
    end
    return true
end

function shared.a11y.review_chrome(text,node)
    if not text or shared.a11y.empty_selection_caption(text) or shared.a11y.unresolved_format(text) then return true end
    local commands={ajuda=true,voltar=true,sair=true,["opções"]=true,confirmar=true,cancelar=true,
        ["avançar"]=true,["próximo"]=true,pular=true,help=true,back=true,exit=true,options=true,
        confirm=true,cancel=true,next=true,skip=true,ok=true}
    if commands[text:lower():gsub('^%s+',''):gsub('%s+$','')] then return true end
    if not node then return false end
    local name=(node.name or ''):lower()
    if name=='padicon' or name=='itemname' or name=='ok_text' or name:find('help',1,true) or name:find('guide',1,true)
            or name:find('tooltip',1,true) or name:match('^btn') or name:match('_button$')
            or name:match('_text$') and (name:find('back',1,true) or name:find('cancel',1,true))
            or shared.a11y.is_media_caption(node) or shared.a11y.is_menu_description(node) then return true end
    local bar=shared.a11y.native_windows and shared.a11y.native_windows.command_bar
    for _,pair in ipairs(bar and bar.pairs or {}) do
        if tonumber(node.address)==pair.caption or tonumber(node.address)==pair.icon then return true end
    end
    return shared.a11y.is_control_help(text)
end

function shared.a11y.content_review_allowed(origin)
    local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[origin.key]
    return node and node.identity==origin.identity and node.text==origin.text
        and origin.owner==shared.a11y.native_owner_token() and shared.a11y.native_presentation_ready(node.address)
        and shared.a11y.ui_node_matches_live(node) and shared.a11y.read_native_rendered_text(node.address)==origin.text
end

-- Selected-record packet, independent of the generic screen-text bag. The
-- native mailbox indexes 0x90 records; b44520 renders +8 title and +50 body.
function shared.a11y.selected_message_packet()
    local snapshot=shared.a11y.native_windows
    local base=tonumber(shared.process_base_u64)
    local context=shared.a11y.read_context_state()
    if not snapshot or not base or context.structural_question or context.structural_event then return nil end
    local work=shared.a11y.render_read_work
    if work and work.mailbox~=nil then return work.mailbox or nil end
    local found
    for _,window in ipairs(snapshot.windows or {}) do
        if window.enabled and (window.vtable or shared.a11y.menu_read(window.address,"u64"))==base+0x26a1120
                and shared.a11y.menu_read(window.address,"u64")==base+0x26a1120
                and shared.a11y.menu_read(base+0x26a1120+0x148,"u64")==base+0xb43ad0 then
            local index=shared.a11y.native_window_selected_index(window,base)
            local first,last=shared.a11y.menu_read(window.address+0x90,"u64"),shared.a11y.menu_read(window.address+0x98,"u64")
            local packet={identity="message:" .. window.address .. ":" .. tostring(window.root),entries={},nodes={}}
            if index and first and first>=0x10000 and last and last>=first and (last-first)%0x90==0
                    and last-first<=4096*0x90 and index<(last-first)/0x90 then
                local record=first+index*0x90
                local title=shared.a11y.read_msvc_string(record+8)
                local mode=shared.a11y.menu_read(record+0x48,"u32")
                local body=(mode==0 or mode==1) and shared.a11y.read_msvc_string(record+0x50)
                if mode==1 then
                    local head,tail=shared.a11y.menu_read(record+0x70,"u64"),shared.a11y.menu_read(record+0x78,"u64")
                    if head and head>=0x10000 and tail and tail>=head and (tail-head)%0x28==0 and tail-head<=256*0x28 then
                        local parts={body or ""}
                        for at=head,tail-0x28,0x28 do
                            local part=shared.a11y.read_msvc_string(at+8)
                            if part and part~="" and not shared.a11y.unresolved_format(part) then parts[#parts+1]=part end
                        end
                        body=table.concat(parts,". ")
                    end
                end
                if title and title~="" then
                    packet.identity=packet.identity .. ":" .. record .. ":" .. title
                    packet.entries[1]=title
                    if body and body~="" and not shared.a11y.unresolved_format(body) then packet.entries[2]=body end
                    packet.signature=packet.identity .. ":" .. (packet.entries[2] or "")
                end
            end
            if found then return {identity="message:ambiguous",entries={},nodes={}} end
            found=packet -- an unresolved record never falls through to all table rows
        end
    end
    if work then work.mailbox=found or false end
    return found
end

function shared.a11y.selected_message_allowed(stamp)
    local packet=shared.a11y.selected_message_packet()
    return packet and packet.signature==stamp.signature and shared.a11y.native_owner_token()==stamp.owner
end

function shared.a11y.poll_selected_message()
    local packet=shared.a11y.selected_message_packet()
    if not packet or not packet.signature then shared.a11y.selected_message_announced=nil;return end
    local previous=shared.a11y.selected_message_announced
    if previous and previous.signature==packet.signature and previous.status~="pending" then return end
    if previous and previous.signature==packet.signature and previous.retry_after
            and tonumber(ffi.C.GetTickCount64())<previous.retry_after then return end
    local state={signature=packet.signature,status="pending",attempt=(previous and previous.attempt or 0)+1};shared.a11y.selected_message_announced=state
    local before=shared.a11y.native_speech_last
    shared.speak(table.concat(packet.entries,". "),true,true,"selected-message:" .. packet.signature .. ":attempt=" .. state.attempt)
    for index=before+1,shared.a11y.native_speech_last do
        shared.a11y.native_speech_queue[index].selected_message={signature=packet.signature,owner=shared.a11y.native_owner_token(),state=state}
        state.status="queued"
    end
end

-- Grouped records live in reader_records.lua and share one packet for speech/exploration.

function shared.a11y.buffer_entries()
    local previous=shared.a11y.detail_reads_allowed
    shared.a11y.detail_reads_allowed=true
    local entries,review=shared.a11y.collect_buffer_entries()
    local date=shared.a11y.read_context_state().kind~="dialog" and shared.a11y.native_ml_date()
    if date then
        local combined={date.text};for _,entry in ipairs(entries) do combined[#combined+1]=entry end
        entries=combined
        local prior=review or {identity="ml-home",nodes={}}
        review={};for key,value in pairs(prior) do review[key]=value end
        review.identity=(prior.identity or "ml-home") .. ":date=" .. date.signature
        review.nodes={};for index,node in pairs(prior.nodes or {}) do review.nodes[index+1]=node end
        review.groups={};for index,group in pairs(prior.groups or {}) do review.groups[index+1]=group end
        review.ml_date=date
    end
    shared.a11y.detail_reads_allowed=previous
    return entries,review
end

function shared.a11y.collect_buffer_entries()
    -- A review request reads the current rendered panel, including companion
    -- lists, rather than the previous entity's cached captions.
    shared.a11y.poll_native_texts(true)
    local nodes=shared.a11y.presented_nodes()
    local context = shared.a11y.read_context_state()
    local message=shared.a11y.selected_message_packet()
    if message then return message.entries,{identity=message.identity,content=true,nodes={},message=message.signature} end
    local country=shared.a11y.native_list_selection
    if country and country.country and country.native_only then
        local current=shared.a11y.native_country_selection()
        if current and current.identity==country.identity and current.text==country.text then
            return {current.text},{identity=current.identity,nodes={},country={identity=current.identity,text=current.text,owner=shared.a11y.native_owner_token()}}
        end
    end
    local bodies,body_nodes={},{}
    for _,node in ipairs(nodes) do
        if node.name=="text_contents" or node.name=="messageBody" or node.name=="bodyText" then
            bodies[#bodies+1]=node.text;body_nodes[#body_nodes+1]=node
        end
    end
    if #bodies>0 and context.kind~="dialog" then
        return bodies,{identity="body:" .. tostring(shared.a11y.native_owner_token()) .. ":" .. context.generation,content=true,nodes=body_nodes}
    end
    if context.kind~="dialog" then
        local entity,entity_review=shared.a11y.entity_review_entries(nodes)
        if entity then return entity,entity_review end
        local record=shared.a11y.structured_record_packet()
        if record then return record.entries,{identity=record.identity,nodes={},groups=record.groups,record=record.signature,content=true} end
        local players,review=shared.a11y.player_list_review_entries(nodes)
        if players then return players,review end
    end
    local result, seen = {}, {}
    local review={content=true,identity="content:" .. tostring(shared.a11y.native_owner_token()) .. ":" .. context.generation,nodes={}}
    local function add(text,node,force)
        if text and text ~= "" and not seen[text] and (force or not shared.a11y.review_chrome(text,node)) then
            result[#result + 1], seen[text] = text, true
            review.nodes[#result]=node
        end
    end
    -- A dialog's body owns review. Background players and command captions do
    -- not become additional entries; answering remains native game navigation.
    if context.kind=="dialog" and context.question then
        add(context.question,nil,true)
        return result,review
    end
    add(context.title)
    add(context.question,nil,true)
    local selection=context.selection
    if selection and (not selection.origin or shared.a11y.speech_origin_allowed(selection.origin)) then
        local committed=context.selection_result
        local current=committed and shared.a11y.selection_result({row=committed.row,widget=committed.widget,
            identity=selection.identity,source=committed.source})
        local selected=selection.origin and shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(selection.origin.address)]
        add(current and current.text or selection.text,selected)
    end
    for _, item in ipairs(shared.a11y.dashboard_texts or {}) do
        local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(item.address)]
        if #result < 80 and shared.a11y.native_widget_allowed(item.address)
                and (not item.owner or item.owner==shared.a11y.native_owner_token())
                and (not item.identity or (node and node.identity==item.identity and node.text==item.text)) then add(item.text,node) end
    end
    if context.kind ~= "dialog" then
        table.sort(nodes,function(a,b)
            local function heading(node)
                local name=(node.name or ""):lower()
                return (name:find("title",1,true) or name:find("headline",1,true) or name:find("subject",1,true)) and 0 or 1
            end
            local ar,br=heading(a),heading(b)
            if ar~=br then return ar<br end
            return (a.sequence or 0)<(b.sequence or 0)
        end)
        for _,node in ipairs(nodes) do
            if #result>=80 then break end
            local role=shared.a11y.text_asset_role(node.text)
            if node.name~="padIcon" and not shared.a11y.is_media_caption(node) and role~="technical" and role~="status"
                    and not shared.is_noninteractive_text(node.text) then add(node.text,node) end
        end
    end
    return result,review
end

function shared.a11y.is_menu_description(node)
    return node and node.name=="description_offline"
end

-- Read-only equivalent of Window::get_select_index (e3d140). A mapped
-- scrolling list uses its typed kind-16 selector; flat menus use Impl+d8.
function shared.a11y.native_window_selected_index(window,base)
    local impl=window.impl or shared.a11y.menu_read(window.address+0x88,"u64")
    if not impl or impl<0x10000 then return nil end
    local group_index=shared.a11y.menu_read(impl+0xa0,"u32")
    local first,last=shared.a11y.menu_read(impl+0xa8,"u64"),shared.a11y.menu_read(impl+0xb0,"u64")
    if not group_index or not first or not last or last<first or (first~=last and first<0x10000) or (last-first)%0x18~=0
            or last-first>0x18*64 then return nil end
    for at=first,last-0x18,0x18 do
        if shared.a11y.menu_read(at,"u32")==group_index then
            local group=shared.a11y.menu_child(window.root,group_index)
            local selectors=group and shared.a11y.holder_kind_nodes(group+0x98,0x10)
            -- e3d1a9 passes index0 to e4d1c0. Additional kind-16 nodes do
            -- not make the game's ordered first selector ambiguous.
            if not selectors or #selectors==0 then return nil end
            return shared.a11y.menu_read(selectors[1]+0xbc,"u32")
        end
    end
    return shared.a11y.menu_read(impl+0xd8,"u32")
end

function shared.a11y.native_music_state(node)
    local snapshot=shared.a11y.native_windows
    local base=tonumber(shared.process_base_u64)
    local member=snapshot and snapshot.members[tonumber(node.address)]
    local found
    for _,owner in ipairs(member and member.owners or {}) do
        local vt=owner.enabled and base and shared.a11y.menu_read(owner.address,"u64")
        if vt and shared.a11y.menu_read(vt+0x270,"u64")==base+0xcb8310
                and shared.a11y.menu_read(vt+0x280,"u64")==base+0xcb8520 then
            for _,window in ipairs(snapshot.windows or {}) do
                if window.enabled and window.address==owner.address then
                    local index=shared.a11y.native_window_selected_index(window,base)
                    local first,last=shared.a11y.menu_read(window.address+0xf0,"u64"),shared.a11y.menu_read(window.address+0xf8,"u64")
                    local category=shared.a11y.menu_read(window.address+0xbc,"u32")
                    local cfirst,clast=shared.a11y.menu_read(window.address+0xc0,"u64"),shared.a11y.menu_read(window.address+0xc8,"u64")
                    if index and first and last and first>=0x10000 and last>=first and (last-first)%0x50==0
                            and last-first<=0x50*4096 and index<(last-first)/0x50
                            and category and cfirst and clast and cfirst>=0x10000 and clast>=cfirst and (clast-cfirst)%32==0
                            and clast-cfirst<=32*64 and category<(clast-cfirst)/32
                            and shared.a11y.menu_read(first+index*0x50+0x41,"u8")==0 then
                        local pointer=shared.a11y.menu_read(first+index*0x50+8,"u64")
                        local state=pointer and pointer>=0x10000 and shared.a11y.menu_read(pointer+category,"u8")
                        -- b25c94 reads the category byte; b25cb6..cff renders
                        -- only 1 checked, 0/2 unchecked. Other values unknown.
                        if state==0 or state==1 or state==2 then
                            local current={window=window.address,index=index,category=category,state=state,
                                identity=table.concat({window.address,index,category,state},":")}
                            if found and found.identity~=current.identity then return nil end
                            found=current
                        end
                    end
                end
            end
        end
    end
    return found
end

function shared.a11y.native_music_packet(node)
    if not node or node.name~="music" or not node.text or node.text=="" then return nil end
    local snapshot=shared.a11y.native_windows
    if not snapshot or not snapshot.selected_members or not snapshot.selected_members[tonumber(node.address)] then return nil end
    local artist
    for _,other in pairs(shared.a11y.ui_model and shared.a11y.ui_model.names.artist or {}) do
        if other.text and other.text~="" and shared.a11y.native_presentation_ready(other.address)
                and shared.a11y.component_peers(node.address,other.address)==true then
            if artist and artist~=other then return nil end
            artist=other
        end
    end
    local state=shared.a11y.native_music_state(node)
    local text=node.text .. (artist and ", " .. artist.text or "")
    if state then
        text=text .. ", " .. (state.state==1 and (shared.a11y.ui_language=="pt" and "ativada" or "enabled")
            or (shared.a11y.ui_language=="pt" and "desativada" or "disabled"))
    end
    return {text=text,artist=artist,state=state,signature=text .. ":" .. (state and state.identity or "unknown")}
end

function shared.a11y.is_media_caption(node)
    if not node or (node.name~="music" and node.name~="artist") then return false end
    -- A passive music banner can inherit cursor membership from a whole panel.
    -- Only the typed soundtrack selector proves explicit track navigation.
    return not shared.a11y.native_music_state(node)
end

function shared.a11y.is_match_ready_notice(text)
    return text and (text:find("A partida começará quando os dois times",1,true)
        or text:lower():find("match will begin when both teams",1,true))~=nil
end

function shared.a11y.native_pause_context()
    if shared.a11y.native_information_context() then return nil end
    local base=tonumber(shared.process_base_u64)
    for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
        local vt=base and window.enabled and window.root and window.root>=0x10000
            and shared.a11y.menu_read(window.address,"u64")
        local flags=vt and shared.a11y.menu_read(window.root+0xc,"u32")
        if flags and flags%8==7 and math.floor(flags/256)%2==1
                and shared.a11y.menu_read(vt+0x18,"u64")==base+0x4d7540
                and shared.a11y.menu_read(vt+0x100,"u64")==base+0x4d7610 then
            return {window=window.address,root=window.root,identity=tostring(window.address) .. ":" .. tostring(window.root)}
        end
    end
end

function shared.a11y.poll_native_pause()
    local pause=shared.a11y.native_pause_context()
    if not pause then shared.a11y.pause_announced=nil;return end
    shared.a11y.pre_match_active,shared.a11y.pre_match_entry_pending,shared.a11y.pre_match_notice_text=false,false,nil
    if shared.a11y.is_match_ready_notice(shared.pending_message_text) then
        shared.pending_message_text,shared.pending_message_key,shared.pending_message_due_ms=nil,nil,nil
        shared.modal_focus_hold_until_ms=0
    end
    local context=shared.a11y.read_context_state()
    if shared.a11y.is_match_ready_notice(context.question) then shared.a11y.reset_read_context("pause-presentation");shared.modal_focus_hold_until_ms=0 end
    if shared.a11y.read_context_state().kind=="dialog" or shared.a11y.pause_announced==pause.identity then return end
    local title=shared.a11y.ui_language=="pt" and "Menu de pausa" or "Pause menu"
    local before=shared.a11y.native_speech_last
    shared.a11y.set_read_title(title)
    shared.speak(title,true,nil,"pause-header:" .. pause.identity)
    if shared.a11y.native_speech_last>before then
        shared.a11y.pause_announced=pause.identity
        shared.a11y.title_pending_first_item=title
        shared.a11y.title_pending_first_item_until_ms=tonumber(ffi.C.GetTickCount64())+2000
        for index=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[index].pause_header=pause.identity end
    end
end

function shared.a11y.native_information_context()
    if shared.core_context and shared.core_context.match_playing then return nil end
    local work=shared.a11y.render_read_work
    if work and work.information~=nil then return work.information or nil end
    local value=shared.a11y.read_native_information_context()
    if work then work.information=value or false end
    return value
end

function shared.a11y.read_native_information_context()
    local base=tonumber(shared.process_base_u64)
    local found
    for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
        local vt=base and window.enabled and window.root and window.root>=0x10000 and shared.a11y.menu_read(window.address,"u64")
        -- ParameterDetail's lifecycle and presentation updater, independent
        -- of translated headings and of whether its page has a text cursor.
        local flags=vt and shared.a11y.menu_read(window.root+0xc,"u32")
        if flags and flags%8==7 and math.floor(flags/256)%2==1
                and shared.a11y.menu_read(vt+0x18,"u64")==base+0x90ca30
                and shared.a11y.menu_read(vt+0x100,"u64")==base+0x9113c0 then
            if found and found.window~=window.address then return nil end
            found={window=window.address,root=window.root,side=shared.a11y.menu_read(window.address+0x98,"u32"),
                identity=tostring(window.address) .. ":" .. tostring(window.root)}
        end
    end
    return found
end

function shared.a11y.poll_information_context()
    local context=shared.a11y.native_information_context()
    if not context then shared.a11y.information_announced=nil;return end
    shared.a11y.clear_pending_tooltips()
    if context.identity==shared.a11y.information_announced or shared.a11y.read_context_state().kind=="dialog" then return end
    local title=shared.a11y.ui_language=="pt" and "Informações do jogador" or "Player information"
    local before=shared.a11y.native_speech_last
    shared.speak(title,true,nil,"information-header:" .. context.identity)
    if shared.a11y.native_speech_last>before then
        shared.a11y.information_announced=context.identity
        shared.a11y.title_pending_first_item=title
        shared.a11y.title_pending_first_item_until_ms=tonumber(ffi.C.GetTickCount64())+2000
        for index=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[index].information_header=context.identity end
    end
end

function shared.a11y.field_visualization_text(label,value,name)
    if name=="height_item" and label:find("(cm)",1,true) and tonumber(value) then
        local number=tonumber(value)/100
        local text=string.format("%.2f",number)
        if shared.a11y.ui_language=="pt" then text=text:gsub("%.",",") end
        return label:gsub("%s*%(cm%)","") .. ": " .. text
            .. (shared.a11y.ui_language=="pt" and " metros" or " metres")
    elseif name=="weight_item" and label:find("(kg)",1,true) and tonumber(value) then
        return label:gsub("%s*%(kg%)","") .. ": " .. value
            .. (shared.a11y.ui_language=="pt" and " quilos" or " kilograms")
    end
    return label .. ": " .. value
end

-- A read-only presentation may share one label column across data columns.
-- Pair resource stems inside the SAME native owner/root; never pair nearby
-- writes or captions. Multiple populated columns remain ambiguous.
function shared.a11y.visualization_player_record()
    local target=shared.a11y.visualization_player
    local base=tonumber(shared.process_base_u64)
    local info=shared.a11y.native_information_context()
    if info then
        target=nil
        local data=info and base and shared.a11y.menu_read(base+0x36f38a0,"u64")
        if data and (info.side==0 or info.side==1) and shared.a11y.menu_read(data,"u64")==base+0x2618830 then
            -- 911650 uses variant zero for the primary displayed column;
            -- variant one is comparison. Resolve the same native descriptor.
            local offset=0xba4+info.side*0xa8
            local slot,side=shared.a11y.menu_read(data+offset,"u32"),shared.a11y.menu_read(data+offset+4,"u32")
            if slot and slot<40 and (side==0 or side==1) then
                target={descriptor_offset=offset,slot=slot,side=side}
            end
        end
    end
    local data=target and base and shared.a11y.menu_read(base+0x36f38a0,"u64")
    if not data or not target.descriptor_offset or shared.a11y.menu_read(data,"u64")~=base+0x2618830 then return nil end
    local descriptor=data+target.descriptor_offset
    if shared.a11y.menu_read(descriptor,"u32")~=target.slot or shared.a11y.menu_read(descriptor+4,"u32")~=target.side then return nil end
    local index=shared.a11y.menu_read(data+target.side*0x248+0x1f8+target.slot,"u8")
    if not index or index>=40 then return nil end
    local object=shared.a11y.menu_read(data+target.side*0x340+0x568+index*16,"u64")
    local id=object and shared.a11y.menu_read(object+0x30,"u32")
    if not id or id==0 or (target.player_id and id~=target.player_id) then return nil end
    local name=shared.a11y.read_native_c_string(object+0x38,64)
    if not name or #name<2 or name:find("%c") or (target.name and target.name:sub(1,#name)~=name) then return nil end
    return {object=object,player_id=id,name=target.name or name}
end

function shared.a11y.visualization_packet()
    local snapshot=shared.a11y.native_windows
    if not snapshot or shared.a11y.keyboard_window or shared.a11y.read_context_state().kind=="dialog" then return nil end
    local information=shared.a11y.native_information_context()
    local found
    for _,window in ipairs(snapshot.windows or {}) do
        local detail=window.cursor_detail
        if window.enabled and (not information or information.window==window.address)
                and (information or not detail or detail.status=="no-cursor" or detail.status=="unknown-delegate") then
            for _,root in ipairs(information and {window.root} or window.owned_roots or {window.root}) do
                local rows=shared.a11y.read_group_fields(window,root)
                if #rows>0 then
                    if found and (found.window~=window.address or found.root~=root) then return nil end
                    found={window=window.address,root=root,fields=rows,
                        identity=(shared.a11y.native_owner_token() or "") .. ":fields:" .. window.address .. ":" .. root,
                        generation=shared.a11y.read_context_state().generation}
                end
            end
        end
    end
    if not found and information then
        found={window=information.window,root=information.root,fields={},identity="information:" .. information.identity,
            generation=shared.a11y.read_context_state().generation}
    end
    if found and (information or (found.fields[1] and found.fields[1].key=="height_item"
            and found.fields[2] and found.fields[2].key=="weight_item")) then
        shared.a11y.append_visualization_attributes(found)
    end
    return found
end

function shared.a11y.append_visualization_attributes(packet)
    local record=shared.a11y.visualization_player_record()
    if not record then return end
    packet.identity=packet.identity .. ":player=" .. record.player_id .. ":" .. record.object
    local seen={}
    for _,field in ipairs(packet.fields) do if field.label then seen[field.label.text]=true end end
    local style=shared.a11y.player_style_text(record)
    if style then packet.fields[#packet.fields+1]={key="style",
        text=(shared.a11y.ui_language=="pt" and "Estilo de jogo: " or "Playing style: ") .. style} end
    if not shared.readable(record.object,0x30) then return end
    local bytes=memory.read(record.object,0x30)
    if not bytes or #bytes~=0x30 then return end
    local attributes,plausible={},0
    for index,spec in ipairs(shared.a11y.player_attribute_specs) do
        local value=shared.a11y.player_record_bits(bytes,spec[3],spec[4],7)
        if value>=40 and value<=99 then plausible=plausible+1 end
        local label=shared.a11y.ui_language=="pt" and spec[1] or spec[2]
        if not seen[label] then attributes[#attributes+1]={key="attribute:" .. index,text=label .. ": " .. value} end
    end
    if plausible>=20 then for _,field in ipairs(attributes) do packet.fields[#packet.fields+1]=field end end
end

function shared.a11y.visualization_allowed(origin)
    local packet=shared.a11y.visualization_packet()
    if not packet or packet.identity~=origin.identity or packet.generation~=origin.generation then return false end
    for _,field in ipairs(packet.fields) do
        if field.key==origin.key then return field.text==origin.text
            and field.group_title==origin.group_title and field.group_key==origin.group_key end
    end
    return false
end

function shared.a11y.read_visualization(action)
    shared.a11y.poll_native_texts(true)
    local packet=shared.a11y.visualization_packet()
    if not packet then shared.a11y.visualization_review=nil;return false end
    local state=shared.a11y.visualization_review
    if not state or state.identity~=packet.identity or state.generation~=packet.generation then
        state={identity=packet.identity,generation=packet.generation,index=0,sequence=0};shared.a11y.visualization_review=state
    end
    local count=#packet.fields
    if count==0 then
        shared.speak(shared.a11y.ui_language=="pt" and "Atributos ainda indisponíveis." or "Attributes unavailable.",true,true,
            "visualization:" .. packet.identity .. ":unavailable")
        return true
    end
    if action=="first" then state.index=1
    elseif action=="next" then state.index=state.index%count+1
    elseif action=="previous" then state.index=state.index==0 and count or (state.index-2)%count+1
    elseif state.index==0 or state.index>count then state.index=1 end
    state.sequence=state.sequence+1
    local field=packet.fields[state.index]
    local before=shared.a11y.native_speech_last
    shared.modal_focus_hold_until_ms=0;shared.a11y.title_pending_first_item=nil;shared.a11y.deferred_modal_announcement=nil
    local spoken=shared.a11y.group_field_speech(state,field.text,{key=field.group_key,title=field.group_title},action=="first")
    -- Read-only fields need no input focus. The packet validator rechecks the
    -- shown values, native owner and graph before delivery.
    shared.speak(spoken,true,true,"visualization:" .. packet.identity .. ":" .. state.sequence)
    local origin={identity=packet.identity,generation=packet.generation,key=field.key,text=field.text,
        group_title=field.group_title,group_key=field.group_key}
    for index=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[index].visualization=origin end
    return true
end

function shared.a11y.read_buffer(action,quiet_empty)
    if action~="first" and action~="next" and action~="previous" then return false end
    if not shared.game_is_foreground() or shared.overlay_visible or shared.sider_overlay_visible or shared.a11y.keyboard_window then return false end
    if shared.a11y.read_context_state().kind~="dialog" then
        if shared.a11y.read_visualization(action) then return true end
        if shared.a11y.read_player_details(action) then return true end
    end
    local entries,review = shared.a11y.buffer_entries()
    if quiet_empty and #entries==0 then return false end
    local context = shared.a11y.read_context_state()
    if review and context.review_identity~=review.identity then context.cursor=0;context.review_group=nil end
    context.review_identity=review and review.identity
    if #entries > 0 then
        if context.cursor > #entries then context.cursor = 1 end
        if action == "next" then context.cursor = context.cursor % #entries + 1 end
        if action == "previous" then context.cursor = context.cursor==0 and #entries or (context.cursor - 2) % #entries + 1 end
        if action == "first" then context.cursor = 1 end
    end
    local text = entries[context.cursor] or (shared.a11y.ui_language == "pt"
        and "Sem conteúdo confirmado neste contexto." or "No confirmed content in this context.")
    text=shared.a11y.group_field_speech(context,text,review and review.groups and review.groups[context.cursor],action=="first")
    shared.modal_focus_hold_until_ms = 0
    shared.a11y.title_pending_first_item = nil
    shared.a11y.deferred_modal_announcement = nil
    local node=review and review.nodes[context.cursor]
    local before=shared.a11y.native_speech_last
    context.review_sequence=(context.review_sequence or 0)+1
    shared.speak(text, true, true,"review:" .. tostring(context.generation) .. ":" .. tostring(context.review_sequence),node and node.address)
    if review and review.ml_date and context.cursor==1 then
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].ml_date={signature=review.ml_date.signature}
        end
    end
    if review and review.message then
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].selected_message={signature=review.message,owner=shared.a11y.native_owner_token()}
        end
    end
    if review and review.country then
        for index=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[index].native_list=review.country end
    end
    if review and review.record then
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].structured_record={signature=review.record,owner=shared.a11y.native_owner_token(),detail=true}
        end
    end
    if node and review.content then
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].content_review={key=node.key,identity=node.identity,text=node.text,owner=shared.a11y.native_owner_token()}
        end
    end
    if node and review.anchor then
        local origin={origin=shared.a11y.capture_speech_origin(node.address),anchor=shared.a11y.capture_speech_origin(review.anchor.address),
            generation=context.generation,identity=shared.a11y.engine_selection_identity(node.key,node),
            list_identity=review.list_identity,selection=review.selection,parts={}}
        for _,part in ipairs(shared.a11y.player_row_details(node,true)) do origin.parts[#origin.parts+1]=shared.a11y.capture_speech_origin(part.address) end
        for index=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[index].roster_review=origin end
    end
    return true
end

function shared.a11y.transition_focus_blocked(key, entry, offset, edge, now_ms)
    if not shared.a11y.transition_old_focus_texts then return false end
    local old = shared.a11y.transition_old_focus_nodes and shared.a11y.transition_old_focus_nodes[key]
    local node = shared.a11y.ui_model and shared.a11y.ui_model.nodes[key]
    local fresh = offset == 0x104 and edge > (shared.a11y.transition_started_frame or shared.frame)
    if now_ms >= shared.a11y.transition_guard_until_ms or fresh or (entry and
            (not old or old.text ~= entry.text or (node and node.identity ~= old.identity))) then
        shared.a11y.transition_old_focus_texts, shared.a11y.transition_old_focus_nodes = nil, nil
        return false
    end
    return true
end

function shared.a11y.capture_pending_modal_button(key, entry, offset, edge)
    local context = shared.a11y.read_context_state()
    local previous = context.baseline and context.baseline[key]
    local fresh = edge and edge >= context.started_frame
    local eligible = context.question and entry and offset == 0x104
        and key ~= context.message_key and shared.is_modal_button(entry.text)
        and entry.text ~= "Sim" and entry.text ~= "Não"
        and entry.last_seen >= context.started_frame
        and (not previous or previous.text ~= entry.text or fresh)
    shared.a11y.pending_modal_button_text = eligible and entry.text or nil
    return eligible and true or false
end

function shared.a11y.buffer_key(vkey)
    if shared.a11y.keyboard_window then return false end
    local actions = {[0x49]="previous", [0x4b]="next", [0x4a]="first"}
    if actions[vkey] then
        local now = tonumber(ffi.C.GetTickCount64())
        if shared.a11y.buffer_last_key == vkey and now - (shared.a11y.buffer_last_ms or 0) < 120 then return true end
        if shared.a11y.read_buffer(actions[vkey]) then
            shared.a11y.buffer_last_key, shared.a11y.buffer_last_ms = vkey, now
            return true
        end
    end
    return false
end

function shared.a11y.review_right_stick(direction)
    if direction==0 then shared.a11y.player_review_stick_direction=nil;return false end
    if shared.a11y.player_review_stick_direction==direction then return true end
    if shared.a11y.keyboard_window then
        shared.a11y.player_review_stick_direction=nil;return false
    end
    shared.a11y.player_review_stick_direction=direction
    local handled=shared.a11y.read_buffer(direction<0 and "previous" or "next",true)
    if not handled then shared.a11y.player_review_stick_direction=nil end
    return handled
end

function shared.a11y.reset_ui_model()
    shared.a11y.reset_read_context("transition")
    local generation = shared.a11y.ui_model and shared.a11y.ui_model.generation or 0
    shared.a11y.ui_model = {
        generation = generation + 1, nodes = {}, names = {}, texts = {}, count = 0,
        sequence = 0, focus_reason = nil,
    }
end

function shared.a11y.forget_ui_widget(key)
    local model = shared.a11y.ui_model
    local node = model and model.nodes[key]
    if node then
        local bucket=model.texts and model.texts[node.text]
        if bucket and bucket.nodes[key] then
            bucket.nodes[key]=nil;bucket.count=bucket.count-1
            if bucket.count==0 then model.texts[node.text]=nil end
        end
        local context = shared.a11y.read_context
        if context then
            if context.answer_owners then context.answer_owners[key] = nil end
            local selected = context.selection
            local identity = selected and tostring(selected.identity or "") or ""
            if selected and (selected.widget_key == key or identity == node.identity
                    or identity:sub(1, #node.identity + 1) == node.identity .. ":") then
                context.selection, context.help = nil, nil
            end
        end
        if shared.a11y.answer_chain then shared.a11y.answer_chain.owners[key] = nil end
        if node.name and model.names[node.name] then
            model.names[node.name][key] = nil
            local remaining = false
            for _ in pairs(model.names[node.name]) do remaining = true; break end
            if not remaining then model.names[node.name] = nil end
        end
        model.nodes[key] = nil
        model.count = model.count - 1
    end
    if shared.ui_focus_widgets[key] then
        shared.ui_focus_widgets[key] = nil
        shared.ui_focus_widget_count = shared.ui_focus_widget_count - 1
    end
    shared.ui_focus_state[key], shared.ui_focus_activated[key] = nil, nil
    local row = shared.control_rows_by_label_widget[key]
    if row then
        if shared.controller_rows[row.label] == row then shared.controller_rows[row.label] = nil end
        if row.value_widget_key and shared.control_row_by_value_widget[row.value_widget_key] == row then
            shared.control_row_by_value_widget[row.value_widget_key] = nil
        end
        if shared.active_control_row == row then shared.active_control_row = nil end
        if shared.pending_control_row == row then shared.pending_control_row = nil end
        shared.control_rows_by_label_widget[key] = nil
    end
    local owner = shared.control_row_by_value_widget[key]
    if owner then
        owner.value_widget, owner.value_widget_key, owner.value = nil, nil, nil
        shared.control_row_by_value_widget[key] = nil
    end
end

function shared.a11y.observe_ui_widget(widget, text)
    if not shared.a11y.ui_model then shared.a11y.reset_ui_model() end
    local model = shared.a11y.ui_model
    local key = memory.hex(widget)
    local name = shared.a11y.widget_internal_name(widget)
    local node = model.nodes[key]
    if node and node.name ~= name then
        shared.a11y.forget_ui_widget(key)
        node = nil
    end
    if not node then
        if model.count >= 1024 then
            local oldest,old_rank
            local snapshot=shared.a11y.native_windows
            for _, candidate in pairs(model.nodes) do
                local address=tonumber(candidate.address)
                local member=snapshot and snapshot.members and snapshot.members[address]
                local rank=snapshot and snapshot.selected_members and snapshot.selected_members[address] and 2
                    or member and member.active and 1 or 0
                if not oldest or rank<old_rank or (rank==old_rank and (candidate.last_seen < oldest.last_seen
                        or (candidate.last_seen == oldest.last_seen and candidate.sequence < oldest.sequence))) then
                    oldest,old_rank=candidate,rank
                end
            end
            if oldest then shared.a11y.forget_ui_widget(oldest.key) end
        end
        model.sequence = model.sequence + 1
        node = {key=key, address=widget, name=name, generation=model.generation,
            sequence=model.sequence, identity=tostring(model.generation) .. ":" ..
                tostring(model.sequence)}
        model.nodes[key] = node
        model.count = model.count + 1
        if name then
            model.names[name] = model.names[name] or {}
            model.names[name][key] = node
        end
    end
    if shared.a11y.component_capture and shared.a11y.component_capture.active and node.text~=text then
        shared.a11y.component_capture_dirty_frame=shared.frame
    end
    if node.text~=text then
        shared.a11y.tooltip_dirty=true
        model.texts=model.texts or {}
        local old=model.texts[node.text]
        if old and old.nodes[key] then
            old.nodes[key]=nil;old.count=old.count-1
            if old.count==0 then model.texts[node.text]=nil end
        end
        local bucket=model.texts[text] or {nodes={},count=0}
        model.texts[text]=bucket
        if not bucket.nodes[key] then bucket.count=bucket.count+1;bucket.nodes[key]=node end
    end
    node.text, node.last_seen = text, shared.frame
    node.owner_link = shared.a11y.ui_owner_link(widget)
    -- These are observations, not a synthetic accessibility tree.
    node.role = name and name:match("_item$") and "control-label"
        or name and name:match("_value$") and "control-value" or "unknown"
    local stem = name and (name:match("^(.-)_item$") or name:match("^(.-)_value$"))
    if stem and not shared.a11y.unique_ui_name(name) then
        shared.a11y.invalidate_structural_pair(stem)
    end
    return node
end

function shared.a11y.unique_ui_name(name)
    local model = shared.a11y.ui_model
    local bucket = model and model.names[name]
    local found
    for _, node in pairs(bucket or {}) do
        if found then return nil, "ambiguous-name" end
        found = node
    end
    return found, found and "unique-name" or "missing-name"
end

function shared.a11y.control_for_widget(key)
    -- Localization may register every short caption as a provisional label.
    -- A value's proven native relation outranks that provisional registration.
    local value = key and shared.control_row_by_value_widget[key]
    if value and value.native_field then return value end
    return key and (shared.control_rows_by_label_widget[key] or value) or nil
end

function shared.a11y.resolve_primary_focus(candidates)
    local groups, ordered = {}, {}
    for _, candidate in ipairs(candidates) do
        local row = shared.a11y.control_for_widget(candidate.key)
        local entry = shared.ui_focus_widgets[candidate.key]
            or (shared.a11y.ui_model and shared.a11y.ui_model.nodes[candidate.key])
        -- Collapse only an existing label/value relation. Equal captions and
        -- different controls remain independent selection candidates.
        local related = row and (row.is_control or (row.value and row.value ~= ""
            and not shared.non_control_labels[row.label] and not shared.is_modal_button(row.value))) and entry and
            ((candidate.key == row.label_widget_key and entry.text == row.label)
                or (candidate.key == row.value_widget_key and entry.text == row.value))
        local owner = related and row or candidate.key
        local group = groups[owner]
        if not group then
            group = {key=candidate.key,edge=candidate.edge or -1,row=related and row or nil}
            groups[owner], ordered[#ordered+1] = group, group
        else
            group.edge = math.max(group.edge, candidate.edge or -1)
            if row and candidate.key == row.label_widget_key then group.key = candidate.key end
        end
    end
    local best, edge, tied = nil, -1, false
    for _, candidate in ipairs(ordered) do
        if not best or candidate.edge > edge then
            best, edge, tied = candidate, candidate.edge, false
        elseif candidate.edge == edge then
            tied = true
        end
    end
    local reason = not best and "no-selection"
        or tied and "ambiguous-selection"
        or #ordered == 1 and (#candidates > 1 and "control-label-value" or "unique-selection")
        or "selection-edge"
    if shared.a11y.ui_model then shared.a11y.ui_model.focus_reason = reason end
    if tied then return nil, reason end
    return best, reason
end

-- Native window authority is independent of captions and the sticky cursorOver
-- field. These reads mirror WindowManager and Window getters in this EXE.
-- Unknown membership stays with the existing reader; only proven background
-- membership is rejected. No new native hooks or calls into game functions.

    shared.stage = 6
end
function component.init(ctx)
    component.install(ctx)

end
return component
