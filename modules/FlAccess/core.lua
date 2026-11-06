-- FLAccess 0.2.0. Shared services; the base reader is always loaded.
local m = {}
function m.init(ctx)
    assert(not ctx.flaccess, "FLAccess is already initialized; remove duplicate/legacy module entries")
    local root = ctx.sider_dir .. "modules\\FlAccess\\"
    ctx.flaccess = {
        version = "0.2.1", root = root,
        content = ctx.sider_dir .. "content\\FlAccess\\",
        reader = {stage = 0}, gameplay = {stage = 0},
    }
    local reader = ctx.flaccess.reader
    local gameplay=ctx.flaccess.gameplay
    gameplay.sound_level_max=300
    gameplay.ball_speed=100
    gameplay.sound_levels={ball=100,sidelines=100,endline=100,own_goal=100,opponent_goal=100,
        gotBall=100,LostBall=100,teamStillWithBall=100}
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
