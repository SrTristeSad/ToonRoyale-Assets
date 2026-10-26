-- Android: host the SAME authoritative Windows LOCAL Lua gameplay in a LÖVE thread.
-- Do not start Node, an Android foreground service or any fake server.
local Random=require("src.net.secure_random")
local Network=require("src.net.mooio_network")
local Host={}
Host.__index=Host
local function localAddress(mode)
  local ok,socket=pcall(require,"socket")
  if not ok then return mode=="lan" and "127.0.0.1" or nil end
  local udp=socket.udp()
  local address
  if udp then
    udp:settimeout(0)
    pcall(function() udp:setpeername("192.0.2.1",9) end)
    address=udp:getsockname()
    udp:close()
  end
  if not Network.accept(address,mode) then
    local name=socket.dns and socket.dns.gethostname()
    local resolved=name and socket.dns.toip(name)
    if Network.accept(resolved,mode) then address=resolved end
  end
  return Network.accept(address,mode) and address
    or (mode=="lan" and "127.0.0.1" or nil)
end
local function roomCode()
  return (Random.bytes(18):gsub(".",function(ch)
    return string.format("%02x",ch:byte())
  end))
end
local function backend()
  assert(love and love.thread and love.filesystem,
    "LÖVE threads/filesystem required for Lua hosting")
  return {
    createDirectory=function(dir)return love.filesystem.createDirectory(dir)end,
    saveDirectory=function()return love.filesystem.getSaveDirectory()end,
    newChannel=function(name)return love.thread.getChannel(name)end,
    newThread=function(path)return love.thread.newThread(path)end
  }
end
local function optionsValid(bots,difficulty,mods,map)
  if type(bots)~="number" or bots%1~=0 or bots<0 or bots>8 then
    return false,"Quantidade de bots invalida (0 a 8)."
  end
  if not ({normal=true,pacifico=true,dificil=true,extremo=true})[difficulty] then
    return false,"Dificuldade desconhecida."
  end
  if type(mods)~="string" or #mods>512 or mods:find("[^a-z0-9,%-]") then
    return false,"Lista de mods invalida."
  end
  if type(map)~="string" or #map>48 or
    (map~="" and not map:match("^[a-z][a-z0-9%-]*$")) then
    return false,"Mapa invalido."
  end
  return true
end
function Host.new(options)
  options=options or {}
  return setmetatable({
    platform=options.platform,chooseIP=options.chooseIP or localAddress,
    generateCode=options.generateCode or roomCode,
    state="idle",code="",address="",hostIP="",port=8080,
    mode="lan",error=nil,progress="",lastLog="",elapsed=0,
    thread=nil,events=nil,commands=nil
  },Host)
end
function Host:start(mode,requestedIP,requestedBots,difficulty,modIds,mapId)
  if self.state=="starting" or self.state=="ready" then
    return false,"Sala local ja aberta."
  end
  if self.thread and self.thread:isRunning() then
    return false,"Aguarde o encerramento da sala Lua anterior."
  end
  mode=mode=="vpn" and "vpn" or "lan"
  local bots=requestedBots or 0
  difficulty=difficulty or "normal"
  modIds=modIds or ""
  mapId=mapId or "classico"
  local valid,why=optionsValid(bots,difficulty,modIds,mapId)
  if not valid then return false,why end
  local ip=requestedIP and requestedIP~="" and requestedIP or self.chooseIP(mode)
  if not Network.accept(ip,mode) then
    return false,"Informe um IP privado valido desta rede LAN/VPN."
  end
  local ok,result=pcall(function()
    local platform=self.platform or backend()
    assert(platform.createDirectory("lua-server"),"Nao foi possivel criar dados do servidor")
    local code=self.generateCode()
    assert(type(code)=="string" and #code>=8 and #code<=64
      and code:match("^[%w%-]+$"),"Codigo privado de sala invalido")
    local id=code:sub(1,24)
    local eventsName="mooio-lua-events-"..id
    local commandsName="mooio-lua-commands-"..id
    local events=platform.newChannel(eventsName)
    local commands=platform.newChannel(commandsName)
    if events.clear then events:clear() end
    if commands.clear then commands:clear() end
    local thread=platform.newThread("src/mobile/lua_host_thread.lua")
    assert(thread:start(commandsName,eventsName,ip,mode,code,bots,
      difficulty,modIds,mapId,platform.saveDirectory().."/lua-server")~=false,
      "Falha ao abrir thread Lua")
    return {thread=thread,events=events,commands=commands,code=code,ip=ip}
  end)
  if not ok then
    self.state="failed";self.error=tostring(result);self.lastLog=self.error
    return false,self.error
  end
  self.thread=result.thread;self.events=result.events;self.commands=result.commands
  self.code=result.code;self.hostIP=result.ip
  self.address=result.ip..":8080";self.mode=mode
  self.state="starting";self.elapsed=0;self.error=nil;self.lastLog=""
  self.progress="Iniciando o servidor Lua do Windows no celular..."
  return true
end
function Host:update(dt)
  if self.state~="starting" and self.state~="ready" then return end
  self.elapsed=self.elapsed+(dt or 0)
  if self.events then
    for _=1,16 do
      local event=self.events:pop()
      if not event then break end
      if event=="ready" then
        if self.state=="starting" then
          self.state="ready";self.progress="Servidor Lua pronto. Sala local ativa."
        end
      elseif event=="stopped" then
        self.state="failed";self.error="Servidor Lua foi encerrado."
      elseif type(event)=="string" and event:sub(1,7)=="failed:" then
        self.state="failed";self.error=event:sub(8)
        self.lastLog=self.error
      end
    end
  end
  local failed=self.thread and self.thread:getError()
  if failed then
    self.state="failed";self.error="Servidor Lua: "..tostring(failed)
    self.lastLog=self.error
  elseif self.thread and not self.thread:isRunning() and
     (self.state=="starting" or self.state=="ready") then
    self.state="failed";self.error=self.error or "Thread do servidor Lua terminou."
  elseif self.state=="starting" and self.elapsed>25 then
    self:stop()
    self.state="failed";self.error="Servidor Lua nao ficou pronto em 25 segundos."
    self.lastLog=self.error
  end
end
function Host:stop()
  if self.thread and self.thread:isRunning() and self.commands then
    self.commands:push("stop")
  end
  self.state="idle";self.code="";self.address="";self.hostIP=""
  self.error=nil;self.progress=""
end
return Host
