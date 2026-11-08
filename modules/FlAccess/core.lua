-- FLAccess 0.2.0. Shared services; the base reader is always loaded.
local m = {}
function m.init(ctx)
    assert(not ctx.flaccess, "FLAccess is already initialized; remove duplicate/legacy module entries")
    local root = ctx.sider_dir .. "modules\\FlAccess\\"
    ctx.flaccess = {
        version = "0.2.2", root = root,
        content = ctx.sider_dir .. "content\\FlAccess\\",
        reader = {stage = 0}, gameplay = {stage = 0},
    }
    local reader = ctx.flaccess.reader
    local gameplay=ctx.flaccess.gameplay
    gameplay.radar_groups={"marked","free","opponent"}
    gameplay.radar_defaults={enabled=0,mode=0,radius=20,pressure_enabled=1,pressure_radius=3,pressure_volume=50}
    for index,group in ipairs(gameplay.radar_groups) do
        local defaults=gameplay.radar_defaults
        defaults[group.."_enabled"]=1
        defaults[group.."_volume"]=40
        defaults[group.."_count"]=({3,1,2})[index]
    end
    gameplay.radar={}
    for key,value in pairs(gameplay.radar_defaults) do gameplay.radar[key]=value end
    function gameplay.radar_bounds(key)
        local suffix=key:match("_(%a+)$")
        if key=="radius" then return 1,60,1 end
        if key=="pressure_radius" then return 1,12,1 end
        if suffix=="count" then return 0,11,1 end
        if suffix=="volume" then return 0,gameplay.sound_level_max,5 end
        return 0,1
    end
    gameplay.sound_level_max=300
    gameplay.ball_speed=100
    gameplay.sound_levels={ball=100,sidelines=100,endline=100,own_goal=100,opponent_goal=100,
        gotBall=100,LostBall=100,teamStillWithBall=100,controlled=100}
    gameplay.sound_speeds={sidelines=100,endline=100,own_goal=100,opponent_goal=100,gotBall=100,
        LostBall=100,teamStillWithBall=100,controlled=100,tackle=100,marked=100,free=100,opponent=100,pressure=100}
    gameplay.sound_enabled={}
    function gameplay.sound_gain(key)
        return gameplay.sound_enabled[key]==false and 0 or gameplay.sound_levels[key]/100
    end
    function reader.save_config_values(a11y,extra_key,extra_value)
        if not a11y.config_path then return end
        local lines, seen = {}, {}
        local values = {read_tooltips = tostring(a11y.read_tooltips), use_text_assets = tostring(a11y.use_text_assets)}
        values.possession_interval=tostring(a11y.possession_interval)
        values.possession_number=tostring(a11y.possession_number)
        local keys={"read_tooltips", "use_text_assets", "possession_interval", "possession_number"}
        if extra_key then
            values[extra_key]=extra_value
            keys[#keys+1]=extra_key
        end
        local old = io.open(a11y.config_path, "rt")
        if old then
            for line in old:lines() do
                local key = line:match("^%s*([%w_]+)%s*=")
                if key and values[key] then
                    line = key .. " = " .. values[key]
                    seen[key] = true
                end
                lines[#lines+1] = line
            end
            old:close()
        end
        for _,key in ipairs(keys) do
            if not seen[key] then lines[#lines+1] = key .. " = " .. values[key] end
        end
        local file = io.open(a11y.config_path, "wt")
        if not file then log("[FLAccess] config-write-failed " .. a11y.config_path); return end
        file:write(table.concat(lines, "\n"), "\n"); file:close()
    end
    log("[FLAccess] version=" .. ctx.flaccess.version .. " native components; mandatory base reader")
end
return m
