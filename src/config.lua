local Config = {}

local default_config = {
    size = 150,
    sensitivity = 1.0,
    color = {1, 0.2, 0.3, 1},
    posX = 100,
    posY = 100
}

function Config.load()
    if love.filesystem.getInfo("settings.lua") then
        local chunk = love.filesystem.load("settings.lua")
        if chunk then
            local success, data = pcall(chunk)
            if success and type(data) == "table" then
                for k, v in pairs(data) do
                    default_config[k] = v
                end
            end
        end
    end
    return default_config
end

function Config.save(config)
    local str = "return {\n"
    for k, v in pairs(config) do
        if type(v) == "table" then
            str = str .. "  " .. k .. " = {" .. table.concat(v, ", ") .. "},\n"
        elseif type(v) == "string" then
             str = str .. "  " .. k .. " = '" .. v .. "',\n"
        elseif type(v) == "boolean" then
            str = str .. "  " .. k .. " = " .. tostring(v) .. ",\n"
        else
            str = str .. "  " .. k .. " = " .. tostring(v) .. ",\n"
        end
    end
    str = str .. "}\n"
    love.filesystem.write("settings.lua", str)
end

return Config
