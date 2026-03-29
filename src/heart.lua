local Heart = {}

function Heart.draw(x, y, size, color, audioFactor)
    -- 计算时间模拟心跳
    local time = love.timer.getTime()
    -- 双峰波形模拟心跳的物理感
    local beat = math.sin(time * 5) * 0.1 + math.sin(time * 10) * 0.05
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
    
    -- 收集被参数化方程计算出的心形多边形顶点
    -- x = 16 * sin(t)^3
    -- y = -(13 * cos(t) - 5 * cos(2t) - 2 * cos(3t) - cos(4t))
    local points = {}
    for i = 0, math.pi * 2, 0.05 do
        local px = 16 * math.sin(i)^3
        local py = -(13 * math.cos(i) - 5 * math.cos(2*i) - 2 * math.cos(3*i) - math.cos(4*i))
        table.insert(points, px * scale)
        table.insert(points, py * scale)
    end
    
    -- 使用多边形三角化填充实心区域
    love.graphics.setColor(color)
    if #points >= 6 then
        local triangles = love.math.triangulate(points)
        for _, tri in ipairs(triangles) do
            love.graphics.polygon("fill", tri)
        end
    end
    
    -- 绘制反光边缘与抗锯齿
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", points)
    
    love.graphics.pop()
end

return Heart
