local Bubble = {}

local activeBubbles = {}
local i18n = require("src.i18n")

local spawnTimer = 0
local lastArousal = 0
local chineseFont = nil

-- 惰性加载中文字体，确保高性能和稳定性
local function getFont()
    if not chineseFont then
        -- 依次尝试加载：黑体(simhei.ttf)、微软雅黑(msyh.ttc)
        local fonts_to_try = { "simhei.ttf", "msyh.ttc" }
        for _, f in ipairs(fonts_to_try) do
            local success, font = pcall(love.graphics.newFont, f, 16)
            if success then
                chineseFont = font
                break
            end
        end
        
        -- 如果都失败了，回退到默认字体（此时依然可能乱码，但程序至少能跑）
        if not chineseFont then
            chineseFont = love.graphics.getFont()
        end
    end
    return chineseFont
end

function Bubble.spawn(arousal, memConfig)
    local langID = memConfig and memConfig.language or 0
    local poolKey = "pool_active"
    if arousal < 0.3 then
        poolKey = "pool_quiet"
    elseif arousal > 0.7 then
        poolKey = "pool_intense"
    end
    
    local pool = i18n.getPool(poolKey, langID)
    
    local text = pool[math.random(#pool)]
    
    table.insert(activeBubbles, {
        text = text,
        timer = 2.5, -- 持续 2.5 秒
        maxTimer = 2.5,
        x_off = math.random(-80, 80),
        y_off = math.random(-150, -100),
        velY = -20 - math.random(0, 20) -- 向上漂浮
    })
end

function Bubble.update(dt, arousal, memConfig)
    spawnTimer = spawnTimer - dt
    
    -- 基础刷新逻辑：5-10 秒随机产生
    if spawnTimer <= 0 then
        Bubble.spawn(arousal, memConfig)
        spawnTimer = 5 + math.random() * 5
    end
    
    -- 剧变触发：如果唤醒度瞬间拉升（比如静音到炸响），强制触发
    if arousal - lastArousal > 0.4 then
        Bubble.spawn(arousal, memConfig)
        spawnTimer = 5 + math.random() * 5 -- 重置计时器防止刷屏
    end
    lastArousal = arousal
    
    -- 更新气泡物理和淡出
    for i = #activeBubbles, 1, -1 do
        local b = activeBubbles[i]
        b.timer = b.timer - dt
        b.y_off = b.y_off + b.velY * dt
        if b.timer <= 0 then
            table.remove(activeBubbles, i)
        end
    end
end

function Bubble.draw(centerX, centerY)
    local font = getFont()
    
    for _, b in ipairs(activeBubbles) do
        local alpha = math.min(1.0, b.timer / 0.5) -- 最后的 0.5 秒淡出
        if b.maxTimer - b.timer < 0.3 then
            alpha = (b.maxTimer - b.timer) / 0.3 -- 前 0.3 秒淡入
        end
        
        local tw = font:getWidth(b.text)
        local th = font:getHeight()
        local padding = 8
        
        local bx = centerX + b.x_off - tw/2
        local by = centerY + b.y_off - th/2
        
        -- 绘制气泡背景（微透明深色风格）
        love.graphics.setColor(0, 0, 0, 0.6 * alpha)
        love.graphics.rectangle("fill", bx - padding, by - padding, tw + padding*2, th + padding*2, 8)
        
        -- 1px 亮边高光
        love.graphics.setColor(1, 1, 1, 0.15 * alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bx - padding, by - padding, tw + padding*2, th + padding*2, 8)
        
        -- 绘制文字
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, 0.9 * alpha)
        love.graphics.print(b.text, bx, by)
    end
end

return Bubble
