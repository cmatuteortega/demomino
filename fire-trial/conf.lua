function love.conf(t)
    t.identity = "fire-trial"
    t.version = "11.4"
    t.console = false

    t.window.title = "Fire Trial"
    t.window.width = 800
    t.window.height = 600
    t.window.borderless = false
    t.window.resizable = false
    t.window.vsync = 1
    t.window.msaa = 0

    t.modules.audio = false
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
    t.modules.sound = false
    t.modules.touch = false
end
