function love.conf(t)
    local isSettings = false
    if arg then
        for i, v in ipairs(arg) do
            if v == "settings" then isSettings = true end
        end
    end
    
    if isSettings then
        t.window.width = 300
        t.window.height = 420
        t.window.title = "Settings"
        t.window.borderless = false
        t.window.transparent = false
        -- 极致精简模块加载以大幅削减拉起进程的世界
        t.modules.audio = false
        t.modules.physics = false
        t.modules.joystick = false
        t.modules.thread = false
        t.modules.video = false
        t.modules.touch = false
    else
        t.window.width = 450
        t.window.height = 450
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
