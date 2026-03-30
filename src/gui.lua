local GUI = {}
local i18n = require("src.i18n")
local Fonts = require("src.fonts")
local Config = require("src.config")

-- Design Tokens
local Theme = {
    background = {0.05, 0.05, 0.07, 0.94},
    border = {1, 1, 1, 0.1},
    accent = {0.4, 0.7, 1.0, 1},
    accent_hover = {0.5, 0.8, 1.0, 1},
    text = {0.95, 0.95, 0.95, 1},
    text_dim = {0.6, 0.6, 0.6, 1},
    slider_bg = {1, 1, 1, 0.08},
    danger = {1.0, 0.3, 0.3, 1}
}

local panelWidth = 320
local panelHeight = 480
local padding = 24
local cornerRadius = 16

GUI.config = nil
local isDragging = nil
local dropdownOpen = false
local uiFont = nil
local titleFont = nil
local hoveredElement = nil

-- Layout tracking
local layout = {
    langY = 0,
    topmostY = 0,
    paletteY = 0
}

-- Animation states
local hoverStates = {}
local introAlpha = 0

local function getHoverAlpha(id, dt)
    hoverStates[id] = hoverStates[id] or 0
    if hoveredElement == id then
        hoverStates[id] = math.min(1, hoverStates[id] + dt * 10)
    else
        hoverStates[id] = math.max(0, hoverStates[id] - dt * 8)
    end
    return hoverStates[id]
end

function GUI.getUIFont(size)
    size = size or 14
    return Fonts.load(size)
end

function GUI.init(memConfig)
    GUI.config = memConfig
    i18n.init()
    introAlpha = 0
    
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

function GUI.isTitleAreaHit(x, y)
    local pX = (love.graphics.getWidth() - panelWidth) / 2
    local pY = (love.graphics.getHeight() - panelHeight) / 2
    return x >= pX and x <= pX + panelWidth and y >= pY and y <= pY + 60
end

local function isMouseIn(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function GUI.update(dt)
    if not GUI.config then return end
    if GUI.config.shouldExit == 1 then
        love.event.quit()
        return
    end

    introAlpha = math.min(1, introAlpha + dt * 4)

    local mx, my = love.mouse.getPosition()
    local mouseDown = love.mouse.isDown(1)
    
    hoveredElement = nil
    
    -- Panel center
    local pX = (love.graphics.getWidth() - panelWidth) / 2
    local pY = (love.graphics.getHeight() - panelHeight) / 2

    -- Check Close Button
    if isMouseIn(pX + panelWidth - 40, pY + 15, 25, 25) then
        hoveredElement = "close"
    end

    -- Check Sliders
    local startY = pY + 80
    for _, s in ipairs(GUI.sliders) do
        if isMouseIn(pX + padding, startY + 25, panelWidth - padding*2, 20) then
            hoveredElement = "slider_" .. s.name
        end
        startY = startY + 70
    end

    -- Check Colors
    local cx = pX + padding
    local cy = startY + 35
    for i, _ in ipairs(GUI.colors) do
        if isMouseIn(cx, cy, 40, 40) then
            hoveredElement = "color_" .. i
        end
        cx = cx + 52
    end
    layout.paletteY = startY

    -- Check Language
    layout.langY = startY + 95
    if isMouseIn(pX + panelWidth - 140, layout.langY, 120, 28) then
        hoveredElement = "lang"
    end

    -- Check Topmost
    layout.topmostY = layout.langY + 45
    if isMouseIn(pX + panelWidth - 65, layout.topmostY, 44, 24) then
        hoveredElement = "topmost"
    end

    -- Dragging logic
    if isDragging and not mouseDown then
        isDragging = nil
    end
    
    if isDragging then
        local slider = isDragging
        local percent = math.max(0, math.min(1, (mx - slider.x) / slider.w))
        GUI.config[slider.name] = slider.min + percent * (slider.max - slider.min)
    end

    -- Update animation states
    getHoverAlpha("close", dt)
    for _, s in ipairs(GUI.sliders) do getHoverAlpha("slider_" .. s.name, dt) end
    for i = 1, #GUI.colors do getHoverAlpha("color_" .. i, dt) end
    getHoverAlpha("lang", dt)
    getHoverAlpha("topmost", dt)
end

function GUI.mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    local pX = (love.graphics.getWidth() - panelWidth) / 2
    local pY = (love.graphics.getHeight() - panelHeight) / 2

    -- 1. Dropdown
    if dropdownOpen then
        local dx, dy = pX + panelWidth - 140, layout.langY
        local dw, dh = 120, 28
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

    -- 2. Close Button
    if hoveredElement == "close" then
        love.event.quit()
        return true
    end

    -- 3. Sliders
    local startY = pY + 80
    for _, s in ipairs(GUI.sliders) do
        local sx, sy, sw = pX + padding, startY + 25, panelWidth - padding*2
        if isMouseIn(sx, sy - 10, sw, 30) then
            s.x, s.w = sx, sw
            isDragging = s
            return true
        end
        startY = startY + 70
    end

    -- 4. Colors
    local cx = pX + padding
    local cy = startY + 35
    for i, c in ipairs(GUI.colors) do
        if hoveredElement == "color_" .. i then
            GUI.config.color_r, GUI.config.color_g, GUI.config.color_b, GUI.config.color_a = c[1], c[2], c[3], c[4]
            return true
        end
        cx = cx + 52
    end

    -- 5. Language
    if hoveredElement == "lang" then
        dropdownOpen = true
        return true
    end

    -- 6. Topmost
    if hoveredElement == "topmost" then
        GUI.config.isTopmost = (GUI.config.isTopmost == 1) and 0 or 1
        return true
    end

    return false
end

function GUI.draw()
    local langID = GUI.config and GUI.config.language or 0
    local pX = (love.graphics.getWidth() - panelWidth) / 2
    local pY = (love.graphics.getHeight() - panelHeight) / 2

    -- Overall Alpha for Intro
    love.graphics.push("all")
    love.graphics.translate(0, (1 - introAlpha) * 10) -- Subtle slide up

    local baseAlpha = introAlpha
    local function applyAlpha(color)
        return {color[1], color[2], color[3], (color[4] or 1) * baseAlpha}
    end

    -- Panel Background (Frosted Glass Effect)
    love.graphics.setColor(applyAlpha(Theme.background))
    love.graphics.rectangle("fill", pX, pY, panelWidth, panelHeight, cornerRadius)
    
    -- Highlight Border
    love.graphics.setLineWidth(1)
    love.graphics.setColor(applyAlpha(Theme.border))
    love.graphics.rectangle("line", pX, pY, panelWidth, panelHeight, cornerRadius)

    -- Title
    if not titleFont then titleFont = Fonts.load(18) end
    love.graphics.setFont(titleFont)
    love.graphics.setColor(applyAlpha(Theme.text))
    love.graphics.print(i18n.get("settings_title", langID), pX + padding, pY + padding - 4)

    -- Close Button (X)
    local closeAlpha = (hoverStates["close"] or 0)
    local cColor = Theme.text
    if hoveredElement == "close" then cColor = Theme.danger end
    love.graphics.setColor(cColor[1], cColor[2], cColor[3], (0.4 + closeAlpha * 0.6) * baseAlpha)
    
    local cx, cy = pX + panelWidth - 30, pY + 25
    love.graphics.setLineWidth(2)
    love.graphics.line(cx - 6, cy - 6, cx + 6, cy + 6)
    love.graphics.line(cx + 6, cy - 6, cx - 6, cy + 6)

    love.graphics.setFont(GUI.getUIFont(14))
    
    local currentY = pY + 80

    -- A. Sliders
    for _, s in ipairs(GUI.sliders) do
        local hAlpha = hoverStates["slider_" .. s.name] or 0
        love.graphics.setColor(applyAlpha(Theme.text))
        love.graphics.print(i18n.get(s.label_key, langID), pX + padding, currentY)
        
        love.graphics.setColor(applyAlpha(Theme.text_dim))
        love.graphics.printf(string.format("%.2f", GUI.config[s.name]), pX + padding, currentY, panelWidth - padding*2, "right")
        
        -- Track
        love.graphics.setColor(applyAlpha(Theme.slider_bg))
        love.graphics.rectangle("fill", pX + padding, currentY + 28, panelWidth - padding*2, 6, 3)
        
        -- Progress
        local percent = (GUI.config[s.name] - s.min) / (s.max - s.min)
        local aC = Theme.accent
        love.graphics.setColor(aC[1], aC[2], aC[3], (0.8 + hAlpha * 0.2) * baseAlpha)
        love.graphics.rectangle("fill", pX + padding, currentY + 28, (panelWidth - padding*2) * percent, 6, 3)
        
        -- Knob
        love.graphics.setColor(1, 1, 1, baseAlpha)
        love.graphics.circle("fill", pX + padding + (panelWidth - padding*2) * percent, currentY + 31, 8 + hAlpha * 2)
        
        currentY = currentY + 70
    end

    -- B. Palette
    love.graphics.setColor(applyAlpha(Theme.text))
    love.graphics.print(i18n.get("palette", langID), pX + padding, currentY + 10)
    
    local ccx = pX + padding
    local ccy = currentY + 40
    for i, c in ipairs(GUI.colors) do
        local hAlpha = hoverStates["color_" .. i] or 0
        love.graphics.setColor(c[1], c[2], c[3], 0.9 * baseAlpha)
        love.graphics.rectangle("fill", ccx, ccy, 40, 40, 10 + hAlpha * 4)
        
        -- Selection Ring
        if math.abs(GUI.config.color_r - c[1]) < 0.01 and math.abs(GUI.config.color_g - c[2]) < 0.01 then
            love.graphics.setColor(1, 1, 1, baseAlpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", ccx - 3, ccy - 3, 46, 46, 12)
        end
        ccx = ccx + 52
    end
    currentY = currentY + 110

    -- C. Language Selector
    love.graphics.setColor(applyAlpha(Theme.text))
    love.graphics.print(i18n.get("language", langID), pX + padding, currentY + 5)
    
    local langHAlpha = hoverStates["lang"] or 0
    love.graphics.setColor(1, 1, 1, (0.05 + langHAlpha * 0.05) * baseAlpha)
    love.graphics.rectangle("fill", pX + panelWidth - 140, currentY, 120, 28, 6)
    love.graphics.setColor(applyAlpha(Theme.text))
    local langNames = i18n.get("lang_names", langID)
    love.graphics.printf(langNames[langID] or "?", pX + panelWidth - 135, currentY + 6, 110, "center")
    
    currentY = currentY + 45

    -- D. Topmost Toggle
    love.graphics.setColor(applyAlpha(Theme.text))
    love.graphics.print(i18n.get("topmost", langID), pX + padding, currentY + 5)
    
    local tmHAlpha = hoverStates["topmost"] or 0
    if GUI.config.isTopmost == 1 then
        local aC = Theme.accent
        love.graphics.setColor(aC[1], aC[2], aC[3], (0.8 + tmHAlpha * 0.2) * baseAlpha)
    else
        love.graphics.setColor(1, 1, 1, (0.1 + tmHAlpha * 0.1) * baseAlpha)
    end
    love.graphics.rectangle("fill", pX + panelWidth - 65, currentY, 44, 24, 12)
    
    love.graphics.setColor(1, 1, 1, baseAlpha)
    local knobX = (GUI.config.isTopmost == 1) and 32 or 12
    love.graphics.circle("fill", pX + panelWidth - 65 + knobX, currentY + 12, 9)

    -- E. Footer
    love.graphics.setColor(applyAlpha(Theme.text_dim))
    love.graphics.setFont(GUI.getUIFont(12))
    love.graphics.printf("v0.1.4.1 by SharpEye", pX, pY + panelHeight - 45, panelWidth, "center")
    love.graphics.setColor(1, 1, 1, 0.2 * baseAlpha)
    love.graphics.printf(i18n.get("close_hint", langID), pX, pY + panelHeight - 30, panelWidth, "center")

    -- F. Dropdown Overlay
    if dropdownOpen then
        local lx, ly = pX + panelWidth - 140, layout.langY
        local lw, lh = 120, 28
        love.graphics.setColor(0.02, 0.02, 0.04, 0.98 * baseAlpha)
        love.graphics.rectangle("fill", lx, ly + lh, lw, lh * 3, 6)
        love.graphics.setColor(applyAlpha(Theme.border))
        love.graphics.rectangle("line", lx, ly + lh, lw, lh * 3, 6)
        
        for i = 0, 2 do
            local iy = ly + (i + 1) * lh
            if isMouseIn(lx, iy, lw, lh) then
                love.graphics.setColor(1, 1, 1, 0.1 * baseAlpha)
                love.graphics.rectangle("fill", lx + 4, iy + 2, lw - 8, lh - 4, 4)
            end
            love.graphics.setColor(applyAlpha(Theme.text))
            love.graphics.print(langNames[i], lx + 10, iy + 6)
        end
    end
    
    love.graphics.pop()
end

return GUI
