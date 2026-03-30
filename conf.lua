function love.conf(t)
    local isSettings = false
    local isMenu = false
    if arg then
        for i, v in ipairs(arg) do
            if v == "settings" then isSettings = true end
            if v == "menu" then isMenu = true end
        end
    end
    
    if isSettings then
        t.window.width = 360
        t.window.height = 540
        t.window.title = "Settings"
        t.window.borderless = true
        t.window.transparent = true
        t.window.msaa = 4
        t.modules.audio = false
        t.modules.physics = false
        t.modules.joystick = false
        t.modules.thread = true
        t.console = false
        t.modules.video = false
        t.modules.touch = false
    elseif isMenu then
        t.window.width = 1
        t.window.height = 1
        t.window.title = "BeatingHeartMenu"
        t.window.borderless = true
        t.window.transparent = true
        t.window.visible = false
        t.console = false
        t.modules.audio = false
        t.modules.physics = false
        t.modules.joystick = false
        t.modules.video = false
        t.modules.touch = false
    else
        t.window.width = 400
        t.window.height = 400
        t.window.title = "Beating Heart"
        t.window.borderless = true
        t.window.transparent = true
        t.window.msaa = 4
        t.modules.audio = true
        t.modules.physics = false
        t.modules.joystick = false
        t.modules.thread = true
        t.console = true
    end
end
