local Config = require("src.config")
local SharedMem = require("src.sharedmem")

local memConfig = nil
local isSettingsMode = false
local isMenuMode = false
local draggingWindow = false
local dragOffsetX, dragOffsetY = 0, 0
local lastTopmost = -1
local sensoryGate = 0.1 
local arousalBuffer = 0.0
local arousalSway = 0.0
local heartFloatX, heartFloatY = 0, 0

-- Physics State for Heart organic animation
local currentScale = 0
local currentVelocity = 0

-- Bionic Brain Logic
local arousal = 0.0
local arousalColor = 0.0
local arousalSpeed = 0.0
local arousalScale = 0.0
local arousalMotion = 0.0
local excitationMomentum = 0.0
local targetArousal = 0.0
local beatPhase = 0.0
local phaseSpeed = 2.5

local Audio, Heart, Tray, Bubble

function love.load(args)
    if args then
        for _, v in ipairs(args) do
            if v == "settings" then isSettingsMode = true end
            if v == "menu" then isMenuMode = true end
        end
    end

    local isFirstInstance = false
    memConfig, isFirstInstance = SharedMem.init()
    
    if not isFirstInstance and not isSettingsMode and not isMenuMode then
        love.event.quit()
        return
    end

    if isMenuMode then
        Tray = require("src.tray")
        Tray.init("BeatingHeartMenu", memConfig, true)
        Tray.hideFromTaskbar() -- 完全从任务栏消失
        Tray.showNativeMenu(memConfig)
        love.event.quit()
        return
    end

    if isFirstInstance then
        local localConfig = Config.load()
        memConfig.size = localConfig.size or 150
        memConfig.sensitivity = localConfig.sensitivity or 1.0
        memConfig.color_r = localConfig.color_r or 1
        memConfig.color_g = localConfig.color_g or 0.2
        memConfig.color_b = localConfig.color_b or 0.3
        memConfig.color_a = localConfig.color_a or 1
        memConfig.posX = localConfig.posX or 100
        memConfig.posY = localConfig.posY or 100
        memConfig.isTopmost = (localConfig.isTopmost == nil) and 1 or localConfig.isTopmost
        memConfig.language = localConfig.language or 0
    end

    local i18n = require("src.i18n")
    i18n.init()
    
    Tray = require("src.tray")
    
    if isSettingsMode then
        local GUI = require("src.gui")
        Tray.init("Settings", memConfig, true) 
        Tray.makeTransparent()
        Tray.hideFromTaskbar()
        GUI.init(memConfig)
        love.graphics.setBackgroundColor(0, 0, 0, 0)
    else
        Heart = require("src.heart")
        Audio = require("src.audio")
        Bubble = require("src.bubble")
        
        love.graphics.setBackgroundColor(0, 0, 0, 0)
        Audio.init()
        
        love.timer.sleep(0.01)
        Tray.init("Beating Heart", memConfig)
        Tray.makeTransparent()
        Tray.hideFromTaskbar()
        love.window.setPosition(memConfig.posX, memConfig.posY)
        
        -- Default startup state
        Tray.setClickThrough(true)
        Tray.setTopmost(memConfig.isTopmost == 1)
        lastTopmost = memConfig.isTopmost
    end
end

function love.update(dt)
    if isSettingsMode then
        local GUI = require("src.gui")
        GUI.update(dt)
        
        if draggingWindow then
            local mx, my = Tray.getCursorPos()
            local newX, newY = mx - dragOffsetX, my - dragOffsetY
            love.window.setPosition(newX, newY)
        end
    elseif isMenuMode then
        -- Native Menu blocks
    else
        if memConfig.shouldExit == 1 then
            love.event.quit()
            return
        end
        
        Audio.update(dt)
        local lowF, midF, hiF = Audio.getBands()
        local beatPulse = Audio.getBeatPulse()
        
        -- 生态唤醒逻辑
        if lowF > 0.05 or midF > 0.05 then
            sensoryGate = math.min(1.0, sensoryGate + dt * 0.08) 
        else
            sensoryGate = math.max(0.1, sensoryGate - dt * 0.04) 
        end
        
        -- 应用设置
        lowF = lowF * memConfig.sensitivity * sensoryGate
        midF = midF * memConfig.sensitivity * sensoryGate
        hiF = hiF * memConfig.sensitivity * sensoryGate
        
        local rawEnergy = math.pow(lowF, 1.8) * 8.0 
        local heatInput = (rawEnergy * 1.5 + beatPulse * 4.0) * dt
        if heatInput > 0.01 then
            targetArousal = math.min(1.0, targetArousal + heatInput * 1.5)
        else
            targetArousal = math.max(0.0, targetArousal - dt * 0.05)
        end
        
        if targetArousal > 0.1 then
            arousalBuffer = math.min(1.0, arousalBuffer + dt * 0.1)
        else
            arousalBuffer = math.max(0.0, arousalBuffer - dt * 0.05)
        end
        
        local finalTarget = targetArousal * arousalBuffer
        arousal = arousal + (finalTarget - arousal) * dt * 1.5
        
        arousalColor = arousalColor + (arousal - arousalColor) * dt * 5.0
        arousalSpeed = arousalSpeed + (arousal - arousalSpeed) * dt * 1.5
        arousalScale = arousalScale + (arousal - arousalScale) * dt * 0.4
        arousalMotion = arousalMotion + (arousal - arousalMotion) * dt * 0.08
        
        -- [MOMENTUM SWAY] 动能累加逻辑：积累慢(0.3)，衰减更慢(0.15)
        local swayTarget = arousal * 0.8 + beatPulse * 0.2
        local swayAlpha = (swayTarget > arousalSway) and 0.3 or 0.15
        arousalSway = arousalSway + (swayTarget - arousalSway) * dt * swayAlpha
        
        local targetPhaseSpeed = 2.5 + arousalSpeed * 9.5
        phaseSpeed = phaseSpeed + (targetPhaseSpeed - phaseSpeed) * dt * 0.2
        beatPhase = beatPhase + phaseSpeed * dt
        
        local targetScale = rawEnergy
        local springK = 35.0 + arousal * 320.0  
        local damping = 16.0 - arousal * 11.0   
        
        local force = (targetScale - currentScale) * springK - currentVelocity * damping
        currentVelocity = currentVelocity + force * dt
        currentScale = currentScale + currentVelocity * dt
        if currentScale < 0 then currentScale = 0 end
        
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
        
        -- [DRAG OPTIMIZATION] 移动物理到逻辑层，实现像素级精准判定
        local t = love.timer.getTime()
        local aSwayFactor = arousalSway * arousalSway
        local floatSpeed = 0.4 + aSwayFactor * 0.4
        heartFloatX = math.sin(t * 0.7 * floatSpeed) * (2 + lowF * 10 + aSwayFactor * 40)
        heartFloatY = math.cos(t * 0.5 * floatSpeed) * (3 + lowF * 10 + aSwayFactor * 40)

        -- Hit-Testing for click-through (同步缩放与位移)
        local wx, wy = love.window.getPosition()
        local mx, my = Tray.getCursorPos()
        local winW, winH = love.graphics.getDimensions()
        
        -- 核心：判定圆心随心脏位移同步偏移
        local centerX, centerY = winW/2 + heartFloatX, winH/2 + heartFloatY
        local dist2 = (mx - wx - centerX)^2 + (my - wy - centerY)^2
        
        -- 核心：判定半径计入实时跳动缩放(currentScale)，并增加 20% 缓冲区
        local pulseScale = 1.0 + currentScale * 0.4
        local hitRadius = memConfig.size * pulseScale * 1.2
        
        if dist2 > hitRadius^2 and not draggingWindow then
            Tray.setClickThrough(true)
        else
            Tray.setClickThrough(false)
        end
        
        if arousal > 0.75 then
            excitationMomentum = math.min(1.0, excitationMomentum + dt * 0.06)
        else
            excitationMomentum = math.max(0.0, excitationMomentum - dt * 0.12)
        end
        
        Bubble.update(dt, arousal, memConfig)
    end
end

function love.draw()
    if isSettingsMode then
        local GUI = require("src.gui")
        GUI.draw()
    elseif isMenuMode then
        -- Nothing
    else
        love.graphics.clear(0, 0, 0, 0)
        local w, h = love.graphics.getDimensions()
        
        local baseR = memConfig.color_r + (arousalColor * 0.2)
        local baseG = memConfig.color_g - ((1.0 - arousalColor) * 0.1)
        local baseB = memConfig.color_b + ((1.0 - arousalColor) * 0.15)
        
        local r = math.min(1, math.max(0, baseR + currentScale * 0.4))
        local g = math.min(1, math.max(0, baseG - currentScale * 0.2))
        local b = math.min(1, math.max(0, baseB - currentScale * 0.2))

        local lowF, midF, hiF = Audio.getBands()
        lowF = lowF * memConfig.sensitivity * sensoryGate
        midF = midF * memConfig.sensitivity * sensoryGate
        hiF = hiF * memConfig.sensitivity * sensoryGate
        
        local arousalTable = {
            color = arousalColor, speed = arousalSpeed,
            scale = arousalScale, motion = arousalMotion,
            sway = arousalSway,
            floatX = heartFloatX, floatY = heartFloatY -- 传给渲染器同步显示
        }
        
        Heart.draw(w/2, h/2, memConfig.size, {r, g, b, memConfig.color_a}, currentScale + (lowF*0.5), midF, hiF, arousalTable, beatPhase, Audio.getBeatPulse(), excitationMomentum)
        Bubble.draw(w/2, h/2)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if isSettingsMode then
        local GUI = require("src.gui")
        if GUI.mousepressed(x, y, button) then return end
        
        if button == 1 and GUI.isTitleAreaHit(x, y) then
            draggingWindow = true
            local wx, wy = love.window.getPosition()
            local mx, my = Tray.getCursorPos()
            dragOffsetX = mx - wx
            dragOffsetY = my - wy
        end
        return
    end
    
    if button == 1 then
        draggingWindow = true
        local wx, wy = love.window.getPosition()
        local mx, my = Tray.getCursorPos()
        dragOffsetX = mx - wx
        dragOffsetY = my - wy
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 and draggingWindow then
        draggingWindow = false
    end
end

function love.quit()
    if Audio and Audio.stop then Audio.stop() end
    if memConfig and not isMenuMode then
        Config.save({
            size = memConfig.size,
            sensitivity = memConfig.sensitivity,
            color_r = memConfig.color_r,
            color_g = memConfig.color_g,
            color_b = memConfig.color_b,
            color_a = memConfig.color_a,
            posX = memConfig.posX,
            posY = memConfig.posY,
            isTopmost = memConfig.isTopmost,
            language = memConfig.language
        })
    end
    if Tray and Tray.cleanup then Tray.cleanup() end
    if SharedMem and SharedMem.cleanup then SharedMem.cleanup() end
    return false
end
