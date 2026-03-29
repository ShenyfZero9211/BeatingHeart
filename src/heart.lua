local Heart = {}

function Heart.draw(x, y, size, color, lowFactor, midFactor, hiFactor, arousal, beatPhase, beatPulse)
    -- 处理默认参数兼容
    arousal = arousal or 0.0
    beatPhase = beatPhase or 0.0
    lowFactor = lowFactor or 0.0
    midFactor = midFactor or 0.0
    hiFactor = hiFactor or 0.0
    beatPulse = beatPulse or 0.0

    -- 1. 低频 (Kick) 驱动核心缩放
    local beat = math.sin(beatPhase) * 0.1 + math.sin(beatPhase * 2) * 0.05
    -- [渐进式兴奋]：不再用阈值切换，而是用 arousal^2 产生平滑的非线性体积膨胀
    local arousalFactor = arousal * arousal -- 平方曲线，初段平稳，末段爆发
    local rawScale = size * (1 + beat + lowFactor * 0.5 + beatPulse * 0.4 + arousalFactor * 0.25) * 0.05
    
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
    
    -- 2. 氛围漂浮 (Ambient Float)
    local t = love.timer.getTime()
    local floatSpeed = 0.5 + arousalFactor * 0.5
    local floatX = math.sin(t * 0.7 * floatSpeed) * (5 + lowFactor * 12 + arousalFactor * 20)
    local floatY = math.cos(t * 0.5 * floatSpeed) * (5 + lowFactor * 12 + arousalFactor * 20)
    love.graphics.translate(x + floatX, y + floatY)
    
    -- ===== 仿生神经视觉表现 (Bionic Behaviors) =====
    
    -- 3. 生物混合震颤 (Bio-Tremor Model) 
    -- [渐进渲染]：震颤感随 arousal 全程线性增长，无启动跳转感
    local tremorIntensity = (arousal * 6) + (beatPulse * 12) + (hiFactor * 5)
    local jitterX, jitterY = 0, 0
    if tremorIntensity > 0.05 then
        local lowTremor = math.sin(t * 15) * 0.5
        local midTremor = math.cos(t * 37 + lowTremor) * 0.3
        local hiTremor = math.sin(t * 62) * 0.2
        jitterX = (lowTremor + midTremor + hiTremor) * tremorIntensity
        jitterY = (math.cos(t * 18) * 0.5 + math.sin(t * 41) * 0.3 + math.cos(t * 57) * 0.2) * tremorIntensity
        love.graphics.translate(jitterX, jitterY)
    end

    -- 4. 旋转与瞬间偏转
    -- 摆动幅度也随唤醒度平方倍增
    local rotationBase = 0.12 * arousalFactor
    local rotAngle = math.sin(beatPhase * 0.5) * rotationBase
    if beatPulse > 0.1 then
        rotAngle = rotAngle + math.sin(t * 25) * (beatPulse * 0.2)
    end
    -- [惯性摆动] 随能量平滑增强
    rotAngle = rotAngle + math.sin(t * 2.5) * (arousalFactor * 0.12)
    love.graphics.rotate(rotAngle)
    
    -- 5. 情绪驱动非等比例缩放
    local scaleX = 1 + (arousal * 0.1) + (beatPulse * 0.08)
    local scaleY = 1 - (arousal * 0.04)
    love.graphics.scale(scaleX, scaleY)
    
    -- 6. 核心色彩处理 (Dynamic Color Layering)
    local r, g, b, a = unpack(color)
    -- 缓慢呼吸感
    r = math.min(1, r + math.sin(t * 0.4) * 0.08)
    
    -- 节奏瞬闪 (Color Flash)：力度增强以提升节奏感
    local flash = beatPulse * 0.6 + (arousal * 0.15)
    r = math.min(1, r + flash)
    g = math.min(1, g + flash * 0.6)
    b = math.min(1, b + flash * 0.6)

    -- 收集心形多边形顶点
    local points = {}
    for i = 0, math.pi * 2, 0.05 do
        local px = 16 * math.sin(i)^3
        local py = -(13 * math.cos(i) - 5 * math.cos(2*i) - 2 * math.cos(3*i) - math.cos(4*i))
        table.insert(points, px * scale)
        table.insert(points, py * scale)
    end
    
    -- 填充实心区域
    love.graphics.setColor(r, g, b, a)
    if #points >= 6 then
        local success, triangles = pcall(love.math.triangulate, points)
        if success then
            for _, tri in ipairs(triangles) do love.graphics.polygon("fill", tri) end
        else
            love.graphics.polygon("fill", points)
        end
    end
    
    -- 绘制高亮边缘
    love.graphics.setColor(1, 1, 1, 0.3 + flash * 0.4)
    love.graphics.setLineWidth(1.3 + flash)
    love.graphics.polygon("line", points)
    
    love.graphics.pop()
end

return Heart
