local Config = require("src.config")
local SharedMem = require("src.sharedmem")

local memConfig = nil
local isSettingsMode = false
local draggingWindow = false
local dragOffsetX, dragOffsetY = 0, 0

local Audio, Heart, Tray -- Lazy load hooks

function love.load(args)
    if args then
        for i, v in ipairs(args) do
            if v == "settings" then isSettingsMode = true end
        end
    end
    
    local isCreator = false
    memConfig, isCreator = SharedMem.init()
    
    if not memConfig then
        memConfig = {
            size=150, sensitivity=1.0, 
            color_r=1, color_g=0.2, color_b=0.3, color_a=1, 
            posX=100, posY=100
        }
    else
        if not isSettingsMode then
            local localConfig = Config.load()
            memConfig.size = localConfig.size or 150
            memConfig.sensitivity = localConfig.sensitivity or 1.0
            memConfig.color_r = localConfig.color and localConfig.color[1] or 1
            memConfig.color_g = localConfig.color and localConfig.color[2] or 0.2
            memConfig.color_b = localConfig.color and localConfig.color[3] or 0.3
            memConfig.color_a = localConfig.color and localConfig.color[4] or 1
            memConfig.posX = localConfig.posX or 100
            memConfig.posY = localConfig.posY or 100
        end
    end
    
    if isSettingsMode then
        local GUI = require("src.gui")
        Tray = require("src.tray")
        -- Initialize settings window internally so it can be hidden instead of destroyed
        Tray.init("Settings", nil, nil, true)
        
        GUI.init(memConfig)
        love.graphics.setBackgroundColor(0.12, 0.12, 0.14)
    else
        Heart = require("src.heart")
        Audio = require("src.audio")
        Tray = require("src.tray")
        
        love.graphics.setBackgroundColor(0, 0, 0, 0)
        Audio.init()
        
        love.timer.sleep(0.01) -- Reduce startup sleep overhead
        Tray.init("Beating Heart", function() 
            -- Check if settings is already running but just hidden
            if not Tray.showSpecificWindow("Settings") then
                -- Bypass heavily blocking 'cmd.exe', invoke direct NT execution kernel
                Tray.spawnProcess('love . settings')
            end
        end, function() 
            love.event.quit()
        end)
        
        Tray.makeTransparent()
        Tray.hideFromTaskbar()
        love.window.setPosition(memConfig.posX, memConfig.posY)
    end
end

function love.update(dt)
    if isSettingsMode then
        local GUI = require("src.gui")
        GUI.update(dt)
    else
        Audio.update()
        if draggingWindow then
            local mx, my = Tray.getCursorPos()
            local newX, newY = mx - dragOffsetX, my - dragOffsetY
            love.window.setPosition(newX, newY)
            memConfig.posX = newX
            memConfig.posY = newY
        end
    end
end

function love.draw()
    if isSettingsMode then
        local GUI = require("src.gui")
        GUI.draw()
    else
        love.graphics.clear(0, 0, 0, 0)
        local w, h = love.graphics.getDimensions()
        local energy = Audio.getEnergy() * memConfig.sensitivity
        Heart.draw(w/2, h/2, memConfig.size, {memConfig.color_r, memConfig.color_g, memConfig.color_b, memConfig.color_a}, energy)
    end
end

function love.keypressed(key)
    if key == "escape" then
        if isSettingsMode then
            -- 仅隐藏自己，而非销毁进程，下次呼出会 0 延迟
            Tray.hide()
        else
            Tray.hide()
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if isSettingsMode then
        local GUI = require("src.gui")
        GUI.mousepressed(x, y, button)
        return
    end
    
    if button == 1 then
        draggingWindow = true
        local wx, wy = love.window.getPosition()
        local mx, my = Tray.getCursorPos()
        dragOffsetX = mx - wx
        dragOffsetY = my - wy
    elseif button == 2 then
        Tray.showMenu()
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 and draggingWindow then
        draggingWindow = false
    end
end

function love.quit()
    Config.save({
        size = memConfig.size,
        sensitivity = memConfig.sensitivity,
        color = {memConfig.color_r, memConfig.color_g, memConfig.color_b, memConfig.color_a},
        posX = memConfig.posX,
        posY = memConfig.posY
    })
    
    if isSettingsMode then
        if Tray then Tray.cleanup() end
    else
        if Tray then Tray.cleanup() end
    end
    
    SharedMem.cleanup()
    return false
end
