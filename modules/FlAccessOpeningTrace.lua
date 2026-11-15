-- FLAccess 0.2.3 audio description. Load after reader and gameplay.
-- Replay research stays in this file, disabled until future development.
-- This flag deliberately has no menu or INI setting.
local m = {replays_enabled = false}

m.cameras = {
    {"stadium", "^ent_001_view_st%d+_cam[12]%.fdc$"},
    {"tunnel", "^ent_007_passage%d+_cmn_cam%.fdc$"},
    {"walkout", "^ent_009_st%d+_cmn_cam%.fdc$"},
    {"crowd", "^ent_011_st%d+_cmn_cam_n_l%.fdc$"},
    {"home", "^ent_016_club_home_st%d+_cam%.fdc$"},
    {"away", "^ent_016_club_away_st%d+_cam%.fdc$"},
    {"lineup", "^ent_018_cmn_all_st%d+_cam[12]%.fdc$"},
    {"photo", "^ent_017_cmn_home_st%d+_cam%.fdc$"},
    {"formation", "^ent_020_st%d+_cam%.fdc$"},
    {"closeups", "^ent_022_cam_cmn%.fdc$"},
    {"kickoff_setup", "^ent_023_cam_cmn%.fdc$"},
}

m.colors = {
    {0xf2f2f2, "branco", "white"}, {0x161616, "preto", "black"}, {0x9a9a9a, "cinza", "gray"},
    {0xb52c3c, "vermelho", "red"}, {0xec6f20, "laranja", "orange"}, {0xe6d120, "amarelo", "yellow"},
    {0xc5ab70, "dourado", "gold"}, {0x168656, "verde", "green"}, {0x173eab, "azul", "blue"},
    {0x79b7e1, "azul-claro", "light blue"}, {0x192948, "azul-escuro", "navy"},
    {0x702477, "roxo", "purple"}, {0xe282ad, "rosa", "pink"}, {0x754f32, "marrom", "brown"},
}

-- Names can be reused by stadium and competition packs. Verify the loaded bytes.
m.visual_assets = {
    ["ent_007_passage02_cmn_cam.fdc"] = {62075, 0x584b9613},
    ["ent_007_passage02_cmn_pl.fdc"] = {22518, 0xc305267f},
    ["ent_011_st000_cmn_cam_n_l.fdc"] = {46225, 0x2cb7868e},
    ["ent_016_club_home_st000_cam.fdc"] = {25257, 0x1b20d490},
    ["ent_016_club_away_st000_cam.fdc"] = {25257, 0xee4a6dc5},
    ["ent_016_pl_club_home.fdc"] = {10634, 0x57c8c0c4},
    ["ent_016_pl_club_away.fdc"] = {11087, 0x65d7cc5f},
}

m.uniform_textures = {
    ["u0103p1"] = {833928, 0x6922e8fd, "Listras brancas nos ombros.", "White stripes on the shoulders."},
    ["u0101p3"] = {692792, 0xb2cfe95c, "Listras azul-escuras nos ombros.", "Navy stripes on the shoulders."},
}

function m.data_ready(ctx, filename, address, size, total, offset)
    local ad, gp = ctx.flaccess.opening_ad, ctx.flaccess.gameplay
    if type(filename) ~= "string" then return end
    local path = filename:lower():gsub("\\", "/")
    local texture = path:match("^asset/model/character/uniform/texture/#windx11/([^/]+)%.ftex$")
    local file = ad.active and path:match("^common/demo/fixdemo/ent/cut_data/([^/]+)$")
    local expected = texture and ad.uniform_textures[texture] or file and ad.visual_assets[file]
    if not expected then return end
    local verified, key = ad.assets, file
    if texture then verified, key = ad.verified_textures, texture end
    verified[key] = nil
    if total ~= expected[1] or size < total or offset ~= 0 then return end
    local saved = gp.read_failure
    local a, b = 1, 0
    for chunk = 0, total - 1, 0x20000 do
        local bytes = gp.blob(address + chunk, math.min(0x20000, total - chunk))
        gp.read_failure = saved
        if not bytes then return end
        for index = 1, #bytes do
            a = (a + bytes:byte(index)) % 65521
            b = (b + a) % 65521
        end
    end
    verified[key] = b * 65536 + a == expected[2] or nil
    if verified[key] then log("[OpeningAD] confirmed visual asset " .. key) end
end

function m.pointer(gp, data, offset)
    local value = gp.ptr(data, offset)
    if value and value >= 65536 and value < 0x800000000000 then return value end
end

function m.native_string(ad, gp, data, offset)
    local size, capacity = gp.ptr(data, offset + 16), gp.ptr(data, offset + 24)
    if not size or not capacity or size == 0 or size > 128 or capacity < size or capacity > 4096 then return end
    if capacity < 16 then return data:sub(offset + 1, offset + size) end
    local address = ad.pointer(gp, data, offset)
    return address and gp.blob(address, size)
end

function m.cut_role(ad, gp, record)
    local role, cameras = nil, {}
    for offset = 0x88, 0x1a8, 32 do
        local text = ad.native_string(ad, gp, record, offset)
        local file = text and text:lower():match("([^/\\]+%.fdc)$")
        if file and file:find("_cam", 1, true) and not file:find("%c") then
            cameras[#cameras + 1] = file
            for _, candidate in ipairs(ad.cameras) do
                if file:match(candidate[2]) then
                    if role and role ~= candidate[1] then return nil, table.concat(cameras, ",") end
                    role = candidate[1]
                    break
                end
            end
        end
    end
    return role, table.concat(cameras, ",")
end

function m.formation_screen(ad, gp, owner)
    if not ad.formation_supported then return end
    local manager = ad.pointer(gp, gp.blob(owner + 0x18ec0, 8), 0)
    if not manager or gp.ptr(gp.blob(manager, 8), 0) ~= gp.base + 0x2bd60f0 then return end
    local links = gp.blob(manager + 0x1218, 16)
    local visible_side, visible_panel
    for side = 0, 1 do
        local panel = ad.pointer(gp, links, side * 8)
        local data = panel and gp.blob(panel, 0x4c)
        -- State 3 is the fully shown layout. State 2 and 4 are the transitions.
        if gp.ptr(data, 0) == gp.base + 0x2bdd450 and gp.uint(data, 8) == 3
                and ad.pointer(gp, data, 0x10) and data:byte(0x23) == 1
                and gp.ptr(data, 0x38) == manager + 0x1818 and gp.uint(data, 0x48) == side then
            if visible_panel then return end
            visible_side, visible_panel = side, panel
        end
    end
    return visible_side, visible_panel
end

function m.read_cut(ad, gp)
    local root = gp.base + 0x36f0260
    local owner = ad.pointer(gp, gp.blob(root, 8), 0)
    if not owner or gp.ptr(gp.blob(owner, 8), 0) ~= gp.base + 0x2bba650 then return nil, "no-listener" end
    local link = owner + 0x18f38
    local manager = ad.pointer(gp, gp.blob(link, 8), 0)
    if not manager then return nil, "no-entrance" end
    local data = gp.blob(manager, 0x1dc)
    if gp.ptr(data, 0) ~= gp.base + 0x2c701f8 then return nil, "entrance-type" end
    if gp.uint(data, 0x1d4) ~= 3 then return nil, "entrance-phase=" .. tostring(gp.uint(data, 0x1d4)) end
    local main, index = ad.pointer(gp, data, 0xe0), data:byte(0xe9)
    local first, last = ad.pointer(gp, data, 0x20), ad.pointer(gp, data, 0x28)
    if not main or not first or not last or last <= first or (last - first) % 0x1e0 ~= 0
            or first + (index + 1) * 0x1e0 > last then return nil, "no-current-cut" end

    local timing = gp.blob(main, 0x68)
    local stage, frame, limit = gp.uint(timing, 0x58), gp.float(timing, 0x60), gp.float(timing, 0x64)
    if gp.ptr(timing, 0) ~= gp.base + 0x2ba51b8 or not stage or stage < 3 or stage >= 6
            or not frame or not limit or frame < 0 or limit <= frame or limit > 36000 then return nil, "cut-clock" end
    local key = string.format("%x:%x:%d", manager, main, index)
    local role, cameras
    if ad.cut and ad.cut.key == key then
        role, cameras = ad.cut.role, ad.cut.cameras
    else
        local record = gp.blob(first + index * 0x1e0, 0x1e0)
        if not record then return end
        role, cameras = ad.cut_role(ad, gp, record)
    end
    local side, panel
    if role == "formation" then side, panel = ad.formation_screen(ad, gp, owner) end
    local current = gp.blob(manager + 0xe0, 9)
    if not current or gp.ptr(current, 0) ~= main or current:byte(9) ~= index
            or gp.ptr(gp.blob(link, 8), 0) ~= manager or gp.ptr(gp.blob(root, 8), 0) ~= owner then return end
    return {key = key, index = index, role = role, cameras = cameras, frame = frame, limit = limit,
        side = side, panel = panel}
end

function m.team_name(ad, gp, side, id)
    if not gp.match_names_supported or not id then return end
    local roster = gp.match_roster_data()
    if not roster then return end
    local bytes = gp.blob(roster + 0x35960 + 0x138 + side * 0x690, 0x4a)
    local encoded = gp.uint(bytes, 0)
    if not encoded or math.floor(encoded / 0x4000) % 0x20000 ~= id or gp.match_roster_data() ~= roster then return end
    local name = bytes:sub(5):match("^([^%z]+)%z")
    if name and not name:find("%c") and name:find("%S") then return name end
end

function m.player_name(gp, roster, side, slot)
    local record = gp.blob(roster + 0x35960 + 0x1308 + (side * 40 + slot) * 0x188, 0x148)
    local id, flags = gp.uint(record, 0x30), gp.uint(record, 0x144)
    if not id or id == 0 or not flags or flags >= 0x80000000 then return end
    local name = record:sub(0x39, 0x75):match("^([^%z]+)%z")
    if name and not name:find("%c") and name:find("%S") then return name end
end

function m.featured_player(ad, ctx, side, captain)
    local gp = ctx.flaccess.gameplay
    if not ad.actors_supported then return end
    local team = side == 0 and ctx.home_team or ctx.away_team
    if not ad.team_name(ad, gp, side, team) then return end
    local roster = gp.match_roster_data()
    local params_link, world_link = gp.base + 0x37f5d50, gp.base + 0x36f3dc8
    local params = ad.pointer(gp, gp.blob(params_link, 8), 0)
    local world = ad.pointer(gp, gp.blob(world_link, 8), 0)
    if not roster or not params or not world then return end
    local players_link = world + 0x1978 + side * 0x28
    local players = ad.pointer(gp, gp.blob(players_link, 8), 0)
    if not players then return end
    -- The entrance's actor selector uses the flag at +f8 (keeper) or +f9
    -- (captain) of the same ordered on-pitch players copied by 1f52ad0.
    local flags = gp.blob(params + side * 0x2830 + 0xf8, 0xa02)
    local slots = gp.blob(players + 4, 44)
    if not flags or not slots then return end
    local slot
    for index = 0, 10 do
        if flags:byte(index * 0x100 + (captain and 2 or 1)) == 1 then
            if slot then return end
            slot = gp.uint(slots, index * 4)
        end
    end
    if not slot or slot >= 40 then return end
    local name = ad.player_name(gp, roster, side, slot)
    if gp.match_roster_data() ~= roster or gp.ptr(gp.blob(params_link, 8), 0) ~= params
            or gp.ptr(gp.blob(world_link, 8), 0) ~= world or gp.ptr(gp.blob(players_link, 8), 0) ~= players
            or gp.blob(players + 4, 44) ~= slots then return end
    return name
end

function m.formation_details(ad, ctx, side)
    local gp, pt = ctx.flaccess.gameplay, ctx.flaccess.reader.a11y.ui_language == "pt"
    local team = ad.team_name(ad, gp, side, side == 0 and ctx.home_team or ctx.away_team)
    local roster = team and gp.match_roster_data()
    local world_root = gp.base + 0x36f3dc8
    local world = roster and ad.pointer(gp, gp.blob(world_root, 8), 0)
    if not world then return end
    -- DemoMemberFormation builds its starting graphic from these formation bytes.
    local tactics_link = world + 0x1928 + side * 0x28
    local tactics = ad.pointer(gp, gp.blob(tactics_link, 8), 0)
    local mode = tactics and gp.uint(gp.blob(tactics + 0x8e08, 4), 0)
    if not mode then return end
    local formation = roster + 0x35960 + 0xe58 + side * 0x258
    local positions_addr, slots_addr = formation + 0x40 + (mode < 3 and mode or 0) * 0xa0, formation + 0x220
    local positions, slots = gp.blob(positions_addr, 11), gp.blob(slots_addr, 11)
    if not positions or not slots then return end
    local groups = {{}, {}, {}, {}}
    local seen = {}
    for index = 1, 11 do
        local position, slot = positions:byte(index), slots:byte(index)
        if position > 12 or slot >= 40 or seen[slot] then return end
        seen[slot] = true
        local name = ad.player_name(gp, roster, side, slot)
        if not name then return end
        local sector = position == 0 and 1 or position <= 3 and 2 or position <= 8 and 3 or 4
        groups[sector][#groups[sector] + 1] = name
    end
    if #groups[1] ~= 1 or gp.match_roster_data() ~= roster
            or gp.ptr(gp.blob(world_root, 8), 0) ~= world or gp.ptr(gp.blob(tactics_link, 8), 0) ~= tactics
            or gp.uint(gp.blob(tactics + 0x8e08, 4), 0) ~= mode or gp.blob(slots_addr, 11) ~= slots
            or gp.blob(positions_addr, 11) ~= positions then return end
    local labels = pt and {"Goleiro", "Defesa", "Meio-campo", "Ataque"}
        or {"Goalkeeper", "Defence", "Midfield", "Attack"}
    labels[1] = (pt and "Escalação, " or "Lineup, ") .. team .. ". " .. labels[1]
    return {groups = groups, labels = labels, sector = 1}
end

function m.color(ad, code, pt)
    local rgb = type(code) == "string" and code:match("^#(%x%x%x%x%x%x)$")
    if not rgb then return end
    local value = tonumber(rgb, 16)
    local r, g, b = math.floor(value / 65536), math.floor(value / 256) % 256, value % 256
    local best, distance
    for _, color in ipairs(ad.colors) do
        local v = color[1]
        local score = (r - math.floor(v / 65536))^2 + (g - math.floor(v / 256) % 256)^2 + (b - v % 256)^2
        if not distance or score < distance then best, distance = color, score end
    end
    return best[pt and 2 or 3]
end

function m.kit(ad, ctx, side, keeper)
    local kits = ctx.kits
    local team = side == 0 and ctx.home_team or ctx.away_team
    if not team or not kits then return end
    if keeper then return kits.get_gk and kits.get_gk(team) end
    local id = kits.get_current_kit_id and kits.get_current_kit_id(side)
    if id and id >= 0 and id <= 9 and kits.get then return kits.get(team, id) end
end

function m.kit_text(ad, ctx, side, pt)
    local kit = ad.kit(ad, ctx, side)
    if not kit then return end
    local shirt, other = ad.color(ad, kit.ShirtColor1, pt), ad.color(ad, kit.ShirtColor2, pt)
    local shorts = ad.color(ad, kit.ShortsColor, pt)
    if not shirt or shirt ~= other then return end
    if pt then
        local feminine = shirt:gsub("o$", "a")
        return "Camisa " .. feminine .. (shorts and ", calção " .. shorts or "") .. "."
    end
    return shirt .. " shirts" .. (shorts and ", " .. shorts .. " shorts" or "") .. "."
end

function m.uniform_side(ad, gp, impl)
    local state = gp.blob(impl, 0xdc)
    if not state or state:byte(10) % 2 ~= 1 then return end
    local key = gp.uint(state, 0xa0)
    local first, last = gp.ptr(state, 0xa8), gp.ptr(state, 0xb0)
    if not first or not last or last < first or (last - first) % 0x18 ~= 0 or last - first > 0x300 then return end
    for address = first, last - 0x18, 0x18 do
        local entry = gp.uint(gp.blob(address, 4), 0)
        if not entry then return end
        if entry == key then
            -- The menu's side getter takes the first type-16 widget in layout zero.
            local root = ad.pointer(gp, state, 0x98)
            local layouts = root and gp.blob(root + 0x170, 16)
            local list, end_list = ad.pointer(gp, layouts, 0), gp.ptr(layouts, 8)
            local layout = list and end_list and end_list > list and ad.pointer(gp, gp.blob(list, 8), 0)
            local head = layout and ad.pointer(gp, gp.blob(layout + 0x110, 8), 0)
            local node = head and ad.pointer(gp, gp.blob(head, 8), 0)
            local stack, count = {}, 0
            while node and (node ~= head or #stack > 0) and count < 128 do
                if node ~= head then
                    local links = gp.blob(node, 0x48)
                    if not links or links:byte(0x1a) ~= 0 then return end
                    stack[#stack + 1] = links
                    node = ad.pointer(gp, links, 0)
                    count = count + 1
                else
                    local links = table.remove(stack)
                    local widget = ad.pointer(gp, links, 0x40)
                    local data = widget and gp.blob(widget, 0xc0)
                    if gp.uint(data, 0x88) == 16 then return gp.uint(data, 0xbc) end
                    node = ad.pointer(gp, links, 0x10)
                end
            end
            return
        end
    end
    return gp.uint(state, 0xd8)
end

function m.uniform_selection(ad, ctx)
    if not ad.uniform_supported then return end
    local reader, gp = ctx.flaccess.reader, ctx.flaccess.gameplay
    local snapshot = reader.a11y.native_windows
    local window
    for _, item in ipairs(snapshot and snapshot.windows or {}) do
        if item.enabled and item.vtable == gp.base + 0x266c030 then
            if window then return end
            window = item
        end
    end
    if not window then return end
    local data = gp.blob(window.address, 0xd0)
    if gp.ptr(data, 0) ~= gp.base + 0x266c030 or gp.ptr(data, 0x88) ~= window.impl then return nil, "window changed" end
    local side = ad.uniform_side(ad, gp, window.impl)
    if side ~= 0 and side ~= 1 then return nil, "focus unavailable" end
    local index = gp.uint(data, 0x98 + side * 4)
    local first, last = ad.pointer(gp, data, 0xa0 + side * 0x18), gp.ptr(data, 0xa8 + side * 0x18)
    if not index or not first or not last or last <= first or (last - first) % 20 ~= 0 or last - first > 640
            or index >= (last - first) / 20 then return nil, "choices unavailable" end
    local row = gp.blob(first + index * 20, 20)
    if not row then return end
    local custom = row:byte(17) == 1
    local team_id = side == 0 and ctx.home_team or ctx.away_team
    local roster = gp.match_roster_data()
    local id
    if roster and not custom and team_id then
        local selected = gp.uint(gp.blob(roster + 0x35960 + 0x120 + side * 4, 4), 0)
        if selected and math.floor(selected / 0x4000) % 0x20000 == team_id then
            id = selected % 0x4000
            if id > 9 then id = nil end
        end
    end
    return {key = string.format("%x:%d:%d:%s:%s", window.address, side, index, tostring(team_id), tostring(id)),
        side = side, index = index, team_id = team_id, kit_id = id, row = row}
end

function m.replay_state(ad, gp)
    if not ad.replay_supported then return end
    local world_link = gp.base + 0x36f3dc8
    local world = ad.pointer(gp, gp.blob(world_link, 8), 0)
    local replay = world and ad.pointer(gp, gp.blob(world + 0x388, 8), 0)
    local data = replay and gp.blob(replay, 0x28)
    -- ReplayInfo type 1 is automatic. Type 2 is the player-controlled replay.
    if not data or data:byte(1) ~= 1 then return end
    -- +4/+5 are transient control requests, cleared by 20b8e40; they do
    -- not mean that the replay has disappeared. +7 is its presentation flag.
    if data:byte(8) == 0 then return nil, "transition" end
    local speed, frame, last = gp.float(data, 0x10), gp.uint(data, 0x14), gp.uint(data, 0x18)
    if not speed or not frame or not last or last <= frame then return nil, "no playable range" end
    if gp.ptr(gp.blob(world_link, 8), 0) ~= world
            or gp.ptr(gp.blob(world + 0x388, 8), 0) ~= replay then return end
    local clip = data:byte(0x0d)
    local target, player
    if data:byte(0x0c) == 0 then
        target, player = gp.uint(data, 0x1c), gp.uint(data, 0x24)
        if target == 0 or target >= 23 or player == 0 then target, player = nil, nil end
    end
    return {key = string.format("%x:%d:%d", replay, clip, last), index = clip, role = "replay",
        frame = frame, limit = last, speed = speed, target = target, player = player, world=world, address=replay}
end

-- Read the frame being reproduced, never the live match's ball or score.
-- 20b8e40 and 20b1ff0 use these same ring-buffer and quantized coordinates.
function m.replay_ball(ad,ctx,sample)
    local gp=ctx.flaccess.gameplay
    if not ad.replay_geometry_supported or not gp.camera_source_supported or not gp.reference_data then return end
    local owner=ad.pointer(gp,gp.blob(gp.base+0x36f0260,8),0)
    if not owner or gp.ptr(gp.blob(owner,8),0)~=gp.base+0x2bba650 then return end
    local controller=ad.pointer(gp,gp.blob(owner+0x138,8),0)
    local data=controller and gp.blob(controller,0x438)
    local vt=gp.ptr(data,0)
    if vt~=gp.base+0x2bd3e50 and vt~=gp.base+0x2bd4238 then return end
    if gp.ptr(data,0x430)~=sample.address then return end
    local function word(raw,at)
        if not raw or #raw<at+2 then return end
        return raw:byte(at+1)+raw:byte(at+2)*256
    end
    local tick,start,period=word(data,0x288),word(data,0x28c),word(data,0x28a)
    local capacity=gp.uint(gp.blob(gp.base+0x36f5114,4),0)
    capacity=capacity==0 and 660 or capacity
    if not tick or not start or not period or period==0 or not capacity or capacity<1 or capacity>65535
            or (tick-start+period)%period~=sample.frame then return end
    local recording=ad.pointer(gp,gp.blob(sample.world+0x6a8,8),0)
    local first=recording and ad.pointer(gp,gp.blob(recording+0x40,8),0)
    local point=first and gp.blob(first+(tick%capacity)*0x1fb0+0x24c,6)
    if not point then return end
    local position={}
    for axis=1,3 do
        local value=word(point,(axis-1)*2)
        position[axis]=(value>=32768 and value-65536 or value)/256
    end
    local field=gp.reference_data("field",0x0c)
    local length,width=gp.float(field,4),gp.float(field,8)
    if not length or length<40 or length>70 or not width or width<20 or width>50
            or math.abs(position[1])>length+12 or math.abs(position[3])>width+12 or position[2]<-2 or position[2]>40 then return end
    local camera=gp.reference_data("camera",0x5c)
    if not camera then return end
    local clip={}
    for column=0,3 do
        local value=gp.float(camera,0x0c+(12+column)*4)
        if not value then return end
        for axis=1,3 do
            local cell=gp.float(camera,0x0c+((axis-1)*4+column)*4)
            if not cell then return end
            value=value+position[axis]*cell
        end
        if value~=value or math.abs(value)>1e12 then return end
        clip[column+1]=value
    end
    if clip[4]<=0.00001 or clip[3]<0 or clip[3]>clip[4]
            or math.abs(clip[1]/clip[4])>1 or math.abs(clip[2]/clip[4])>1 then return end
    if gp.blob(controller+0x288,2)~=data:sub(0x289,0x28a)
            or gp.ptr(gp.blob(sample.world+0x388,8),0)~=sample.address
            or gp.ptr(gp.blob(gp.base+0x36f3dc8,8),0)~=sample.world
            or gp.ptr(gp.blob(owner+0x138,8),0)~=controller
            or gp.ptr(gp.blob(recording+0x40,8),0)~=first then return end
    return {position=position,length=length,width=width}
end

function m.replay_ball_cue(ad,ctx,sample,previous)
    local geometry=ad.replay_ball(ad,ctx,sample)
    local status=geometry and "visible ball" or "no verified visible ball"
    if status~=ad.replay_geometry_status then
        ad.replay_geometry_status=status
        log("[OpeningAD] replay geometry: " .. status)
    end
    if not geometry then return end
    sample.geometry=geometry
    local p=geometry.position
    local pt=ctx.flaccess.reader.a11y.ui_language=="pt"
    local zone,place
    if math.abs(p[1])>geometry.length or math.abs(p[3])>geometry.width then
        zone,place="outside",pt and "fora das linhas do campo" or "outside the pitch markings"
    elseif math.abs(p[1])>geometry.length-16.5 and math.abs(p[3])<20.16 then
        zone,place="area",pt and "na grande área" or "in the penalty area"
    elseif math.abs(p[3])>geometry.width-8 then
        zone,place="wing",pt and "perto da linha lateral" or "near the touchline"
    elseif math.abs(p[1])<10 then
        zone,place="middle",pt and "no meio-campo" or "in midfield"
    else zone,place="field",pt and "no campo" or "on the pitch" end
    local height=p[2]>2 and "high" or p[2]>0.4 and "medium" or "low"
    local movement
    local before=previous.geometry and previous.geometry.position
    local delta=sample.frame-previous.frame
    if before and delta>0 and delta<=30 then
        local vertical=(p[2]-before[2])/delta
        if p[2]>1 and vertical>0.025 then movement=pt and "sobe" or "rises"
        elseif p[2]>1 and vertical< -0.025 then movement=pt and "desce" or "drops" end
    end
    local key=zone .. ":" .. height .. ":" .. (movement or "")
    local text
    if movement then text=(pt and "A bola " or "The ball ") .. movement .. ", " .. place .. "."
    elseif height=="high" then text=(pt and "Bola pelo alto, " or "Ball in the air, ") .. place .. "."
    elseif height=="medium" then text=(pt and "Bola à meia altura, " or "Ball at mid height, ") .. place .. "."
    else text=(pt and "Bola rente ao gramado, " or "Ball close to the grass, ") .. place .. "." end
    return {key=key,text=text,geometry=true}
end

function m.replay_player(ad, ctx, sample)
    if not sample.player then return end
    local gp = ctx.flaccess.gameplay
    local side = sample.target > 11 and 1 or 0
    if not ad.team_name(ad, gp, side, side == 0 and ctx.home_team or ctx.away_team) then return end
    local roster = gp.match_roster_data()
    if not roster then return end
    -- The replay name bar looks up the player ID in the corresponding match roster.
    local first = roster + 0x35960 + 0x1308 + side * 40 * 0x188
    local data = gp.blob(first, 40 * 0x188)
    if not data or gp.match_roster_data() ~= roster then return end
    for slot = 0, 39 do
        if gp.uint(data, slot * 0x188 + 0x30) == sample.player then
            return ad.player_name(gp, roster, side, slot)
        end
    end
end

function m.update_replay(ad, ctx)
    local reader, gp = ctx.flaccess.reader, ctx.flaccess.gameplay
    if ad.replays_enabled~=true then
        if ad.speech and ad.speech.replay then ad.stop(ad,reader) end
        ad.replay,ad.replay_cues=nil,{}
        return false
    end
    local saved = gp.read_failure
    local sample, status
    if not ctx.is_replay_gallery and ctx.home_team and ctx.away_team then sample, status = ad.replay_state(ad, gp) end
    gp.read_failure = saved
    if status ~= ad.replay_status then
        ad.replay_status = status
        if status then log("[OpeningAD] replay " .. status) end
    end
    local previous = ad.replay
    if not sample or not previous or sample.key ~= previous.key or sample.frame < previous.frame then
        if ad.speech and ad.speech.replay then ad.stop(ad, reader) end
        if previous then log("[OpeningAD] replay closed") end
        ad.replay, ad.replay_cues,ad.replay_geometry_status = sample, {},nil
        if sample then sample.geometry=ad.replay_ball(ad,ctx,sample);gp.read_failure=saved end
        if sample then log(string.format("[OpeningAD] replay visible clip=%d frame=%d/%d speed=%.3f",
            sample.index, sample.frame, sample.limit, sample.speed)) end
        return sample ~= nil
    end

    local now = tonumber(gp.kernel.GetTickCount64())
    local advancing = sample.frame > previous.frame
    local ball_cue=advancing and ad.replay_ball_cue(ad,ctx,sample,previous)
    if not advancing then sample.geometry=previous.geometry end
    gp.read_failure=saved
    sample.last_move = advancing and now or previous.last_move
    ad.replay = sample
    local pause = reader.a11y.native_pause_context and reader.a11y.native_pause_context()
    if not reader.game_is_foreground() or reader.overlay_visible or reader.sider_overlay_visible or pause
            or sample.speed <= 0 or (sample.last_move and now - sample.last_move >= 180) then
        if ad.speech and ad.speech.replay then ad.stop(ad, reader) end
        return true
    end
    local cue = ad.speech and ad.speech.replay
    if cue and (cue.player and cue.player ~= sample.player
            or cue.geometry and advancing and (not ball_cue or cue.key~=ball_cue.key)) then ad.stop(ad, reader) end
    if not advancing or not ad.poll_speech(ad, reader) then return true end

    local pt = reader.a11y.ui_language == "pt"
    local cues = ad.replay_cues
    local cue_state = sample.player and cues[sample.player]
    if sample.player and not cue_state then
        local name = ad.replay_player(ad, ctx, sample)
        gp.read_failure = saved
        cue_state = {player = sample.player, text = name and (pt and "Em destaque, " or "Featured, ") .. name .. "."}
        cues[sample.player] = cue_state
    end
    if not cues.intro then
        local text = sample.speed < 0.95 and (pt and "Replay em câmera lenta." or "Slow-motion replay.") or "Replay."
        cues.intro = {text = text}
    end
    if cue_state and cue_state.said then cue_state=nil end
    if ball_cue and (not cue_state or not cue_state.text) then
        cues[ball_cue.key]=cues[ball_cue.key] or ball_cue
        cue_state=cues[ball_cue.key]
    end
    if not cue_state or not cue_state.text then cue_state = cues.intro end
    if not cue_state.said and cue_state.text
            and ad.fits(cue_state.text, (sample.limit - sample.frame) / math.max(sample.speed, 0.05))
            and ad.speak(ad, reader, sample, cue_state.text) then ad.speech.replay = cue_state end
    return true
end

function m.uniform_text(ad, ctx, selection)
    local reader, gp = ctx.flaccess.reader, ctx.flaccess.gameplay
    local pt = reader.a11y.ui_language == "pt"
    local team = ad.team_name(ad, gp, selection.side, selection.team_id)
    local number = (selection.kit_id or selection.index) + 1
    local phrases = {pt and "Uniforme " .. number .. "." or "Kit " .. number .. "."}
    if team then table.insert(phrases, 1, team .. ".") end
    local kits = ctx.kits
    local kit = selection.kit_id and kits and kits.get and kits.get(selection.team_id, selection.kit_id)
    if kit then
        local shirt = ad.color(ad, kit.ShirtColor1, pt)
        local contrast = ad.color(ad, kit.ShirtColor2, pt)
        local shorts, socks = ad.color(ad, kit.ShortsColor, pt), ad.color(ad, kit.SocksColor, pt)
        if shirt then
            local colors = contrast and contrast ~= shirt and shirt .. (pt and " e " or " and ") .. contrast or shirt
            phrases[#phrases + 1] = (pt and "Camisa em " or "Shirt in ") .. colors .. "."
        end
        if shorts then phrases[#phrases + 1] = (pt and "Calção em " or "Shorts in ") .. shorts .. "." end
        if socks then phrases[#phrases + 1] = (pt and "Meias em " or "Socks in ") .. socks .. "." end
        local texture = type(kit.KitFile) == "string" and kit.KitFile:lower()
        if texture and ad.verified_textures[texture] then
            phrases[#phrases + 1] = ad.uniform_textures[texture][pt and 3 or 4]
        end
        if type(kit.ChestNumbersFile) == "string" and kit.ChestNumbersFile:find("%S")
                and type(kit.ChestNumberSize) == "number" and kit.ChestNumberSize > 0 then
            phrases[#phrases + 1] = pt and "Número no peito." or "Number on the chest."
        end
    else
        local r, g, b = gp.float(selection.row, 4), gp.float(selection.row, 8), gp.float(selection.row, 12)
        if r and g and b and r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 then
            local color = ad.color(ad, string.format("#%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5), pt)
            phrases[#phrases + 1] = (pt and "Cor da amostra, " or "Swatch colour, ") .. color .. "."
        end
    end
    return table.concat(phrases, " ")
end

function m.update_uniform(ad, ctx)
    local reader, gp = ctx.flaccess.reader, ctx.flaccess.gameplay
    local saved = gp.read_failure
    local selection, status
    if reader.game_is_foreground() and not reader.overlay_visible and not reader.sider_overlay_visible then
        selection, status = ad.uniform_selection(ad, ctx)
    end
    if status ~= ad.uniform_status then
        ad.uniform_status = status
        if status then log("[OpeningAD] uniform " .. status) end
    end
    local key = selection and selection.key
    if key ~= ad.uniform_key then
        if ad.speech and ad.speech.uniform then ad.stop(ad, reader) end
        ad.uniform_key, ad.uniform_spoken = key, nil
    elseif selection and not ad.uniform_spoken and ad.poll_speech(ad, reader) then
        local text = ad.uniform_text(ad, ctx, selection)
        if ad.speak(ad, reader, {index = selection.index, role = "uniform", frame = 0}, text) then
            ad.speech.uniform, ad.uniform_spoken = true, true
        end
    end
    gp.read_failure = saved
    return selection ~= nil
end

function m.keeper_detail(ad, ctx, side, pt)
    local name = ad.featured_player(ad, ctx, side, false)
    local kit = ad.kit(ad, ctx, side, true)
    local color = kit and ad.color(ad, kit.ShirtColor1, pt)
    if color ~= (kit and ad.color(ad, kit.ShirtColor2, pt)) then color = nil end
    local phrases = {}
    if name and color then
        phrases[#phrases + 1] = name .. (pt and ", de " or " in ") .. color .. "."
    end
    if name then
        phrases[#phrases + 1] = name .. (pt and ", de luvas." or ", wearing gloves.")
        phrases[#phrases + 1] = pt and name .. ", goleiro." or name .. ", goalkeeper."
    elseif color then
        phrases[#phrases + 1] = (pt and "Goleiro de " or "Goalkeeper in ") .. color .. "."
    end
    phrases[#phrases + 1] = pt and "Goleiro de luvas." or "Goalkeeper wearing gloves."
    return phrases
end

function m.visual_details(ad, ctx, cut, details)
    local pt = ctx.flaccess.reader.a11y.ui_language == "pt"
    local file = cut.cameras
    if not file or not ad.assets[file] then return end
    local anfield = ctx.stadium_server and tonumber(ctx.stadium_server.id) == 4
    if cut.role == "tunnel" and anfield and ad.assets["ent_007_passage02_cmn_pl.fdc"]
            and cut.limit >= 390 and cut.limit <= 395 then
        local away = ad.featured_player(ad, ctx, 1, true)
        local home = ad.featured_player(ad, ctx, 0, true)
        local phrases = {}
        if away and home then
            phrases[#phrases + 1] = (pt and "No túnel, " or "In the tunnel, ") .. away
                .. (pt and " à frente. " or " in front. ") .. home
                .. (pt and " junto à parede." or " by the wall.")
        end
        if away then
            local kit = ad.kit(ad, ctx, 1)
            local color = kit and ad.color(ad, kit.ShirtColor1, pt)
            if color and color == ad.color(ad, kit.ShirtColor2, pt) then
                phrases[#phrases + 1] = away .. (pt and ", de " or " in ") .. color .. "."
            end
            phrases[#phrases + 1] = (pt and "Túnel. " or "Tunnel. ") .. away .. "."
        end
        if home then phrases[#phrases + 1] = (pt and "Túnel. " or "Tunnel. ") .. home .. "." end
        phrases[#phrases + 1] = pt and "Capitães no túnel." or "Captains in the tunnel."
        return {{303, cut.limit, phrases}}
    end
    if cut.role == "crowd" and anfield and ctx.home_team == 103 and cut.limit == 360 then
        return {
            {0, 166, {pt and "Arquibancada cheia." or "Packed stands."}},
            {166, 360, {pt and "Bandeiras vermelhas tremulam." or "Red flags wave."}},
        }
    end
    if (cut.role == "home" or cut.role == "away") and cut.limit == 360 then
        local side = cut.role == "home" and 0 or 1
        if not ad.assets["ent_016_pl_club_" .. cut.role .. ".fdc"] then return end
        local team, kit = unpack(details)
        local keeper = ad.keeper_detail(ad, ctx, side, pt)
        if side == 0 then
            return {{0, 266, {team}}, {0, 266, {kit}}, {266, 360, keeper}}
        end
        return {{5, 113, keeper}, {113, 360, {team}}, {113, 360, {kit}}}
    end
end

function m.details(ad, ctx, role)
    local pt = ctx.flaccess.reader.a11y.ui_language == "pt"
    if role == "stadium" then
        local name = ctx.stadium_server and ctx.stadium_server.name
        if type(name) == "string" and #name <= 100 and not name:find("%c") and name:find("%S") then
            return {pt and "Vista de " .. name .. "." or "A view of " .. name .. "."}
        end
        return {pt and "Vista do estádio." or "A view of the stadium."}
    end
    if role == "home" or role == "away" or role == "photo" then
        local side = role == "away" and 1 or 0
        local id = side == 0 and ctx.home_team or ctx.away_team
        local name = ad.team_name(ad, ctx.flaccess.gameplay, side, id)
        if role == "photo" then
            return {pt and (name and name .. " posa para a foto." or "Jogadores posam para a foto.")
                or (name and name .. " poses for a team photo." or "Players pose for a team photo."),
                pt and "Primeira fila agachada, segunda em pé." or "Front row crouching, back row standing."}
        end
        return {pt and (name and name .. " em fila." or "A câmera percorre a fila de jogadores.")
            or (name and name .. " in a line." or "The camera pans along the players."), ad.kit_text(ad, ctx, side, pt)}
    end
    if role == "tunnel" then return {pt and "Jogadores no túnel." or "Players in the tunnel."} end
    if role == "walkout" then return {pt and "Os árbitros saem à frente dos times." or "The referees lead the teams out.",
        pt and "Os jogadores entram em campo." or "The players walk onto the pitch."} end
    if role == "crowd" then return {pt and "A câmera mostra a arquibancada." or "The camera shows the stands."} end
    if role == "lineup" then return {pt and "Os times se alinham no meio-campo." or "The teams line up at midfield.",
        pt and "Os árbitros ficam entre eles." or "The referees stand between them."} end
    if role == "closeups" then return {pt and "A câmera alterna closes dos jogadores." or "Close-ups of the players."} end
    if role == "kickoff_setup" then return {pt and "Jogador na saída." or "Player at kickoff."} end
    return {}
end

function m.fits(phrase, remaining)
    local _, words = phrase:gsub("%S+", "")
    return remaining >= 60 * (0.35 + 0.34 * words)
end

function m.speak(ad, reader, cut, phrase, lineup)
    local a11y = reader.a11y
    local backend = a11y.prism_backend
    local result = a11y.prism_functions.backend_speak(backend, a11y.to_c_string(phrase), false)
    if result == 0 then ad.speech = {backend = backend, sequence = reader.speech_sequence, lineup = lineup} end
    log(string.format("[OpeningAD] speech result=%d cut=%d role=%s frame=%.2f text=%q",
        result, cut.index, cut.role, cut.frame, phrase))
    return result == 0
end

function m.stop(ad, reader)
    local speech = ad.speech
    ad.speech = nil
    local a11y = reader.a11y
    if speech and a11y.prism_backend == speech.backend and reader.speech_sequence == speech.sequence then
        a11y.prism_functions.backend_stop(speech.backend)
    end
end

function m.poll_speech(ad, reader)
    local speech, a11y = ad.speech, reader.a11y
    local backend, prism = a11y.prism_backend, a11y.prism_functions
    if not backend or not prism or not prism.backend_stop then return false end
    if ad.voice_backend ~= backend then
        ad.voice_backend = backend
        local features = tonumber(prism.backend_features(backend))
        ad.is_speaking = features % 256 >= 192 and a11y.prism_proc("prism_backend_is_speaking", "int (__cdecl *)(void *, bool *)") or nil
    end
    if not ad.is_speaking or ad.is_speaking(backend, ad.busy) ~= 0 then return false end
    if speech and (speech.backend ~= backend or speech.sequence ~= reader.speech_sequence) then
        ad.speech, speech = nil, nil
    end
    if speech then
        if ad.busy[0] then speech.started = true
        elseif speech.started then
            if speech.lineup then speech.lineup.sector = speech.lineup.sector + 1 end
            if speech.replay then speech.replay.said = true end
            ad.speech = nil
        end
    end
    return not ad.speech and not ad.busy[0] and a11y.native_speech_first > a11y.native_speech_last
end

function m.speak_lineups(ad, reader)
    while ad.lineups[1] do
        local lineup = ad.lineups[1]
        local group = lineup.groups[lineup.sector]
        if not group then
            table.remove(ad.lineups, 1)
            log("[OpeningAD] formation complete side=" .. lineup.cut.side)
        elseif #group == 0 then
            lineup.sector = lineup.sector + 1
        else
            local phrase = lineup.labels[lineup.sector] .. ", " .. table.concat(group, ", ") .. "."
            ad.speak(ad, reader, lineup.cut, phrase, lineup)
            return true
        end
    end
    return false
end

function m.display_frame(ctx)
    local ad, reader, gp = ctx.flaccess.opening_ad, ctx.flaccess.reader, ctx.flaccess.gameplay
    local settings=reader.a11y
    -- Kit selection is ordinary focus feedback, independent of cinematic AD.
    if ad.update_uniform(ad, ctx) then return end
    if settings.ad_enabled==false then
        ad.stop(ad,reader)
        ad.lineups,ad.replay,ad.replay_cues={},nil,{}
        ad.uniform_key,ad.uniform_spoken=nil,nil
        return
    end
    if settings.ad_lineups==false then
        if ad.speech and ad.speech.lineup then ad.stop(ad,reader) end
        ad.lineups={}
    end
    if ad.replays_enabled~=true then
        if ad.speech and ad.speech.replay then ad.stop(ad,reader) end
        ad.replay,ad.replay_cues=nil,{}
    elseif #ad.lineups == 0 and ad.update_replay(ad, ctx) then return end
    if settings.ad_opening==false and ad.speech and not ad.speech.lineup then ad.stop(ad,reader) end
    if not ad.active and #ad.lineups == 0 then return end
    if ad.active and ctx.flaccess.match_playing then
        ad.active = false
        ad.cut = nil
        if ad.speech and not ad.speech.lineup then ad.stop(ad, reader) end
        log("[OpeningAD] kickoff; closed")
    end
    local saved = gp.read_failure
    local cut, reason
    if ad.active then cut, reason = ad.read_cut(ad, gp) end
    gp.read_failure = saved
    if reason ~= ad.reason then
        ad.reason = reason
        if reason then log("[OpeningAD] waiting " .. reason) end
    end
    local previous = ad.cut
    local same = cut and previous and cut.key == previous.key
    local rewind = same and cut.frame < previous.frame
    if (cut or previous) and (not same or rewind) then
        if ad.speech and not ad.speech.lineup then ad.stop(ad, reader) end
        ad.details_for_cut, ad.timed_for_cut, ad.used = nil, nil, {}
        if cut then
            log(string.format("[OpeningAD] cut=%d role=%s cameras=%s frame=%.2f/%.2f", cut.index,
                tostring(cut.role), cut.cameras or "", cut.frame, cut.limit))
        end
    end
    ad.cut = cut
    if cut and cut.role == "formation" and (not same or cut.panel ~= previous.panel or cut.side ~= previous.side) then
        log(string.format("[OpeningAD] formation visible side=%s frame=%.2f", tostring(cut.side), cut.frame))
    end
    if not reader.game_is_foreground() or reader.overlay_visible or reader.sider_overlay_visible then
        ad.stop(ad, reader)
        return
    end
    local advancing = same and cut.frame > previous.frame
    if settings.ad_lineups~=false and advancing and cut.panel and previous.panel == cut.panel and previous.side == cut.side
            and not ad.queued_sides[cut.side] then
        local lineup = ad.formation_details(ad, ctx, cut.side)
        gp.read_failure = saved
        if lineup then
            lineup.cut = cut
            ad.lineups[#ad.lineups + 1] = lineup
            ad.queued_sides[cut.side] = true
            log(string.format("[OpeningAD] formation queued side=%d frame=%.2f", cut.side, cut.frame))
        end
    end
    if cut and ad.speech and ad.speech.until_frame and cut.frame >= ad.speech.until_frame then ad.stop(ad, reader) end
    if (not cut and #ad.lineups == 0) or not ad.poll_speech(ad, reader) or ad.speak_lineups(ad, reader) then return end
    if settings.ad_opening==false or not advancing or not cut.role or cut.role == "formation" then return end
    local remaining = cut.limit - cut.frame
    if not ad.details_for_cut then
        ad.details_for_cut = ad.details(ad, ctx, cut.role)
        ad.timed_for_cut = ad.visual_details(ad, ctx, cut, ad.details_for_cut)
        gp.read_failure = saved
    end
    if ad.timed_for_cut then
        for index, detail in ipairs(ad.timed_for_cut) do
            local first, last, phrases = unpack(detail)
            if not ad.used[index] and cut.frame >= first and cut.frame < last then
                for _, phrase in ipairs(phrases) do
                    if ad.fits(phrase, last - cut.frame) then
                        ad.used[index] = true
                        if ad.speak(ad, reader, cut, phrase) then ad.speech.until_frame = last end
                        return
                    end
                end
            end
        end
        return
    end
    for index, phrase in ipairs(ad.details_for_cut) do
        if not ad.used[index] and ad.fits(phrase, remaining) then
            ad.used[index] = true
            ad.speak(ad, reader, cut, phrase)
            break
        end
    end
end

function m.reset(ctx)
    local ad = ctx.flaccess.opening_ad
    ad.stop(ad, ctx.flaccess.reader)
    ad.active, ad.cut, ad.reason, ad.details_for_cut, ad.used = false, nil, nil, nil, {}
    ad.assets, ad.timed_for_cut = {}, nil
    ad.lineups, ad.queued_sides = {}, {}
    ad.uniform_key, ad.uniform_spoken = nil, nil
    ad.replay, ad.replay_cues = nil, {}
    ad.replay_geometry_status=nil
    ad.uniform_status, ad.replay_status = nil, nil
end

function m.after_conditions(ctx)
    local ad = ctx.flaccess.opening_ad
    ad.reset(ctx)
    ad.active = ctx.home_team ~= nil and ctx.away_team ~= nil
    if ad.active then log("[OpeningAD] armed") end
end

function m.init(ctx)
    local gp = ctx.flaccess and ctx.flaccess.gameplay
    if not gp or not gp.base then return end
    local checks = {
        {0x401c90, "\xe8\x5b\xfa\xba\x01\x48\x89\x05\xc4\xe5\x2e\x03"},
        {0x1fb03ff, "\x48\x8d\x05\x4a\xa2\xc0\x00\x48\x89\x03"},
        {0x1fd03ec, "\x48\x89\x86\x38\x8f\x01\x00"},
        {0x23f0977, "\x48\x8d\x05\x7a\xf8\x87\x00\x48\x89\x03"},
        {0x1f59934, "\x48\x89\x86\xe0\x00\x00\x00\x44\x88\x86\xe8\x00\x00\x00"},
        {0x1f611b2, "\x49\x69\xc1\xe0\x01\x00\x00\x48\x03\x41\x20\xc3"},
        {0x1f5a6a3, "\x48\x8d\xb5\x88\x00\x00\x00\x48\xc1\xe0\x05"},
        {0x1f2f965, "\xf3\x0f\x10\x5b\x64\x0f\x2f\xda"},
        {0x1f2f9a2, "\xf3\x0f\x58\x4b\x6c\xf3\x0f\x11\x4b\x60"},
        {0x1f23734, "\x48\x8d\x05\x7d\x1a\xc8\x00"},
    }
    for _, check in ipairs(checks) do
        if gp.blob(gp.base + check[1], #check[2]) ~= check[2] then
            log("[OpeningAD] unsupported executable")
            return
        end
    end
    local formation_checks = {
        {0x1fdd3d4, "\xe8\x27\x47\x0e\x00\x48\x89\x86\xc0\x8e\x01\x00"},
        {0x20c0dbd, "\x48\x8d\x05\x2c\x53\xb1\x00\x49\x89\x04\x24"},
        {0x20c1c32, "\x48\x89\x86\x18\x12\x00\x00"},
        {0x20c1c51, "\x48\x89\x86\x20\x12\x00\x00"},
        {0x20d8f1e, "\x48\x8d\x05\x2b\x45\xb0\x00\x48\x89\x03\x89\x7b\x48"},
        {0x20fbc42, "\x89\x7b\x08\x48\x8b\x5c\x24\x38"},
        {0x20da0bf, "\x48\x8b\x0d\x02\x9d\x61\x01\xe8\x65\xe9\x96\xfe\x48\x8d\x88\x08\x8e\x00\x00"},
        {0x20da11a, "\x0f\x10\x80\x20\x02\x00\x00\x0f\x11\x45\xd8"},
        {0x1527419, "\x0f\xb6\x0c\x30\x89\x0b"},
        {0x1527453, "\x0f\xb6\x0c\x28\xeb\x05\xb9\x0d\x00\x00\x00"},
        {0x14c02b6, "\x48\x8d\x43\x38\x48\x83\xc4\x20\x5b\xc3"},
    }
    m.formation_supported = true
    for _, check in ipairs(formation_checks) do
        if gp.blob(gp.base + check[1], #check[2]) ~= check[2] then
            m.formation_supported = false
            break
        end
    end
    local actor_checks = {
        {0x1f500dd, "\x48\x8b\x05\x6c\x5c\x8a\x01\x48\x85\xc0"},
        {0x1f52b01, "\xe8\x1a\x25\x97\xfe\x4c\x8b\xa4\x24\x90\x00\x00\x00"},
        {0x1f52c0d, "\x3b\x6c\x24\x20\x75\x07\xc6\x83\x07\xff\xff\xff\x01"},
        {0x1f56c1e, "\x80\xbc\x02\xf9\x00\x00\x00\x00\x75\x0b"},
        {0x1f56cde, "\x80\xbc\x02\xf8\x00\x00\x00\x00\x75\x0b"},
    }
    m.actors_supported = true
    for _, check in ipairs(actor_checks) do
        if gp.blob(gp.base + check[1], #check[2]) ~= check[2] then
            m.actors_supported = false
            break
        end
    end
    local uniform_checks = {
        {0xaaae0f, "\x48\x8d\x05\x1a\x12\xbc\x01\x48\x89\x03"},
        {0xaabb7d, "\x8b\xbc\xb5\x98\x00\x00\x00\x48\x8d\x0c\x76"},
        {0x14c2010, "\x48\x63\xc2\x44\x89\x84\x81\x20\x01\x00\x00\xc3"},
        {0xe3d144, "\x4c\x8b\x81\x88\x00\x00\x00\x49\x8b\x80\xb0\x00\x00\x00"},
        {0xe3d182, "\x41\x8b\x80\xd8\x00\x00\x00\x48\x83\xc4\x28\xc3"},
        {0xe8dc40, "\x48\x8b\x81\x78\x01\x00\x00\x4c\x8b\xc1\x48\x2b\x81\x70\x01\x00\x00"},
        {0xe4d1d2, "\x48\x8b\x50\x40\x44\x39\x92\x88\x00\x00\x00"},
    }
    m.uniform_supported = true
    for _, check in ipairs(uniform_checks) do
        if gp.blob(gp.base + check[1], #check[2]) ~= check[2] then
            m.uniform_supported = false
            break
        end
    end
    local replay_checks = {
        {0x20ebd3c, "\x48\x8b\x05\x85\x80\x60\x01\x48\x8b\xb0\x88\x03\x00\x00"},
        {0x20ebb78, "\x48\x8b\x88\x88\x03\x00\x00\x80\x79\x07\x00"},
        {0xa86720, "\x84\xd2\x75\x0d\x88\x11\x88\x51\x07\xc6\x41\x02\x13"},
        {0x20b8f28, "\x89\x43\x14\x41\x8b\xc3\x41\x2b\xc2"},
        {0x20b8e0c, "\x89\x43\x10\x33\xc0\x48\x89\x43\x14\x89\x43\x1c"},
        {0x20b8fc4, "\x88\x43\x07\x0f\xb6\x46\x5c\x88\x43\x0a"},
    }
    m.replay_supported = true
    for _, check in ipairs(replay_checks) do
        if gp.blob(gp.base + check[1], #check[2]) ~= check[2] then
            m.replay_supported = false
            break
        end
    end
    local geometry_checks={
        {0x20b388c, "\x48\x8d\x05\xbd\x05\xb2\x00\x48\x89\x03"},
        {0x1fdbec7, "\x48\x89\x83\x38\x01\x00\x00"},
        {0x20b8e97, "\x48\x69\xc8\xb0\x1f\x00\x00\x48\x8b\x05\x73\xc2\x63\x01\x49\x03\x4e\x40"},
        {0x20b2042, "\x0f\xbf\x81\x50\x02\x00\x00"},
        {0xa8a170, "\x8b\x0d\x9e\xaf\xc6\x02\xb8\x94\x02\x00\x00\x85\xc9\x0f\x45\xc1\xc3"},
    }
    m.replay_geometry_supported=true
    for _,check in ipairs(geometry_checks) do
        if gp.blob(gp.base+check[1],#check[2])~=check[2] then m.replay_geometry_supported=false;break end
    end
    ctx.flaccess.opening_ad = m
    m.verified_textures = {}
    m.busy = ffi.new("bool[1]")
    m.reset(ctx)
    ctx.register("context_reset", m.reset)
    ctx.register("after_set_conditions", m.after_conditions)
    ctx.register("display_frame", m.display_frame)
    ctx.register("livecpk_data_ready", m.data_ready)
    log("[OpeningAD] experimental speech loaded; formation=" .. tostring(m.formation_supported)
        .. " actors=" .. tostring(m.actors_supported) .. " uniform=" .. tostring(m.uniform_supported)
        .. " replay-supported=" .. tostring(m.replay_supported)
        .. " replay-enabled=" .. tostring(m.replays_enabled))
end

return m
