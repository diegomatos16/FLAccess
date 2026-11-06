-- Native list selection and lightweight window refresh. No detail decoding.
local component={}
function component.install(ctx)
    assert(ctx.flaccess,"FLAccess core must load first")
    local shared=ctx.flaccess.reader
    assert(shared.stage==11,"reader_lists must follow controls")
-- A full discovery is needed on ownership/layout changes. Stable frames only
-- re-read the manager/window headers and the native cursor. No historical
-- scalar value or caption crosses frames; graph edges are still checked at use.
function shared.a11y.capture_window_headers(snapshot,base)
    local checks,seen={},{}
    local valid=true
    local function add(address,kind,mask)
        if not address or address<0x10000 then valid=false;return nil end
        local key=address .. ":" .. kind
        local value=shared.a11y.menu_read(address,kind)
        if value==nil then valid=false;return nil end
        if not seen[key] then
            seen[key]=true;checks[#checks+1]={address=address,kind=kind,value=mask and value%(mask+1) or value,mask=mask}
        end
        return value
    end
    local manager=add(base+0x36f9c10,"u64")
    if not manager or manager<0x10000 then return nil end
    add(manager,"u64")
    for slot=0,7 do
        add(manager+0xc8+slot*16,"u64");add(manager+0xd0+slot*16,"i32")
        local first,last=add(manager+8+slot*24,"u64"),add(manager+16+slot*24,"u64")
        if first and last and first>=0x10000 and last>=first and last-first<=1024 and (last-first)%16==0 then
            for at=first,last-16,16 do add(at,"u64") end
        end
    end
    for _,window in ipairs(snapshot.windows or {}) do
        add(window.address,"u64")
        add(window.address+0x88,"u64")
        local impl=window.impl
        if not impl or impl<0x10000 then return nil end
        add(impl+9,"u8",1);add(impl+0x98,"u64");add(impl+0x90,"u64")
        local first,last=add(impl+0x70,"u64"),add(impl+0x78,"u64")
        if first and last and first>=0x10000 and last>=first and last-first<=0x50*64 and (last-first)%0x50==0 then
            for at=first,last-0x50,0x50 do add(at+0x40,"u64") end
        end
        if shared.a11y.is_native_window_task(window.address,base) then
            for _,offset in ipairs({0x38,0x40,0x50}) do add(window.address+offset,"u64") end
        end
        for _,root in ipairs(window.owned_roots or {}) do add(root,"u64");add(root+0xc,"u32",7) end
    end
    return valid and checks or nil
end

function shared.a11y.list_cursor_unchanged(window,base)
    local detail=window.cursor_detail
    if not detail or not window.enabled or not window.root or window.root<0x10000 then return true end
    local cursor=shared.a11y.menu_read(window.root+0x190,"u64")
    local kind=cursor and shared.a11y.menu_read(cursor,"u64")
    if cursor~=detail.cursor or kind~=detail.cursor_type then return false end
    if kind~=base+0x27c1ac0 then return true end
    local parent=shared.a11y.menu_read(cursor+0x88,"u64")
    local group_index,item_index=shared.a11y.menu_read(cursor+0x90,"u32"),shared.a11y.menu_read(cursor+0x94,"u32")
    if parent~=detail.parent or group_index~=detail.group_index or item_index~=detail.item_index then return false end
    local group=shared.a11y.menu_child(parent,group_index)
    local selected=group and shared.a11y.menu_child(group,item_index)
    return group==detail.group and selected==detail.selected
        and (not selected or shared.a11y.menu_read(selected,"u64")==detail.selected_type)
end

-- Immutable expectations, fresh bytes at every validation. One protected RPM
-- per touched page/span instead of a scalar call for every manager/header slot.
function shared.a11y.compile_header_batches(checks)
    if not checks then return nil end
    local batches,by_page={},{}
    local types={u64="uint64_t",u32="uint32_t",i32="int32_t",u16="uint16_t",u8="uint8_t"}
    for _,check in ipairs(checks) do
        local ctype=types[check.kind]
        if not ctype then return nil end
        local size=ffi.sizeof(ctype)
        local page=math.floor(check.address/4096)*4096
        if check.address+size>page+4096 then return nil end
        local batch=by_page[page]
        if not batch then batch={first=check.address,last=check.address+size,checks={}};by_page[page]=batch;batches[#batches+1]=batch end
        batch.first,batch.last=math.min(batch.first,check.address),math.max(batch.last,check.address+size)
        local bytes=not check.mask and ffi.string(ffi.new(ctype .. "[1]",check.value),size) or nil
        batch.checks[#batch.checks+1]={address=check.address,size=size,kind=check.kind,mask=check.mask,value=check.value,bytes=bytes}
    end
    return batches
end

function shared.a11y.header_batches_live(batches)
    for _,batch in ipairs(batches) do
        local bytes=shared.a11y.safe_memory_read(batch.first,batch.last-batch.first)
        if not bytes or #bytes~=batch.last-batch.first then return false end
        for _,check in ipairs(batch.checks) do
            local at=check.address-batch.first+1
            local actual=bytes:sub(at,at+check.size-1)
            if check.mask then
                local value=tonumber(memory.unpack(check.kind,actual))
                if not value or value%(check.mask+1)~=check.value then return false end
            elseif actual~=check.bytes then return false end
        end
    end
    return true
end

-- Selection authority is structural, independent of whether a translated
-- caption happened to arrive through a list-render hook.
function shared.a11y.proven_snapshot_cursor(snapshot,base)
    if not snapshot or shared.a11y.keyboard_window or shared.a11y.read_context_state().kind=="dialog" then return false end
    local selected_window
    for _,window in ipairs(snapshot.windows or {}) do
        if window.enabled then
            if shared.a11y.native_dialog_window(window) then return false end
            local detail=window.cursor_detail
            if detail and detail.selected and detail.cursor_type==base+0x27c1ac0
                    and (detail.status=="resolved" or detail.status=="shared-caption")
                    and detail.graph_edges and detail.proof_root then
                if selected_window then return false end
                local cursor=shared.a11y.menu_read(window.root+0x190,"u64")
                if cursor~=detail.cursor or shared.a11y.menu_read(cursor,"u64")~=detail.cursor_type
                        or shared.a11y.menu_read(cursor+0x88,"u64")~=detail.parent
                        or shared.a11y.menu_read(cursor+0x90,"u32")~=detail.group_index
                        or shared.a11y.menu_child(detail.parent,detail.group_index)~=detail.group then return false end
                -- Item movement inside this proven group is resolved below.
                -- A new/missing graph edge still forces full discovery.
                selected_window=window
            end
        end
    end
    return selected_window~=nil
end

function shared.a11y.refresh_list_snapshot(base,previous)
    if not previous or not previous.header_checks or not previous.full_frame then return nil,"initial" end
    local selection_only=not shared.a11y.keyboard_window
        and shared.a11y.read_context_state().kind~="dialog"
        and (shared.a11y.proven_snapshot_cursor(previous,base) or shared.a11y.native_list_has_focus())
    if shared.a11y.window_graph_dirty then return nil,"layout" end
    local period=6
    -- MatchMenu can be registered while its root is still being built.
    -- Header validation detects the root publication on the very next frame.
    for _,window in ipairs(previous.windows) do
        if window.primary and window.enabled and window.vtable==base+0x266b9f0 then period=24;break end
    end
    if not selection_only and shared.frame-previous.full_frame>=period then return nil,"periodic" end
    -- Pitch parameter captions use a separate native selection adapter.
    for _,window in ipairs(previous.windows or {}) do
        if window.enabled and window.vtable==base+0x261e0c8 then return nil,"parameter" end
        if window.enabled then
            for _,root in ipairs(window.owned_roots or {}) do
                local cached=shared.a11y.native_tree_cache and shared.a11y.native_tree_cache[root]
                if not cached or (not selection_only and shared.frame-cached.frame>=period) then return nil,"periodic" end
            end
        end
    end
    if previous.header_batches then
        if not shared.a11y.header_batches_live(previous.header_batches) then return nil,"ownership" end
    else for _,check in ipairs(previous.header_checks) do
        local value=shared.a11y.menu_read(check.address,check.kind)
        if value==nil or (check.mask and value%(check.mask+1) or value)~=check.value then return nil,"ownership" end
    end end
    local bar
    if previous.guide_batches then
        if not shared.a11y.header_batches_live(previous.guide_batches) then return nil,"guide" end
        bar=previous.command_bar
    else
        bar=shared.a11y.read_native_command_bar(base)
    end
    if (bar and bar.address)~=(previous.command_bar and previous.command_bar.address)
            or (bar and bar.root)~=(previous.command_bar and previous.command_bar.root) then return nil,"guide" end
    for _,pair in ipairs(bar and bar.pairs or {}) do
        if not previous.members[pair.icon] or not previous.members[pair.caption] then return nil,"guide" end
    end
    local unchanged=true
    for _,window in ipairs(previous.windows or {}) do
        if not shared.a11y.list_cursor_unchanged(window,base) then unchanged=false;break end
    end
    local result={};for key,value in pairs(previous) do result[key]=value end
    result.command_bar,result.light,result.light_same_cursor=bar,true,unchanged
    result.selection_only=selection_only
    if unchanged then return result end
    result.windows,result.selected_members,result.cursor_members,result.cursor_proofs={},{},{},{}
    result.cursor_graphs={}
    result.controlled_selections={}
    for _,old in ipairs(previous.windows) do
        local window={};for key,value in pairs(old) do window[key]=value end
        result.windows[#result.windows+1]=window
        if window.enabled and window.root and window.root>=0x10000 then
            local cached=shared.a11y.native_tree_cache and shared.a11y.native_tree_cache[window.root]
            if not cached then return nil,"layout" end
            local selected,detail=shared.a11y.menu_cursor_texts(window.root,base,cached)
            window.cursor_detail=detail
            if not selected and detail and (detail.status=="missing-item" or detail.status=="missing-group") then return nil,"layout" end
            if selected then
                if not detail.graph_edges then return nil,"layout" end
                local proof={window=window,root=detail.proof_root,parents=detail.parents,edges=detail.graph_edges}
                for address in pairs(selected) do
                    if not previous.members[address] then return nil,"layout" end
                    result.selected_members[address],result.cursor_members[address]=true,true
                    result.cursor_proofs[address]=result.cursor_proofs[address] or {}
                    result.cursor_proofs[address][window.address]=proof
                end
                result.cursor_graphs[#result.cursor_graphs+1]=cached.members
            end
        end
    end
    return result
end

function shared.a11y.empty_selection_caption(text)
    local value=(text or ""):gsub("%s","")
    return value=="" or value=="-" or value=="–" or value=="—"
end

function shared.a11y.observe_native_list_selection(text,identity,widget)
    if shared.a11y.empty_selection_caption(text) or not widget or widget<0x10000 then return end
    local previous=shared.a11y.native_list_selection
    local name,link=shared.a11y.widget_internal_name(widget),shared.a11y.ui_owner_link(widget)
    if previous and previous.identity==identity and previous.text==text and previous.widget==widget
            and previous.name==name and previous.link==link then
        previous.observed=shared.frame
        return
    end
    shared.a11y.native_list_selection={text=text,identity=identity,widget=widget,observed=shared.frame,
        name=name,link=link}
end

-- The base carousel exposes 0x50 caption records. NationalitySelect instead
-- overrides its country renderer with filtered IDs; keep both layouts separate.
-- Its outer cursor selects the carousel, not an individual country caption.
-- C9D900/C9D860 select country IDs from the continent's filtered uint16 vector.
-- This override does not populate the generic carousel's 0x50 caption records.
function shared.a11y.filtered_country_id(window,parent)
    local key=shared.a11y.menu_read(parent,"u32")
    local offset,index=shared.a11y.menu_read(parent+0x64,"u32"),shared.a11y.menu_read(parent+0x68,"u32")
    local head=shared.a11y.menu_read(window+0x170,"u64")
    if not key or key>4 or not offset or not index or not head or head<0x10000 then return nil end
    local at=shared.a11y.menu_read(head+8,"u64")
    local seen={}
    for _=1,64 do
        if not at or at<0x10000 or at==head or seen[at] or shared.a11y.menu_read(at+0x19,"u8")~=0 then return nil end
        seen[at]=true
        local current=shared.a11y.menu_read(at+0x20,"u32")
        if current==nil then return nil end
        if current==key then
            local first,last=shared.a11y.menu_read(at+0x28,"u64"),shared.a11y.menu_read(at+0x30,"u64")
            if not first or first<0x10000 or not last or last<first or (last-first)%2~=0
                    or last-first>1024 or offset+index>=(last-first)/2 then return nil end
            local id=shared.a11y.menu_read(first+(offset+index)*2,"u16")
            if not id or id>=0x1ff then return nil end
            return id,first+(offset+index)*2
        end
        at=shared.a11y.menu_read(at+(current<key and 0x10 or 0),"u64")
    end
end

-- Read-only equivalent of CBBA20 -> 14BB0B0 -> 14B8060. Require an exact
-- native ID match; the game's missing-ID fallback to its first record is unsafe
-- for speech. Names come from the current database, not a hardcoded country map.
function shared.a11y.country_name(id)
    local base=tonumber(shared.process_base_u64)
    local manager=base and shared.a11y.menu_read(base+0x3705e10,"u64")
    local database=manager and shared.a11y.menu_read(manager+0x48,"u64")
    local count=database and shared.a11y.menu_read(database+0x184b5e0,"u32")
    if not count or count<1 or count>512 then return nil end
    local low,high=0,count
    local first=database+0x1843f20
    while low<high do
        local mid=math.floor((low+high)/2)
        local packed=shared.a11y.menu_read(first+mid*0x4c+0x48,"u32")
        if not packed then return nil end
        if packed%512<id then low=mid+1 else high=mid end
    end
    if low>=count then return nil end
    local record=first+low*0x4c
    local packed=shared.a11y.menu_read(record+0x48,"u32")
    if not packed or packed%512~=id then return nil end
    local text=shared.a11y.read_native_c_string(record,0x48)
    return text and text~="" and shared.clean_text(text) or nil
end

function shared.a11y.native_country_selection()
    local base=tonumber(shared.process_base_u64)
    local snapshot=shared.a11y.native_windows
    if not base or not snapshot then return nil end
    local work=shared.a11y.render_read_work
    if work and work.country_selection~=nil then return work.country_selection or nil end
    local found
    for _,window in ipairs(snapshot.windows or {}) do
        local at=window.address
        local vt=window.enabled and shared.a11y.menu_read(at,"u64")
        if vt==base+0x271f4d0 and shared.a11y.menu_read(vt+0xd8,"u64")==base+0xc9d990
                and shared.a11y.menu_read(vt+0x268,"u64")==base+0xc97190
                and shared.a11y.menu_read(at+0x9b,"u8")==1 then
            local first,last=shared.a11y.menu_read(at+0x100,"u64"),shared.a11y.menu_read(at+0x108,"u64")
            local scroll,index=shared.a11y.menu_read(at+0x118,"u32"),shared.a11y.menu_read(at+0x11c,"u32")
            if first and first>=0x10000 and last and last>=first and (last-first)%0x70==0
                    and last-first<=512*0x70 and scroll and index and scroll+index<(last-first)/0x70 then
                local parent=first+(scroll+index)*0x70
                local special=shared.a11y.menu_read(at+0x180,"u8")
                local category=shared.a11y.menu_read(parent,"u32")
                local text,record
                if special==0 and category and category<=4 then
                    local id,cell=shared.a11y.filtered_country_id(at,parent)
                    text,record=id and shared.a11y.country_name(id),cell
                elseif special~=nil then
                    local children,finish=shared.a11y.menu_read(parent+8,"u64"),shared.a11y.menu_read(parent+0x10,"u64")
                    local offset,selected=shared.a11y.menu_read(parent+0x64,"u32"),shared.a11y.menu_read(parent+0x68,"u32")
                    if children and children>=0x10000 and finish and finish>=children and (finish-children)%0x50==0
                            and finish-children<=512*0x50 and offset and selected and offset+selected<(finish-children)/0x50 then
                        record=children+(offset+selected)*0x50
                        text=shared.a11y.read_msvc_string(record+0x28)
                    end
                end
                if text and not shared.a11y.empty_selection_caption(text) then
                    if found then return nil end
                    found={text=text,native_only=true,
                        identity="country:" .. at .. ":" .. window.root .. ":" .. parent .. ":" .. record}
                end
            end
        end
    end
    if work then work.country_selection=found or false end
    return found
end

function shared.a11y.poll_native_country_selection()
    local context=shared.a11y.read_context_state()
    if context.kind=="dialog" and (context.structural_question or context.structural_event or not shared.a11y.native_country_active()) then return end
    local item=shared.a11y.native_list_selection
    local current=shared.a11y.native_country_selection()
    if current then
        if current.native_only then
            if not item or item.identity~=current.identity or item.text~=current.text then
                shared.a11y.native_list_selection={text=current.text,identity=current.identity,native_only=true,observed=shared.frame}
            end
        else shared.a11y.observe_native_list_selection(current.text,current.identity,current.widget) end
        shared.a11y.native_list_selection.country=true
    elseif shared.a11y.native_list_selection and shared.a11y.native_list_selection.country then
        shared.a11y.native_list_selection=nil
    end
end

function shared.a11y.native_list_delivery_allowed(origin)
    local item=shared.a11y.native_list_selection
    if item and item.country then
        local current=shared.a11y.native_country_selection()
        if not current or current.identity~=item.identity or current.text~=item.text then return false end
        if item.native_only then
            return item.identity==origin.identity and item.text==origin.text and shared.a11y.native_owner_token()==origin.owner
        end
    end
    return item and item.identity==origin.identity and item.text==origin.text
        and item.widget==origin.widget and shared.a11y.native_owner_token()==origin.owner
end

function shared.a11y.native_country_active()
    local base=tonumber(shared.process_base_u64)
    if not base then return false end
    for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
        if window.enabled and (window.vtable or shared.a11y.menu_read(window.address,"u64"))==base+0x271f4d0
                and shared.a11y.menu_read(window.address,"u64")==base+0x271f4d0
                and shared.a11y.menu_read(window.address+0x9b,"u8")==1 then return true end
    end
    return false
end

function shared.a11y.native_list_has_focus()
    local item=shared.a11y.native_list_selection
    if not item or not item.widget or (not item.committed and shared.frame-(item.observed or -10000)>120) then return false end
    local snapshot=shared.a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[item.widget]
    if not member or not member.active or not shared.a11y.native_presentation_ready(item.widget) then return false end
    if shared.a11y.cursor_contains(snapshot,item.widget)
            and not snapshot.selected_members[item.widget] then return false end
    return (not item.name or shared.a11y.widget_internal_name(item.widget)==item.name)
        and (not item.link or shared.a11y.ui_owner_link(item.widget)==item.link)
        and shared.a11y.read_native_rendered_text(item.widget)==item.text
end

function shared.a11y.process_native_list_focus(modal_blocked)
    local item=shared.a11y.native_list_selection
    local context=shared.a11y.read_context_state()
    if item and (item.nested or item.country) and context.kind=="dialog" and not context.structural_question and not context.structural_event
            and shared.a11y.native_country_active() then
        shared.a11y.reset_read_context("native-nested-selection")
        shared.modal_focus_hold_until_ms=0;modal_blocked=false
        shared.a11y.screen_title_hold_until_ms=0
    end
    if not item or (not item.committed and shared.frame-(item.observed or -10000)>120) or modal_blocked or shared.a11y.keyboard_window
            or shared.a11y.read_context_state().kind=="dialog" then return false end
    if item.country and item.native_only then
        local current=shared.a11y.native_country_selection()
        if not current or current.identity~=item.identity or current.text~=item.text then return false end
        local identity=(shared.a11y.native_owner_token() or "") .. ":" .. item.identity .. ":" .. item.text
        if item.committed~=identity and item.speech_status~="failed-content" then
            shared.a11y.commit_read_selection(item.text,identity,"native-list")
            local before=shared.a11y.native_speech_last
            item.attempt=(item.attempt or 0)+1
            shared.speak(item.text,true,true,"native-country:" .. identity .. ":" .. item.attempt)
            for index=before+1,shared.a11y.native_speech_last do
                shared.a11y.native_speech_queue[index].native_list={identity=item.identity,text=item.text,owner=shared.a11y.native_owner_token(),state=item}
                item.committed=identity
            end
        end
        return true
    end
    local snapshot=shared.a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[item.widget]
    if not member or not member.active or not shared.a11y.native_presentation_ready(item.widget) then return false end
    if shared.a11y.cursor_contains(snapshot,item.widget)
            and not snapshot.selected_members[item.widget] then return false end
    if (item.name and shared.a11y.widget_internal_name(item.widget)~=item.name)
            or (item.link and shared.a11y.ui_owner_link(item.widget)~=item.link) then
        shared.a11y.native_list_selection=nil;return false
    end
    -- Callbacks capture data before setters finish. Verify the actual rendered
    -- caption in the frame, then let this native component own its selection.
    local text=shared.a11y.read_native_rendered_text(item.widget)
    if text~=item.text then
        if shared.frame-item.observed>120 then shared.a11y.native_list_selection=nil;return false end
        return true -- wait; a cached old caption cannot take over
    end
    local owner=shared.a11y.native_owner_token()
    if not owner then return false end
    local identity=owner .. ":" .. item.identity .. ":" .. text
    if tonumber(ffi.C.GetTickCount64())<(shared.a11y.screen_title_hold_until_ms or 0) then return true end
    local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(item.widget)]
    if not node or node.text~=text then shared.a11y.on_observed_ui_text(item.widget,text,text,nil,true) end
    local before=shared.a11y.native_speech_last
    shared.a11y.deliver_selection_result(shared.a11y.selection_result({text=text,widget=item.widget,
        identity=identity,source="native-list"}),{interrupt=true})
    if shared.a11y.native_speech_last>before then
        item.committed=identity
        for index=before+1,shared.a11y.native_speech_last do
            shared.a11y.native_speech_queue[index].native_list={identity=item.identity,text=text,widget=item.widget,owner=owner,state=item}
        end
        log(string.format("[FLAccess] native-list-commit text=%q widget=%s",text,memory.hex(item.widget)))
    end
    return true
end

-- The league/team carousel renders nine records around its selection. At this
-- call site r13 is the visible-cell index (0..8) and r15 is the corresponding
-- data record. Cell 4 is the real selected record, independent of scroll
-- direction and of the widget addresses recycled by the UI.
function shared.m.on_list_item_render(ctx, event_id, registers)
    if shared.a11y.read_context_state().kind == "dialog" then return end
    local visible_index = tonumber(shared.read_u64(registers.r13))
    if visible_index ~= 4 then
        return
    end

    local record = tonumber(shared.read_u64(registers.r15))
    if not record or record < 0x10000 or not shared.readable(record + 0x20, 0x20) then
        return
    end

    local text = shared.a11y.read_msvc_string(record + 0x20)
    if not text or text == "" or shared.is_noninteractive_text(text) then
        return
    end
    if shared.a11y.game_plan_context == "Configurações táticas básicas"
            or shared.a11y.game_plan_context == "Basic Tactical Settings"
            or shared.a11y.game_plan_edit_contexts[shared.a11y.game_plan_context] then
        -- This renderer is shared by carousels and game-plan background
        -- lists. Tactical headings and player headings are authoritative.
        return
    end
    local formation_context = shared.a11y.game_plan_context == "Alterar formação"
        or shared.a11y.game_plan_context == "Change Formation"
    local formation_inside = text:match("%((.-)%)")
    local compact_formation = formation_inside
        and formation_inside:gsub("%s+", "") or nil
    local formation_value = (compact_formation
            and compact_formation:match("^%d[%d%-]+$"))
        or text:match("^%d[%d%-]+$")
    if shared.a11y.game_plan_active and formation_context and formation_value then
        shared.a11y.game_plan_formation_active = true
    elseif shared.a11y.game_plan_active then
        -- Both teams' formations are permanently rendered on the normal Game
        -- Plan pitch. They are display data, not the focused bottom command.
        return
    end

    -- r12 is the exact text node assigned immediately before c97408.
    shared.a11y.observe_native_list_selection(text,"list:" .. memory.hex(record),tonumber(shared.read_u64(registers.r12)))
end

-- Shared nested-carousel caption setter. Here RSI is the selected 0x50 child
-- record and RDI is its actual kind-19 text node. Capture before the setter;
-- process_native_list_focus verifies the rendered copy after it completes.
function shared.m.on_nested_list_caption(ctx,event_id,registers)
    local context=shared.a11y.read_context_state()
    if context.kind=="dialog" and (context.structural_question or context.structural_event or not shared.a11y.native_country_active()) then return end
    local record=tonumber(shared.read_u64(registers.rsi))
    local widget=tonumber(shared.read_u64(registers.rdi))
    if not record or record<0x10000 or not widget or widget<0x10000 then return end
    local text=shared.a11y.read_msvc_string(record+0x28)
    if text and not shared.a11y.empty_selection_caption(text) then
        shared.a11y.observe_native_list_selection(text,"nested-list:" .. memory.hex(record),widget)
        shared.a11y.native_list_selection.nested=true
    end
end

-- Club selection uses a separate nine-cell renderer. r14 is its visible-cell
-- index and the game itself treats cell 4 as selected. Both native and
-- alternate/modded club-name branches build the displayed MSVC string in the
-- same stack slot immediately before assigning it to the UI widget.
function shared.m.on_team_item_text(ctx, event_id, registers)
    if shared.a11y.read_context_state().kind == "dialog" then return end
    local visible_index = tonumber(shared.read_u64(registers.r14))
    if visible_index ~= 4 then
        return
    end

    local saved_rbp = tonumber(shared.read_u64(registers.rbp))
    if not saved_rbp or saved_rbp < 0x10000 then
        return
    end
    local text = shared.a11y.read_msvc_string(saved_rbp - 0x19)
    if not text or text == "" or shared.is_noninteractive_text(text) then
        return
    end
    -- Capture is passive. A retained game-plan adapter flag must not block a
    -- later team carousel; render delivery still requires current native focus.

    -- Both string branches pass this rdi node to e48bf0 after the hook.
    shared.a11y.observe_native_list_selection(text,"team:" .. text,tonumber(shared.read_u64(registers.rdi)))
end


    shared.a11y.lists_ready=true
end
component.init=component.install
return component
