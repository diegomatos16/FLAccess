-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 7, "FLAccess reader: missing or reordered component native_windows")
function shared.a11y.read_native_windows_snapshot(base)
    local manager = shared.a11y.menu_read(base + 0x36f9c10, "u64")
    if not manager or shared.a11y.menu_read(manager, "u64") ~= base + 0x27c1568 then return nil end
    local result = {manager=manager, windows={}, members={}, active={}, signature={},
        selected_members={}, cursor_members={},cursor_proofs={}}
    local tree_cache = {}
    local seen = {}
    for slot = 0, 7 do
        local window = shared.a11y.menu_read(manager + 0xc8 + slot * 16, "u64")
        local priority = shared.a11y.menu_read(manager + 0xd0 + slot * 16, "i32")
        if not window or priority == nil then return nil end
        local registered = {}
        local first = shared.a11y.menu_read(manager + 8 + slot * 24, "u64")
        local last = shared.a11y.menu_read(manager + 16 + slot * 24, "u64")
        if not first or not last or last < first or (last - first) % 16 ~= 0
                or last - first > 1024 then return nil end
        if first >= 0x10000 then
            for at = first, last - 16, 16 do
                local address = shared.a11y.menu_read(at, "u64")
                if not address then return nil end
                if address >= 0x10000 then registered[#registered + 1] = address end
            end
        elseif first ~= last then return nil end
        if window >= 0x10000 then registered[#registered + 1] = window end
        for _, address in ipairs(registered) do
          if not seen[address] then
            seen[address] = true
            for _,related in ipairs(shared.a11y.related_window_tasks(address,base)) do
                if not seen[related] and #registered<96 then registered[#registered+1]=related end
            end
            local impl = shared.a11y.menu_read(address + 0x88, "u64")
            if not impl then return nil end
            local flags = shared.a11y.menu_read(impl + 9, "u8")
            local root = shared.a11y.menu_read(impl + 0x98, "u64")
            if flags == nil or not root then return nil end
            local enabled = flags % 2 == 1
            local entry = {slot=slot, address=address, impl=impl, root=root,
                priority=priority, enabled=enabled,primary=address==window,vtable=shared.a11y.menu_read(address,"u64")}
            entry.presentation_root=shared.a11y.menu_read(impl+0x90,"u64")
            if shared.a11y.is_native_window_task(address,base) then entry.task_parent=shared.a11y.menu_read(address+0x38,"u64") end
            entry.owned_roots=shared.a11y.window_owned_roots(impl,root,base)
            if enabled and shared.a11y.menu_read(address,"u64") == base + 0x27c3eb0 then result.keyboard = address end
            result.windows[#result.windows + 1] = entry
            if #result.windows > 96 then return nil end
            if entry.primary or #entry.owned_roots>0 then result.signature[#result.signature + 1] = tostring(address) .. ":" ..
                tostring(root) .. ":" .. tostring(enabled) .. ":" .. tostring(priority)
                .. ":" .. table.concat(entry.owned_roots,",") end
            if enabled and (entry.primary or #entry.owned_roots>0) then
                local identity=tostring(address) .. ":" .. tostring(root)
                if #entry.owned_roots>1 or (root<0x10000 and #entry.owned_roots>0) then
                    identity=identity .. ":owned=" .. table.concat(entry.owned_roots,",")
                end
                result.active[#result.active+1]=identity
            end
            for _,root in ipairs(entry.owned_roots) do
                local cached = tree_cache[root] or (shared.a11y.native_tree_cache and shared.a11y.native_tree_cache[root])
                if not cached or (enabled and shared.frame - cached.frame >= 6) then
                    local members,parents,evidence=shared.a11y.menu_tree(root, base)
                    cached = {frame=shared.frame, members=members, parents=parents,evidence=evidence}
                end
                tree_cache[root] = cached
                if root==entry.root then entry.tree_evidence=cached.evidence end
                for address in pairs(cached.members) do
                    -- Shared elements are eligible if ANY owner still accepts
                    -- input. Unknown branches never acquire invented ownership.
                    local member = result.members[address] or {active=false,owners={}}
                    member.owners = member.owners or {}
                    member.owners[#member.owners+1]={address=entry.address,root=root,enabled=enabled,
                        parents=cached.parents}
                    member.active = member.active or enabled
                    result.members[address] = member
                end
                if enabled and root==entry.root then
                    local selected, detail = shared.a11y.menu_cursor_texts(root, base,cached)
                    entry.cursor_detail = detail
                    if selected then
                        local proof=detail.graph_edges and {window=entry,root=detail.proof_root,
                            edges=detail.graph_edges,parents=detail.parents}
                        -- The window's typed cursor and its indexed child path
                        -- prove ownership even if the broad tree hit its limit.
                        for address in pairs(selected) do
                            result.selected_members[address]=true
                            result.cursor_members[address]=true
                            if proof then
                                result.cursor_proofs[address]=result.cursor_proofs[address] or {}
                                result.cursor_proofs[address][entry.address]=proof
                            end
                            local member=result.members[address] or {active=false,owners={}}
                            member.active=true
                            member.owners=member.owners or {}
                            member.owners[#member.owners+1]={address=entry.address,root=root,
                                enabled=true,parents=detail.parents}
                            result.members[address]=member
                        end
                        for address in pairs(cached.members) do result.cursor_members[address]=true end
                    end
                end
            end
          end
        end
    end
    shared.a11y.bind_presented_window_contexts(result,base)
    shared.a11y.bind_controlled_player_captions(result,base)
    result.command_bar=shared.a11y.read_native_command_bar(base)
    if result.command_bar then
        local bar=result.command_bar
        local cached=shared.a11y.native_tree_cache and shared.a11y.native_tree_cache[bar.root]
        if not cached or shared.frame-cached.frame>=6 then
            local texts,parents=shared.a11y.menu_tree(bar.root,base)
            cached={frame=shared.frame,members=texts,parents=parents}
        end
        tree_cache[bar.root]=cached
        for address in pairs(cached.members) do
            local member=result.members[address] or {active=false,owners={}}
            member.active=true
            member.owners[#member.owners+1]={address=bar.address,root=bar.root,enabled=true,
                parents=cached.parents,command_bar=true}
            result.members[address]=member
        end
        result.signature[#result.signature+1]="guide:" .. tostring(bar.address) .. ":" .. tostring(bar.root)
    end
    result.signature = table.concat(result.signature, "|")
    result.active_identity = table.concat(result.active, "|")
    result.active_text_count = 0
    for _, member in pairs(result.members) do
        if member.active then result.active_text_count = result.active_text_count + 1 end
    end
    shared.a11y.native_tree_cache = tree_cache
    local owner_parts={}
    for _,window in ipairs(result.windows) do
        if window.enabled and (window.primary or #window.owned_roots>0) then owner_parts[#owner_parts+1]=tostring(window.address) .. ":" .. tostring(window.root or 0) end
    end
    table.sort(owner_parts)
    result.owner_token=table.concat(owner_parts,",")
    return result
end

function shared.a11y.read_native_windows(base)
    local previous=shared.a11y.snapshot_read_work
    shared.a11y.snapshot_tree_work={}
    shared.a11y.snapshot_read_work=previous or shared.a11y.render_read_work or {}
    local result,reason
    if shared.a11y.refresh_list_snapshot then result,reason=shared.a11y.refresh_list_snapshot(base,shared.a11y.native_windows) end
    if not result then
        -- A different input owner/guide does not replace every other tree.
        -- Root-keyed entries retain their six-frame expiry and fresh edge
        -- validation. Only an unresolved changed selection invalidates them.
        if reason=="layout" then shared.a11y.native_tree_cache=nil end
        shared.a11y.window_graph_dirty=nil
        result=shared.a11y.read_native_windows_snapshot(base)
        if result then
            result.full_frame=shared.frame
            if shared.a11y.capture_window_headers then result.header_checks=shared.a11y.capture_window_headers(result,base) end
        end
    end
    shared.a11y.snapshot_tree_work=nil
    shared.a11y.snapshot_read_work=previous
    if shared.a11y.render_metric then
        local metric=shared.a11y.render_metric
        metric.window_refresh=result and result.light and "light" or reason or "initial"
    end
    return result
end

function shared.a11y.clear_closed_native_dialog()
    local context = shared.a11y.read_context
    if context and context.message_key and ((context.native_owner
            and context.native_owner ~= shared.a11y.native_owner_token())
            or not shared.a11y.native_key_allowed(context.message_key)) then
        shared.a11y.reset_read_context("native-window-closed")
        shared.modal_focus_hold_until_ms = 0
        shared.a11y.deferred_modal_announcement = nil
        shared.a11y.modal_message_backlog = {}
        shared.a11y.pending_modal_button_text = nil
    end
end

function shared.a11y.poll_native_windows()
    if not shared.a11y.native_windows_enabled or shared.a11y.native_windows_frame == shared.frame then return end
    shared.a11y.native_windows_frame = shared.frame
    local snapshot = shared.a11y.read_native_windows(tonumber(shared.process_base_u64))
    local previous = shared.a11y.native_windows
    shared.a11y.native_windows = snapshot
    if not snapshot then return end
    if shared.a11y.player_detail_review and not shared.a11y.focused_player_node() then shared.a11y.player_detail_review=nil end
    shared.a11y.prune_roster_limits(snapshot)
    if snapshot.keyboard ~= shared.a11y.keyboard_window then
        shared.a11y.keyboard_window, shared.a11y.keyboard_text, shared.a11y.keyboard_caret = snapshot.keyboard, nil, nil
        if not snapshot.keyboard then shared.a11y.keyboard_input_address = nil end
        if snapshot.keyboard then shared.speak(shared.a11y.ui_language == "pt" and "Teclado aberto." or "Keyboard opened.") end
    end
    if snapshot.light_same_cursor then shared.a11y.clear_closed_native_dialog();return end
    if not previous or previous.signature ~= snapshot.signature then
        local lines = {"[FLAccess] native-windows frame=" .. tostring(shared.frame)
            .. " active-texts=" .. tostring(snapshot.active_text_count)}
        for _, window in ipairs(snapshot.windows) do
            lines[#lines + 1] = string.format("slot=%d window=%s root=%s slot-priority=%d input=%s window-type=%s root-type=%s cursor=%s",
                window.slot, memory.hex(window.address), memory.hex(window.root),
                window.priority, tostring(window.enabled),memory.hex(window.vtable or 0),
                memory.hex(shared.a11y.menu_read(window.root,"u64") or 0),
                memory.hex(shared.a11y.menu_read(window.root+0x190,"u64") or 0))
        end
        log(table.concat(lines, " "))
    end
    local selected = {}
    for address in pairs(snapshot.selected_members) do selected[#selected+1] = memory.hex(address) end
    table.sort(selected)
    local identity = table.concat(selected, ",")
    if identity ~= shared.a11y.native_cursor_identity then
        shared.a11y.native_cursor_identity = identity
        shared.a11y.native_cursor_log_count = (shared.a11y.native_cursor_log_count or 0) + 1
        if shared.a11y.native_cursor_log_count <= 300 then
            log("[FLAccess] native-cursor frame=" .. tostring(shared.frame) .. " text-widgets=" .. identity)
        end
    end
    -- Trace indices and each failed link, including cursors with zero labels.
    -- Bounded change-only output; no selection or caption is invented.
    local details = {}
    for _, window in ipairs(snapshot.windows) do
        local d = window.enabled and window.cursor_detail
        if d then
            details[#details+1] = string.format("window=%s delegate=%s type=%s parent=%s group-index=%s item-index=%s group=%s selected=%s selected-type=%s status=%s",
                memory.hex(window.address),memory.hex(d.cursor or 0),memory.hex(d.cursor_type or 0),
                memory.hex(d.parent or 0),tostring(d.group_index),tostring(d.item_index),
                memory.hex(d.group or 0),memory.hex(d.selected or 0),memory.hex(d.selected_type or 0),d.status)
        end
    end
    local detail_identity = table.concat(details," | ")
    if detail_identity ~= shared.a11y.native_cursor_detail_identity then
        shared.a11y.native_cursor_detail_identity = detail_identity
        shared.a11y.native_cursor_detail_count = (shared.a11y.native_cursor_detail_count or 0)+1
        if shared.a11y.native_cursor_detail_count <= 500 then
            log("[FLAccess] native-selection frame=" .. tostring(shared.frame) .. " " .. detail_identity)
            for _, window in ipairs(snapshot.windows) do
                local d=window.enabled and window.cursor_detail
                if d and d.status=="no-text" then
                    log("[FLAccess] native-selection-gap frame=" .. tostring(shared.frame)
                        .. " selected={" .. shared.a11y.native_node_summary(d.selected)
                        .. "} group={" .. shared.a11y.native_node_summary(d.group) .. "}")
                    local evidence=window.tree_evidence
                    if evidence then
                        local parts={}
                        for _,item in ipairs(evidence.frontier) do
                            parts[#parts+1]=memory.hex(item.address) .. "/" .. memory.hex(item.rva)
                        end
                        log("[FLAccess] native-tree-gap root=" .. memory.hex(window.root)
                            .. " visited=" .. tostring(evidence.visited) .. " queued=" .. tostring(evidence.queued)
                            .. " at-capacity=" .. tostring(evidence.at_capacity)
                            .. " frontier=" .. table.concat(parts,","))
                    end
                end
            end
        end
    end
    if previous and previous.active_identity ~= snapshot.active_identity then
        shared.a11y.engine_focus=nil
        shared.a11y.companion_candidate,shared.a11y.companion_spoken=nil,nil
        if shared.a11y.pending_message_owner and shared.a11y.pending_message_owner~=shared.a11y.native_owner_token() then
            shared.pending_message_text,shared.pending_message_key,shared.pending_message_due_ms=nil,nil,nil
            shared.a11y.pending_message_widget_key,shared.a11y.pending_message_owner=nil,nil
            shared.a11y.modal_message_backlog={}
        end
        shared.last_screen_title_key,shared.last_announced_message_key=nil,nil
        shared.a11y.last_page_announcement=nil;shared.a11y.last_page_delivery=nil
        shared.a11y.answer_chain=nil
        if not (shared.a11y.read_context and shared.a11y.read_context.message_key) then
            shared.a11y.reset_read_context("native-presentation-changed")
        end
        shared.modal_focus_hold_until_ms=0
        shared.a11y.screen_title_hold_until_ms=0
        shared.a11y.title_pending_first_item=nil
        shared.a11y.deferred_modal_announcement,shared.a11y.pending_modal_button_text=nil,nil
        shared.a11y.clear_pending_tooltips()
        -- A real change of input ownership releases deduplication. Keep new
        -- text observations: construction can precede manager registration.
        shared.a11y.reset_focus_reuse_state()
        -- Preserve recorded edges. Clearing them promotes every retained
        -- cursorOver=1 from the previous window to a brand-new selection.
        shared.last_selected_ui_entry = nil
        shared.a11y.control_focus_owner = nil
    end
    shared.a11y.clear_closed_native_dialog()
end

-- Native cursor ownership proves selection; a selected label may have the
-- display state7 without accepting input itself (e4bb90 vs e4bb70).
function shared.a11y.native_selected_text_presented(address)
    address=tonumber(address)
    local snapshot=shared.a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[address]
    local base=tonumber(shared.process_base_u64)
    if not address or not base or not member or not member.active
            or not snapshot.selected_members or not snapshot.selected_members[address]
            or shared.a11y.menu_read(address,"u64")~=base+0x27b5260 then return false end
    local flags=shared.a11y.menu_read(address+0xc,"u32")
    if not flags or flags%8~=7 then return false end
    for _,window in ipairs(snapshot.windows or {}) do
        local detail=window.enabled and window.cursor_detail
        if detail and detail.selected and shared.a11y.record_contains({address=address},window,detail.selected) then return true end
    end
    return false
end

function shared.a11y.native_widget_allowed(address)
    if not shared.a11y.cursor_member_live(address) then return false end
    if shared.a11y.native_windows_enabled then
        local active = shared.a11y.menu_node_active(tonumber(address), tonumber(shared.process_base_u64))
        if active == false and not shared.a11y.native_selected_text_presented(address) then return false end
    end
    local snapshot = shared.a11y.native_windows
    local member = snapshot and snapshot.members[tonumber(address)]
    if member then return member.active end
    return true
end

function shared.a11y.native_dialog_window(window)
    local base=tonumber(shared.process_base_u64)
    if not base or not window or not window.enabled or not window.root or window.root<0x10000 then return false end
    local vt=shared.a11y.menu_read(window.address,"u64")
    return vt==base+0x27bd238 and shared.a11y.menu_read(vt+0x18,"u64")==base+0xe607d0
        and shared.a11y.menu_read(vt+0x100,"u64")==base+0xe472b0
end

function shared.a11y.native_dialog_text_presented(address)
    address=tonumber(address)
    local base=tonumber(shared.process_base_u64)
    if not address or not base or shared.a11y.menu_read(address,"u64")~=base+0x27b5260 then return false end
    local flags=shared.a11y.menu_read(address+0xc,"u32")
    if not flags or flags%8~=7 then return false end
    for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
        if shared.a11y.native_dialog_window(window) and shared.a11y.record_contains({address=address},window,window.root) then return true end
    end
    return false
end

function shared.a11y.native_text_presented(address)
    if not shared.a11y.cursor_member_live(address) then return false end
    if shared.a11y.native_widget_allowed(address) then return true end
    if shared.a11y.native_dialog_text_presented(address) then return true end
    local member=address and shared.a11y.native_windows and shared.a11y.native_windows.members[tonumber(address)]
    return member and member.presented==true
        and shared.a11y.menu_node_active(tonumber(address),tonumber(shared.process_base_u64))==true
end

function shared.a11y.menu_node_active(address, base)
    if not address or not base then return nil end
    local vtable = shared.a11y.menu_read(address, "u64")
    if not vtable then return nil end
    if vtable ~= base + 0x27b5260 and vtable ~= base + 0x27c3a38 then return false end
    local flags = shared.a11y.menu_read(address + 0xc, "u32")
    if flags == nil then return nil end
    -- Same predicate as Node::state getter at 0xe4bb70; unlike cursorOver,
    -- this includes the current propagated state of the node.
    return flags % 8 == 7 and math.floor(flags / 256) % 2 == 1
end

function shared.a11y.native_key_allowed(key)
    local node = key and shared.a11y.ui_model and shared.a11y.ui_model.nodes[key]
    return not node or shared.a11y.native_widget_allowed(node.address)
end

function shared.a11y.native_presentation_ready(address)
    if address and not shared.a11y.native_text_presented(address) then return false end
    if not shared.a11y.native_windows_enabled then return true end
    local member=address and shared.a11y.native_windows and shared.a11y.native_windows.members[tonumber(address)]
    if member and member.presented and not member.active then return true end
    if member and member.owners and #member.owners>0 then
        for _,owner in ipairs(member.owners) do
            if owner.enabled and owner.root and owner.root>=0x10000 then return true end
        end
        return false
    end
    for _,window in ipairs(shared.a11y.native_windows and shared.a11y.native_windows.windows or {}) do
        if window.enabled and window.root and window.root>=0x10000 then return true end
    end
    return false
end

-- A native owner/tree, not string loading, establishes these review entries.
-- Sorting uses observation sequence; no inferred visual coordinates/categories.
function shared.a11y.observe_control_font(data,offset,total)
    if total>4194304 or offset<0 then return end
    if offset==0 then
        shared.a11y.control_font_scan={a=1,b=0,next=0,total=total}
        shared.a11y.control_font_family=nil
    end
    local scan=shared.a11y.control_font_scan
    if not scan or scan.next~=offset or scan.total~=total then return end
    local a,b=scan.a,scan.b
    for index=1,#data do a=(a+data:byte(index))%65521;b=(b+a)%65521 end
    scan.a,scan.b,scan.next=a,b,offset+#data
    if scan.next==total then
        -- Signatures of the local font assets inspected as actual glyph bitmaps.
        local known={
            ["55036:38782804"]="playstation",["760560:3728391537"]="playstation",
            ["47727:2475288431"]="xbox",["757104:3636751182"]="xbox",
            ["108565:763610868"]="xbox",["3021552:1135989911"]="xbox",
        }
        shared.a11y.control_font_family=known[tostring(total)..":"..tostring(b*65536+a)]
        log("[FLAccess] control-font=" .. tostring(shared.a11y.control_font_family or "unrecognized"))
        shared.a11y.control_font_scan=nil
    end
end

-- Renderer parser e2b050 dispatches j/k to these exact callbacks. Read their
-- current mapping and symbol pointer; never call game code or infer letters.
function shared.a11y.native_control_marker(kind,letter)
    local base=tonumber(shared.process_base_u64)
    local index=letter:byte()-0x61
    local category=kind=="j" and 0 or kind=="k" and 1
    if not base or not category or index<0 or index>=(category==0 and 15 or 9) then return nil end
    if shared.a11y.menu_read(base+0x36f9590+category*8,"u64")
            ~=base+(category==0 and 0xe264b0 or 0xe26960) then return nil end
    local mapped=shared.a11y.menu_read(base+(category==0 and 0x27ae3b8 or 0x27ae3f8)+index*4,"u32")
    if not mapped or mapped>33 then return nil end
    local at=base+0x34c0660+mapped*0x10
    local pointer=shared.a11y.menu_read(at+8,"u64")
    if pointer==0 and (mapped==32 or mapped==33) then
        mapped=shared.a11y.menu_read(base+0x34c08c0+(mapped-32)*4,"u32")
        if not mapped or mapped>31 then return nil end
        at=base+0x34c0660+mapped*0x10
        pointer=shared.a11y.menu_read(at+8,"u64")
    end
    if not pointer or pointer<0x10000 then return nil end
    local symbol=shared.a11y.read_native_c_string(pointer,128)
    if not symbol or symbol=="" or symbol:find("\17",1,true) then return nil end
    return symbol
end

function shared.a11y.control_symbol_text(text)
    local family=shared.a11y.control_font_family
    if not (text:find("\17",1,true) or text:find("\238\128",1,true)) then return text end
    local captions=family=="playstation"
        and {[0]="Círculo",[1]="Cruz",[2]="Triângulo",[3]="Quadrado",[4]="R1",[5]="R2",[6]="L1",[7]="L2",[8]="Options",[9]="Share",[14]="R3",[15]="L3"}
        or {[0]="B",[1]="A",[2]="Y",[3]="X",[4]="RB",[5]="RT",[6]="LB",[7]="LT",[8]="Menu",[9]="Exibir",[14]="RS",[15]="LS"}
    local function caption(index)
        if not family then return nil end
        local value=captions[index]
        if not value then return nil end
        if shared.a11y.ui_language~="pt" then
            if value=="Círculo" then value="Circle" elseif value=="Cruz" then value="Cross"
            elseif value=="Triângulo" then value="Triangle" elseif value=="Quadrado" then value="Square"
            elseif value=="Exibir" then value="View" end
        end
        return (shared.a11y.ui_language=="pt" and "botão " or "button ") .. value
    end
    -- Markup follows the current renderer binding, including remapped confirm
    -- and cancel. Literal digits still are not physical button indices.
    text=text:gsub("\17([jk])([a-o])",function(kind,letter)
        local symbol=shared.a11y.native_control_marker(kind,letter)
        if symbol then
            if symbol:find("\238\128",1,true) then return symbol end
            if symbol:match("^[%w%s%-_]+$") then
                return (shared.a11y.ui_language=="pt" and "tecla " or "key ") .. symbol
            end
        end
        if kind=="k" and letter=="a" and family then return caption(1) end
        return "\17" .. kind .. letter
    end)
    return text:gsub("\238\128[\128-\143]",function(glyph)
        return caption(glyph:byte(3)-128) or glyph
    end)
end

function shared.a11y.output_speech_text(text)
    for _,role in ipairs({"seletor","selector","campo de texto","text field",
            "ativar para editar","activate to edit","controle deslizante","slider"}) do
        text=text:gsub(", " .. role .. ",",","):gsub(", " .. role .. "$","")
    end
    for _,suffix in ipairs({"item selecionado","botão selecionado","opção selecionada",
            "selecionado","selecionada","item","selected item","selected button",
            "selected option","selected","button selected"}) do text=text:gsub(", " .. suffix .. "$","") end
    return text
end

function shared.a11y.unresolved_format(text)
    return text and text:find("%%[%d%$%.%-%+]*[sdifucxX]")~=nil
end

function shared.a11y.read_native_c_string(address,limit)
    address=tonumber(address)
    if not address then return nil end
    if not address or address<0x10000 then return nil end
    local parts={}
    for offset=0,(limit or 2048)-1,64 do
        local size=math.min(64,(limit or 2048)-offset)
        while size>0 and not shared.readable(address+offset,size) do size=math.floor(size/2) end
        if size==0 then return nil end
        local bytes=shared.a11y.safe_memory_read(address+offset,size)
        if not bytes or #bytes~=size then return nil end
        local zero=bytes:find("\0",1,true)
        parts[#parts+1]=zero and bytes:sub(1,zero-1) or bytes
        if zero then return table.concat(parts) end
        if size<64 then return nil end
    end
end


    shared.stage = 8
end
function component.init(ctx)
    component.install(ctx)

end
return component
