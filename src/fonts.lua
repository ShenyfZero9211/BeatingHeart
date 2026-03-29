local Fonts = {}

-- [SharpEye] Native System Font Loader v1.2
-- 增加了对 debug_log.txt 的同步记录，并优化了 TTC 集合的二进制识别

local function logToFile(msg)
    print(msg)
    local f = io.open("debug_log.txt", "a")
    if f then
        f:write(os.date("[%H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
end

function Fonts.load(size)
    local windir = os.getenv("WINDIR") or "C:\\Windows"
    local paths = {
        windir .. "\\Fonts\\msyh.ttc",   -- 微软雅黑
        windir .. "\\Fonts\\msyh.ttf",
        windir .. "\\Fonts\\simhei.ttf", -- 黑体
        "C:\\Windows\\Fonts\\msyh.ttc",
    }

    local font = nil
    for _, path in ipairs(paths) do
        local file = io.open(path, "rb")
        if file then
            local data = file:read("*all")
            file:close()
            
            if data and #data > 0 then
                -- 核心修复：手动指定 extension，引导 Love2D 正确调用 Vector 引擎
                local ext = path:match("%.(%w+)$") or "ttf"
                local fileData = love.filesystem.newFileData(data, "tempfont." .. ext)
                
                local success, res = pcall(love.graphics.newFont, fileData, size)
                if success then
                    logToFile("[FONTS] SUCCESS: Loaded system font from " .. path)
                    font = res
                    break
                else
                    logToFile("[FONTS] ERROR: Found file but parse failed: " .. tostring(res))
                end
            end
        else
            logToFile("[FONTS] Checked path (not found or access denied): " .. path)
        end
    end

    if not font then
        logToFile("[FONTS] CRITICAL: No system fonts could be bridged.")
        font = love.graphics.newFont(size)
    end

    return font
end

return Fonts
