function love.conf(t)
  t.identity = "moo_io"
  t.version = "11.5"
  -- The host is a second process, not a second graphical window.
  -- Disable the window and graphics BEFORE module initialization.
  if os.getenv("MOO_IO_LUA_SERVER") == "1" then
    t.window = nil
    t.modules.window = false
    t.modules.graphics = false
    t.modules.font = false
    t.modules.image = false
    t.modules.audio = false
    t.modules.video = false
    t.modules.mouse = false
    t.modules.keyboard = false
    t.modules.joystick = false
    t.modules.touch = false
    return
  end
  t.window.title = "Moo IO | Seu mundo, seus amigos"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 480
  t.console = false
end
