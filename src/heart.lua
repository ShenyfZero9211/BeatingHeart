local Heart = {}

function Heart.draw(x, y, size, color, audioFactor)
    -- 计算时间模拟心跳
    local time = love.timer.getTime()
    -- 双峰波形模拟心跳的物理感
    local beat = math.sin(time * 5) * 0.1 + math.sin(time * 10) * 0.05
    -- 加入音频加权因子，能量越高缩放越大
    local scale = size * (1 + beat + audioFactor) * 0.05
    
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
