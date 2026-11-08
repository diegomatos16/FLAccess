-- FLAccess 0.2.0. Native Sider component; maintained source.
local component = {}
function component.install(ctx)
    assert(ctx.flaccess, "FLAccess core must load first")
    local shared = ctx.flaccess.reader
    assert(shared.stage == 9, "FLAccess reader: missing or reordered component players")
function shared.a11y.player_search_context()
    return (shared.a11y.menu_flow_name or ""):match("/MLNegoSearchResultMemberList%.json$")~=nil
end
function shared.a11y.player_search_ready()
    if shared.a11y.search_results_ready then return true end
    local context=shared.a11y.read_context_state()
    if context.kind=="dialog" and (context.structural_question or context.structural_event) then return true end
    local snapshot=shared.a11y.native_windows
    local base=tonumber(shared.process_base_u64)
    if not snapshot or not base then return false end
    for address in pairs(snapshot.selected_members or {}) do
        if shared.a11y.widget_internal_name(address)=="playerName"
                and shared.a11y.menu_node_active(address,base)==true
                and shared.a11y.native_presentation_ready(address)
                and not shared.a11y.empty_selection_caption(shared.a11y.read_native_rendered_text(address)) then
            shared.a11y.search_results_ready=true;return true
        end
    end
    return false
end

function shared.a11y.poll_player_search_loading()
    if not shared.a11y.player_search_context() then shared.a11y.search_loading_notice=nil;return false end
    if shared.a11y.player_search_ready() then shared.a11y.search_loading_notice=nil;return false end
    if not shared.a11y.search_loading_notice then
        shared.a11y.clear_speech_queue()
        shared.a11y.search_loading_notice={}
        local before=shared.a11y.native_speech_last
        shared.speak(shared.a11y.ui_language=="pt" and "Carregando tela" or "Loading screen",true,true,"search-loading:" .. shared.frame)
        for i=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[i].search_loading=shared.a11y.search_loading_notice end
    end
    return true
end

function shared.a11y.player_row_details(node,explicit)
    local result={}
    if not node or node.name~="playerName" or shared.a11y.empty_selection_caption(node.text) then return result end
    local unique=0
    local names=shared.a11y.ui_model and shared.a11y.ui_model.names or {}
    for _,other in pairs(names.playerName or {}) do
        if other.name=="playerName" and shared.a11y.component_peers(node.address,other.address)
                and shared.a11y.native_presentation_ready(other.address) and not shared.a11y.empty_selection_caption(other.text) then unique=unique+1 end
    end
    if unique~=1 then return result end
    local search=shared.a11y.player_search_context()
    for _,name in ipairs((explicit or shared.a11y.detail_reads_allowed or search) and {"allOver","noSetting"} or {"noSetting"}) do
        local found
        for _,other in pairs(names[name] or {}) do
            if other.name==name and shared.a11y.component_peers(node.address,other.address)
                    and shared.a11y.native_presentation_ready(other.address) and shared.a11y.ui_node_matches_live(other)
                    and not shared.a11y.empty_selection_caption(other.text) and not shared.a11y.unresolved_format(other.text) then
                if found then found=false;break end
                found=other
            end
        end
        local placeholder=search and name=="noSetting" and (found and (found.text=="Desativar" or found.text=="Disable" or found.text=="Disabled" or found.text=="Desativado"))
        if found and not placeholder and found.text~=node.text then result[#result+1]=found end
    end
    return result
end

shared.a11y.cup_group_non_team_items = {
    ["OK"] = true,
    ["Confirmar"] = true,
    ["Voltar"] = true,
    ["Substituir"] = true,
    ["Atualizar"] = true,
    ["Aleatório"] = true,
    ["Cancelar"] = true,
    ["botão A"] = true,
}

function shared.a11y.native_cup_group(address)
    local snapshot=shared.a11y.native_windows
    local base=tonumber(shared.process_base_u64)
    address=tonumber(address)
    if not base or not address or not snapshot or not snapshot.selected_members
            or not snapshot.selected_members[address] then return end
    local window=shared.a11y.primary_input_window()
    local cursor=window and window.cursor_detail
    if not cursor or not cursor.group_index or cursor.group_index>=8
            or not cursor.item_index or cursor.item_index>=4 or not cursor.selected
            or shared.a11y.menu_read(window.address,"u64")~=base+0x2722620
            or not shared.a11y.record_contains({address=address},window,cursor.selected) then return end
    -- CompeGroupings exposes eight team groups in A–H order. Its other
    -- cursor groups, including the confirmation cell, are not team groups.
    local identity=table.concat({window.address,window.root,cursor.group_index},":")
    local label=(shared.a11y.ui_language=="pt" and "Grupo " or "Group ")
        .. string.char(65+cursor.group_index)
    return {identity=identity,selection=identity .. ":" .. cursor.item_index,label=label}
end

function shared.a11y.cup_group_team_speech(text, widget_key)
    if not shared.a11y.cup_group_table_active
            or shared.a11y.cup_group_non_team_items[text]
            or text:match("^Grupo [A-H]$")
            or text:match("^Group [A-H]$") then
        return nil
    end

    local cell = shared.a11y.cup_group_cell_by_widget[widget_key]
    if not cell then
        local current = shared.a11y.cup_group_current_cell
        local action = shared.a11y.navigation_action
        local recent_navigation = shared.frame - shared.a11y.navigation_frame <= 20
            and shared.a11y.navigation_frame ~=
                shared.a11y.cup_group_last_navigation_frame
        if current then
            cell = {group=current.group, row=current.row}
            if recent_navigation then
                if action == "left" and cell.group % 4 ~= 1 then
                    cell.group = cell.group - 1
                elseif action == "right" and cell.group % 4 ~= 0 then
                    cell.group = cell.group + 1
                elseif action == "up" then
                    if cell.row > 1 then
                        cell.row = cell.row - 1
                    elseif cell.group > 4 then
                        cell.group = cell.group - 4
                        cell.row = 4
                    end
                elseif action == "down" then
                    if cell.row < 4 then
                        cell.row = cell.row + 1
                    elseif cell.group <= 4 then
                        cell.group = cell.group + 4
                        cell.row = 1
                    end
                end
            end
        else
            -- Group assignment opens on the first team in Group A.
            cell = {group=1, row=1}
        end
        shared.a11y.cup_group_cell_by_widget[widget_key] = cell
    end

    if shared.frame - shared.a11y.navigation_frame <= 20 then
        shared.a11y.cup_group_last_navigation_frame = shared.a11y.navigation_frame
    end
    shared.a11y.cup_group_current_cell = cell
    local prefix = ""
    if cell.group ~= shared.a11y.cup_group_last_announced then
        shared.a11y.cup_group_last_announced = cell.group
        local letter = string.char(string.byte("A") + cell.group - 1)
        prefix = (shared.a11y.ui_language == "pt" and "Grupo " or "Group ")
            .. letter .. ". "
    end
    return prefix .. shared.ui_focus_speech(text)
end

function shared.a11y.ignore_cup_group_focus(text)
    -- The group-assignment grid exposes an extra OK focus cell after its
    -- final team. It is not a team and adds no useful navigation information.
    return shared.a11y.cup_group_table_active and text == "OK"
end

-- Classify a list entry from headings in its own native component. Localized
-- words identify the section, while the tree proves the relationship. A label
-- elsewhere in the same resource file or a player's position proves nothing.
function shared.a11y.player_component_section(node)
    local snapshot=shared.a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[tonumber(node.address)]
    if not member or not member.active then return nil end
    local native,_,typed=shared.a11y.native_roster_section(node,member)
    if typed then return native end
    local panel=shared.a11y.native_player_roster_context(node)
    if panel then return panel.section end
    local headings={Titulares="starter",Reservas="reserve",["Não relacionados"]="unselected",
        ["Não relacionado"]="unselected",Starters="starter",Substitutes="reserve",
        ["Starting lineup"]="starter",["Not selected"]="unselected",["Not in squad"]="unselected"}
    local result,conflicting
    for _,owner in ipairs(member.owners or {}) do
        if owner.enabled and owner.parents then
            local parents=owner.parents
            local ancestor=parents[tonumber(node.address)]
            local visited={}
            for _=1,8 do
                if not ancestor or ancestor==owner.root or visited[ancestor] then break end
                visited[ancestor]=true
                local section,ambiguous
                for _,heading in pairs(shared.a11y.ui_model and shared.a11y.ui_model.nodes or {}) do
                    local value=headings[heading.text]
                    local at=tonumber(heading.address)
                    local known=snapshot.members[at]
                    if value and at~=tonumber(node.address) and known and known.active
                            and shared.a11y.native_widget_allowed(at) and shared.a11y.ui_node_matches_live(heading) then
                        local walked={}
                        for _=1,8 do
                            at=parents[at]
                            if not at or walked[at] then break end
                            walked[at]=true
                            if at==ancestor then
                                if section and section~=value then ambiguous=true end
                                section=value;break
                            end
                        end
                    end
                end
                if ambiguous then break end
                if section then
                    if result and result~=section then conflicting=true end
                    result=section;break
                end
                ancestor=parents[ancestor]
            end
        end
    end
    if conflicting then return nil end
    if not result then shared.a11y.component_evidence(node,"player-section-unresolved") end
    return result
end

-- The information panel is a separate sibling Window, not a descendant of
-- the pitch card. Resolve its validated player id through the same model as
-- PitchBase::getPlayer (914280), never through position or discovery order.
function shared.a11y.focused_player_node()
    local context=shared.a11y.read_context_state()
    if context.kind=="dialog" or context.question or shared.a11y.keyboard_window then return nil end
    local snapshot=shared.a11y.native_windows
    local found
    for address in pairs(snapshot and snapshot.controlled_selections or {}) do
        local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[memory.hex(address)]
        if node and shared.a11y.native_caption_selection_identity(address) then
            if found and found~=node then return nil end
            found=node
        end
    end
    return found
end

-- Mirror the record used by 910490: playerInfo_0/1 selects one native
-- (slot, side) descriptor; the squad order resolves its actual player object.
-- This path does not require the old attribute-copy callbacks or name cache.
function shared.a11y.current_player_record(node,basic)
    local base=tonumber(shared.process_base_u64)
    local snapshot=shared.a11y.native_windows
    local binding=node and snapshot and snapshot.controlled_selections and snapshot.controlled_selections[tonumber(node.address)]
    if not base or not binding or not shared.a11y.native_caption_selection_identity(node.address) then return nil end
    local data=shared.a11y.menu_read(base+0x36f38a0,"u64")
    if not data or shared.a11y.menu_read(data,"u64")~=base+0x2618830 then return nil end
    local member=snapshot.members[tonumber(node.address)]
    local variant
    for _,owner in ipairs(member and member.owners or {}) do
        if owner.address==binding.panel and owner.enabled and owner.parents then
            local current=shared.a11y.parameter_caption_variant(node,owner,base)
            if current~=nil then
                if variant~=nil and variant~=current then return nil end
                variant=current
            end
        end
    end
    if variant==nil then return nil end
    local descriptor=data+0xba4+binding.side*0xa8+variant*20
    local slot,side=shared.a11y.menu_read(descriptor,"u32"),shared.a11y.menu_read(descriptor+4,"u32")
    if not slot or slot>=40 or (side~=0 and side~=1) then return nil end
    local record=shared.a11y.menu_read(data+side*0x248+0x1f8+slot,"u8")
    if not record or record>=40 then return nil end
    local object=shared.a11y.menu_read(data+side*0x340+0x568+record*16,"u64")
    if not object or object<0x10000 then return nil end
    local id=shared.a11y.menu_read(object+0x30,"u32")
    local name=shared.a11y.read_native_c_string(object+0x38,64)
    local heading=shared.a11y.normalized_player_name(node.text)
    if not id or id==0 or not name or #name<2 or name:find("%c")
            or not heading or heading:sub(1,#name)~=name then return nil end
    if basic then
        return {data=data,object=object,player_id=id,slot=slot,side=side,record=record,descriptor_offset=descriptor-data,
            identity=table.concat({binding.identity,variant,slot,side,record,object,id},":")}
    end
    local primary=shared.a11y.menu_read(object+4,"u32")
    primary=primary and math.floor(primary/0x10000000)
    if primary and primary>12 then primary=nil end
    local secondary={}
    local first,last=shared.a11y.menu_read(object+0x1c,"u32"),shared.a11y.menu_read(object+0x20,"u32")
    if first and last then
        for position=0,12 do
            local value=position<3 and math.floor(first/2^(25+position*2))%4
                or math.floor(last/2^((position-3)*2))%4
            if value>2 then secondary=nil;break end
            if value>0 and position~=primary then secondary[#secondary+1]={position=position,level=value} end
        end
    else secondary=nil end
    local field_position
    if slot<11 then
        local tactic=shared.a11y.menu_read(data+side*0xa8+0xb34,"u32")
        if tactic and tactic<3 then
            local phase=0
            local enabled=shared.a11y.menu_read(data+side*0x248+tactic*0xa0+0xb4,"u8")
            if enabled and enabled~=0 then phase=shared.a11y.menu_read(data+side*0xa8+0xb38,"u32") end
            if enabled and phase and phase<3 then
                field_position=shared.a11y.menu_read(data+side*0x248+0x18+tactic*0xa0+phase*0x21+slot,"u8")
                if field_position and field_position>12 then field_position=nil end
            end
        end
    end
    return {data=data,object=object,player_id=id,slot=slot,side=side,record=record,descriptor_offset=descriptor-data,
        primary=primary,secondary=secondary,field_position=field_position,
        identity=table.concat({binding.identity,variant,slot,side,record,object,id},":")}
end

-- 911650 renders playStyle through 8e1f40/14c0300, property 3b.
-- Its code translation and localization-ID table are independent of position.
function shared.a11y.load_player_style_schema()
    local base=tonumber(shared.process_base_u64)
    if not base or base==0 then return end
    local ids={}
    for index=0,21 do
        local value=shared.a11y.menu_read(base+0x27d3500+index*8,"u32")
        if value and value>0 then ids[value]=true end
    end
    shared.a11y.player_style_ids=ids
end

function shared.a11y.load_player_style_assets()
    shared.a11y.player_style_asset_texts={pt={},en={}}
    if not shared.a11y.use_text_assets or not shared.a11y.sider_dir or not shared.a11y.player_style_ids then return end
    for _,language in ipairs({"pt","en"}) do
        local path=shared.a11y.sider_dir .. "\\content\\FlAccess\\text\\styles-" .. language .. ".tsv"
        local file=io.open(path,"rt")
        if file then
            local labels,invalid,count={},false,0
            for line in file:lines() do
                if line:sub(1,1)~="#" then
                    local id,text=line:match("^(%d+)\t([^\t]+)$")
                    id=tonumber(id)
                    if not id or not shared.a11y.player_style_ids[id] or not text or #text>120 or count>=64
                            or (labels[id] and labels[id]~=text) then invalid=true;break end
                    labels[id]=text;count=count+1
                end
            end
            file:close()
            if not invalid then shared.a11y.player_style_asset_texts[language]=labels end
            log("[FLAccess] style-assets language=" .. language .. " labels=" .. tostring(invalid and 0 or count))
        end
    end
end

function shared.a11y.remember_player_style_text(id,text)
    if shared.a11y.player_style_ids and shared.a11y.player_style_ids[id] then
        shared.a11y.player_style_texts=shared.a11y.player_style_texts or {}
        shared.a11y.player_style_texts[shared.a11y.ui_language]=shared.a11y.player_style_texts[shared.a11y.ui_language] or {}
        shared.a11y.player_style_texts[shared.a11y.ui_language][id]=text
    end
end

function shared.a11y.player_style_text(record)
    local base=tonumber(shared.process_base_u64)
    local packed=record and shared.a11y.menu_read(record.object+0x1c,"u32")
    local index=packed and math.floor(packed/2^11)%32
    if not base or not index or index>=22 then return nil end
    local code=shared.a11y.menu_read(base+0x2979080+index*4,"u32")
    if not code or code>=22 then return nil end
    if code==0 then return shared.a11y.ui_language=="pt" and "Sem estilo de jogo" or "No playing style" end
    local id=shared.a11y.menu_read(base+0x27d3500+code*8,"u32")
    local texts=shared.a11y.player_style_texts and shared.a11y.player_style_texts[shared.a11y.ui_language]
    local assets=shared.a11y.player_style_asset_texts and shared.a11y.player_style_asset_texts[shared.a11y.ui_language]
    return (texts and texts[id]) or (assets and assets[id])
end

function shared.a11y.player_detail_packet()
    local node=shared.a11y.focused_player_node()
    if not node then return nil end
    local record=shared.a11y.current_player_record(node)
    local pt=shared.a11y.ui_language=="pt"
    local names=shared.a11y.player_position_names[shared.a11y.ui_language] or shared.a11y.player_position_names.en
    local fields={{key="name",text=node.text}}
    local style=shared.a11y.player_style_text(record)
    fields[#fields+1]={key="style",text=style and
        ((pt and "Estilo de jogo: " or "Playing style: ") .. style)
        or (pt and "Estilo de jogo indisponível." or "Playing style unavailable.")}
    if shared.a11y.player_secondary_verified and record and record.secondary then
        local parts={}
        for _,position in ipairs(record.secondary) do
            if position.level==2 or shared.a11y.player_secondary_partial then
                parts[#parts+1]=names[position.position] .. (position.level==1
                    and (pt and " (adaptação parcial)" or " (partial familiarity)")
                    or (pt and " (adaptação completa)" or " (full familiarity)"))
            end
        end
        if #parts>0 then fields[#fields+1]={key="secondary",text=(pt and "Posições secundárias: " or "Secondary positions: ") .. table.concat(parts,", ")} end
    end
    local field=record and record.slot>=11 and (pt and "Não está no campo." or "Not on the pitch.")
        or record and record.field_position and ((pt and "Posição no campo: " or "Position on the pitch: ") .. names[record.field_position])
        or (pt and "Posição no campo indisponível." or "Position on the pitch unavailable.")
    fields[#fields+1]={key="field",text=field}
    return {node=node,record=record,fields=fields,generation=shared.a11y.read_context_state().generation,
        identity=node.identity .. ":" .. node.text .. ":" .. (shared.a11y.native_caption_selection_identity(node.address) or "")
            .. ":" .. (record and record.identity or "unknown")}
end

function shared.a11y.player_details_allowed(origin)
    local packet=shared.a11y.player_detail_packet()
    if not packet or packet.identity~=origin.identity or packet.generation~=origin.generation then return false end
    for _,field in ipairs(packet.fields) do
        if field.key==origin.key then return field.text==origin.text end
    end
    return false
end

function shared.a11y.read_player_details(action)
    local packet=shared.a11y.player_detail_packet()
    if not packet then shared.a11y.player_detail_review=nil;return false end
    local state=shared.a11y.player_detail_review
    if not state or state.identity~=packet.identity or state.generation~=packet.generation then
        state={identity=packet.identity,generation=packet.generation,index=0};shared.a11y.player_detail_review=state
    end
    local count=#packet.fields
    if action=="first" then state.index=1
    elseif action=="next" then state.index=state.index%count+1
    elseif action=="previous" then state.index=state.index==0 and count or (state.index-2)%count+1
    elseif state.index==0 or state.index>count then state.index=1 end
    local field=packet.fields[state.index]
    state.sequence=(state.sequence or 0)+1
    local before=shared.a11y.native_speech_last
    shared.modal_focus_hold_until_ms=0;shared.a11y.title_pending_first_item=nil;shared.a11y.deferred_modal_announcement=nil
    shared.speak(field.text,true,true,"player-review:" .. packet.identity .. ":" .. state.sequence,packet.node.address)
    local origin={identity=packet.identity,generation=packet.generation,key=field.key,text=field.text}
    for index=before+1,shared.a11y.native_speech_last do shared.a11y.native_speech_queue[index].player_details=origin end
    return true
end

-- Read the same rule as 8e9210/15098a0 without calling game code. Competition
-- database lookups not resolved here remain unknown; FFFF selects the current
-- match configuration's native +33 getter (14c0d50).
function shared.a11y.live_roster_limit(data)
    local base=tonumber(shared.process_base_u64)
    if not base or not data then return nil end
    local mode=shared.a11y.menu_read(data+8,"u32")
    if mode==4 then return 23 end
    if mode==nil or mode==0 or mode==1 or mode==3 or mode==8 then return nil end
    local flow=shared.a11y.menu_read(base+0x3704e38,"u64")
    local index=flow and shared.a11y.menu_read(flow+0xf0,"u32")
    if not index or index>=61 then return nil end
    local category=shared.a11y.menu_read(base+0x34fc9c0+index*16,"u32")
    local manager=shared.a11y.menu_read(base+0x3705e10,"u64")
    local config=manager and shared.a11y.menu_read(manager+0x50,"u64")
    if not category or not config or config<0x10000 then return nil end
    local rule
    if category>=7 and category<=10 then
        return nil
    elseif index<=39 and math.floor(0xd7c0000000/2^index)%2==1 then
        rule=shared.a11y.menu_read(config+0x35968,"u16")
    else rule=0xffff end
    if rule~=0xffff then return nil end
    local limit=shared.a11y.menu_read(config+0x35993,"u8")
    if limit and limit>=11 and limit<=40 then return limit end
end

function shared.a11y.native_player_roster_context(node)
    if not node or node.name~="playerName" then return nil end
    local work=shared.a11y.render_read_work
    local key=node.key .. ":" .. node.text
    if work and work.rosters and work.rosters[key]~=nil then return work.rosters[key] or nil end
    local value=shared.a11y.read_native_player_roster_context(node)
    if work then work.rosters=work.rosters or {};work.rosters[key]=value or false end
    return value
end

function shared.a11y.roster_card_speech(roster)
    if not roster or (roster.side~=0 and roster.side~=1)
            or not roster.record or roster.record<0 or roster.record>=40 or not roster.player_id then return "" end
    local base=tonumber(shared.process_base_u64)
    if not base then return "" end
    local data=shared.a11y.menu_read(base+0x36f38a0,"u64")
    if not data or shared.a11y.menu_read(data,"u64")~=base+0x2618830
            or shared.a11y.menu_read(base+0x915253,"u32")~=0x7504f883
            or shared.a11y.menu_read(base+0x91528d,"u32")~=0x7505f883 then return "" end
    local slot=data+roster.side*0x340+0x560+roster.record*16
    local object=shared.a11y.menu_read(slot+8,"u64")
    if not object or object<0x10000 or shared.a11y.menu_read(object+0x30,"u32")~=roster.player_id then return "" end
    local status=shared.a11y.menu_read(slot,"u32")
    if status==4 then return shared.a11y.ui_language=="pt" and ", cartão amarelo" or ", yellow card" end
    if status==5 then return shared.a11y.ui_language=="pt" and ", cartão vermelho" or ", red card" end
    return ""
end

local function roster_limit(window,root,impl,side,data)
    local limit=shared.a11y.live_roster_limit(data)
    if limit then return limit end
    local bound=shared.a11y.roster_limits and shared.a11y.roster_limits[window]
    if bound and bound.root==root and bound.impl==impl and bound.side==side
            and bound.limit>=11 and bound.limit<=40 then return bound.limit end
end

function shared.a11y.read_native_player_roster_context(node)
    if not node or node.name~="playerName" then return nil end
    local snapshot=shared.a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[tonumber(node.address)]
    local base=tonumber(shared.process_base_u64)
    if not base or not member or not member.active or not shared.a11y.native_presentation_ready(node.address)
            or not shared.a11y.ui_node_matches_live(node) or shared.a11y.read_native_rendered_text(node.address)~=node.text then return nil end
    local target=shared.a11y.normalized_player_name(node.text)
    local live=shared.a11y.current_player_record(node,true)
    local player=live and {player_id=live.player_id}
    for name,entry in pairs(not live and shared.a11y.game_plan_player_cache or {}) do
        if target and (target==name or target:sub(1,#name)==name) and entry.player_id and entry.player_id>0 then
            if player and player.player_id~=entry.player_id then return nil end
            player=entry
        end
    end
    if not player then return nil end
    local data=shared.a11y.menu_read(base+0x36f38a0,"u64") -- 8e1af0's singleton
    if not data or shared.a11y.menu_read(data,"u64")~=base+0x2618830 then return nil end
    local windows={}
    for _,window in ipairs(snapshot.windows or {}) do windows[window.address]=window end
    local binding=snapshot.controlled_selections and snapshot.controlled_selections[tonumber(node.address)]
    local controller=live and binding and windows[binding.window]
    if controller and controller.cursor_detail then
        local target=shared.a11y.cursor_player_target(controller,controller.cursor_detail,binding.side,snapshot,base)
        if target and target.slot==live.slot and target.side==live.side and target.object==live.object then
            local root,impl=shared.a11y.roster_presentation_root(target.window)
            local limit=target.slot>=11 and roster_limit(target.window,root,impl,target.side,data) or nil
            local section=target.slot<11 and "starter" or limit and (target.slot<limit and "reserve" or "unselected")
            if section then
                return {section=section,identity=live.identity .. ":" .. target.window .. ":" .. (limit or -1),
                    window=target.window,slot=target.slot,player_id=target.id,side=target.side,
                    record=target.record,root=root,limit=limit}
            end
        end
    end
    local result
    for _,owned in ipairs(member.owners or {}) do
        local panel=windows[owned.address]
        if owned.enabled and panel and panel.enabled and panel.task_parent
                and shared.a11y.menu_read(panel.address,"u64")==base+0x261e0c8 then
            local side=shared.a11y.menu_read(panel.address+0x98,"u32")
            if side==0 or side==1 then
                for _,window in ipairs(snapshot.windows) do
                    local vt=window.enabled and shared.a11y.menu_read(window.address,"u64")
                    local pitch=vt==base+0x261eaa0
                    local subs=vt==base+0x261f788
                    if (pitch or subs) and window.task_parent==panel.task_parent
                            and shared.a11y.menu_read(window.address+0x98,"u32")==side then
                        local root,impl=shared.a11y.roster_presentation_root(window.address)
                        local flags=root and shared.a11y.menu_read(root+0xc,"u32")
                        local scroll=pitch and 0 or shared.a11y.menu_read(window.address+0x4e8,"u32")
                        if flags and flags%8==7 and scroll and scroll<=29 then
                            for index=0,(pitch and 10 or 11) do
                                local slot=pitch and index or index+scroll+11
                                local record=shared.a11y.menu_read(window.address+0x2a0+index*4,"u32")
                                local order=slot<40 and shared.a11y.menu_read(data+side*0x248+0x1f8+slot,"u8")
                                local card=shared.a11y.menu_read(window.address+0xb8+index*8,"u64")
                                local shown=card and card>=0x10000 and shared.a11y.menu_read(card+0xc,"u32")
                                if record and record<40 and order==record and shown and shown%8==7 then
                                    local object=shared.a11y.menu_read(data+side*0x340+0x568+record*16,"u64")
                                    local id=object and object>=0x10000 and shared.a11y.menu_read(object+0x30,"u32")
                                    if id==player.player_id then
                                        local section,limit="starter",nil
                                        if subs then
                                            limit=roster_limit(window.address,root,impl,side,data)
                                            section=limit and (slot<limit and "reserve" or "unselected")
                                        end
                                        local identity=table.concat({panel.address,window.address,root,side,slot,record,object,id,limit or -1},":")
                                        if result and result.identity~=identity then return nil end
                                        result={section=section,identity=identity,window=window.address,slot=slot,player_id=id,
                                            side=side,record=record,root=root,limit=limit}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return result
end

-- A pitch/card array proves the displayed slot. Player position and names
-- cannot classify it. Substitute slot indices include the native scroll offset;
-- the match-rule boundary is recorded from the game's actual return value.
function shared.a11y.roster_presentation_root(address)
    local base=tonumber(shared.process_base_u64)
    local impl=shared.a11y.menu_read(address+0x88,"u64")
    if not base or not impl or impl<0x10000 then return nil end
    -- Pitch/PitchSubstitute have no navigation root in the real dev 21
    -- capture. e3d790 uses Impl+90, including in the boundary renderer.
    local root=shared.a11y.menu_read(impl+0x90,"u64")
    local vt=root and root>=0x10000 and shared.a11y.menu_read(root,"u64")
    if vt and shared.a11y.native_layout.holders[vt-base] then return root,impl end
    root=shared.a11y.menu_read(impl+0x98,"u64")
    return root and root>=0x10000 and root or nil,impl
end

function shared.a11y.native_roster_section(node,member)
    local base=tonumber(shared.process_base_u64)
    if not base then return nil end
    local result,identity,matched
    for _,owner in ipairs(member.owners or {}) do
        local vt=owner.enabled and shared.a11y.menu_read(owner.address,"u64")
        local pitch=vt==base+0x261eaa0
        local substitutes=vt==base+0x261f788
        if (pitch or substitutes) and owner.parents then
            local ancestors,at={},tonumber(node.address)
            for _=1,12 do
                if not at or ancestors[at] then break end
                ancestors[at]=true
                if at==owner.root then break end
                at=owner.parents[at]
            end
            local found,ambiguous
            for index=0,(pitch and 10 or 11) do
                for _,offset in ipairs({0xb8,0x118}) do
                    local card=shared.a11y.menu_read(owner.address+offset+index*8,"u64")
                    if card and ancestors[card] then
                        if found and found~=index then ambiguous=true end
                        found=index
                    end
                end
            end
            if ambiguous then return nil,nil,true end
            if found and not ambiguous then
                local value,slot,limit= nil,found,nil
                matched=true
                local root,impl=shared.a11y.roster_presentation_root(owner.address)
                if not root then return nil,nil,true end
                if pitch then value="starter" else
                    local scroll=shared.a11y.menu_read(owner.address+0x4e8,"u32")
                    local bound=shared.a11y.roster_limits and shared.a11y.roster_limits[owner.address]
                    if scroll and scroll<=29 and found+scroll+11<40 and bound
                            and bound.impl==impl and bound.root==root
                            and bound.side==shared.a11y.menu_read(owner.address+0x98,"u32")
                            and bound.limit>=11 and bound.limit<=40 then
                        value=found+scroll+11<bound.limit and "reserve" or "unselected"
                        slot,limit=found+scroll+11,bound.limit
                    end
                end
                local current=tostring(owner.address) .. ":" .. tostring(root or owner.root) .. ":" .. tostring(slot)
                    .. ":" .. tostring(limit) .. ":" .. tostring(value)
                    .. ":" .. tostring(shared.a11y.menu_read(owner.address+0x98,"u32"))
                if identity and identity~=current then return nil,nil,true end
                identity=current
                if value and result and result~=value then return nil,nil,true end
                result=value or result
            end
        end
    end
    return result,identity,matched
end

function shared.m.on_roster_rule_boundary(ctx,event_id,registers)
    local address=tonumber(shared.read_u64(registers.rdi))
    local limit=tonumber(shared.read_u64(registers.rbx))
    local base=tonumber(shared.process_base_u64)
    if not base or not address or not limit or shared.a11y.menu_read(address,"u64")~=base+0x261f788 then return end
    limit=limit%256
    local root,impl=shared.a11y.roster_presentation_root(address)
    if not root or root<0x10000 then return end
    local side=shared.a11y.menu_read(address+0x98,"u32")
    if side~=0 and side~=1 then return end
    shared.a11y.roster_limits=shared.a11y.roster_limits or {}
    shared.a11y.roster_limits[address]={impl=impl,root=root,limit=limit,
        side=side,frame=shared.frame}
    shared.a11y.component_capture_dirty_frame=shared.frame
end

function shared.a11y.prune_roster_limits(snapshot)
    local registered
    for address,bound in pairs(shared.a11y.roster_limits or {}) do
        -- Construction can record the rule just before manager registration.
        -- Keep that short handoff, not a cache belonging to a closed component.
        if shared.frame-(bound.frame or -10000)>2 then
            if not registered then
                registered={}
                for _,window in ipairs(snapshot.windows or {}) do registered[window.address]=window end
            end
            local window=registered[address]
            local flags=shared.a11y.menu_read(bound.root+0xc,"u32")
            local root,impl=shared.a11y.roster_presentation_root(address)
            if not window or window.impl~=bound.impl or impl~=bound.impl or root~=bound.root
                    or not flags or math.floor(flags/4)%2~=1 then shared.a11y.roster_limits[address]=nil end
        end
    end
end

function shared.a11y.game_plan_player_section(text, heading_widget_key)
    local target=shared.a11y.normalized_player_name(text)
    if not target then return nil end
    local heading=heading_widget_key and shared.a11y.ui_model and shared.a11y.ui_model.nodes[heading_widget_key]
    local panel=heading and heading.text==text and shared.a11y.native_player_roster_context(heading)
    if panel then return panel.section end
    local section,conflicting
    for key,node in pairs(shared.a11y.ui_model and shared.a11y.ui_model.nodes or {}) do
        if key~=heading_widget_key and shared.a11y.normalized_player_name(node.text)==target
                and shared.a11y.native_widget_allowed(node.address) and shared.a11y.ui_node_matches_live(node) then
            local value=shared.a11y.player_component_section(node)
            if value and section and section~=value then conflicting=true end
            if value then section=value end
        end
    end
    if conflicting then return nil end
    return section
end

function shared.a11y.game_plan_lineup_screen_visible()
    if not shared.a11y.game_plan_active then return false end
    local context = shared.a11y.game_plan_context
    return context == "Escalação/Editar posição"
        or context == "Team Sheet/Edit Position"
        or context == "Plano de jogo normal"
        or context == "Normal Game Plan"
end

function shared.a11y.read_visible_game_plan_lineup()
    if not shared.a11y.game_plan_lineup_screen_visible() then return false end
    local generation_frame = shared.a11y.game_plan_lineup_generation_frame
    local players = {}
    local observed_starters = 0
    for _, observed in pairs(shared.a11y.game_plan_observed_lineup) do
        local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[observed.widget]
        if observed.section == "starter" and node
                and shared.a11y.game_plan_player_section(node.text,nil)=="starter" then
            observed_starters = observed_starters + 1
        end
    end
    if observed_starters == 11 then
        for name, observed in pairs(shared.a11y.game_plan_observed_lineup) do
            local node=shared.a11y.ui_model and shared.a11y.ui_model.nodes[observed.widget]
            local current=node and shared.a11y.game_plan_player_section(node.text,nil)
            if current then players[name] = {
                name = name,
                section = current,
                number = observed.number or 999,
                widget = observed.widget,
            } end
        end
    else
        for widget_key, entry in pairs(shared.ui_focus_widgets) do
            local name = shared.a11y.normalized_player_name(entry.text)
            if name and entry.address and not players[name] then
                local section = shared.a11y.game_plan_player_section(entry.text, nil)
                if section then
                    players[name] = {
                        name = name,
                        section = section,
                        number = tonumber(entry.text:match("^%s*(%d+)%s+")) or 999,
                        widget = widget_key,
                    }
                end
            end
        end
    end
    local starters, reserves, unselected = {}, {}, {}
    for _, player in pairs(players) do
        local target = player.section == "starter" and starters
            or player.section == "reserve" and reserves or unselected
        target[#target + 1] = player
    end
    local function order(left, right)
        if left.number ~= right.number then return left.number < right.number end
        return left.name < right.name
    end
    table.sort(starters, order)
    table.sort(reserves, order)
    table.sort(unselected, order)
    log(string.format(
        "[FLAccess] lineup-read generation=%d starters=%d reserves=%d",
        generation_frame, #starters, #reserves))
    -- A football starting eleven must contain exactly eleven authoritative
    -- pitch containers. Never turn an incomplete/ambiguous scan into speech.
    if #starters ~= 11 then
        shared.speak(shared.a11y.ui_language == "pt"
            and "A escalação ainda não foi identificada com segurança."
            or "The lineup has not been identified safely yet.")
        return false
    end
    local function names(items)
        local result = {}
        for _, item in ipairs(items) do result[#result + 1] = item.name end
        return table.concat(result, ", ")
    end
    local spoken
    if shared.a11y.ui_language == "pt" then
        spoken = "Escalação. Titulares: " .. names(starters)
            .. ". Reservas: " .. names(reserves)
            .. (#unselected>0 and ". Não relacionados: " .. names(unselected) or "")
    else
        spoken = "Lineup. Starters: " .. names(starters)
            .. ". Reserves: " .. names(reserves)
            .. (#unselected>0 and ". Not selected: " .. names(unselected) or "")
    end
    shared.speak(spoken)
    local now_ms = tonumber(ffi.C.GetTickCount64())
    shared.a11y.game_plan_attribute_hold_until_ms = now_ms
        + math.min(12000, math.max(3500, #spoken * 55 + 500))
    return true
end

function shared.a11y.game_plan_focus_speech(text, widget_key)
    local context = shared.a11y.game_plan_context
    local node=widget_key and shared.a11y.ui_model and shared.a11y.ui_model.nodes[widget_key]
    local roster=node and shared.a11y.native_player_roster_context(node)
    local roster_identity=roster and roster.identity
    if shared.a11y.game_plan_basic_prompt_items[text]
            and not shared.a11y.game_plan_basic_prompt_active then
        return nil
    end
    if shared.a11y.game_plan_active
            and text == shared.a11y.game_plan_last_focus_text
            and context == shared.a11y.game_plan_announced_context
            and roster_identity==shared.a11y.game_plan_last_roster_identity then
        return nil
    end
    local tactical_label, tactical_value =
        text:match("^(.+)%s+:%s+(.+)$")
    local announcement
    if tactical_label and tactical_value
            and shared.a11y.game_plan_tactical_labels[tactical_label] then
        announcement = tactical_label .. (shared.a11y.ui_language == "pt"
            and ", seletor, " or ", selector, ") .. tactical_value
    else
        announcement = shared.ui_focus_speech(text)
    end
    announcement=announcement .. shared.a11y.roster_card_speech(roster)
    local player = shared.a11y.player_for_text(text)
    local player_focus = (player or text:match("^%d+%s+%S"))
        and (shared.a11y.game_plan_edit_contexts[context]
            or text:match("^%d+%s+%S"))
    if player_focus then
        local section = shared.a11y.game_plan_player_section(text, widget_key)
        if section then
            shared.a11y.game_plan_last_player_section = section
            local normalized_name = shared.a11y.normalized_player_name(text)
            if normalized_name then
                shared.a11y.game_plan_observed_lineup[normalized_name] = {
                    section = section,
                    number = tonumber(text:match("^%s*(%d+)%s+")) or 999,
                    widget = widget_key,
                }
            end
            local section_speech
            if shared.a11y.ui_language == "pt" then
                section_speech = section == "starter"
                    and "Titular. " or section=="reserve" and "Reserva. " or "Não relacionado. "
            else
                section_speech = section == "starter"
                    and "Starter. " or section=="reserve" and "Substitute. " or "Not selected. "
            end
            announcement = section_speech .. announcement
        else
            -- Never let an unclassified player inherit the preceding section.
            -- This was why Salah sounded like a reserve despite no match.
            shared.a11y.game_plan_last_player_section = nil
        end
    elseif not shared.a11y.game_plan_edit_contexts[context] then
        shared.a11y.game_plan_last_player_section = nil
    end
    if shared.a11y.game_plan_active then
        shared.a11y.game_plan_last_focus_text = text
        shared.a11y.game_plan_last_roster_identity=roster_identity
        shared.a11y.game_plan_last_focus_widget = widget_key
        shared.a11y.game_plan_last_focus_frame = shared.frame
        if context and context ~= shared.a11y.game_plan_announced_context then
            shared.a11y.game_plan_announced_context = context
            announcement = context .. ". " .. announcement
            shared.a11y.game_plan_pending_title = nil
        end
    end
    return announcement
end

-- Leaving a component must also cancel work scheduled by that component.
-- This shared lifecycle is used by the existing exit adapters; no caption
-- rules or inferred player-section mappings are introduced here.
function shared.a11y.leave_game_plan()
    shared.a11y.game_plan_active = false
    shared.a11y.game_plan_main_surface = false
    shared.a11y.game_plan_context = nil
    shared.a11y.game_plan_announced_context = nil
    shared.a11y.game_plan_last_focus_text = nil
    shared.a11y.game_plan_last_roster_identity=nil
    shared.a11y.game_plan_last_menu_focus = nil
    shared.a11y.game_plan_last_player_section = nil
    shared.a11y.game_plan_basic_prompt_active = false
    shared.a11y.game_plan_attribute_panel_until_ms = 0
    shared.a11y.game_plan_attribute_locked_name = nil
    shared.a11y.game_plan_attribute_due_ms = nil
    shared.a11y.game_plan_attribute_hold_until_ms = 0
    shared.a11y.game_plan_active_tactical_label = nil
    shared.a11y.game_plan_active_tactical_value = nil
    shared.a11y.game_plan_active_tactical_widget = nil
    shared.a11y.game_plan_active_tactical_frame = -10000
    shared.a11y.game_plan_selected_heading_due_frame = nil
    shared.a11y.game_plan_basic_menu_heading_due_frame = nil
    shared.a11y.game_plan_lineup_due_ms = nil
    shared.a11y.game_plan_lineup_input = nil
    shared.a11y.game_plan_menu_probe_due_frame = nil
    shared.a11y.game_plan_menu_probe_action = nil
end

function shared.a11y.process_game_plan_selected_heading(modal_focus_blocked)
    if shared.a11y.read_context_state().kind == "dialog" then return false end
    local due = shared.a11y.game_plan_selected_heading_due_frame
    if not due or shared.frame < due or modal_focus_blocked
            or shared.a11y.game_plan_main_surface
            or tonumber(ffi.C.GetTickCount64()) <=
                shared.a11y.game_plan_attribute_panel_until_ms then return false end
    shared.a11y.game_plan_selected_heading_due_frame = nil
    local text = shared.a11y.game_plan_selected_heading
    if not text or text == shared.a11y.game_plan_last_announced_heading then
        return false
    end
    local widget = shared.a11y.game_plan_selected_heading_widget
    local node = shared.a11y.ui_model and shared.a11y.ui_model.nodes[widget]
    -- A native pitch selection already publishes this heading and tracks
    -- transitions between starters and substitutes.
    if node and shared.a11y.native_caption_selection_identity(node.address) then
        return false
    end
    shared.a11y.game_plan_last_announced_heading = text
    local announcement = shared.a11y.game_plan_focus_speech(
        text, widget)
    if announcement then
        shared.a11y.commit_read_selection(announcement,
            widget or text, "adapter-focus")
        shared.speak(announcement)
        return true
    end
    return false
end

function shared.a11y.process_game_plan_basic_menu_heading(modal_focus_blocked)
    if shared.a11y.read_context_state().kind == "dialog" then return false end
    local due = shared.a11y.game_plan_basic_menu_heading_due_frame
    if not due or shared.frame < due or modal_focus_blocked
            or (shared.a11y.game_plan_context ~= "Menu de configuração básica"
                and shared.a11y.game_plan_context ~= "Basic Settings Menu") then
        return false
    end
    shared.a11y.game_plan_basic_menu_heading_due_frame = nil
    local text = shared.a11y.game_plan_basic_menu_heading_text
    if not text then return false end
    local announcement = shared.a11y.game_plan_focus_speech(
        text, shared.a11y.game_plan_basic_menu_heading_widget)
    if announcement then
        shared.a11y.commit_read_selection(announcement,
            shared.a11y.game_plan_basic_menu_heading_widget or text, "adapter-focus")
        shared.speak(announcement)
        return true
    end
    return false
end

function shared.a11y.game_plan_attribute_summary()
    if shared.a11y.visualization_packet() then
        return shared.a11y.ui_language=="pt"
            and "Informações do jogador. Use I e K ou analógico direito para cima e para baixo."
            or "Player information. Use I and K or the right stick up and down."
    end
    return shared.a11y.ui_language=="pt"
        and "Os valores deste painel ainda não foram associados."
        or "This panel's values have not been associated yet."
end

function shared.a11y.poll_diagnostic_keyboard()
    shared.a11y.buffer_keyboard_state = shared.a11y.buffer_keyboard_state or {}
    for _, vkey in ipairs({0x49, 0x4b, 0x4a, 0x4c}) do
        local down = shared.user32.GetAsyncKeyState(vkey) < 0
        if down and not shared.a11y.buffer_keyboard_state[vkey] then shared.a11y.buffer_key(vkey) end
        shared.a11y.buffer_keyboard_state[vkey] = down
    end
    local inputs = {
        {0x26, "up"}, {0x28, "down"},
        {0x25, "left"}, {0x27, "right"},
        {0x59, "Y"}, {0x0d, "A"}, {0x1b, "escape"},
    }
    for _, input_entry in ipairs(inputs) do
        local down = shared.user32.GetAsyncKeyState(input_entry[1]) < 0
        local previous = shared.a11y.diagnostic_keyboard_state[input_entry[1]]
        if down and not previous then
            shared.a11y.record_game_plan_input(input_entry[2], "keyboard")
        end
        shared.a11y.diagnostic_keyboard_state[input_entry[1]] = down
    end
end

function shared.a11y.poll_attribute_input(now_ms)
    shared.a11y.poll_diagnostic_keyboard()
    local o_down = shared.user32.GetAsyncKeyState(0x4f) < 0
    local keyboard_y_down = shared.user32.GetAsyncKeyState(0x59) < 0
    local escape_down = shared.user32.GetAsyncKeyState(0x1b) < 0
    if escape_down and not shared.a11y.attribute_escape_down then
        shared.a11y.game_plan_attribute_panel_until_ms = 0
        shared.a11y.game_plan_attribute_locked_name = nil
    end
    if o_down and not shared.a11y.lineup_keyboard_o_down
            and shared.a11y.game_plan_lineup_screen_visible() then
        shared.a11y.game_plan_lineup_due_ms = now_ms + 80
        shared.a11y.game_plan_lineup_input = "O"
    end
    if keyboard_y_down and not shared.a11y.attribute_keyboard_y_down
            and now_ms - shared.a11y.game_plan_attribute_opened_ms > 500 then
        shared.a11y.game_plan_attribute_panel_until_ms = 0
        shared.a11y.game_plan_attribute_locked_name = nil
    end
    shared.a11y.lineup_keyboard_o_down = o_down
    shared.a11y.attribute_keyboard_y_down = keyboard_y_down
    shared.a11y.attribute_escape_down = escape_down

    if not shared.a11y.xinput or now_ms < (shared.a11y.xinput_next_poll_ms or 0) then
        return
    end
    -- Sample once per render frame. The previous 80 ms interval could miss a
    -- quick D-pad tap, leaving pre-match and Game Plan speech waiting for a
    -- later visual debounce even though the game had already moved.
    shared.a11y.xinput_next_poll_ms = now_ms + 16
    if shared.a11y.xinput.XInputGetState(0, shared.a11y.xinput_state) ~= 0 then
        shared.a11y.scoreboard_select_down=nil
        shared.a11y.attribute_right_stick_y = 0
        shared.a11y.lineup_right_stick_x = 0
        return
    end
    local raw = tonumber(shared.a11y.xinput_state[0].Gamepad.sThumbRY)
    local buttons = tonumber(shared.a11y.xinput_state[0].Gamepad.wButtons)
    local select_down=math.floor(buttons/0x0020)%2==1
    local select_pressed=select_down and shared.a11y.scoreboard_select_down==false
    shared.a11y.scoreboard_select_down=select_down
    local y_down = math.floor(buttons / 0x8000) % 2 == 1
    local b_down = math.floor(buttons / 0x2000) % 2 == 1
    local gamepad_buttons = {
        {0x0001, "up"}, {0x0002, "down"},
        {0x0004, "left"}, {0x0008, "right"},
        {0x1000, "A"}, {0x8000, "Y"}, {0x2000, "B"},
    }
    for _, input_entry in ipairs(gamepad_buttons) do
        local down = math.floor(buttons / input_entry[1]) % 2 == 1
        local previous = shared.a11y.diagnostic_gamepad_state[input_entry[1]]
        if down and not previous then
            shared.a11y.record_game_plan_input(input_entry[2], "gamepad-button")
        end
        shared.a11y.diagnostic_gamepad_state[input_entry[1]] = down
    end
    local left_x = tonumber(shared.a11y.xinput_state[0].Gamepad.sThumbLX)
    local left_y = tonumber(shared.a11y.xinput_state[0].Gamepad.sThumbLY)
    local left_direction = left_y > 16000 and "up"
        or (left_y < -16000 and "down"
        or (left_x < -16000 and "left"
        or (left_x > 16000 and "right" or nil)))
    if left_direction and not shared.a11y.diagnostic_left_stick_direction then
        shared.a11y.record_game_plan_input(left_direction, "gamepad-left-stick")
    end
    shared.a11y.diagnostic_left_stick_direction = left_direction
    local right_x = tonumber(shared.a11y.xinput_state[0].Gamepad.sThumbRX)
    local horizontal = right_x < -16000 and -1
        or (right_x > 16000 and 1 or 0)
    shared.a11y.lineup_right_stick_x = horizontal
    if (b_down and not shared.a11y.attribute_b_down)
            or (y_down and not shared.a11y.attribute_y_down
                and now_ms - shared.a11y.game_plan_attribute_opened_ms > 500) then
        shared.a11y.game_plan_attribute_panel_until_ms = 0
        shared.a11y.game_plan_attribute_locked_name = nil
    end
    local vertical = raw > 16000 and 1 or (raw < -16000 and -1 or 0)
    if vertical==0 then shared.a11y.review_right_stick(0) end
    if vertical ~= 0 and shared.a11y.attribute_right_stick_y == 0 then
        shared.a11y.review_right_stick(vertical > 0 and -1 or 1)
    end
    shared.a11y.attribute_right_stick_y = vertical
    shared.a11y.attribute_y_down = y_down
    shared.a11y.attribute_b_down = b_down
    return select_pressed
end

function shared.is_focused(text_id)
    local entry = shared.widgets[text_id]
    if not entry or not shared.readable(entry.address + 0x104, 4) then
        return false
    end
    return memory.unpack("u32", memory.read(entry.address + 0x104, 4)) == 1
end

function shared.is_widget_focused(widget)
    if not widget or not shared.readable(widget + 0x104, 4) then
        return false
    end
    return memory.unpack("u32", memory.read(widget + 0x104, 4)) == 1
end

function shared.register_control_label(label, widget, role, is_control)
    local label_key = memory.hex(widget)
    local node = shared.a11y.observe_ui_widget(widget, label)
    local previous_row = shared.control_rows_by_label_widget[label_key]
    if previous_row and previous_row.label == label then
        if not previous_row.native_slider then
            previous_row.role = role or previous_row.role
        end
        previous_row.is_control = is_control or previous_row.is_control
        previous_row.created_frame = shared.frame
        shared.controller_rows[label] = previous_row
        shared.pending_control_row = previous_row
        return previous_row
    end
    if previous_row and previous_row.value_widget_key
            and shared.control_row_by_value_widget[previous_row.value_widget_key]
                == previous_row then
        shared.control_row_by_value_widget[previous_row.value_widget_key] = nil
    end
    if previous_row and shared.controller_rows[previous_row.label] == previous_row then
        shared.controller_rows[previous_row.label] = nil
    end
    local row = {
        label = label,
        label_widget = widget,
        label_widget_key = label_key,
        role = role or shared.selector_role(label),
        is_control = is_control or false,
        created_frame = shared.frame,
        value_variants = {},
        value_variant_count = 0,
        identity = node.identity,
        generation = node.generation,
        structural = node.role == "control-label",
    }
    shared.control_rows_by_label_widget[label_key] = row
    shared.controller_rows[label] = row
    shared.pending_control_row = row
    return row
end

function shared.a11y.valid_control_value(widget,value,structural_boolean)
    local boolean=structural_boolean and (value=="Sim" or value=="Não" or value=="Yes" or value=="No")
    if not value or value=="" or (shared.is_modal_button(value) and not boolean)
            or shared.non_control_labels[value] or shared.is_noninteractive_text(value)
            or shared.looks_like_message(value, widget) then
        return false
    end
    local name = shared.a11y.widget_internal_name(widget)
    if name == "padIcon" or name == "listName" or name == "teamName"
            or name == "playerName" or name == "groupName"
            or name == "title" or (name and name:match("_item$")) then
        return false
    end
    return true
end

function shared.attach_control_value(row, widget, value)
    if not row or row.native_slider or row.external_value
            or widget == row.label_widget
            or not shared.a11y.valid_control_value(widget,value,row.native_field) then
        return false
    end
    local label_name = shared.a11y.widget_internal_name(row.label_widget)
    local value_name = shared.a11y.widget_internal_name(widget)
    local structural_stem = label_name
        and label_name:match("^(.-)_item$")
    if structural_stem and value_name ~= structural_stem .. "_value" then
        -- A rules page redraws competition names alongside its selectors.
        -- Render order alone must not make a club or another field the value.
        return false
    end
    if (structural_stem or (value_name and value_name:match("_value$")))
            and shared.a11y.structural_control_row(widget) ~= row then
        -- Duplicate field names must not pair by table iteration order.
        return false
    end
    local value_key = memory.hex(widget)
    local previous_owner = shared.control_row_by_value_widget[value_key]
    if previous_owner and previous_owner ~= row then
        previous_owner.value_widget = nil
        previous_owner.value_widget_key = nil
        previous_owner.value = nil
        previous_owner.is_control = shared.controller_labels[previous_owner.label] or false
    end
    if row.value_widget_key and row.value_widget_key ~= value_key
            and shared.control_row_by_value_widget[row.value_widget_key] == row then
        shared.control_row_by_value_widget[row.value_widget_key] = nil
    end
    row.value_widget = widget
    row.value_widget_key = value_key
    row.value = value
    row.value_frame = shared.frame
    if not row.value_variants then
        row.value_variants = {}
        row.value_variant_count = 0
    end
    if not row.value_variants[value] then
        row.value_variants[value] = true
        row.value_variant_count = row.value_variant_count + 1
    end
    row.is_control = row.is_control
        or row.structural
        or row.native_slider
        or shared.controller_labels[row.label]
        or (not shared.non_control_labels[row.label]
            and row.value_variant_count >= 2)
    shared.control_row_by_value_widget[value_key] = row
    return true
end

function shared.a11y.rebind_presented_control(node)
    if node.role=="control-value" or node.name=="text" or node.name=="jump" or node.name=="textWord" then
        local row=shared.a11y.structural_control_row(node.address)
        if row then shared.attach_control_value(row,node.address,node.text) end
    end
end

-- A selector's delegated text belongs to its enclosing native choice. This
-- schema uses setName outside the selector and one current text inside it.
-- Native ancestry AND selector RTTI must agree; captions/render order do not
-- establish the relation. Multiple labels/values remain unresolved.
function shared.a11y.native_field_label(widget)
    local snapshot=shared.a11y.native_windows
    local member=snapshot and snapshot.members and snapshot.members[tonumber(widget)]
    local model=shared.a11y.ui_model
    local target=model and model.nodes[memory.hex(widget)]
    if not member or not member.active or not target
            or (target.name~="text" and target.name~="jump" and target.name~="textWord") then return nil end
    local base=tonumber(shared.process_base_u64)
    if not base then return nil end
    local found
    for _,owner in ipairs(member.owners or {}) do
        if owner.enabled and owner.parents then
            local parents=owner.parents
            local at,selector,choice=tonumber(widget),nil,nil
            local direct_jump=target.name=="jump" and parents[at]
                and shared.a11y.menu_read(parents[at],"u64")==base+0x27cb508
            if direct_jump then selector=at end
            local visited={}
            for _=1,12 do
                if not at or at==owner.root or visited[at] then break end
                visited[at]=true
                local kind=shared.a11y.menu_read(at,"u64")
                if kind==base+0x27b84d0 or kind==base+0x27be998 or kind==base+0x27bb538
                        or kind==base+0x27bac10 or kind==base+0x27cb970
                        or kind==base+0x27c3a38 then selector=at end
                if selector and kind==base+0x27cb508 then choice=at;break end
                at=parents[at]
            end
            if selector and choice then
                local label,value,ambiguous
                for _,node in pairs(model.nodes) do
                    -- Establish component membership before touching memory.
                    -- The model also holds captions from previous screens.
                    if node.text and node.text~="" and parents[tonumber(node.address)] then
                        local cursor,inside,seen=tonumber(node.address),false,{}
                        for _=1,12 do
                            if not cursor or seen[cursor] then break end
                            seen[cursor]=true
                            if cursor==selector then inside=true end
                            if cursor==choice then
                                if not shared.a11y.native_presentation_ready(node.address)
                                        or not shared.a11y.ui_node_matches_live(node) then break end
                                if (inside or (direct_jump and parents[tonumber(node.address)]==choice and node.name=="jump"))
                                        and (node.name=="text" or node.name=="jump" or node.name=="textWord")
                                        and shared.a11y.valid_control_value(node.address,node.text,true) then
                                    if value and value~=node then ambiguous=true end
                                    value=node
                                elseif not inside and (node.name=="setName"
                                        or (node.name=="text" and parents[tonumber(node.address)]==choice)) then
                                    if label and label~=node then ambiguous=true end
                                    label=node
                                end
                                break
                            end
                            cursor=parents[cursor]
                        end
                    end
                end
                if not ambiguous and label and value and value.key==target.key then
                    if found and found.key~=label.key then return nil end
                    found=label
                end
            end
        end
    end
    return found
end

function shared.a11y.structural_control_row(widget)
    local name = shared.a11y.widget_internal_name(widget)
    local stem = name and name:match("^(.-)_value$")
    if not stem then
        local label=shared.a11y.native_field_label(widget)
        if label then
            local row=shared.control_rows_by_label_widget[label.key]
            if not row then row=shared.register_control_label(label.text,label.address,nil,true) end
            row.is_control=true
            row.native_field=true
            return row
        end
        return nil
    end
    local value_key = memory.hex(widget)
    local model = shared.a11y.ui_model
    if model and model.nodes[value_key] then
        local value_node = model.nodes[value_key]
        local label_node = shared.a11y.scoped_ui_name(stem .. "_item",widget)
        if not value_node or not label_node then return nil end
        local scoped_value=shared.a11y.scoped_ui_name(name,label_node.address)
        if not scoped_value or scoped_value.key~=value_key then return nil end
        return shared.control_rows_by_label_widget[label_node.key]
    end
    local found
    for _, row in pairs(shared.control_rows_by_label_widget) do
        if shared.a11y.widget_internal_name(row.label_widget)
                == stem .. "_item" then
            if found then return nil end
            found = row
        end
    end
    return found
end

function shared.a11y.capture_structural_control(widget, text)
    local node = shared.a11y.observe_ui_widget(widget, text)
    if node.role == "control-value" then
        local row = shared.a11y.structural_control_row(widget)
        if row then shared.attach_control_value(row, widget, text) end
        return nil
    end
    local stem = node.name and node.name:match("^(.-)_item$")
    if not stem or not text or text == "" or shared.looks_like_message(text, widget)
            or shared.is_noninteractive_text(text) or shared.is_modal_button(text) then
        return nil
    end
    local row = shared.register_control_label(text, widget,
        shared.a11y.ui_language == "pt" and "seletor" or "selector", true)
    local value_node = shared.a11y.scoped_ui_name(stem .. "_value",widget)
    if value_node and shared.attach_control_value(row, value_node.address, value_node.text) then
        shared.pending_control_row = nil
    end
    return row
end


    shared.stage = 10
end
function component.init(ctx)
    component.install(ctx)

end
return component
