-- SPDX-License-Identifier: AGPL-3.0-only
-- 127.0.0.1:{PORT+1} local controller from LOCAL server/src/index.js.
local Socket=require("socket")
local Json=require("server-lua.vendor.dkjson")
local Crypto=require("src.protocol.original_crypto")
local Control={}
Control.__index=Control
local function constantEqual(a,b)
 if type(a)~="string" or type(b)~="string" or #a~=#b then return false end
 local diff=0
 for i=1,#a do diff=Crypto.bor(diff,Crypto.bxor(a:byte(i),b:byte(i))) end
 return diff==0
end
local function response(code,payload)
 local data=assert(Json.encode(payload))
 return ("HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: %d\r\n\r\n%s"):format(
  code,code==200 and "OK" or "Forbidden",#data,data)
end
function Control.new(opts)
 assert(type(opts.port)=="number" and opts.port>=1 and opts.port<=65534)
 assert(type(opts.roomCode)=="string" and #opts.roomCode>=8)
 return setmetatable({port=opts.port,roomCode=opts.roomCode,
  mode=assert(opts.mode),host=assert(opts.host),
  peers={},listener=nil,shutdown=false},Control)
end
function Control:start()
 local sock,err=Socket.bind("127.0.0.1",self.port+1)
 if not sock then return false,err end
 sock:settimeout(0)
 self.listener=sock
 return true
end
function Control:close()
 if self.listener then self.listener:close();self.listener=nil end
 for _,peer in ipairs(self.peers) do peer.tcp:close() end
 self.peers={}
end
function Control:request(raw)
 local head=raw:match("^(.-)\r\n\r\n")
 if not head then return nil end
 local method,path=head:match("^([A-Z]+)%s+([^%s]+)%s+HTTP/1%.[01]")
 local headers={}
 for line in head:gmatch("\r\n([^\r\n]+)") do
  local key,val=line:match("^([%w%-]+):%s*(.-)%s*$")
  if key then headers[key:lower()]=val end
 end
 local forbidden=false
 for _,key in ipairs({"forwarded","x-forwarded-for","x-real-ip","x-forwarded-host"}) do
  if headers[key] then forbidden=true end
 end
 if method=="GET" and path=="/status" then
  return response(200,{project="Moo-IO",mode=self.mode,host=self.host}),false
 end
 if method=="POST" and path=="/shutdown" and not forbidden
  and constantEqual(headers["x-mooio-code"],self.roomCode) then
  return response(200,{ok=true}),true
 end
 return response(403,{error="forbidden"}),false
end
function Control:update()
 if not self.listener then return false end
 for _=1,8 do
  local tcp=self.listener:accept()
  if not tcp then break end
  tcp:settimeout(0)
  if #self.peers>=8 then tcp:close() else
   self.peers[#self.peers+1]={tcp=tcp,input="",out="",done=false,stop=false}
  end
 end
 local remaining={}
 for _,peer in ipairs(self.peers) do
  if peer.out=="" and not peer.done then
   local data,err,partial=peer.tcp:receive(4096)
   peer.input=peer.input..(data or partial or "")
   if #peer.input>8192 then peer.done=true end
   if not peer.done then
    local reply,stop=self:request(peer.input)
    if reply then peer.out=reply;peer.done=true;peer.stop=stop end
   end
   if err and err~="timeout" and not peer.done then peer.done=true end
  end
  if peer.out~="" then
   local sent,err,last=peer.tcp:send(peer.out)
   peer.out=peer.out:sub((sent or last or 0)+1)
   if err and err~="timeout" then peer.out="" end
  end
  if peer.done and peer.out=="" then
   peer.tcp:close()
   if peer.stop then self.shutdown=true end
  else remaining[#remaining+1]=peer end
 end
 self.peers=remaining
 return self.shutdown
end
return Control
