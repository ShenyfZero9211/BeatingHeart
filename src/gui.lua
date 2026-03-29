local GUI = {}

local panelWidth = 300
local panelHeight = 420

GUI.config = nil
local isDragging = nil

function GUI.init(memConfig)
    GUI.config = memConfig
    
    GUI.sliders = {
        { name = "size", min = 50, max = 250, label = "Size" },
        { name = "sensitivity", min = 0.1, max = 5.0, label = "Sensitivity" }
    }
    GUI.colors = {
         {0.9, 0.2, 0.3, 1}, -- Red
         {1.0, 0.5, 0.7, 1}, -- Pink
         {0.3, 0.7, 1.0, 1}, -- Blue
         {0.4, 0.9, 0.5, 1}, -- Green
         {0.6, 0.4, 1.0, 1}  -- Purple
    }
end

function GUI.update(dt)
    if not GUI.config then return end
    if GUI.config.shouldExit == 1 then
        love.event.quit()
        return
    end

    local mx, my = love.mouse.getPosition()
    local mouseDown = love.mouse.isDown(1)
    
    if isDragging and not mouseDown then
        isDragging = nil
    end
    
    if isDragging then
        local slider = isDragging
        local percent = math.max(0, math.min(1, (mx - slider.x) / slider.w))
        
        -- 直接修改 RAM 映射内存中的值，0 硬盘损耗，跨进程同步
        GUI.config[slider.name] = slider.min + percent * (slider.max - slider.min)
    end
end

function GUI.mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    -- Toggle Topmost
    if x >= 150 and x <= 194 and y >= 310 and y <= 334 then
        GUI.config.isTopmost = (GUI.config.isTopmost == 1) and 0 or 1
        return true
    end
    
    local startY = 60
    for _, s in ipairs(GUI.sliders) do
        local sx = 20
        local sy = startY + 25
        local sw = 260
        local sh = 10
        
        if x >= sx and x <= sx + sw and y >= sy - 10 and y <= sy + sh + 10 then
            s.x = sx
            s.w = sw
            isDragging = s
            return true
        end
        startY = startY + 70
    end
    
    local startColorY = startY + 40
    local cx = 20
    for i, c in ipairs(GUI.colors) do
        if x >= cx and x <= cx + 45 and y >= startColorY and y <= startColorY + 45 then
            -- 直接修改内存颜色值
            GUI.config.color_r = c[1]
            GUI.config.color_g = c[2]
            GUI.config.color_b = c[3]
            GUI.config.color_a = c[4]
            return true
        end
        cx = cx + 55
    end
    
    return true
end

function GUI.draw()
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Settings", 20, 20)
    
    love.graphics.print("Window Topmost", 20, 310)
    
    -- Draw Toggle Background
    if GUI.config.isTopmost == 1 then
        love.graphics.setColor(0.3, 0.8, 0.4) -- Green active
    else
        love.graphics.setColor(0.3, 0.3, 0.3) -- Gray inactive
    end
    love.graphics.rectangle("fill", 150, 310, 44, 24, 12, 12)
    
    -- Draw Toggle knob
    love.graphics.setColor(1, 1, 1)
    if GUI.config.isTopmost == 1 then
        love.graphics.circle("fill", 150 + 32, 310 + 12, 9)
    else
        love.graphics.circle("fill", 150 + 12, 310 + 12, 9)
    end
    
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("v0.0.3 by Antigravity", 20, 380)
    
    local startY = 60
    for _, s in ipairs(GUI.sliders) do
        love.graphics.setColor(0.85, 0.85, 0.85, 1)
        love.graphics.print(s.label .. ": " .. string.format("%.2f", GUI.config[s.name]), 20, startY)
        
        love.graphics.setColor(0.25, 0.25, 0.3, 1)
        love.graphics.rectangle("fill", 20, startY + 25, 260, 10, 5)
        
        local percent = (GUI.config[s.name] - s.min) / (s.max - s.min)
        love.graphics.setColor(0.4, 0.75, 1.0, 1)
        love.graphics.rectangle("fill", 20, startY + 25, 260 * percent, 10, 5)
        
        love.graphics.circle("fill", 20 + 260 * percent, startY + 30, 8)
        
        startY = startY + 70
    end
    
    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.print("Palette:", 20, startY)
    
    local startColorY = startY + 40
    local cx = 20
    for i, c in ipairs(GUI.colors) do
        love.graphics.setColor(c)
        love.graphics.rectangle("fill", cx, startColorY, 45, 45, 8)
        
        if math.abs(GUI.config.color_r - c[1]) < 0.01 and math.abs(GUI.config.color_g - c[2]) < 0.01 and math.abs(GUI.config.color_b - c[3]) < 0.01 then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cx-2, startColorY-2, 49, 49, 8)
        end
        cx = cx + 55
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Press ESC or Right Click to close.", 20, 390)
end

return GUI
