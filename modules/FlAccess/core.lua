-- FLAccess 0.2.0. Shared services; the base reader is always loaded.
local m = {}
function m.init(ctx)
    assert(not ctx.flaccess, "FLAccess is already initialized; remove duplicate/legacy module entries")
    local root = ctx.sider_dir .. "modules\\FlAccess\\"
    ctx.flaccess = {
        version = "0.2.0", root = root,
        content = ctx.sider_dir .. "content\\FlAccess\\",
        reader = {stage = 0}, gameplay = {stage = 0},
    }
    local reader = ctx.flaccess.reader
    function reader.save_config_values(a11y)
        if not a11y.config_path then return end
        local lines, seen = {}, {}
        local values = {read_tooltips = tostring(a11y.read_tooltips), use_text_assets = tostring(a11y.use_text_assets)}
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
        for _,key in ipairs({"read_tooltips", "use_text_assets"}) do
            if not seen[key] then lines[#lines+1] = key .. " = " .. values[key] end
        end
        local file = io.open(a11y.config_path, "wt")
        if not file then log("[FLAccess] config-write-failed " .. a11y.config_path); return end
        file:write(table.concat(lines, "\n"), "\n"); file:close()
    end
    log("[FLAccess] version=0.2.0 native components; mandatory base reader")
end
return m
