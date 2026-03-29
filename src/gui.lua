local GUI = {}
local i18n = require("src.i18n")

local panelWidth = 300
local panelHeight = 500 -- 增加高度以容纳多语言和置顶项

GUI.config = nil
local isDragging = nil
local dropdownOpen = false
local Fonts = require("src.fonts")
local uiFont = nil

local layout = {
    langY = 0,
    topmostY = 0,
    paletteY = 0
}

-- 获取统一的 UI 字体
function GUI.getUIFont()
    if not uiFont then
        uiFont = Fonts.load(14)
    end
    return uiFont
end

function GUI.init(memConfig)
    GUI.config = memConfig
    i18n.init()
    
    GUI.sliders = {
        { name = "size", min = 50, max = 250, label_key = "size" },
        { name = "sensitivity", min = 0.1, max = 5.0, label_key = "sensitivity" }
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
        GUI.config[slider.name] = slider.min + percent * (slider.max - slider.min)
    end
end

function GUI.mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    -- 1. 处理下拉列表（拥有最高点击优先级）
    if dropdownOpen then
        local dx, dy = 150, layout.langY
        local dw, dh = 130, 25
        for i = 0, 2 do
            local iy = dy + (i + 1) * dh
            if x >= dx and x <= dx + dw and y >= iy and y <= iy + dh then
                GUI.config.language = i
                dropdownOpen = false
                return true
            end
        end
        dropdownOpen = false
        return true
    end

    -- 2. 设置项点击判定（基于动态布局变量）
    
    -- 语言下拉框触发
    if x >= 150 and x <= 280 and y >= layout.langY and y <= layout.langY + 25 then
        dropdownOpen = true
        return true
    end
    
    -- 置顶开关触发
    if x >= 150 and x <= 194 and y >= layout.topmostY and y <= layout.topmostY + 24 then
        GUI.config.isTopmost = (GUI.config.isTopmost == 1) and 0 or 1
        return true
    end
    
    -- 滑动条触发
    local startY = 60
    for _, s in ipairs(GUI.sliders) do
        local sx, sy, sw, sh = 20, startY + 25, 260, 10
        if x >= sx and x <= sx + sw and y >= sy - 10 and y <= sy + sh + 10 then
            s.x, s.w = sx, sw
            isDragging = s
            return true
        end
        startY = startY + 70
    end
    
    -- 色板触发
    local cx = 20
    local cy = layout.paletteY + 40
    for i, c in ipairs(GUI.colors) do
        if x >= cx and x <= cx + 45 and y >= cy and y <= cy + 45 then
            GUI.config.color_r, GUI.config.color_g, GUI.config.color_b, GUI.config.color_a = c[1], c[2], c[3], c[4]
            return true
        end
        cx = cx + 55
    end
    
    return true
end

function GUI.draw()
    local langID = GUI.config and GUI.config.language or 0
    love.graphics.setFont(GUI.getUIFont())

    -- 背景与标题
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(i18n.get("settings_title", langID), 20, 20)
    
    local currentY = 60

    -- A. 渲染滑动条
    for _, s in ipairs(GUI.sliders) do
        love.graphics.setColor(0.85, 0.85, 0.85, 1)
        love.graphics.print(i18n.get(s.label_key, langID) .. ": " .. string.format("%.2f", GUI.config[s.name]), 20, currentY)
        love.graphics.setColor(0.25, 0.25, 0.3, 1)
        love.graphics.rectangle("fill", 20, currentY + 25, 260, 10, 5)
        local percent = (GUI.config[s.name] - s.min) / (s.max - s.min)
        love.graphics.setColor(0.4, 0.75, 1.0, 1)
        love.graphics.rectangle("fill", 20, currentY + 25, 260 * percent, 10, 5)
        love.graphics.circle("fill", 20 + 260 * percent, currentY + 30, 8)
        currentY = currentY + 75
    end
    
    -- B. 渲染预设色板
    layout.paletteY = currentY
    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.print(i18n.get("palette", langID), 20, currentY)
    local cx = 20
    local cy = currentY + 40
    for i, c in ipairs(GUI.colors) do
        love.graphics.setColor(c)
        love.graphics.rectangle("fill", cx, cy, 45, 45, 8)
        if math.abs(GUI.config.color_r - c[1]) < 0.01 and math.abs(GUI.config.color_g - c[2]) < 0.01 and math.abs(GUI.config.color_b - c[3]) < 0.01 then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cx-2, cy-2, 49, 49, 8)
        end
        cx = cx + 55
    end
    currentY = currentY + 110 -- 给色板留出空间
    
    -- C. 渲染语言选择器
    layout.langY = currentY
    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.print(i18n.get("language", langID), 20, currentY)
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", 150, currentY, 130, 25, 4)
    love.graphics.setColor(1, 1, 1, 0.8)
    local langNames = i18n.get("lang_names", langID)
    love.graphics.print(langNames[langID] or "?", 158, currentY + 5)
    currentY = currentY + 45

    -- D. 渲染置顶切换
    layout.topmostY = currentY
    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.print(i18n.get("topmost", langID), 20, currentY)
    if GUI.config.isTopmost == 1 then
        love.graphics.setColor(0.3, 0.8, 0.4)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", 150, currentY, 44, 24, 12, 12)
    love.graphics.setColor(1, 1, 1)
    if GUI.config.isTopmost == 1 then
        love.graphics.circle("fill", 150 + 32, currentY + 12, 9)
    else
        love.graphics.circle("fill", 150 + 12, currentY + 12, 9)
    end
    
    -- E. 渲染页脚
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.print("v0.1.4 by SharpEye", 20, panelHeight - 40)
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print(i18n.get("close_hint", langID), 20, panelHeight - 30)

    -- F. 渲染下拉列表浮层（确保在最上层）
    if dropdownOpen then
        local dx, dy = 150, layout.langY
        local dw, dh = 130, 25
        love.graphics.setColor(0.1, 0.1, 0.1, 0.98)
        love.graphics.rectangle("fill", dx, dy + dh, dw, dh * 3, 4)
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("line", dx, dy + dh, dw, dh * 3, 4)
        for i = 0, 2 do
            local iy = dy + (i + 1) * dh
            local mx, my = love.mouse.getPosition()
            if mx >= dx and mx <= dx + dw and my >= iy and my <= iy + dh then
                love.graphics.setColor(1, 1, 1, 0.2)
                love.graphics.rectangle("fill", dx, iy, dw, dh)
            end
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.print(langNames[i], dx + 8, iy + 5)
        end
    end
end

return GUI
