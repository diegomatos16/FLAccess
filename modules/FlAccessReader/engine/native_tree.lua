function a11y.menu_read(address,kind)
    -- Hooks pass uint64_t cdata; normalize before arithmetic and table keys.
    -- LuaJIT math.floor does not accept cdata, even for a valid address.
    address=tonumber(address)
    local cache=a11y.snapshot_read_work or a11y.render_read_work
    local values=cache and cache[kind]
    local cached=values and values[address]
    if cached~=nil then return cached~=false and cached or nil end
    if cache and not values then values={};cache[kind]=values end
    local size=kind=="u64" and 8 or kind=="u8" and 1 or kind=="u16" and 2 or 4
    if not address or address<0x10000 or address>0x7fffffffffff or address%1~=0
            or not readable(address,size) then
        if values and address then values[address]=false end
        return nil
    end
    local bytes
    if cache and a11y.safe_memory_read==a11y.production_memory_read then
        local block=math.floor(address/128)*128
        if address+size<=block+128 and readable(block,128) then
            cache.blocks=cache.blocks or {}
            local data=cache.blocks[block]
            if data==nil then data=a11y.safe_memory_read(block,128) or false;cache.blocks[block]=data end
            if data then bytes=data:sub(address-block+1,address-block+size) end
        end
    end
    if not bytes then bytes=a11y.safe_memory_read(address,size) end
    local value=bytes and #bytes==size and tonumber(memory.unpack(kind,bytes)) or nil
    if values then values[address]=value or false end
    return value
end

-- Immutable native schemas: shared by every traversal, never inferred from text.
a11y.native_layout = {
    holder_trees = {{8,0x30},{0x88,0x40},{0x78,0x40}},
    containers = {[0x27bae88]=true,[0x27cb508]=true,[0x27b6490]=true,
        [0x27b8d60]=true,[0x27cb298]=true},
    holders = {[0x27bae88]=true,[0x27cb508]=true,[0x27b6490]=true,
        [0x27b8d60]=true,[0x27cb298]=true,[0x27cbc08]=true,[0x27cbe98]=true},
}

-- NodeRectHolder dispatch walks three MSVC trees, not the indexed vector.
-- e4db00 visits +8; the full e4dbd0 also visits +0x88 AND +0x78.
-- Only callers with RTTI-proven holder layout may supply this address.
function a11y.menu_holder_children(holder)
    local children, seen_children = {}, {}
    for _, spec in ipairs(a11y.native_layout.holder_trees) do
        local head = a11y.menu_read(holder+spec[1], "u64")
        if head and head >= 0x10000 and a11y.menu_read(head+0x19,"u8") == 1 then
            local root = a11y.menu_read(head+8,"u64")
            local stack, visited, count = {root}, {}, 0
            while #stack > 0 and count < 256 do
                local at = table.remove(stack)
                if at and at >= 0x10000 and at ~= head and not visited[at] then
                    visited[at], count = true, count+1
                    if a11y.menu_read(at+0x19,"u8") == 0 then
                        local child = a11y.menu_read(at+spec[2],"u64")
                        if child and child >= 0x10000 and not seen_children[child] then
                            seen_children[child] = true
                            children[#children+1] = child
                        end
                        local left = a11y.menu_read(at,"u64")
                        local right = a11y.menu_read(at+0x10,"u64")
                        if left and left >= 0x10000 then stack[#stack+1] = left end
                        if right and right >= 0x10000 then stack[#stack+1] = right end
                    end
                end
            end
        end
    end
    return children
end

function a11y.has_owned_node_delegate(vtable,base)
    if not vtable then return false end
    local getter=a11y.menu_read(vtable+0x88,"u64")
    return (getter==base+0xe8ecd0 or getter==base+0xe546a0)
        and a11y.menu_read(vtable+0x28,"u64")==base+0xe8ecb0
end

function a11y.scan_menu_tree(root, base)
    local members, visited, queue, cursor, parents = {}, {}, {root}, 1, {}
    local queued,limit = {[root]=true},2048
    local truncated=false
    local function enqueue(child,parent)
        if not child or child<0x10000 or queued[child] then return end
        if #queue>=limit then truncated=true;return end
        queued[child],parents[child]=true,parent
        queue[#queue+1]=child
    end
    local frontier = {}
    -- RTTI-proven NodeBasicNodeBase and inline NodeRectHolder layouts.
    -- NodeRectText and arbitrary NodeRect subclasses do not share these.
    local containers, holders = a11y.native_layout.containers, a11y.native_layout.holders
    while cursor <= #queue do
        local node = queue[cursor]
        cursor = cursor + 1
        if not visited[node] then
            visited[node] = true
            local vtable = a11y.menu_read(node, "u64")
            if vtable then
                local rva = vtable - base
                if rva == 0x27b5260 or rva == 0x27c3a38 then members[node] = true end
                -- NodeWindow forwards native state/event calls to +0x190.
                -- NodeCursor resolves its choices from the parent at +0x88.
                -- Follow these typed links too; its flat child vector can be empty.
                local linked = rva == 0x27b6490 and a11y.menu_read(node+0x190,"u64")
                    or rva == 0x27c1ac0 and a11y.menu_read(node+0x88,"u64")
                -- PartsNormalBase forwards events/state to the NODE pointed
                -- to by +98 (e8ecd0/e8ecb0). This is not an inline holder.
                -- Verify both virtual methods before following that layout:
                -- selectors, LR switches, help boxes and player cards share it.
                if not linked then
                    -- e546a0 is an unconditional jump to e8ecd0. Headline
                    -- and slider nodes use this same +98 delegate contract.
                    if a11y.has_owned_node_delegate(vtable,base) then
                        linked=a11y.menu_read(node+0x98,"u64")
                    end
                end
                enqueue(linked,node)
                if not linked and not holders[rva] and not containers[rva]
                        and rva~=0x27b5260 and rva~=0x27c3a38 and #frontier<6 then
                    frontier[#frontier+1]={address=node,rva=rva}
                end
                if holders[rva] then
                    for _, child in ipairs(a11y.menu_holder_children(node+0x98)) do
                        enqueue(child,node)
                    end
                end
                if containers[rva] then
                    local first = a11y.menu_read(node + 0x170, "u64")
                    local last = a11y.menu_read(node + 0x178, "u64")
                    if first and last and first >= 0x10000 and last >= first
                            and (last - first) % 8 == 0 and last - first <= 2048 then
                        for at = first, last - 8, 8 do
                            local child = a11y.menu_read(at, "u64")
                            enqueue(child,node)
                        end
                    end
                end
            end
        end
    end
    return members, parents, {visited=cursor-1,queued=#queue,at_capacity=truncated,frontier=frontier}
end

-- Reuse identical traversals only within one synchronous window snapshot.
-- No object or field cache survives to another callback/frame.
function a11y.menu_tree(root,base)
    local cache=a11y.snapshot_tree_work
    local entry=cache and cache[root]
    if entry and entry.base==base then
        local parents={}
        for at,parent in pairs(entry.parents) do parents[at]=parent end
        return entry.members,parents,entry.evidence
    end
    local members,parents,evidence=a11y.scan_menu_tree(root,base)
    if not cache then return members,parents,evidence end
    if cache then
        -- Cursor readers add parent links; give each caller its own map.
        cache[root]={base=base,members=members,parents=parents,evidence=evidence}
    end
    local copy={}
    for at,parent in pairs(parents) do copy[at]=parent end
    return members,copy,evidence
end

function a11y.menu_child(container, index)
    if not container or not index or index < 0 or index >= 256 then return nil end
    local first = a11y.menu_read(container + 0x170, "u64")
    local last = a11y.menu_read(container + 0x178, "u64")
    if not first or not last or first < 0x10000 or last < first
            or (last-first)%8 ~= 0 or last-first > 2048 or index >= (last-first)/8 then return nil end
    return a11y.menu_read(first + index * 8, "u64")
end

function a11y.menu_cursor_texts(root, base)
    local cursor = a11y.menu_read(root + 0x190, "u64")
    local detail = {root=root,cursor=cursor,
        cursor_type=cursor and a11y.menu_read(cursor,"u64"),status="unknown-delegate"}
    if not cursor or detail.cursor_type ~= base + 0x27c1ac0 then return nil,detail end
    local parent = a11y.menu_read(cursor + 0x88, "u64")
    detail.parent,detail.group_index,detail.item_index = parent,
        a11y.menu_read(cursor+0x90,"u32"),a11y.menu_read(cursor+0x94,"u32")
    local group = a11y.menu_child(parent, detail.group_index)
    local selected = group and a11y.menu_child(group, detail.item_index)
    detail.group,detail.selected = group,selected
    detail.selected_type = selected and a11y.menu_read(selected,"u64")
    if not selected or selected < 0x10000 then
        detail.status = group and "missing-item" or "missing-group"
        return nil,detail
    end
    local members,parents = a11y.menu_tree(selected, base)
    parents[selected],parents[group]=group,parent
    detail.parents=parents
    detail.status = "no-text"
    for _ in pairs(members) do detail.status="resolved"; return members,detail end
    -- Some cursor groups select icons and render their current caption as a
    -- direct text child of the group (8f0366..8f03f2), outside the icon subtree.
    -- Only one live, non-decorative sibling can supply that shared caption.
    local group_members,group_parents=a11y.menu_tree(group,base)
    local caption
    for address in pairs(group_members) do
        if group_parents[address]==group and a11y.menu_node_active(address,base)==true
                and a11y.widget_internal_name(address)~="padIcon" then
            local text=a11y.read_native_rendered_text(address)
            if text and not a11y.empty_selection_caption(text) and not text:match("^%d+$")
                    and not a11y.unresolved_format(text) and not is_noninteractive_text(text) then
                if caption then return nil,detail end
                caption=address
            end
        end
    end
    if caption then
        detail.shared_caption,detail.status=caption,"shared-caption"
        detail.parents[caption]=group
        return {[caption]=true},detail
    end
    return nil,detail
end

function a11y.cursor_caption_identity(window,detail)
    if window.impl then
        local flags=a11y.menu_read(window.impl+9,"u8")
        if a11y.menu_read(window.address+0x88,"u64")~=window.impl or not flags or flags%2~=1
                or a11y.menu_read(window.impl+0x98,"u64")~=window.root then return nil end
    end
    if detail.cursor and detail.cursor>=0x10000 then
        local parent=a11y.menu_read(detail.cursor+0x88,"u64")
        local group_index=a11y.menu_read(detail.cursor+0x90,"u32")
        local item_index=a11y.menu_read(detail.cursor+0x94,"u32")
        local group=parent and group_index and a11y.menu_child(parent,group_index)
        local selected=group and item_index and a11y.menu_child(group,item_index)
        if a11y.menu_read(window.root+0x190,"u64")~=detail.cursor
                or group~=detail.group or selected~=detail.selected or item_index~=detail.item_index then return nil end
    end
    return table.concat({window.address,window.root,detail.group,detail.selected,detail.item_index or -1},":")
end

-- SelectBase and ParameterPlayerInfo share a side/Task relationship. The
-- selected card is image-only; the native parameter panel supplies its name.
-- Recognize the shared controller methods, not a translated screen title.
function a11y.parameter_caption_variant(node,owner,base)
    if not node or not owner or not owner.parents then return nil end
    local at,seen=tonumber(node.address),{}
    for _=1,12 do
        if not at or seen[at] or at==owner.root then break end
        seen[at]=true
        local name=a11y.widget_internal_name(at)
        for index=0,1 do
            local pointer=a11y.menu_read(base+0x34a2048+index*8,"u64")
            if pointer and pointer>=0x10000 and name==a11y.read_native_c_string(pointer,64) then return index end
        end
        at=owner.parents[at]
    end
end

-- The SelectBase cursor points at the actual roster card. Compare that
-- pointer to Pitch/PitchSubstitute's native card arrays, not panel order.
function a11y.cursor_player_target(window,detail,side,snapshot,base)
    local data=a11y.menu_read(base+0x36f38a0,"u64")
    if not data or a11y.menu_read(data,"u64")~=base+0x2618830 then return nil end
    local found
    for _,roster in ipairs(snapshot.windows or {}) do
        local vt=roster.enabled and a11y.menu_read(roster.address,"u64")
        local pitch,subs=vt==base+0x261eaa0,vt==base+0x261f788
        if (pitch or subs) and roster.task_parent==window.task_parent
                and a11y.menu_read(roster.address+0x98,"u32")==side then
            local scroll=pitch and 0 or a11y.menu_read(roster.address+0x4e8,"u32")
            if scroll and scroll<=29 then
                for index=0,(pitch and 10 or 11) do
                    local card=a11y.menu_read(roster.address+0xb8+index*8,"u64")
                    local selection=a11y.menu_read(roster.address+0x118+index*8,"u64")
                    -- SelectBase's native groups are pitch(0,11 entries)
                    -- and substitutes(1,12 visible entries). Its copied image
                    -- cards need not share the Pitch presentation pointers.
                    local indexed=detail.group_index==(pitch and 0 or 1) and detail.item_index==index
                    if card==detail.selected or selection==detail.selected or indexed then
                        local slot=pitch and index or index+scroll+11
                        local record=a11y.menu_read(roster.address+0x2a0+index*4,"u32")
                        local order=slot<40 and a11y.menu_read(data+side*0x248+0x1f8+slot,"u8")
                        local shown=a11y.menu_read(detail.selected+0xc,"u32")
                        if slot<40 and record and record<40 and order==record and shown and shown%8==7 then
                            local object=a11y.menu_read(data+side*0x340+0x568+record*16,"u64")
                            local id=object and object>=0x10000 and a11y.menu_read(object+0x30,"u32")
                            local name=id and id>0 and a11y.read_native_c_string(object+0x38,64)
                            if name and #name>=2 and not name:find("%c") then
                                local current={data=data,slot=slot,side=side,record=record,object=object,id=id,name=name}
                                if found and (found.slot~=slot or found.id~=id) then return nil end
                                found=current
                            end
                        end
                    end
                end
            end
        end
    end
    return found
end

function a11y.parameter_caption_matches_target(node,variant,side,target)
    if variant==nil then return false end
    local descriptor=target.data+0xba4+side*0xa8+variant*20
    local slot=a11y.menu_read(descriptor,"u32")
    local player_side=a11y.menu_read(descriptor+4,"u32")
    local name=a11y.normalized_player_name(node.text)
    return slot==target.slot and player_side==target.side and name
        and name:sub(1,#target.name)==target.name
end

function a11y.controlled_player_caption(node,snapshot,base)
    if not node or node.name~="playerName" or not snapshot or not snapshot.members then return nil end
    local member=snapshot.members[tonumber(node.address)]
    if not member or not member.active or a11y.menu_node_active(node.address,base)~=true
            or not a11y.ui_node_matches_live(node) or a11y.read_native_rendered_text(node.address)~=node.text
            or a11y.empty_selection_caption(node.text) then return nil end
    local windows={}
    for _,window in ipairs(snapshot.windows or {}) do windows[window.address]=window end
    local result
    for _,owner in ipairs(member.owners or {}) do
        local panel=windows[owner.address]
        local vt=panel and panel.enabled and a11y.menu_read(panel.address,"u64")
        if owner.enabled and vt==base+0x261e0c8 and panel.task_parent then
            local unique=0
            local variant=a11y.parameter_caption_variant(node,owner,base)
            for _,other in pairs(a11y.ui_model.names.playerName or {}) do
                local other_member=snapshot.members[tonumber(other.address)]
                if other_member and other_member.active and a11y.menu_node_active(other.address,base)==true then
                    for _,other_owner in ipairs(other_member.owners or {}) do
                        if other_owner.enabled and other_owner.address==panel.address then
                            unique=unique+1
                            break
                        end
                    end
                end
            end
            local side=a11y.menu_read(panel.address+0x98,"u32")
            if side==0 or side==1 then
                for _,window in ipairs(snapshot.windows) do
                    local d=window.cursor_detail
                    local controller=window.enabled and a11y.menu_read(window.address,"u64")
                    if controller and d and d.status=="no-text" and d.group and d.selected
                            and window.task_parent==panel.task_parent
                            and a11y.menu_read(window.address+0x98,"u32")==side
                            and a11y.menu_read(controller+0x100,"u64")==base+0x917a40
                            and a11y.menu_read(controller+0x1a0,"u64")==base+0x917ee0 then
                        local target=a11y.cursor_player_target(window,d,side,snapshot,base)
                        local matches=target and a11y.parameter_caption_matches_target(node,variant,side,target)
                        -- A single panel remains the existing normal-navigation
                        -- fallback. Multiple panels require exact cursor proof.
                        local eligible=target and matches or (not target and unique==1)
                        if eligible and target and matches and variant==0 then
                            -- Source and candidate may refer to the SAME
                            -- player when returning over the original card.
                            -- Collapse aliases only after both IDs/slots agree.
                            for _,other in pairs(a11y.ui_model.names.playerName or {}) do
                                local other_member=snapshot.members[tonumber(other.address)]
                                for _,other_owner in ipairs(other_member and other_member.owners or {}) do
                                    if other_owner.enabled and other_owner.address==panel.address
                                            and a11y.parameter_caption_variant(other,other_owner,base)==1
                                            and a11y.parameter_caption_matches_target(other,1,side,target) then eligible=false end
                                end
                            end
                        end
                        local cursor_identity=eligible and a11y.cursor_caption_identity(window,d)
                        if cursor_identity then
                            local identity=cursor_identity .. ":panel=" .. panel.address .. ":side=" .. side
                            if result and result.identity~=identity then return nil end
                            result={identity=identity,window=window.address,panel=panel.address,side=side}
                        end
                    end
                end
            end
        end
    end
    return result
end

function a11y.bind_controlled_player_captions(snapshot,base)
    for address in pairs(snapshot.controlled_selections or {}) do
        snapshot.selected_members[address],snapshot.cursor_members[address]=nil,nil
    end
    snapshot.controlled_selections={}
    for _,node in pairs(a11y.ui_model and a11y.ui_model.names.playerName or {}) do
        local binding=a11y.controlled_player_caption(node,snapshot,base)
        if binding then
            local address=tonumber(node.address)
            snapshot.selected_members[address],snapshot.cursor_members[address]=true,true
            snapshot.controlled_selections[address]=binding
            -- Other fields in this controlled panel are presentation, not
            -- additional choices created by propagated text focus events.
            for other,member in pairs(snapshot.members) do
                for _,owner in ipairs(member.owners or {}) do
                    if owner.address==binding.panel then snapshot.cursor_members[other]=true;break end
                end
            end
        end
    end
end

function a11y.native_caption_selection_identity(address)
    local snapshot=a11y.native_windows
    local binding=snapshot and snapshot.controlled_selections and snapshot.controlled_selections[tonumber(address)]
    if binding then
        local node=a11y.ui_model and a11y.ui_model.nodes[memory.hex(address)]
        local current=a11y.controlled_player_caption(node,snapshot,tonumber(process_base_u64))
        return current and current.identity
    end
    for _,window in ipairs(snapshot and snapshot.windows or {}) do
        local d=window.cursor_detail
        if window.enabled and d and d.shared_caption==tonumber(address) then return a11y.cursor_caption_identity(window,d) end
    end
end

-- Shared NodeRectText event dispatcher. Record only; speech runs next frame.
function m.on_ui_focus_event(ctx,event_id,registers)
    local base=tonumber(process_base_u64)
    if not base then return end
    local address=tonumber(read_u64(registers.rcx))
    local event=tonumber(read_u64(registers.rdx))
    local table_start=a11y.menu_read(base+0x36f9c28,"u64")
    local table_end=a11y.menu_read(base+0x36f9c30,"u64")
    if not table_start or not table_end or table_start < 0x10000
            or table_end-table_start < 16*8 or table_end-table_start > 4096 then return end
    local signature=a11y.menu_read(event,"u64")
    if not signature or signature == 0 then return end
    local entering=signature==a11y.menu_read(table_start+15*8,"u64")
    local leaving=signature==a11y.menu_read(table_start+14*8,"u64")
    if not entering and not leaving then return end
    if a11y.menu_read(address,"u64") ~= base+0x27b5260 then return end
    a11y.record_engine_focus(address,entering)
end

function a11y.record_engine_focus(address,entering)
    local owner=a11y.native_owner_token()
    local state=a11y.engine_focus
    if not entering and (not state or state.owner ~= owner) then return end
    if not state or state.owner ~= owner then
        state={owner=owner,nodes={},count=0,sequence=0}
        a11y.engine_focus=state
    end
    local key=memory.hex(address)
    if not entering then
        if state.nodes[key] then state.nodes[key]=nil; state.count=state.count-1 end
        return
    end
    if not state.nodes[key] and state.count >= 128 then return end
    if not state.nodes[key] then state.count=state.count+1 end
    local previous=state.nodes[key]
    state.sequence=state.sequence+1
    state.nodes[key]={address=address,frame=frame,
        edge=previous and previous.edge or frame,
        sequence=previous and previous.sequence or state.sequence}
    if not previous then
        log("[FLAccess] engine-focus-enter frame=" .. tostring(frame)
            .. " widget=" .. key .. " owner=" .. tostring(owner))
    end
end

function a11y.ui_node_matches_live(node)
    if not node then return false end
    local name=a11y.widget_internal_name(node.address)
    local link=a11y.ui_owner_link(node.address)
    -- A resource link is not window ownership, but a changed link/name proves
    -- that the cached caption no longer describes this same native object.
    if (name and node.name and name ~= node.name)
            or (link and node.owner_link and link ~= node.owner_link) then
        log("[FLAccess] engine-focus-recycled widget=" .. node.key)
        a11y.forget_ui_widget(node.key)
        return false
    end
    return true
end

function a11y.window_cursor_anchor(window)
    local detail=window and window.enabled and window.cursor_detail
    if not detail or not detail.group or not detail.selected then return nil end
    return {window=window.address,token=table.concat({window.address,window.root or 0,
        detail.group,detail.selected,detail.group_index or -1,detail.item_index or -1},":")}
end

function a11y.selection_cursor_anchor(key)
    local snapshot=a11y.native_windows
    local node=a11y.ui_model and a11y.ui_model.nodes[key]
    if not snapshot or not node then return nil end
    local controlled=snapshot.controlled_selections and snapshot.controlled_selections[tonumber(node.address)]
    local member=snapshot.members and snapshot.members[tonumber(node.address)]
    local found
    for _,window in ipairs(snapshot.windows or {}) do
        local detail=window.cursor_detail
        local owns=controlled and controlled.window==window.address
            or detail and detail.shared_caption==tonumber(node.address)
        if not owns and snapshot.selected_members and snapshot.selected_members[tonumber(node.address)] then
            for _,owner in ipairs(member and member.owners or {}) do
                if owner.enabled and owner.address==window.address then owns=true end
            end
        end
        local anchor=owns and a11y.window_cursor_anchor(window)
        if anchor then
            if found and found.token~=anchor.token then return nil end
            found=anchor
        end
    end
    return found
end

function a11y.release_moved_engine_selection(state)
    local previous=state and state.last_anchor
    if not previous then return end
    for _,window in ipairs(a11y.native_windows and a11y.native_windows.windows or {}) do
        if window.address==previous.window then
            local current=a11y.window_cursor_anchor(window)
            if current and current.token~=previous.token then
                local context=a11y.read_context_state()
                local result=context.selection_result
                local row=a11y.control_for_widget(state.last_key)
                if context.kind~="dialog" and result and (result.key==state.last_key or (row and result.row==row)) then
                    context.selection_result,context.selection=nil,nil
                end
                state.last_identity,state.last_anchor,state.last_key=nil,nil,nil
                a11y.reset_focus_reuse_state()
            end
            return
        end
    end
end

function a11y.engine_focus_candidates()
    local state=a11y.engine_focus
    local snapshot=a11y.native_windows
    local cursor_keys={}
    for address in pairs(snapshot and snapshot.selected_members or {}) do
        cursor_keys[#cursor_keys+1]=memory.hex(address)
    end
    table.sort(cursor_keys)
    local cursor_identity=table.concat(cursor_keys,",")
    for _,key in ipairs(cursor_keys) do
        local node=a11y.ui_model and a11y.ui_model.nodes[key]
        local binding=node and a11y.native_caption_selection_identity(node.address)
        if binding then cursor_identity=cursor_identity .. ":caption=" .. binding end
    end
    local owner=a11y.native_owner_token()
    if state and state.owner ~= owner then state=nil; a11y.engine_focus=nil end
    if not state and #cursor_keys>0 then
        state={owner=owner,nodes={},count=0,sequence=0}
        a11y.engine_focus=state
    end
    if not state then return nil end
    a11y.release_moved_engine_selection(state)
    local old_cursors=state.cursor_nodes or {}
    local current_cursors={}
    for _,key in ipairs(cursor_keys) do
        local node=a11y.ui_model and a11y.ui_model.nodes[key]
        local binding=node and a11y.native_caption_selection_identity(node.address)
        local token=(binding or key) .. ":" .. (node and node.text or "")
        current_cursors[key]={token=token,edge=old_cursors[key]
            and old_cursors[key].token==token and old_cursors[key].edge or frame}
    end
    for key in pairs(old_cursors) do
        if not current_cursors[key] and state.nodes[key] and state.nodes[key].cursor then
            state.nodes[key]=nil;state.count=state.count-1
        end
    end
    state.cursor_identity,state.cursor_nodes=cursor_identity,current_cursors
    for _,key in ipairs(cursor_keys) do
        local node=a11y.ui_model and a11y.ui_model.nodes[key]
        if node then
            if not state.nodes[key] then state.count=state.count+1 end
            state.nodes[key]={address=node.address,frame=frame,edge=current_cursors[key].edge,
                cursor=true,sequence=state.sequence}
        end
    end
    local candidates={}
    local owners=a11y.command_icon_owners()
    local pending_label=#cursor_keys>0
    for key,event in pairs(state.nodes) do
        -- Exclude recycled/background nodes; never decode captions in the hook.
        local node=a11y.ui_model and a11y.ui_model.nodes[key]
        local row=a11y.control_for_widget(key)
        -- Numeric values remain valid when linked to an observed control; bare
        -- glyph/counter nodes and controller-icon captions are not menu choices.
        local value_member=row and node and row.value_widget_key==key and row.value==node.text
        local decoration=node and (node.name=="padIcon" or node.name=="abilityNumber"
            or a11y.is_media_caption(node) or a11y.is_menu_description(node)
            or (node.name and node.name:match("_value") and not (row and row.is_control
                and (row.native_field or row.structural or row.native_slider)))
            or (node.text and (node.text:match("^%d+$") or a11y.empty_selection_caption(node.text)) and not value_member))
        local cursor_scope=snapshot and snapshot.cursor_members
        local cursor_allowed=not cursor_scope or not cursor_scope[tonumber(event.address)]
            or snapshot.selected_members[tonumber(event.address)]
        if cursor_allowed and node and node.text and node.text ~= "" and not decoration
                and a11y.ui_node_matches_live(node)
                and a11y.native_widget_allowed(event.address)
                and not is_noninteractive_text(node.text)
                and not a11y.is_command_legend(key,true,owners)
                and not looks_like_message(node.text,event.address)
                and (not a11y.is_control_help(node.text) or a11y.is_structural_answer(node.text,key))
                and not a11y.unresolved_format(node.text) then
            state.accepted=true
            if event.cursor or frame>event.edge then candidates[#candidates+1]={key=key,edge=event.edge} end
        elseif (not node or not node.text or node.text=="") and frame-event.edge <= 30 then
            pending_label=true
        end
    end
    -- A title/paragraph event alone does not establish menu-selection authority.
    if not state.accepted and not pending_label then return nil end
    -- The native dispatcher focuses a whole compound row. In the common
    -- text_item/infoText_* schema, the information slots share its resource
    -- link and event edge, but are not independent choices. Preserve model
    -- data; only collapse a proven sibling packet, never matching captions.
    local primary={}
    for _,candidate in ipairs(candidates) do
        local node=a11y.ui_model.nodes[candidate.key]
        if node.name=="text_item" and node.owner_link then
            local packet=tostring(node.owner_link) .. ":" .. tostring(candidate.edge)
            primary[packet]=(primary[packet] or 0)+1
        end
    end
    local filtered={}
    for _,candidate in ipairs(candidates) do
        local node=a11y.ui_model.nodes[candidate.key]
        local packet=node.owner_link and (tostring(node.owner_link) .. ":" .. tostring(candidate.edge))
        local detail=false
        if node.name=="noSetting" or node.name=="allOver" then
            local labels=0
            for _,other in ipairs(candidates) do
                local label=a11y.ui_model.nodes[other.key]
                if other.edge==candidate.edge and label.name=="playerName" then
                    for _,part in ipairs(a11y.player_row_details(label)) do
                        if part==node then labels=labels+1 end
                    end
                end
            end
            detail=labels==1
        end
        if node.name=="description" or (node.name and node.name:match("^description_%d+$")) then
            local labels=0
            for _,other in ipairs(candidates) do
                local label=a11y.ui_model.nodes[other.key]
                if other.edge==candidate.edge and (label.role=="control-label" or label.name=="item" or label.name=="itemName")
                        and a11y.component_peers(node.address,label.address)==true then labels=labels+1 end
            end
            detail=labels==1
        end
        if not detail and not (node.name and node.name:match("^infoText_")
                and packet and primary[packet]==1) then filtered[#filtered+1]=candidate end
    end
    candidates=filtered
    local music,artists={},{}
    for _,candidate in ipairs(candidates) do
        local packet=a11y.native_music_packet(a11y.ui_model.nodes[candidate.key])
        if packet and packet.artist then music[candidate.key]=packet;artists[packet.artist.key]=candidate end
    end
    filtered={}
    for _,candidate in ipairs(candidates) do
        local packet=music[candidate.key]
        if packet and packet.artist then
            for _,other in ipairs(candidates) do
                if other.key==packet.artist.key then candidate.edge=math.max(candidate.edge,other.edge) end
            end
        end
        if not artists[candidate.key] then filtered[#filtered+1]=candidate end
    end
    candidates=filtered
    local pause=a11y.native_pause_context()
    if pause and a11y.read_context_state().kind~="dialog" then
        local base=tonumber(process_base_u64)
        local has_navigation,navigation_members,passive=false,{},{}
        for _,candidate in ipairs(candidates) do
            local node=a11y.ui_model.nodes[candidate.key]
            local member=snapshot and snapshot.members[tonumber(node.address)]
            for _,owner in ipairs(member and member.owners or {}) do
                if owner.enabled then
                    if owner.address==pause.window and owner.root==pause.root then
                        has_navigation=true;navigation_members[candidate.key]=true
                    end
                    local vt=base and a11y.menu_read(owner.address,"u64")
                    -- MatchStatsMenuContentTeamStats owns the teamRecord
                    -- captions. Its displayed cursor is not pause navigation.
                    if vt and a11y.menu_read(vt+0x18,"u64")==base+0x4eb1c0
                            and a11y.menu_read(vt+0x100,"u64")==base+0xca1a50 then
                        passive[candidate.key]=true
                    end
                end
            end
        end
        if has_navigation then
            local scoped={}
            for _,candidate in ipairs(candidates) do
                if not passive[candidate.key] or navigation_members[candidate.key] then scoped[#scoped+1]=candidate end
            end
            candidates=scoped
        end
    end
    return candidates
end

function a11y.process_engine_focus(modal_blocked)
    if a11y.native_information_context() and not a11y.keyboard_window
            and a11y.read_context_state().kind~="dialog" then return true end
    if a11y.process_native_list_focus(modal_blocked) then return true end
    local candidates=a11y.engine_focus_candidates()
    if not candidates then return false end -- Existing adapters remain a fallback.
    if a11y.keyboard_window then return true end
    for _,candidate in ipairs(candidates) do
        if a11y.capture_reading_panel(a11y.ui_model.nodes[candidate.key]) then return true end
    end
    if a11y.process_read_dialog_focus(candidates) then return true end
    local selected,reason=a11y.resolve_primary_focus(candidates)
    if not selected then
        local keys={}
        for _,candidate in ipairs(candidates) do keys[#keys+1]=candidate.key end
        table.sort(keys)
        local unresolved=reason .. ":" .. table.concat(keys,",")
        if unresolved ~= a11y.engine_focus.unresolved then
            a11y.engine_focus.unresolved=unresolved
            log("[FLAccess] engine-focus-unresolved reason=" .. reason .. " widgets=" .. table.concat(keys,","))
            local state=a11y.engine_focus
            state.gap_count=(state.gap_count or 0)+1
            if state.gap_count<=40 then
                local events={}
                for key,event in pairs(state.nodes) do events[#events+1]={key=key,event=event} end
                table.sort(events,function(a,b)
                    if a.event.edge~=b.event.edge then return a.event.edge>b.event.edge end
                    return a.key<b.key
                end)
                local parts={}
                for index,item in ipairs(events) do
                    if index>8 then break end
                    local node=a11y.ui_model and a11y.ui_model.nodes[item.key]
                    if node then a11y.component_evidence(node,"focus-" .. reason) end
                    parts[#parts+1]=string.format("%s name=%q text=%q edge=%s flags=%s",
                        item.key,(node and node.name) or a11y.widget_internal_name(item.event.address) or "",
                        node and node.text or "",tostring(item.event.edge),
                        tostring(a11y.menu_read(item.event.address+0xc,"u32")))
                end
                log("[FLAccess] engine-focus-gap " .. table.concat(parts," | "))
            end
        end
        -- An empty/ambiguous frame is not a new selection. Keep the last
        -- committed identity through construction and propagation bursts.
        return true -- Wait for a label/settled selection, rather than old flags.
    end
    local node=a11y.ui_model.nodes[selected.key]
    a11y.engine_focus.unresolved=nil
    local event=a11y.engine_focus.nodes[selected.key]
    if not event then return true end
    -- A field keeps focus while its value changes. The value belongs in the
    -- spoken-state identity, even when no new selection event was dispatched.
    local row=a11y.control_for_widget(selected.key)
    local identity=a11y.engine_selection_identity(selected.key,node)
    if modal_blocked and event.edge <= modal_message_spoken_frame+2 then return true end
    local now=tonumber(ffi.C.GetTickCount64())
    if now < (a11y.screen_title_hold_until_ms or 0) then return true end
    a11y.track_control_focus(selected.key)
    local last_result=a11y.read_context_state().selection_result
    if a11y.engine_focus.last_identity==identity and not (last_result
            and (last_result.status=="discarded" or last_result.status=="failed")) then return true end
    local queue_before=a11y.native_speech_last
    if row and row.is_control then
        announce_control(row)
    else
        a11y.deliver_selection_result(a11y.selection_result({node=node,widget=node.address,
            identity=identity,source="engine-focus"}),{interrupt=true})
    end
    if a11y.native_speech_last==queue_before then
        -- The text-update path may already have delivered this same field.
        -- Record its current state only if control dedupe confirms delivery;
        -- a modal/presentation hold must still retry.
        if row and last_announced_control_row==row and last_controller_announcement==control_speech(row) then
            a11y.engine_focus.last_identity=identity
            a11y.engine_focus.last_key=selected.key
            a11y.engine_focus.last_anchor=a11y.selection_cursor_anchor(selected.key)
        end
        return true
    end
    a11y.engine_focus.last_identity=identity
    a11y.engine_focus.last_key=selected.key
    a11y.engine_focus.last_anchor=a11y.selection_cursor_anchor(selected.key)
    for index=queue_before+1,a11y.native_speech_last do
        a11y.native_speech_queue[index].engine_focus={owner=a11y.engine_focus.owner,
            key=selected.key,identity=identity}
    end
    if a11y.ui_model then a11y.ui_model.focus_reason="engine-event:" .. reason end
    log("[FLAccess] engine-focus-commit widget=" .. selected.key .. " identity=" .. identity
        .. " source=" .. (event.cursor and "native-cursor" or "native-event"))
    return true
end

function a11y.reading_selection_delivery_allowed(origin)
    local context=a11y.read_context
    return context and context.generation==origin.generation and context.selection
        and context.selection.identity==origin.identity
end

function a11y.engine_selection_identity(key,node)
    local row=a11y.control_for_widget(key)
    local identity=a11y.ui_focus_identity(key,node.text)
    local binding=a11y.native_caption_selection_identity(node.address)
    if binding then identity=identity .. ":caption=" .. binding end
    if row and row.is_control then identity=identity .. ":value=" .. (row.value or "") end
    for _,part in ipairs(a11y.player_row_details(node)) do
        identity=identity .. ":part=" .. part.identity .. ":" .. part.text
    end
    local roster=a11y.native_player_roster_context(node)
    local state=a11y.engine_focus
    if state and node.name=="playerName" then
        -- Availability of optional roster evidence is not another cursor move.
        -- Retain only the last identity token, never attributes or authority.
        if roster then state.roster_focus_key,state.roster_focus_token=identity,roster.identity end
        if state.roster_focus_key==identity and state.roster_focus_token then
            identity=identity .. ":panel-roster=" .. state.roster_focus_token
        end
    elseif roster then identity=identity .. ":panel-roster=" .. roster.identity end
    local page=a11y.native_page_context(node.address)
    if page then identity=identity .. ":page=" .. page.identity end
    local music=a11y.native_music_packet(node)
    if music then identity=identity .. ":music=" .. music.signature end
    local assignment=a11y.native_assignment_context(node.address)
    if assignment then identity=identity .. ":assignment=" .. assignment.identity end
    local member=a11y.native_windows and a11y.native_windows.members
        and a11y.native_windows.members[tonumber(node.address)]
    if member and member.active then
        local _,slot=a11y.native_roster_section(node,member)
        if slot then identity=identity .. ":roster=" .. slot end
    end
    return identity
end

-- Controller-assignment component: c67970 stores the selected column at +a4;
-- c68e40 resolves root[group +94][column +a4] before showing the user name.
-- c67ad0 converts column 1 to unassigned (0), 0 to side 1, 2 to side 2.
-- Follow those exact links and native methods, never discovery order/captions.
function a11y.native_assignment_context(address,unfocused)
    local snapshot=a11y.native_windows
    local base=tonumber(process_base_u64)
    if not address or not base or not snapshot or not snapshot.selected_members
            or (not unfocused and not snapshot.selected_members[tonumber(address)]) then return nil end
    local found
    for _,window in ipairs(snapshot.windows or {}) do
        local vt=window.enabled and a11y.menu_read(window.address,"u64")
        if vt and a11y.menu_read(vt+0x140,"u64")==base+0xc68fd0
                and a11y.menu_read(vt+0x148,"u64")==base+0xc67970 then
            local state=a11y.menu_read(window.address+0xa4,"u32")
            local index=a11y.menu_read(window.address+0x94,"u32")
            if state and state<=2 and index and index<32 then
                local group=a11y.menu_child(window.root,index)
                local column=group and a11y.menu_child(group,state)
                local texts=column and a11y.menu_tree(column,base)
                if texts and texts[tonumber(address)] then
                    local label
                    if state==1 then
                        label=a11y.ui_language=="pt" and "Neutro" or "Neutral"
                    else
                        local name=state==0 and "text_home" or "text_away"
                        for _,node in pairs(a11y.ui_model and a11y.ui_model.names[name] or {}) do
                            if node.name==name and a11y.native_presentation_ready(node.address) and a11y.ui_node_matches_live(node) then
                                local member=snapshot.members[tonumber(node.address)]
                                for _,owner in ipairs(member and member.owners or {}) do
                                    if owner.address==window.address or owner.address==window.task_parent then
                                        if label and label~=node.text then return nil end
                                        label=node.text;break
                                    end
                                end
                            end
                        end
                    end
                    if label and label~="" then
                        -- c68d00 passes +98 to c68e40; it selects the personal
                        -- data profile whose name is rendered in this column.
                        local profile=a11y.menu_read(window.address+0x98,"u32")
                        if profile and profile>=32 then profile=nil end
                        local result={window=window.address,root=window.root,profile=profile,state=state,text=label,focus_address=address,
                            identity=tostring(window.address) .. ":" .. tostring(group) .. ":" .. state .. ":" .. label
                                .. ":profile=" .. tostring(profile)}
                        if found and found.identity~=result.identity then return nil end
                        found=result
                    end
                end
            end
        end
    end
    return found
end

function a11y.assignment_change_allowed(change)
    local node=a11y.ui_model and a11y.ui_model.nodes[memory.hex(change.address)]
    local current=node and a11y.ui_node_matches_live(node)
        and a11y.native_assignment_context(node.address,true)
    local rendered=node and a11y.read_native_rendered_text(node.address)
    return current and current.root==change.root and current.identity==change.identity and node.text==change.text
        and (rendered==nil or rendered==change.text)
end

function a11y.poll_assignment_changes()
    if a11y.read_context_state().kind=="dialog" then a11y.assignment_monitor=nil;return end
    local owner=a11y.native_owner_token()
    local previous=a11y.assignment_monitor
    local delivered=a11y.assignment_delivered or {}
    a11y.assignment_delivered=delivered
    local current={owner=owner,items={}}
    for _,node in pairs(a11y.ui_model and a11y.ui_model.names.personalDataName or {}) do
        -- This is a profile/state announcement, not focus speech. The native
        -- column still owns its user label when focus flags change to 0x105.
        -- native_assignment_context validates the enabled typed controller,
        -- current column/side and exact subtree independently of those flags.
        if a11y.ui_node_matches_live(node) then
            local assignment=a11y.native_assignment_context(node.address,true)
            if assignment then
                -- Buttons may change an unfocused/previously blank user row
                -- without hitting the observed text setter. Refresh that exact
                -- typed column now, rather than waiting for background scanning.
                local text,raw=a11y.read_native_rendered_text(node.address)
                if text~=nil and (text~=node.text or not a11y.ui_node_matches_live(node)) then
                    a11y.on_observed_ui_text(node.address,text,raw,nil,true)
                    node=a11y.ui_model.nodes[memory.hex(node.address)]
                end
            end
            if assignment and node and node.text and not a11y.empty_selection_caption(node.text) then
                local key=tostring(assignment.window) .. ":" .. tostring(assignment.root)
                local signature=assignment.identity .. ":" .. node.text
                local item=current.items[key]
                if item and item.signature~=signature then
                    -- More than one current name in the same typed column is
                    -- ambiguous; do not pick one by discovery order.
                    current.items[key]={ambiguous=true}
                elseif not item then current.items[key]={node=node,text=node.text,assignment=assignment,signature=signature} end
            end
        end
    end
    a11y.assignment_monitor=current
    for key,item in pairs(current.items) do
        local old=previous and previous.items[key]
        if not item.ambiguous and not delivered[key] and not old then
            delivered[key]={signature=item.signature} -- initial placement is a silent baseline
        end
        local last=delivered[key]
        if not item.ambiguous and last and last.signature~=item.signature then
            local result=a11y.read_context_state().selection_result
            local already=result and result.assignment and result.assignment.identity==item.assignment.identity
                and result.label==item.node.text and result.status~="discarded" and result.status~="failed"
            if already and result.status=="delivered" then delivered[key]={signature=item.signature}
            elseif not already or result.status=="discarded" or result.status=="failed" then
                -- A native profile change may precede the rendered name. Wait
                -- for that caption to change instead of announcing the old user.
                local awaiting_name=old and old.assignment.profile~=item.assignment.profile
                    and old.text==item.text
                local queued=false
                for index=a11y.native_speech_first,a11y.native_speech_last do
                    local change=a11y.native_speech_queue[index] and a11y.native_speech_queue[index].assignment_change
                    if change and change.key==key and change.signature==item.signature then queued=true end
                end
                if awaiting_name then
                    item.awaiting_profile_name=true
                elseif old and old.awaiting_profile_name and old.text==item.text then
                    item.awaiting_profile_name=true
                elseif not queued then
                local before=a11y.native_speech_last
                a11y.assignment_attempt=(a11y.assignment_attempt or 0)+1
                speak(item.node.text .. ", " .. item.assignment.text,true,nil,
                    "assignment-change:" .. item.signature .. ":attempt=" .. a11y.assignment_attempt)
                for index=before+1,a11y.native_speech_last do
                    a11y.native_speech_queue[index].assignment_change={root=item.assignment.root,address=item.node.address,
                        text=item.node.text,identity=item.assignment.identity,key=key,signature=item.signature}
                end
                end
            end
        end
    end
    for key in pairs(delivered) do if not current.items[key] then delivered[key]=nil end end
end

-- ListMultiPageBase selects TabPageInfo from its own vector (+1d8/+1e0,
-- 40-byte records). eb1c87/eb1928 write +1d0; eb0e90/eb1090 animate
-- the exact Node at record+20 as active/inactive. No caption/index catalogue.
function a11y.native_page_context(address)
    local base=tonumber(process_base_u64)
    local snapshot=a11y.native_windows
    local member=address and snapshot and snapshot.members[tonumber(address)]
    if not base or not member or not member.active then return nil end
    local result
    for _,window in ipairs(snapshot.windows or {}) do
        local vt=a11y.menu_read(window.address,"u64")
        if (window.enabled or window.context_active) and vt and a11y.menu_read(vt+0x2e0,"u64")==base+0xeb17f0
                and a11y.menu_read(vt+0x2e8,"u64")==base+0xeb1b60 then
            local first=a11y.menu_read(window.address+0x1d8,"u64")
            local last=a11y.menu_read(window.address+0x1e0,"u64")
            local index=a11y.menu_read(window.address+0x1d0,"u32")
            if first and last and first>=0x10000 and last>=first and (last-first)%0x40==0
                    and last-first<=0x40*32 and index and index<(last-first)/0x40 then
                local record=first+index*0x40
                local child=a11y.menu_read(record+8,"u64")
                local tab=a11y.menu_read(record+0x20,"u64")
                local related=false
                for _,owner in ipairs(member.owners or {}) do
                    if owner.enabled and (owner.address==window.address or owner.address==child) then related=true end
                end
                if related and tab and tab>=0x10000 and a11y.menu_read(record,"u64")==base+0x27d6590 then
                    local texts=a11y.menu_tree(tab,base)
                    local caption,ambiguous
                    for at in pairs(texts) do
                        if a11y.widget_internal_name(at)=="tabText" and a11y.menu_node_active(at,base)
                                and a11y.native_text_presented(at) then
                            local text=a11y.read_native_rendered_text(at)
                            if text and text~="" and not a11y.unresolved_format(text) then
                                if caption then ambiguous=true end
                                caption={address=at,text=text}
                            end
                        end
                    end
                    if caption and not ambiguous then
                        caption.window,caption.index,caption.focus_address=window.address,index,address
                        caption.identity=a11y.native_owner_token() .. ":" .. tostring(window.address)
                            .. ":" .. tostring(record) .. ":" .. tostring(tab) .. ":" .. caption.text
                        if result and result.identity~=caption.identity then return nil end
                        result=caption
                    end
                end
            end
        end
    end
    return result
end

function a11y.page_focus_speech(text,address)
    local page=a11y.native_page_context(address)
    if page and page.identity~=a11y.last_page_delivery then return page.text .. ". " .. text,page end
    return text,page
end

function a11y.page_delivery_allowed(origin)
    local current=a11y.native_page_context(origin.focus_address or origin.address)
    return current and current.identity==origin.identity
end

-- A tab can change while its content has no selectable text (an icon grid or
-- empty page). Its native selected record remains presentation authority.
function a11y.poll_native_pages(blocked)
    if a11y.native_information_context() then return end
    if blocked or a11y.keyboard_window or a11y.read_context_state().kind=="dialog" then return end
    local snapshot=a11y.native_windows
    local base=tonumber(process_base_u64)
    local page
    for _,window in ipairs(snapshot and snapshot.windows or {}) do
        local vt=base and window.enabled and a11y.menu_read(window.address,"u64")
        if vt and a11y.menu_read(vt+0x2e0,"u64")==base+0xeb17f0
                and a11y.menu_read(vt+0x2e8,"u64")==base+0xeb1b60 then
            for address,member in pairs(snapshot.members or {}) do
                local belongs=false
                for _,owner in ipairs(member.owners or {}) do
                    if owner.enabled and owner.address==window.address then belongs=true;break end
                end
                if belongs and member.active then
                    local found=a11y.native_page_context(address)
                    if found then
                        if page and page.identity~=found.identity then return end
                        page=found
                    end
                    break
                end
            end
        end
    end
    if not page or page.identity==a11y.last_page_delivery then return end
    for index=a11y.native_speech_first,a11y.native_speech_last do
        local pending=a11y.native_speech_queue[index]
        if pending and pending.page_context and pending.page_context.identity==page.identity
                and a11y.speech_entry_allowed(pending) then return end
    end
    page.focus_address=page.address
    local before=a11y.native_speech_last
    speak(page.text,false,nil,"page:" .. page.identity,page.address)
    if a11y.native_speech_last>before then
        a11y.last_page_announcement=page.identity
        for index=before+1,a11y.native_speech_last do a11y.native_speech_queue[index].page_context=page end
    end
end

function a11y.engine_focus_delivery_allowed(origin)
    local state=a11y.engine_focus
    local node=a11y.ui_model and a11y.ui_model.nodes[origin.key]
    return state and state.owner==origin.owner and state.owner==a11y.native_owner_token()
        and state.last_identity==origin.identity and state.nodes[origin.key] ~= nil
        and node and a11y.engine_selection_identity(origin.key,node)==origin.identity
end

function a11y.native_node_summary(address)
    if not address or address < 0x10000 then return "none" end
    local fields = {}
    -- Diagnostic raw candidates only: these do not establish child ownership.
    for _, offset in ipairs({0,0x38,0x98,0xa0,0x120,0x170,0x178,0x180,0x190}) do
        local value = a11y.menu_read(address+offset,"u64")
        if value then fields[#fields+1]=string.format("%x=%s",offset,memory.hex(value)) end
    end
    return table.concat(fields,",")
end

-- Bounded structural evidence for unresolved components. Never used to infer
-- speech, visibility, a button mapping or roster status from an address/name.
function a11y.component_evidence(node,reason)
    if not node then return end
    local owner=a11y.native_owner_token()
    if a11y.component_evidence_owner~=owner or not a11y.component_evidence_seen then
        a11y.component_evidence_owner,a11y.component_evidence_seen=owner,{}
        a11y.component_evidence_count=0
    end
    local key=reason .. ":" .. node.key .. ":" .. node.text
    if a11y.component_evidence_seen[key] or (a11y.component_evidence_count or 0)>=24 then return end
    a11y.component_evidence_seen[key]=true
    a11y.component_evidence_count=(a11y.component_evidence_count or 0)+1
    local snapshot=a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[tonumber(node.address)]
    local paths={}
    for index,entry in ipairs(member and member.owners or {}) do
        if index>2 then break end
        local at,visited,parts=tonumber(node.address),{},{}
        for _=1,12 do
            if not at or visited[at] then break end
            visited[at]=true
            parts[#parts+1]=string.format("%s/%s/%s",memory.hex(at),
                tostring(a11y.menu_read(at,"u64")),a11y.widget_internal_name(at) or "")
            if at==entry.root then break end
            at=entry.parents and entry.parents[at]
        end
        paths[#paths+1]=table.concat(parts,">")
    end
    local _,raw,font=a11y.read_native_rendered_text(node.address)
    log(string.format("[FLAccess] component-evidence reason=%s widget=%s name=%q text=%q flags=%s font=%s raw=%q path=%s",
        reason,node.key,node.name or "",node.text or "",tostring(a11y.menu_read(node.address+0xc,"u32")),
        tostring(font),raw or "",table.concat(paths," | ")))
end

-- Window::close (e43450) walks Impl+70/+78 in 50-byte records and
-- clears the shown state of each Node at record+40 through e4c240.
-- These owned roots include passive presentation, not just Impl+98 navigation.
function a11y.window_owned_roots(impl,primary,base)
    local roots,seen={},{}
    if primary and primary>=0x10000 then roots[1],seen[primary]=primary,true end
    -- e3d790 returns the presentation Node, e3dc90 the navigation Node.
    -- They can differ even while the same window owns both. Ownership does
    -- not grant input authority to a disabled window.
    local presentation=a11y.menu_read(impl+0x90,"u64")
    if presentation and presentation>=0x10000 and not seen[presentation] then
        local vt=a11y.menu_read(presentation,"u64")
        if vt and a11y.native_layout.holders[vt-base] then
            roots[#roots+1],seen[presentation]=presentation,true
        end
    end
    local first,last=a11y.menu_read(impl+0x70,"u64"),a11y.menu_read(impl+0x78,"u64")
    if not first or not last or first<0x10000 or last<first
            or (last-first)%0x50~=0 or last-first>0x50*64 then return roots end
    for at=first,last-0x50,0x50 do
        if #roots>=16 then break end
        local node=a11y.menu_read(at+0x40,"u64")
        if node and node>=0x10000 and not seen[node] then
            local vtable=a11y.menu_read(node,"u64")
            local rva=vtable and vtable-base
            local typed=rva and (a11y.native_layout.holders[rva] or rva==0x27b5260 or rva==0x27c3a38)
            local delegate=a11y.has_owned_node_delegate(vtable,base)
            if typed or delegate then roots[#roots+1],seen[node]=node,true end
        end
    end
    return roots
end

-- Read-only equivalent of e4d1c0: ordered holder+78 tree, value at +40,
-- filtering the Node kind at +88. Tree order, not pointer/visit order,
-- defines the index consumed by the game's presentation code.
function a11y.holder_kind_nodes(holder,kind)
    local head=a11y.menu_read(holder+0x78,"u64")
    if not head or head<0x10000 or a11y.menu_read(head+0x19,"u8")~=1 then return nil end
    local at=a11y.menu_read(head+8,"u64")
    local stack,seen,nodes,count={},{},{},0
    while (at and at~=head) or #stack>0 do
        while at and at~=head do
            if at<0x10000 or seen[at] or count>=256
                    or a11y.menu_read(at+0x19,"u8")~=0 then return nil end
            seen[at],count=true,count+1
            stack[#stack+1]=at
            at=a11y.menu_read(at,"u64")
            if not at then return nil end
        end
        at=table.remove(stack)
        local child=a11y.menu_read(at+0x40,"u64")
        if child and child>=0x10000 and a11y.menu_read(child+0x88,"u32")==kind then
            nodes[#nodes+1]=child
        end
        at=a11y.menu_read(at+0x10,"u64")
        if not at then return nil end
    end
    return nodes
end

function a11y.read_native_command_bar(base)
    -- e34b60 returns this typed singleton; e346e0 destroys +70 while hidden.
    local address=a11y.menu_read(base+0x36f98f0,"u64")
    if not address or a11y.menu_read(address,"u64")~=base+0x27b2668 then return nil end
    local root=a11y.menu_read(address+0x70,"u64")
    if not root or a11y.menu_read(root,"u64")~=base+0x27bae88
            or a11y.menu_read(address+0x1b9,"u8")~=0 then return nil end
    local flags=a11y.menu_read(root+0xc,"u32")
    -- GuideBar is presentation, not an input window. Its shown/enabled bits
    -- matter here; individual text nodes still pass the propagated-state gate.
    if not flags or flags%8~=7 then return nil end
    local pairs={}
    -- e3594d/e35969 and e35a77/e35a94 resolve the seven displayed
    -- icons at kind 19 indices 0..6 and captions at indices 7..13.
    -- The constructor's +90 arrays contain other templates/placeholders.
    local texts=a11y.holder_kind_nodes(root+0x98,0x13) or {}
    for index=0,6 do
        local icon,caption=texts[index+1],texts[index+8]
        if icon and caption and a11y.menu_read(icon,"u64")==base+0x27b5260
                and a11y.menu_read(caption,"u64")==base+0x27b5260 then
            pairs[#pairs+1]={icon=icon,caption=caption,index=index}
        end
    end
    return {address=address,root=root,pairs=pairs}
end

function a11y.component_link_capture_lines(snapshot)
    local lines,seen={},{}
    local caption_count=0
    for address in pairs(snapshot and snapshot.selected_members or {}) do
        local binding=a11y.native_caption_selection_identity(address)
        if binding and caption_count<32 then
            caption_count=caption_count+1
            lines[#lines+1]=string.format("CAPTION_SELECTION widget=%s identity=%q",tostring(address),binding)
        end
    end
    local result=a11y.read_context and a11y.read_context.selection_result
    if result then
        lines[#lines+1]=string.format("RESULT source=%q widget=%s generation=%s label=%q value=%q value_known=%s page=%q status=%q missing=%q",
            result.source,tostring(result.widget),tostring(result.generation),result.label,result.value or "",
            tostring(result.value~=nil),result.page and result.page.identity or "",result.status or "",
            table.concat(result.missing,","))
    end
    local base=tonumber(process_base_u64)
    for address in pairs(snapshot and snapshot.selected_members or {}) do
        local page=a11y.native_page_context(address)
        if page and not seen[page.identity] then
            seen[page.identity]=true
            lines[#lines+1]=string.format("PAGE window=%s index=%d caption=%s text=%q identity=%q",
                tostring(page.window),page.index,tostring(page.address),page.text,page.identity)
        end
    end
    local bar=snapshot and snapshot.command_bar
    if bar then
        for _,pair in ipairs(bar.pairs) do
            local icon,raw,font=a11y.read_native_rendered_text(pair.icon)
            local caption=a11y.read_native_rendered_text(pair.caption)
            lines[#lines+1]=string.format("COMMAND bar=%s root=%s index=%d icon=%s caption=%s icon_text=%q raw=%q font=%s text=%q",
                tostring(bar.address),tostring(bar.root),pair.index,tostring(pair.icon),tostring(pair.caption),
                icon or "",raw or "",tostring(font),caption or "")
        end
    end
    for _,window in ipairs(snapshot and snapshot.windows or {}) do
        local vt=base and a11y.menu_read(window.address,"u64")
        if vt and a11y.menu_read(vt+0x2e0,"u64")==base+0xeb17f0
                and a11y.menu_read(vt+0x2e8,"u64")==base+0xeb1b60 then
            local first=a11y.menu_read(window.address+0x1d8,"u64")
            local last=a11y.menu_read(window.address+0x1e0,"u64")
            local index=a11y.menu_read(window.address+0x1d0,"u32")
            local tab=first and last and index and last>=first and (last-first)%0x40==0
                and index<(last-first)/0x40 and a11y.menu_read(first+index*0x40+0x20,"u64")
            lines[#lines+1]=string.format("PAGE_STATE window=%s input=%s first=%s last=%s index=%s tab=%s type=%s",
                tostring(window.address),tostring(window.enabled),tostring(first),tostring(last),tostring(index),
                tostring(tab),tostring(tab and a11y.menu_read(tab,"u64")))
        end
        if vt and a11y.menu_read(vt+0x140,"u64")==base+0xc68fd0
                and a11y.menu_read(vt+0x148,"u64")==base+0xc67970 then
            lines[#lines+1]=string.format("ASSIGNMENT window=%s root=%s group=%s column=%s task_parent=%s",
                tostring(window.address),tostring(window.root),tostring(a11y.menu_read(window.address+0x94,"u32")),
                tostring(a11y.menu_read(window.address+0xa4,"u32")),tostring(window.task_parent))
        end
        if vt and (vt==base+0x261eaa0 or vt==base+0x261f788) then
            local bound=a11y.roster_limits and a11y.roster_limits[window.address]
            local presentation=a11y.roster_presentation_root(window.address)
            lines[#lines+1]=string.format("ROSTER window=%s type=%s root=%s input=%s side=%s scroll=%s boundary=%s boundary_root=%s presentation=%s",
                tostring(window.address),tostring(vt),tostring(window.root),tostring(window.enabled),
                tostring(a11y.menu_read(window.address+0x98,"u32")),
                tostring(a11y.menu_read(window.address+0x4e8,"u32")),tostring(bound and bound.limit),tostring(bound and bound.root),tostring(presentation))
            for index=0,(vt==base+0x261eaa0 and 10 or 11) do
                local data=a11y.menu_read(base+0x36f38a0,"u64")
                local side=a11y.menu_read(window.address+0x98,"u32")
                local record=a11y.menu_read(window.address+0x2a0+index*4,"u32")
                local object=data and a11y.menu_read(data,"u64")==base+0x2618830
                    and (side==0 or side==1) and record and record<40
                    and a11y.menu_read(data+side*0x340+0x568+record*16,"u64")
                local id=object and object>=0x10000 and a11y.menu_read(object+0x30,"u32")
                lines[#lines+1]=string.format("SLOT window=%s index=%d card=%s selection_card=%s record=%s player_object=%s player_id=%s",
                    tostring(window.address),index,tostring(a11y.menu_read(window.address+0xb8+index*8,"u64")),
                    tostring(a11y.menu_read(window.address+0x118+index*8,"u64")),tostring(record),tostring(object),tostring(id))
            end
        end
    end
    for address in pairs(snapshot and snapshot.members or {}) do
        local node=a11y.ui_model and a11y.ui_model.nodes[memory.hex(address)]
        local player=node and a11y.current_player_record(node)
        if player then
            local positions={}
            for _,entry in ipairs(player.secondary or {}) do positions[#positions+1]=entry.position .. ":" .. entry.level end
            lines[#lines+1]=string.format("PLAYER_DATA widget=%s object=%s player_id=%s slot=%s side=%s primary=%s secondary=%q field=%s mode=%s limit=%s identity=%q",
                tostring(address),tostring(player.object),tostring(player.player_id),tostring(player.slot),tostring(player.side),
                tostring(player.primary),table.concat(positions,","),tostring(player.field_position),
                tostring(a11y.menu_read(player.data+8,"u32")),tostring(a11y.live_roster_limit(player.data)),player.identity)
        end
        local roster=node and a11y.native_player_roster_context(node)
        if roster then
            lines[#lines+1]=string.format("PLAYER_PANEL widget=%s window=%s slot=%s side=%s player_id=%s section=%q identity=%q",
                tostring(address),tostring(roster.window),tostring(roster.slot),tostring(roster.side),
                tostring(roster.player_id),roster.section or "",roster.identity)
        end
    end
    return lines
end

-- Window instances inherit both lifecycle slots. Only this verified family
-- shares Task links (+38 parent, +40 child anchor, +50 next sibling).
-- Node objects use entirely different meanings for these offsets.
function a11y.is_native_window_task(address,base)
    local vt=address and address>=0x10000 and a11y.menu_read(address,"u64")
    return vt and a11y.menu_read(vt+0x50,"u64")==base+0xe43510
        and a11y.menu_read(vt+0x58,"u64")==base+0xe43450
end

function a11y.related_window_tasks(address,base)
    local result={}
    if not a11y.is_native_window_task(address,base) then return result end
    local parent=a11y.menu_read(address+0x38,"u64")
    if a11y.is_native_window_task(parent,base) then result[#result+1]=parent end
    local child=a11y.menu_read(address+0x40,"u64")
    local seen={}
    while child and child>=0x10000 and not seen[child] and #result<32 do
        seen[child]=true
        if not a11y.is_native_window_task(child,base)
                or a11y.menu_read(child+0x38,"u64")~=address then break end
        result[#result+1]=child
        child=a11y.menu_read(child+0x50,"u64")
    end
    return result
end

function a11y.bind_presented_window_contexts(snapshot,base)
    local windows={}
    for _,window in ipairs(snapshot.windows) do windows[window.address]=window end
    for _,window in ipairs(snapshot.windows) do
        if window.enabled then
            local current,seen=window,{}
            for depth=1,16 do
                local parent=current.task_parent and windows[current.task_parent]
                if not parent or seen[parent.address] then break end
                seen[parent.address]=true
                -- A Task relation proves ownership, not visibility. Demand the
                -- native shown state of the parent's presentation root as well.
                local flags=parent.presentation_root and a11y.menu_read(parent.presentation_root+0xc,"u32")
                if not flags or flags%8~=7 then break end
                parent.context_active=true
                current=parent
            end
        end
    end
    for _,member in pairs(snapshot.members) do
        member.presented=member.active
        for _,owner in ipairs(member.owners or {}) do
            if windows[owner.address] and windows[owner.address].context_active then member.presented=true end
        end
    end
end

