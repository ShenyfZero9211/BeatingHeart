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

local cache = {}

function Fonts.load(size)
    size = size or 14
    if cache[size] then return cache[size] end

    -- [OPTIMIZED] 缓存原始二进制数据，避免为不同字号重复读取大文件
    if Fonts.rawData then
        local fileData = love.filesystem.newFileData(Fonts.rawData, "tempfont." .. (Fonts.rawExt or "ttf"))
        local success, res = pcall(love.graphics.newFont, fileData, size)
        if success then
            cache[size] = res
            return res
        end
    end

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
                local ext = path:match("%.(%w+)$") or "ttf"
                local fileData = love.filesystem.newFileData(data, "tempfont." .. ext)
                
                local success, res = pcall(love.graphics.newFont, fileData, size)
                if success then
                    logToFile("[FONTS] SUCCESS: Loaded system font from " .. path)
                    Fonts.rawData = data -- 缓存并共享给该进程的其他字号请求
                    Fonts.rawExt = ext
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

    cache[size] = font
    return font
end

return Fonts
