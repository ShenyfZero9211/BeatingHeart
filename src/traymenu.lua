local SharedMem = require("src.sharedmem")

local Menu = {}
local memConfig = nil

local buttons = {
    { text = "Settings", y = 15, h = 30, action = "settings" },
    { text = "Exit / Quit", y = 55, h = 30, action = "exit" }
}

local hovered = nil

function Menu.init(config)
    memConfig = config
end

function Menu.update(dt)
    local mx, my = love.mouse.getPosition()
    hovered = nil
    for _, b in ipairs(buttons) do
        if mx >= 10 and mx <= 150 and my >= b.y and my <= b.y + b.h then
            hovered = b.action
        end
    end
end

function Menu.mousepressed(x, y, button)
    if button == 1 then
        if hovered == "settings" then
            local Tray = require("src.tray")
            if not Tray.showSpecificWindow("Settings") then
                Tray.spawnProcess('love . settings')
            end
            love.event.quit()
        elseif hovered == "exit" then
            if memConfig then
                memConfig.shouldExit = 1
            end
            love.event.quit()
        end
    end
end

function Menu.draw()
    -- Create aesthetic frosted glass blur panel
    love.graphics.setColor(0.12, 0.12, 0.14, 0.95)
    love.graphics.rectangle("fill", 0, 0, 160, 100, 10)
    
    -- Mac-style 1px highlight line
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 0, 0, 160, 100, 10)
    
    -- Draw interactive elements
    for _, b in ipairs(buttons) do
        if hovered == b.action then
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.rectangle("fill", 10, b.y, 140, b.h, 6)
        end
        
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.print(b.text, 25, b.y + 7)
    end
end

-- Replicate native WinUI behavior: close menu automatically if clicked away
function love.focus(f)
    if not f then
        love.event.quit()
    end
end

return Menu
