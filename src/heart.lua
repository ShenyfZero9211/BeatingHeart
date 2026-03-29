local Heart = {}

function Heart.draw(x, y, size, color, lowFactor, midFactor, hiFactor, arousal, beatPhase)
    -- 处理默认参数兼容
    arousal = arousal or 0.0
    beatPhase = beatPhase or (love.timer.getTime() * 5)
    lowFactor = lowFactor or 0.0
    midFactor = midFactor or 0.0
    hiFactor = hiFactor or 0.0

    -- 1. 低频 (Kick) 驱动核心缩放
    local beat = math.sin(beatPhase) * 0.1 + math.sin(beatPhase * 2) * 0.05
    local rawScale = size * (1 + beat + lowFactor) * 0.05
    
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
    love.graphics.translate(x, y)
    
    -- ===== 仿生神经视觉表现 (Bionic Behaviors) =====
    
    -- 2. 高频 (Hat) 驱动整体震动 (Global Jitter) - 调低强度以增加克制感
    local jitterX, jitterY = 0, 0
    if arousal > 0.6 or hiFactor > 0.4 then
        local intensity = (arousal > 0.6 and (arousal-0.6)*6 or 0) + (hiFactor * 6)
        jitterX = (math.random() - 0.5) * intensity
        jitterY = (math.random() - 0.5) * intensity
        love.graphics.translate(jitterX, jitterY)
    end

    -- 3. 中频 (Snare) 驱动摇头晃脑与瞬间偏转
    local rotationAmt = (arousal > 0.4 and (arousal - 0.4) / 0.6 or 0)
    local rotAngle = math.sin(beatPhase * 0.5) * (0.12 * rotationAmt)
    -- 中频增加瞬间冲击旋转感 (调低倍率从 0.3 到 0.12)
    rotAngle = rotAngle + (midFactor * 0.12 * (math.random() > 0.5 and 1 or -1))
    love.graphics.rotate(rotAngle)
    
    -- 4. 情绪驱动非等比例缩放
    local scaleX = 1 + (arousal * 0.08) + (midFactor * 0.05)
    local scaleY = 1 - (arousal * 0.03)
    love.graphics.scale(scaleX, scaleY)
    
    -- 收集被参数化方程计算出的心形多边形顶点
    local points = {}
    for i = 0, math.pi * 2, 0.05 do
        local px = 16 * math.sin(i)^3
        local py = -(13 * math.cos(i) - 5 * math.cos(2*i) - 2 * math.cos(3*i) - math.cos(4*i))
        table.insert(points, px * scale)
        table.insert(points, py * scale)
    end
    
    -- 使用多边形填充实心区域
    -- 注意：由于在高能模式下存在 Shiver Noise 导致多边形可能自相交，
    -- 我们使用 pcall 保护 triangulate，或直接使用更稳健的填充方式。
    love.graphics.setColor(color)
    if #points >= 6 then
        local success, triangles = pcall(love.math.triangulate, points)
        if success then
            for _, tri in ipairs(triangles) do
                love.graphics.polygon("fill", tri)
            end
        else
            -- 如果由于形状太复杂（自相交）导致无法三角化，则回退到直接填充
            -- 这样虽然在极少数老旧硬件上可能有极小的渲染瑕疵，但能保证核心逻辑永不崩溃
            love.graphics.polygon("fill", points)
        end
    end
    
    -- 绘制反光边缘与抗锯齿
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", points)
    
    love.graphics.pop()
end

return Heart
