-- Verify that the shipped Android LÖVE thread executes the real Windows
-- LOCAL server; a stub or bundled Node runtime does not satisfy this contract.
local source=assert(io.open("src/mobile/lua_host_thread.lua","rb"))
local code=source:read("*a");source:close()
assert(code:find('require("server-lua.local_server")',1,true))
assert(code:find('utf8=require("utf8")',1,true),
  "Android Lua worker must initialize the UTF8 library before spawning players")
assert(code:find("Local.new",1,true))
assert(code:find("server:update()",1,true))
assert(code:find("Socket.sleep",1,true))
local host=assert(io.open("src/net/mooio_host.lua","rb"))
local client=host:read("*a");host:close()
assert(client:find("lua_host_thread.lua",1,true))
assert(not client:find("MooIONodeBridge",1,true))
assert(not client:find("controlServer",1,true))
assert(not client:find("node",1,true))
print("ANDROID LUA THREAD CONTRACT PASS")
