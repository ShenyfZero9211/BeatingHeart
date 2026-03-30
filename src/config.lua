local Config = {}

local default_config = {
    size = 150,
    sensitivity = 1.0,
    color_r = 1.0,
    color_g = 0.2,
    color_b = 0.3,
    color_a = 1.0,
    posX = 100,
    posY = 100,
    isTopmost = 1,
    language = 0 -- 0: Auto, 1: EN, 2: ZH
}

function Config.load()
    local f = io.open("settings.ini", "r")
    if not f then
        -- [INITIALIZE] 如果没有 .ini，新建初始化配置
        Config.save(default_config)
        return default_config
    end

    -- [READ] 如果有 .ini，读取信息初始化
    local content = f:read("*all")
    f:close()
    
    local cfg = {}
    for k, v in pairs(default_config) do cfg[k] = v end

    if content then
        for line in content:gmatch("[^\r\n]+") do
            local key, value = line:match("^([^=%s]+)%s*=%s*(.+)$")
            if key and value then
                if tonumber(value) then
                    cfg[key] = tonumber(value)
                else
                    cfg[key] = value
                end
            end
        end
    end
    return cfg
end

function Config.save(config)
    local f = io.open("settings.ini", "w")
    if f then
        f:write("[Settings]\n")
        local keys = {"size", "sensitivity", "color_r", "color_g", "color_b", "color_a", "posX", "posY", "isTopmost", "language"}
        for _, k in ipairs(keys) do
            local v = config[k]
            if v ~= nil then
                f:write(k .. " = " .. tostring(v) .. "\n")
            end
        end
        f:close()
    end
end

return Config
