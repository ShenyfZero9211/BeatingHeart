local SharedMem = require("src.sharedmem")

local Menu = {}
local memConfig = nil

local i18n = require("src.i18n")

local buttons = {
    { text_key = "tray_settings", y = 15, h = 30, action = "settings" },
    { text_key = "tray_exit", y = 55, h = 30, action = "exit" }
}

local hovered = nil

function Menu.init(config)
    memConfig = config
end

function Menu.update(dt)
    if memConfig and memConfig.shouldExit == 1 then
        love.event.quit()
        return
    end

    local mx, my = love.mouse.getPosition()
    hovered = nil
    for _, b in ipairs(buttons) do
        if mx >= 10 and mx <= 150 and my >= b.y and my <= b.y + b.h then
            hovered = b.action
        end
    end
    
    if memConfig and memConfig.showMenu == 1 then
        love.window.setPosition(memConfig.menuX - 80, memConfig.menuY - 100)
        local Tray = require("src.tray")
        Tray.restore()
        memConfig.showMenu = 0
    elseif memConfig and memConfig.showMenu == -1 then
        local Tray = require("src.tray")
        Tray.hide()
        memConfig.showMenu = 0
    end
end

function Menu.mousepressed(x, y, button)
    if button == 1 then
        if hovered == "settings" then
            local Tray = require("src.tray")
            if not Tray.showSpecificWindow("Settings") then
                Tray.spawnProcess('love . settings')
            end
            Tray.hide()
        elseif hovered == "exit" then
            if memConfig then
                memConfig.shouldExit = 1
            end
        end
    end
end

local Fonts = require("src.fonts")
local menuFont = nil

function Menu.draw()
    if not menuFont then menuFont = Fonts.load(14) end
    love.graphics.setFont(menuFont)

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
        
        local langID = memConfig and memConfig.language or 0
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.print(i18n.get(b.text_key, langID), 25, b.y + 7)
    end
end

-- Replicate native WinUI behavior: close menu automatically if clicked away
function Menu.focus(f)
    if not f then
        local Tray = require("src.tray")
        Tray.hide()
    end
end

return Menu
