local Heart = {}

function Heart.draw(x, y, size, color, audioFactor, arousal, beatPhase)
    -- 处理默认参数兼容
    arousal = arousal or 0.0
    beatPhase = beatPhase or (love.timer.getTime() * 5)

    -- 双峰波形模拟心跳的物理感，由阶段性的积分相位无缝驱动
    local beat = math.sin(beatPhase) * 0.1 + math.sin(beatPhase * 2) * 0.05
    -- 加入音频加权因子，能量越高缩放越大
    local rawScale = size * (1 + beat + audioFactor) * 0.05
    
    -- 获取当前窗口尺寸，计算安全缩放上限
    local winW, winH = love.graphics.getDimensions()
    local safeRadius = math.min(winW, winH) / 2 * 0.92 -- 留出一点边距
    local maxScale = safeRadius / 17.0 -- 17 是心形方程的最大极径常数近似值
    
    local scale = rawScale
    local threshold = maxScale * 0.75 -- 在达到 75% 时开始软限制
    
    if scale > threshold then
        -- 完美的连续导数软限制（Soft Clipping）算法，避免达到极值时出现生硬的截断感
        local excess = scale - threshold
        local remaining = maxScale - threshold
        scale = threshold + remaining * (1 - math.exp(-excess / remaining))
    end
    
    love.graphics.push()
    love.graphics.translate(x, y)
    
    -- ===== 仿生神经视觉表现 (Bionic Behaviors) =====
    -- 1. 摇头晃脑 (Rotation Wobble)
    -- 当情绪处于开心/活跃阈值 (arousal > 0.4) 时，开始出现左右欢快的晃动
    if arousal > 0.4 then
        local rotationAmt = (arousal - 0.4) / 0.6
        -- 半周期的打转，模仿跟随音乐左右摇摆
        local rotAngle = math.sin(beatPhase * 0.5) * (0.25 * rotationAmt)
        love.graphics.rotate(rotAngle)
    end
    
    -- 收集被参数化方程计算出的心形多边形顶点
    local points = {}
    
    -- 2. 激灵/颤抖神经 (Shiver Noise)
    -- 如果非常激动或者受到了剧烈的重低音打击，边缘会发生细微颤栗
    local shiverAmount = 0
    if arousal > 0.7 then
        shiverAmount = (arousal - 0.7) / 0.3 * 1.5
    end
    if audioFactor > 0.6 then -- audioFactor 即为物理系统的绝对膨胀倍数，代表瞬间能量打击
        shiverAmount = shiverAmount + math.min(1.5, audioFactor * 0.5)
    end
    
    for i = 0, math.pi * 2, 0.05 do
        -- 经典参数化心形方程
        local px = 16 * math.sin(i)^3
        local py = -(13 * math.cos(i) - 5 * math.cos(2*i) - 2 * math.cos(3*i) - math.cos(4*i))
        
        -- 施加非线性的神经颤抖扰动
        if shiverAmount > 0 then
            -- 利用三角函数的相位高频交错生成类似柏林噪声的伪随机扰动
            local noiseX = math.sin(i * 12 + beatPhase * 20) * shiverAmount
            local noiseY = math.cos(i * 15 - beatPhase * 25) * shiverAmount
            px = px + noiseX
            py = py + noiseY
        end
        
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
