-- Server runtime: same Windows server-lua modules on a headless LÖVE thread.
local commandsName,eventsName,bind,mode,roomCode,bots,difficulty,mods,mapId,dataDir=...
local event=love.thread.getChannel(eventsName)
local commands=love.thread.getChannel(commandsName)
local server
local ok,reason=xpcall(function()
  require("love.filesystem")
  -- LÖVE threads start in a fresh LuaJIT state. Unlike the Windows main.lua
  -- headless entrypoint, this thread did not initialize global utf8; the
  -- player name sanitizer then crashed on the first real spawn packet M.
  if not utf8 then utf8=require("utf8") end
  local Socket=require("socket")
  local Local=require("server-lua.local_server")
  server=Local.new({
    bind=bind,port=8080,roomCode=roomCode,mode=mode,botCount=bots,
    difficulty=difficulty,modIds=mods,mapId=mapId,dataDir=dataDir,
    guiHost=true,rotateBuild=false,
    log=function(message) print("[MooIO Lua] "..tostring(message)) end
  })
  local started,err=server:start()
  assert(started,err or "Falha ao ligar socket local Lua")
  event:push("ready")
  while server.host.listener do
    if commands:pop()=="stop" then break end
    if server:update()==false then break end
    Socket.sleep(0.005)
  end
end,debug.traceback)
if server then pcall(function() server:close() end) end
if not ok then
  event:push("failed:"..tostring(reason):sub(1,500))
else
  event:push("stopped")
end
