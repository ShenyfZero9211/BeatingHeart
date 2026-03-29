function love.conf(t)
    local isSettings = false
    local isMenu = false
    local menuX, menuY
    if arg then
        for i, v in ipairs(arg) do
            if v == "settings" then isSettings = true end
            if v == "menu" then 
                isMenu = true 
                menuX = tonumber(arg[i+1])
                menuY = tonumber(arg[i+2])
            end
        end
    end
    
    if isSettings then
        t.window.width = 300
        t.window.height = 420
        t.window.title = "Settings"
        t.window.borderless = false
        t.window.transparent = false
        t.modules.audio = false
        t.modules.physics = false
        t.modules.joystick = false
        t.modules.thread = false
        t.modules.video = false
        t.modules.touch = false
    elseif isMenu then
        t.window.width = 160
        t.window.height = 100
        t.window.title = "BeatingHeartMenu"
        t.window.borderless = true
        t.window.transparent = true
        if menuX and menuY then
            t.window.x = menuX - 80 
            t.window.y = menuY - 100 
        end
        t.modules.audio = false
        t.modules.physics = false
        t.modules.joystick = false
        t.modules.thread = false
        t.modules.video = false
        t.modules.touch = false
    else
        t.window.width = 800
        t.window.height = 800
        t.window.title = "Beating Heart"
        t.window.borderless = true
        t.window.transparent = true
        t.modules.audio = true
    end
    t.window.resizable = false
    t.window.alwaysontop = true
    t.modules.window = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.math = true
end
