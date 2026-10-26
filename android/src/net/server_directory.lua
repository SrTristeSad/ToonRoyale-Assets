-- SPDX-License-Identifier: AGPL-3.0-only
-- Browse the existing V2 game's read-only room directory, not its admin panel.
-- An IP:port connects only over a private LAN/VPN. Public servers use
-- the pre-existing certificate-verified HTTPS/WSS TLS bridge.
local Network=require("src.net.mooio_network")
local TLS=require("src.net.tls_bridge")
local Json=require("src.net.json")
local Directory={}
local function validRoomCode(code)
 return type(code)=="string" and #code>=8 and #code<=64
   and code:match("^[A-Za-z0-9%-]+$")~=nil
end
function Directory.parse(value)
 if type(value)~="string" then return nil,"Informe o IP:porta do servidor." end
 value=value:match("^%s*(.-)%s*$")
 local hostname=value:match("^https://([a-z0-9%.%-]+)/?$")
 if hostname then
   if not TLS.validDomain(hostname) then
     return nil,"Use um dominio HTTPS valido para o servidor publico."
   end
   return {host=hostname,port=443,secure=true}
 end
 local host,port=value:match("^(%d+%.%d+%.%d+%.%d+):(%d+)$")
 if host and Network.kind(host) then
   port=tonumber(port)
   if port and port>=1 and port<=65534 then
     return {host=host,port=port,secure=false}
   end
 end
 return nil,"Informe IP privado:porta (LAN/VPN) ou https://sala.dominio.com."
end
local function validRoom(raw)
 return type(raw)=="table" and type(raw.id)=="string" and #raw.id<=48
  and raw.id:match("^[a-z][a-z0-9%-]*$")~=nil
  and type(raw.name)=="string" and #raw.name>0 and #raw.name<=60
  and (raw.preset=="traditional" or raw.preset=="custom")
  and type(raw.port)=="number" and raw.port%1==0 and raw.port>=1024 and raw.port<=65534
  and type(raw.players)=="number" and raw.players%1==0 and raw.players>=0 and raw.players<=40
  and type(raw.capacity)=="number" and raw.capacity%1==0 and raw.capacity>=1
  and raw.capacity<=40 and type(raw.online)=="boolean"
  and type(raw.publicAccess)=="boolean"
  and (not raw.publicAccess or validRoomCode(raw.inviteCode))
end
function Directory.decode(raw,endpoint)
 if type(raw)~="string" or #raw>32768 then return nil,"Lista do servidor muito grande." end
 local payload=Json.decode(raw)
 if type(payload)~="table" or payload.schemaVersion~=1
   or payload.serverType~="Moo-IO-V2" or type(payload.rooms)~="table"
   or #payload.rooms>32 then
   return nil,"Este endereco nao oferece a lista de salas V2."
 end
 if type(payload.currentId)~="string" or
   not payload.currentId:match("^[a-z][a-z0-9%-]*$") then
   return nil,"Identidade do servidor V2 invalida."
 end
 local rooms={}
 for _,room in ipairs(payload.rooms) do
   if not validRoom(room) then return nil,"O servidor enviou uma sala invalida." end
   local entry={
     id=room.id,name=room.name,preset=room.preset,port=room.port,
     players=room.players,capacity=room.capacity,online=room.online,
     publicAccess=room.publicAccess,
     inviteCode=room.publicAccess and room.inviteCode or nil
   }
   rooms[#rooms+1]=entry
 end
 return {endpoint=endpoint,currentId=payload.currentId,rooms=rooms}
end
function Directory.fetch(value,overrides)
 local endpoint,why=Directory.parse(value)
 if not endpoint then return nil,why end
 overrides=overrides or {}
 local http=overrides.http or require("socket.http")
 local ltn12=overrides.ltn12 or require("ltn12")
 local secureOpts
 if endpoint.secure then
   secureOpts,why=TLS.options(endpoint.host,endpoint.port,overrides)
   if not secureOpts then return nil,why end
 end
 local chunks={}
 local previous=http.TIMEOUT
 http.TIMEOUT=3
 local ok,body,status=pcall(http.request,{
   url="http://"..endpoint.host..":"..endpoint.port.."/api/public/rooms",
   method="GET",
   headers={["Connection"]="close"},
   sink=ltn12.sink.table(chunks),
   create=secureOpts and secureOpts.create or nil
 })
 http.TIMEOUT=previous
 if not ok or not body then return nil,"Servidor nao respondeu a consulta de salas." end
 if tonumber(status)~=200 then
   return nil,"Servidor nao oferece catalogo V2 (HTTP "..tostring(status)..")."
 end
 return Directory.decode(table.concat(chunks),endpoint)
end
function Directory.target(directory,room,manualCode)
 if type(directory)~="table" or type(directory.endpoint)~="table"
   or type(room)~="table" then return nil,"Selecione uma sala." end
 local code=room.publicAccess and room.inviteCode or manualCode
 if not validRoomCode(code) then
   return nil,"Esta sala e privada. Informe o codigo do convite."
 end
 local ep=directory.endpoint
 if ep.secure then
   -- Public gateway advertises room.id.base-domain, all covered by verified TLS.
   local prefix=directory.currentId.."."
   if ep.host:sub(1,#prefix)~=prefix then
     return nil,"O dominio informado nao corresponde ao gateway V2."
   end
   local domain=ep.host:sub(#prefix+1)
   local newHost=room.id.."."..domain
   if not TLS.validDomain(newHost) then
     return nil,"Nome DNS da sala V2 invalido."
   end
   return {host=newHost,port=443,code=code,secure=true,
     invite="https://"..newHost.."/"..code}
 end
 return {host=ep.host,port=room.port,code=code,secure=false,
   invite=ep.host..":"..room.port.."/"..code}
end
return Directory
