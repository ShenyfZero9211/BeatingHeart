local Heart = {}

function Heart.draw(x, y, size, color, lowFactor, midFactor, hiFactor, arousal, beatPhase, beatPulse, excitationMomentum)
    -- 处理 ASR (Asynchronous Synesthetic Response) 结构
    local a_color = (type(arousal) == "table") and arousal.color or (arousal or 0)
    local a_speed = (type(arousal) == "table") and arousal.speed or (arousal or 0)
    local a_scale = (type(arousal) == "table") and arousal.scale or (arousal or 0)
    local a_sway = (type(arousal) == "table") and arousal.sway or (arousal or 0)
    local floatX = (type(arousal) == "table") and arousal.floatX or 0
    local floatY = (type(arousal) == "table") and arousal.floatY or 0

    beatPhase = beatPhase or 0.0
    excitationMomentum = excitationMomentum or 0.0
    lowFactor = lowFactor or 0.0
    midFactor = midFactor or 0.0
    hiFactor = hiFactor or 0.0
    beatPulse = beatPulse or 0.0

    -- [Epic Awakening] Beat Masking: 在苏醒前期 (a_speed < 0.4)，强制抑制 80% 的脉冲响应
    -- 这能有效消除音乐初起时的频繁“躁动”闪烁感
    if a_speed < 0.4 then
        local mask = 0.2 + (a_speed / 0.4) * 0.8
        beatPulse = beatPulse * mask
    end

    -- 1. 心跳缩放 (Amplitude) 
    local beat = math.sin(beatPhase) * 0.1 + math.sin(beatPhase * 2) * 0.05
    -- [Epic Awakening] 高阶幂律映射：使用 a_scale^4 锁定前半段的极端内敛
    local aScaleFactor = a_scale * a_scale * a_scale * a_scale
    local rawScale = size * (1 + beat + lowFactor * 0.4 + beatPulse * 0.3 + aScaleFactor * 0.35) * 0.05
    
    local winW, winH = love.graphics.getDimensions()
    local safeRadius = math.min(winW, winH) / 2 * 0.92
    local maxScale = safeRadius / 17.0
    
    local scale = rawScale
    local threshold = maxScale * 0.75
    if scale > threshold then
        local excess = scale - threshold
        local remaining = maxScale - threshold
        scale = threshold + remaining * (1 - math.exp(-excess / remaining))
    end
    
    love.graphics.push()
    
    -- 2. 空间位移 (Sway Drift - SYNCED with Hit-Test)
    love.graphics.translate(x + floatX, y + floatY)
    
    -- ===== 仿生感知维度 (Bionic Sensing Layers) =====
    local t = love.timer.getTime()
    local aSwayFactor = a_sway * a_sway
    
    -- 3. [SOOTHE JITTER] 生理震颤平滑化
    -- 大幅削弱 hiFactor 的尖锐权重，增加时间低通滤镜感
    local tremorIntensity = (a_speed * 4) + (beatPulse * 8) + (hiFactor * 1.5)
    if tremorIntensity > 0.05 then
        -- 降低频率：由 (15, 37, 62) 降低为更沉稳的 (8, 18, 12)
        local lowTremor = math.sin(t * 8) * 0.4
        local midTremor = math.cos(t * 18 + lowTremor) * 0.2
        local hiTremor = math.sin(t * 12) * 0.1
        love.graphics.translate((lowTremor + midTremor + hiTremor) * tremorIntensity, 
                                (math.cos(t * 12) * 0.4 + math.sin(t * 22) * 0.2) * tremorIntensity)
    end

    -- 4. 旋转与重心偏转 (Inertia Sway)
    -- 主旋转使用 aSwayFactor 产生缓慢堆叠的“重力感”摆动
    local rotAngle = math.sin(beatPhase * 0.5) * (0.12 * aSwayFactor)
    if beatPulse > 0.1 then
        rotAngle = rotAngle + math.sin(t * 25) * (beatPulse * 0.15)
    end
    -- 持续性重心漂移
    rotAngle = rotAngle + math.sin(t * 1.8) * (aSwayFactor * 0.25)
    love.graphics.rotate(rotAngle)
    
    -- 5. [ORGANIC DISTORTION] 非等比例有机形变
    -- 正常状态下是等比。兴奋积压久了会产生纵向拉伸与横向挤压的呼吸感
    local bassThump = lowFactor * 0.5 -- 强化低频冲击感
    local squash = (excitationMomentum * 0.12 + bassThump * 0.15) * math.sin(beatPhase)
    local stretch = (excitationMomentum * 0.15 + bassThump * 0.1) * math.cos(beatPhase)
    
    love.graphics.scale(1 + (a_speed * 0.1) + (beatPulse * 0.12) + bassThump + squash, 
                        1 - (a_speed * 0.05) - (bassThump * 0.2) + stretch)
    
    -- 6. 色彩与光感渲染 (Color Response)
    local r, g, b, a = unpack(color)
    -- 呼吸变色速度随频率 (a_speed) 动态调整
    local colorCycleSpeed = 0.4 + a_speed * 1.5
    r = math.min(1, r + math.sin(t * colorCycleSpeed) * (0.05 + a_color * 0.12))
    
    -- 节奏瞬闪 (Color Flash)
    local flash = beatPulse * 0.6 + (a_color * 0.25)
    r = math.min(1, r + flash)
    g = math.min(1, g + flash * 0.6)
    b = math.min(1, b + flash * 0.6)

    -- 渲染多边形
    local points = {}
    for i = 0, math.pi * 2, 0.05 do
        local px = 16 * math.sin(i)^3
        local py = -(13 * math.cos(i) - 5 * math.cos(2*i) - 2 * math.cos(3*i) - math.cos(4*i))
        table.insert(points, px * scale)
        table.insert(points, py * scale)
    end
    
    love.graphics.setColor(r, g, b, a)
    if #points >= 6 then
        local success, triangles = pcall(love.math.triangulate, points)
        if success then
            for _, tri in ipairs(triangles) do love.graphics.polygon("fill", tri) end
        else
            love.graphics.polygon("fill", points)
        end
    end
    
    -- 绘制反光边缘
    love.graphics.setColor(1, 1, 1, 0.3 + flash * 0.4)
    love.graphics.setLineWidth(1.3 + flash)
    love.graphics.polygon("line", points)
    
    love.graphics.pop()
end

return Heart
