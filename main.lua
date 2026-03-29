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

-- Bionic Brain Logic: Asynchronous Synesthetic Response (ASR)
local arousal = 0.0          -- 核心情绪底色
local arousalColor = 0.0     -- 颜色响应 (极快: 5.0)
local arousalSpeed = 0.0     -- 频率响应 (中速: 1.5)
local arousalScale = 0.0     -- 体积响应 (慢速: 0.6)
local arousalMotion = 0.0    -- 位移响应 (极慢: 0.2)
local targetArousal = 0.0
local beatPhase = 0.0
local phaseSpeed = 2.5
local sensoryGate = 0.1 -- 感官唤醒门限 (0.1 ~ 1.0)

local Audio, Heart, Tray, Bubble

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
        memConfig = {size=150, sensitivity=1.0, color_r=1, color_g=0.2, color_b=0.3, color_a=1, posX=100, posY=100, shouldExit=0, menuX=0, menuY=0, showMenu=0, isTopmost=1, language=0}
    else
        local i18n = require("src.i18n")
        i18n.init()
        
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
            memConfig.language = localConfig.language or 0
        end
    end
    
    if isSettingsMode then
        local GUI = require("src.gui")
        Tray = require("src.tray")
        Tray.init("Settings", nil, nil, true, memConfig)
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
        Bubble = require("src.bubble")
        
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
        end, false, memConfig)
        
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
        
        Audio.update(dt)
        local lowF, midF, hiF = Audio.getBands()
        local beatPulse = Audio.getBeatPulse()
        
        -- 生态唤醒逻辑：极致降速至 12-15 秒完全唤醒
        if lowF > 0.05 or midF > 0.05 then
            sensoryGate = math.min(1.0, sensoryGate + dt * 0.08) 
        else
            sensoryGate = math.max(0.1, sensoryGate - dt * 0.04) 
        end
        
        -- 应用唤醒系数
        lowF = lowF * memConfig.sensitivity * sensoryGate
        midF = midF * memConfig.sensitivity * sensoryGate
        hiF = hiF * memConfig.sensitivity * sensoryGate
        
        -- The Spring-Mass Simulation for organic heartbeats!
        local rawEnergy = lowF -- 只有低频层驱动弹性缩放
        
        -- Bionic Logic: Accumulated Arousal (生理动量/热量累积)
        local heatInput = (rawEnergy * 1.5 + beatPulse * 2.0) * dt
        if heatInput > 0.01 then
            targetArousal = math.min(1.0, targetArousal + heatInput * 1.2)
        else
            targetArousal = math.max(0.0, targetArousal - dt * 0.05)
        end
        
        -- [Epic Awakening] 认知延迟缓冲区：情绪并不是瞬间爆开的
        arousalBuffer = arousalBuffer or 0.0
        if targetArousal > 0.1 then
            arousalBuffer = math.min(1.0, arousalBuffer + dt * 0.1) -- 10s 缓冲区
        else
            arousalBuffer = math.max(0.0, arousalBuffer - dt * 0.05)
        end
        
        -- 最终情绪结合缓冲区 (增加惯性，响应速度 1.5)
        local finalTarget = targetArousal * arousalBuffer
        arousal = arousal + (finalTarget - arousal) * dt * 1.5
        
        -- ASR 分层感官推进 (进一步调重惯性)
        arousalColor = arousalColor + (arousal - arousalColor) * dt * 5.0
        arousalSpeed = arousalSpeed + (arousal - arousalSpeed) * dt * 1.5
        arousalScale = arousalScale + (arousal - arousalScale) * dt * 0.4
        arousalMotion = arousalMotion + (arousal - arousalMotion) * dt * 0.15
        
        -- 相位积分器: 彻底接管绝对时间，基于分层频率（arousalSpeed）驱动心跳频率
        -- 极致平滑频率感 (0.2 逼近速度)，实现马拉松式的加速过程
        local targetPhaseSpeed = 2.5 + arousalSpeed * 9.5
        phaseSpeed = phaseSpeed + (targetPhaseSpeed - phaseSpeed) * dt * 0.2
        beatPhase = beatPhase + phaseSpeed * dt
        
        local targetScale = rawEnergy * 2.0 -- Target inflation
        
        -- 随情绪动态改变阻尼和刚度
        -- 舒缓模式 (arousal=0): 刚度极低(25)，模拟水母般的浮动
        -- 节奏模式 (arousal=1): 刚度极高(160)，模拟强力泵血
        local springK = 25.0 + arousal * 135.0  
        local damping = 14.0 - arousal * 9.0   -- 舒缓时阻尼大(14)，兴奋时阻尼小(5)
        
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
        
        Bubble.update(dt, arousal, memConfig)
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
        
        -- Aesthetic Color Infusion (基于 arousalColor 驱动)
        local baseR = memConfig.color_r + (arousalColor * 0.2)
        local baseG = memConfig.color_g - ((1.0 - arousalColor) * 0.1)
        local baseB = memConfig.color_b + ((1.0 - arousalColor) * 0.15)
        
        local r = math.min(1, math.max(0, baseR + currentScale * 0.4))
        local g = math.min(1, math.max(0, baseG - currentScale * 0.2))
        local b = math.min(1, math.max(0, baseB - currentScale * 0.2))

        local lowF, midF, hiF = Audio.getBands()
        local beatPulse = Audio.getBeatPulse()
        lowF = lowF * memConfig.sensitivity * sensoryGate
        midF = midF * memConfig.sensitivity * sensoryGate
        hiF = hiF * memConfig.sensitivity * sensoryGate
        
        -- 传递 ASR 分层参数到渲染器
        local arousalTable = {
            color = arousalColor,
            speed = arousalSpeed,
            scale = arousalScale,
            motion = arousalMotion
        }
        Heart.draw(w/2, h/2, memConfig.size, {r, g, b, memConfig.color_a}, currentScale + (lowF*0.5), midF, hiF, arousalTable, beatPhase, beatPulse)
        
        -- 渲染情感气泡
        Bubble.draw(w/2, h/2)
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
            isTopmost = memConfig.isTopmost,
            language = memConfig.language
        })
    end
    
    if Tray then Tray.cleanup() end
    SharedMem.cleanup()
    return false
end
