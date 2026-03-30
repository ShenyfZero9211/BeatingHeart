local i18n = {}

local translations = {
    -- ID 1: English
    [1] = {
        settings_title = "Settings",
        size = "Heart Size",
        sensitivity = "Audio Sensitivity",
        topmost = "Window Topmost",
        language = "Language / 语言",
        exit = "Exit / Quit",
        close_hint = "Press ESC or Right Click to close.",
        tray_settings = "Settings",
        tray_exit = "Exit / Quit",
        palette = "Palette:",
        lang_names = { [0] = "System Auto", [1] = "English", [2] = "简体中文" },
        -- Bubble Pools
        pool_quiet = { "...", "Peaceful", "Deep breath", "Serene", "Zen", "Alone", "Watching you...", "So quiet." },
        pool_active = { "Rhythmic", "Grooving", "I feel you", "Lively", "Good vibes", "Steady", "Nice beat", "Dance with me" },
        pool_intense = { "ROCK ON!", "ADRENALINE!", "HEART RACING!", "SO LOUD!", "YEAH!", "PUMPING!", "I'M ALIVE!", "FEEL THE HEAT!" }
    },
    -- ID 2: Chinese (Simplified)
    [2] = {
        settings_title = "设置面板",
        size = "心脏体积",
        sensitivity = "声敏度",
        topmost = "窗口最前",
        language = "语言 / Language",
        exit = "彻底退出",
        close_hint = "按下 ESC 或 右键点击 即可关闭",
        tray_settings = "设置面板 (Settings)",
        tray_exit = "彻底退出 (Exit)",
        palette = "预设配色:",
        lang_names = { [0] = "系统默认", [1] = "English", [2] = "简体中文" },
        -- Bubble Pools
        pool_quiet = { "...", "安宁", "深呼吸", "宁静", "入定", "心无旁骛", "在看你呢...", "好安静..." },
        pool_active = { "律动中", "有节奏", "感觉到你了", "悦动", "这种感觉不错", "心率平稳", "节奏感拉满", "一起跳吧" },
        pool_intense = { "太炸了！", "燥起来！", "心跳加速！", "高能预警！", "全速跳动！", "热血沸腾！", "彻底疯狂！", "感受这热度！" }
    }
}

local detectedLang = 1 -- Default to EN

function i18n.init()
    local lang = "en"
    
    -- Windows 特化探测：love.system.getLanguage 在某些环境下可能返回 en_us
    -- 但 GetUserDefaultUILanguage 能直接从内核获取 UI 语言设置
    if love.system.getOS() == "Windows" then
        local success, ffi = pcall(require, "ffi")
        if success then
            pcall(function()
                ffi.cdef[[
                    unsigned short GetUserDefaultUILanguage();
                ]]
                local langID = ffi.C.GetUserDefaultUILanguage()
                -- 0x0804: zh-CN, 0x0404: zh-TW, 0x0C04: zh-HK, 0x1004: zh-SG
                if langID == 0x0804 or langID == 0x0404 or langID == 0x0C04 or langID == 0x1004 then
                    lang = "zh_windows"
                end
            end)
        end
    end

    if lang == "en" then
        if love.system.getLanguage then
            lang = love.system.getLanguage()
        else
            local locale = os.getenv("LANG") or os.setlocale(nil) or "en"
            lang = locale:lower()
        end
    end
    
    local f = io.open("debug_log.txt", "a")
    if f then
        f:write(os.date("[%H:%M:%S] ") .. "[I18N] Final Detected Language: " .. lang .. "\n")
        f:close()
    end
    
    if lang:find("zh") or lang:find("chi") or lang:find("936") then
        detectedLang = 2
    else
        detectedLang = 1
    end
end

-- 根据 ID 获取翻译，如果 ID 为 0 (Auto)，则使用探测到的系统语言
function i18n.get(key, langID)
    local id = langID or 0
    if id == 0 then id = detectedLang end
    
    local dict = translations[id] or translations[1]
    return dict[key] or key
end

function i18n.getPool(poolKey, langID)
    return i18n.get(poolKey, langID)
end

return i18n
