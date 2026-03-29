local Heart = {}

function Heart.draw(x, y, size, color, lowFactor, midFactor, hiFactor, arousal, beatPhase, beatPulse)
    -- 处理 ASR (Asynchronous Synesthetic Response) 结构
    local a_color = (type(arousal) == "table") and arousal.color or (arousal or 0)
    local a_speed = (type(arousal) == "table") and arousal.speed or (arousal or 0)
    local a_scale = (type(arousal) == "table") and arousal.scale or (arousal or 0)
    local a_motion = (type(arousal) == "table") and arousal.motion or (arousal or 0)

    beatPhase = beatPhase or 0.0
    lowFactor = lowFactor or 0.0
    midFactor = midFactor or 0.0
    hiFactor = hiFactor or 0.0
    beatPulse = beatPulse or 0.0

    -- 1. 心跳缩放 (Amplitude) - 受 arousalScale 驱动，具备高物理惯性
    local beat = math.sin(beatPhase) * 0.1 + math.sin(beatPhase * 2) * 0.05
    -- 采用平方曲线增加温和到狂热的非线性感
    local aScaleFactor = a_scale * a_scale
    local rawScale = size * (1 + beat + lowFactor * 0.5 + beatPulse * 0.4 + aScaleFactor * 0.25) * 0.05
    
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
    
    -- 2. 空间律动 (Motion) - 受 arousalMotion 驱动，极长响应周期
    local t = love.timer.getTime()
    local aMotionFactor = a_motion * a_motion
    local floatSpeed = 0.5 + aMotionFactor * 0.5
    local floatX = math.sin(t * 0.7 * floatSpeed) * (5 + lowFactor * 12 + aMotionFactor * 25)
    local floatY = math.cos(t * 0.5 * floatSpeed) * (5 + lowFactor * 12 + aMotionFactor * 25)
    love.graphics.translate(x + floatX, y + floatY)
    
    -- ===== 仿生感知维度 (Bionic Sensing Layers) =====
    
    -- 3. 生理震颤 (Tremor) - 与心率 (a_speed) 同步建立
    local tremorIntensity = (a_speed * 6) + (beatPulse * 12) + (hiFactor * 5)
    if tremorIntensity > 0.05 then
        local lowTremor = math.sin(t * 15) * 0.5
        local midTremor = math.cos(t * 37 + lowTremor) * 0.3
        local hiTremor = math.sin(t * 62) * 0.2
        love.graphics.translate((lowTremor + midTremor + hiTremor) * tremorIntensity, 
                                (math.cos(t * 18) * 0.5 + math.sin(t * 41) * 0.3) * tremorIntensity)
    end

    -- 4. 旋转与重心偏转 (Inertia Sway) - 受 Motion 惯性驱动
    local rotAngle = math.sin(beatPhase * 0.5) * (0.12 * aMotionFactor)
    if beatPulse > 0.1 then
        rotAngle = rotAngle + math.sin(t * 25) * (beatPulse * 0.2)
    end
    -- 持续性重心漂移
    rotAngle = rotAngle + math.sin(t * 2.5) * (aMotionFactor * 0.15)
    love.graphics.rotate(rotAngle)
    
    -- 5. 非等比例缩放 (Anisotropy)
    love.graphics.scale(1 + (a_speed * 0.1) + (beatPulse * 0.08), 1 - (a_speed * 0.04))
    
    -- 6. 色彩与光感渲染 (Color Response) - 受 arousalColor 驱动
    local r, g, b, a = unpack(color)
    -- 呼吸变色速度随频率 (a_speed) 动态调整
    local colorCycleSpeed = 0.4 + a_speed * 1.5
    r = math.min(1, r + math.sin(t * colorCycleSpeed) * (0.05 + a_color * 0.1))
    
    -- 节奏瞬闪 (Color Flash)
    local flash = beatPulse * 0.6 + (a_color * 0.2)
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
