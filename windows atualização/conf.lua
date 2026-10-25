function love.conf(t)
  t.identity = "moo_io"
  t.version = "11.5"
  t.window.title = "Moo IO | Seu mundo, seus amigos"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 480
  if os.getenv("MOO_IO_LUA_SERVER") == "1" then
    t.window = false
  end
  t.console = false
end
