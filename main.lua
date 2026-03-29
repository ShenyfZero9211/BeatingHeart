local Config = require("src.config")
local SharedMem = require("src.sharedmem")

local memConfig = nil
local isSettingsMode = false
local isMenuMode = false
local draggingWindow = false
local dragOffsetX, dragOffsetY = 0, 0
local lastSetSize = 0
local lastTopmost = -1
local menuSpawned = false

-- Physics State for Heart organic animation
local currentScale = 0
local currentVelocity = 0

local Audio, Heart, Tray

function love.load(args)
    if args then
        for i, v in ipairs(args) do
            if v == "settings" then isSettingsMode = true end
            if v == "menu" then isMenuMode = true end
        end
    end
    
    local isCreator = false
    memConfig, isCreator = SharedMem.init()
    if memConfig then
        memConfig.shouldExit = 0
    end
    
    if not memConfig then 
        memConfig = {size=150, sensitivity=1.0, color_r=1, color_g=0.2, color_b=0.3, color_a=1, posX=100, posY=100, shouldExit=0, menuX=0, menuY=0, showMenu=0, isTopmost=1}
    else
        if not isSettingsMode and not isMenuMode then
            local localConfig = Config.load()
            memConfig.size = localConfig.size or 150
            memConfig.sensitivity = localConfig.sensitivity or 1.0
            memConfig.color_r = localConfig.color and localConfig.color[1] or 1
            memConfig.color_g = localConfig.color and localConfig.color[2] or 0.2
            memConfig.color_b = localConfig.color and localConfig.color[3] or 0.3
            memConfig.color_a = localConfig.color and localConfig.color[4] or 1
            memConfig.posX = localConfig.posX or 100
            memConfig.posY = localConfig.posY or 100
            memConfig.isTopmost = (localConfig.isTopmost == nil) and 1 or localConfig.isTopmost
        end
    end
    
    if isSettingsMode then
        local GUI = require("src.gui")
        Tray = require("src.tray")
        Tray.init("Settings", nil, nil, true)
        Tray.hideFromTaskbar()
        GUI.init(memConfig)
        love.graphics.setBackgroundColor(0.12, 0.12, 0.14)
        
    elseif isMenuMode then
        local Menu = require("src.traymenu")
        Tray = require("src.tray")
        Tray.init("BeatingHeartMenu", nil, nil, true)
        Tray.hideFromTaskbar()
        Tray.makeTransparent()
        Menu.init(memConfig)
        
    else
        Heart = require("src.heart")
        Audio = require("src.audio")
        Tray = require("src.tray")
        
        love.graphics.setBackgroundColor(0, 0, 0, 0)
        Audio.init()
        
        love.timer.sleep(0.01)
        Tray.init("Beating Heart", function()
            -- Native Tray menu clicked "Settings" -> load standard Settings layout dialog
            if not Tray.showSpecificWindow("Settings") then
                Tray.spawnProcess('love . settings')
            end
        end, function()
            memConfig.shouldExit = 1
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
        
    elseif isMenuMode then
        local Menu = require("src.traymenu")
        Menu.update(dt)
        
    else
        if memConfig.shouldExit == 1 then
            love.event.quit()
            return
        end
        
        Audio.update()
        
        -- The Spring-Mass Simulation for organic heartbeats!
        local rawEnergy = Audio.getEnergy() * memConfig.sensitivity
        local targetScale = rawEnergy * 2.0 -- Target inflation
        
        local springK = 80.0 -- Hardness of the imaginary spring
        local damping = 9.0  -- Organic tissue decay rate
        
        local force = (targetScale - currentScale) * springK - currentVelocity * damping
        currentVelocity = currentVelocity + force * dt
        currentScale = currentScale + currentVelocity * dt
        
        if currentScale < 0 then currentScale = 0 end
        
        -- Apply Z-Order Topmost synchronization
        if lastTopmost ~= memConfig.isTopmost then
            Tray.setTopmost(memConfig.isTopmost == 1)
            lastTopmost = memConfig.isTopmost
        end
        
        if draggingWindow then
            local mx, my = Tray.getCursorPos()
            local newX, newY = mx - dragOffsetX, my - dragOffsetY
            love.window.setPosition(newX, newY)
            memConfig.posX = newX
            memConfig.posY = newY
        end
        
        -- Pixel-perfect Ghost Window Hit-Testing
        local wx, wy = love.window.getPosition()
        local mx, my = Tray.getCursorPos()
        local localX, localY = mx - wx, my - wy
        
        -- Approximate radius constraint (the heart draws up to roughly 0.8 * size)
        local winW, winH = love.graphics.getDimensions()
        local dist2 = (localX - winW/2)^2 + (localY - winH/2)^2
        local hitRadius = memConfig.size * 0.95
        
        if dist2 > hitRadius^2 and not draggingWindow then
            Tray.setClickThrough(true)
        else
            Tray.setClickThrough(false)
        end
    end
end

function love.draw()
    if isSettingsMode then
        local GUI = require("src.gui")
        GUI.draw()
    elseif isMenuMode then
        local Menu = require("src.traymenu")
        Menu.draw()
    else
        love.graphics.clear(0, 0, 0, 0)
        local w, h = love.graphics.getDimensions()
        
        -- Aesthetic Color Infusion
        -- Rapid pulse forces red and dark blood flush interpolation dynamically
        local r = math.min(1, math.max(0, memConfig.color_r + currentScale * 0.4))
        local g = math.min(1, math.max(0, memConfig.color_g - currentScale * 0.2))
        local b = math.min(1, math.max(0, memConfig.color_b - currentScale * 0.2))

        Heart.draw(w/2, h/2, memConfig.size, {r, g, b, memConfig.color_a}, currentScale)
    end
end

function love.keypressed(key)
    if key == "escape" then
        if isSettingsMode or isMenuMode then
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
    elseif isMenuMode then
        local Menu = require("src.traymenu")
        Menu.mousepressed(x, y, button)
        return
    end
    
    if button == 1 then
        memConfig.showMenu = -1 -- Explicitly banish customized tray menu upon main window interaction
        draggingWindow = true
        local wx, wy = love.window.getPosition()
        local mx, my = Tray.getCursorPos()
        dragOffsetX = mx - wx
        dragOffsetY = my - wy
    end
end

function love.focus(f)
    if isMenuMode then
        local Menu = require("src.traymenu")
        if Menu.focus then Menu.focus(f) end
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 and draggingWindow then
        draggingWindow = false
    end
end

function love.quit()
    if not isSettingsMode and not isMenuMode then
        Config.save({
            size = memConfig.size,
            sensitivity = memConfig.sensitivity,
            color = {memConfig.color_r, memConfig.color_g, memConfig.color_b, memConfig.color_a},
            posX = memConfig.posX,
            posY = memConfig.posY,
            isTopmost = memConfig.isTopmost
        })
    end
    
    if Tray then Tray.cleanup() end
    SharedMem.cleanup()
    return false
end
