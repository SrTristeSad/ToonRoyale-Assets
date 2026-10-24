-- SPDX-License-Identifier: AGPL-3.0-only
-- Nonblocking LuaSocket HTTP/WebSocket room gateway for LÖVE's update loop.
-- The World/gameplay dispatcher is deliberately injected (not faked);
-- this adapter is not yet the full Moo-IO server.
local Socket=require("socket")
local Random=require("src.net.secure_random")
local Network=require("src.net.mooio_network")
local Build=require("server-lua.protocol.build")
local Session=require("server-lua.protocol.session")
local WS=require("server-lua.net.websocket")
local Host={}
Host.__index=Host
local function hex(s) return (s:gsub(".",function(c)return string.format("%02x",c:byte())end)) end
local function jsonString(v)
  return '"'..tostring(v):gsub('\\','\\\\'):gsub('"','\\"')..'"'
end
local function publicBuild(b)
  local out={}
  for i=1,8 do out[i]=tostring(b.constants[i]) end
  return '{"buildId":'..jsonString(b.buildId)..',"salt":'..b.salt..
    ',"rounds":'..b.rounds..',"tapA":'..b.tapA..',"tapB":'..b.tapB..
    ',"rotA":'..b.rotA..',"rotB":'..b.rotB..',"mult":'..b.mult..
    ',"constants":['..table.concat(out,",")..']}'
end
local function equal(a,b)
  if type(a)~="string" or type(b)~="string" or #a~=#b then return false end
  local diff=0
  local C=require("src.protocol.original_crypto")
  for i=1,#a do diff=C.bor(diff,C.bxor(a:byte(i),b:byte(i))) end
  return diff==0
end
local function parseHead(buffer)
  local at=buffer:find("\r\n\r\n",1,true)
  if not at then return nil end
  local raw=buffer:sub(1,at+3)
  local method,target,version=raw:match("^([A-Z]+)%s+([^%s]+)%s+HTTP/(1%.[01])\r\n")
  if not method then return false,"bad request" end
  local headers={}
  for line in raw:gmatch("\r\n([^\r\n]+)") do
    local k,v=line:match("^([%w%-]+):%s*(.-)%s*$")
    if k then headers[k:lower()]=v end
  end
  local length=tonumber(headers["content-length"] or "0")
  if not length or length%1~=0 or length<0 or length>8192 then return false,"bad body length" end
  local endAt=at+3+length
  if #buffer<endAt then return nil end
  return {method=method,target=target,version=version,headers=headers,
    body=buffer:sub(at+4,endAt)},buffer:sub(endAt+1)
end
local responses={
  [200]="OK",[101]="Switching Protocols",[400]="Bad Request",
  [403]="Forbidden",[404]="Not Found",[409]="Conflict",
  [413]="Payload Too Large",[429]="Too Many Requests",[503]="Service Unavailable"
}
local function reply(code,body,contentType)
  body=body or ""
  return ("HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n%s"):format(
    code,responses[code] or "Error",contentType or "application/json",
    #body,body)
end
local function addOutput(peer,data)
  if #peer.out + #data>262144 then return false end
  peer.out=peer.out..data
  return true
end
function Host.new(options)
  options=options or {}
  assert(type(options.onPacket)=="function" and type(options.onConnect)=="function",
    "Lua gameplay callbacks onConnect and onPacket are required")
  local ip=options.bind or "127.0.0.1"
  local mode=options.mode or "lan"
  assert(Network.accept(ip,mode),"LAN/VPN adapter required")
  local port=options.port or 8080
  assert(type(port)=="number" and port%1==0 and port>=1 and port<=65534,"invalid port")
  local code=options.roomCode
  assert(type(code)=="string" and #code>=8 and #code<=64
    and code:match("^[%w%-]+$"),"invalid room code")
  local build=options.build or Build.new()
  return setmetatable({
    bind=ip,mode=mode,port=port,roomCode=code,build=build,
    onConnect=options.onConnect,onPacket=options.onPacket,onClose=options.onClose,
    capacity=options.capacity or 40,maxPeers=options.maxPeers or 40,
    tickets={},peers={},listener=nil,active=0
  },Host)
end
function Host:start()
  if self.listener then return false,"already started" end
  local sock,err=Socket.bind(self.bind,self.port)
  if not sock then return false,err end
  sock:settimeout(0)
  self.listener=sock
  return true
end
function Host:drop(peer)
  if peer.closed then return end
  peer.closed=true
  pcall(function() peer.tcp:close() end)
  if peer.state=="websocket" then
    self.active=math.max(0,self.active-1)
    if self.onClose then pcall(self.onClose,peer) end
  end
end
function Host:close()
  if self.listener then self.listener:close();self.listener=nil end
  for _,p in ipairs(self.peers) do self:drop(p) end
  self.peers={};self.tickets={};self.active=0
end
local function bad(peer,code,err)
  addOutput(peer,reply(code,'{"error":'..jsonString(err)..'}'))
  peer.state="closing"
end
function Host:request(peer,req)
  local path=req.target:match("^[^?]+") or "/"
  local h=req.headers
  local upgrade=(h.upgrade or ""):lower()=="websocket"
  if upgrade then
    local key,build=req.target:match("^/s/(%w+)%?b=([%w]+)")
    if not key or key~="LC" or build~=self.build.buildId then return bad(peer,403,"build") end
    local token=req.target:match("[?&]token=tk:([0-9a-f]+)")
    local t=token and self.tickets[token] or nil
    if not t then return bad(peer,403,"ticket") end
    -- One-use ticket, consumed before the WebSocket upgrade.
    self.tickets[token]=nil
    if os.time()-t.created>45 then return bad(peer,403,"expired ticket") end
    if self.active>=self.capacity then return bad(peer,409,"server full") end
    if h.origin~="http://"..self.bind..":"..self.port
      or h.host~=self.bind..":"..self.port then return bad(peer,403,"origin") end
    if h["sec-websocket-version"]~="13" then return bad(peer,400,"ws version") end
    if not (h.connection or ""):lower():find("upgrade",1,true) then return bad(peer,400,"upgrade") end
    local accept=WS.acceptKey(h["sec-websocket-key"])
    if not accept then return bad(peer,400,"ws key") end
    peer.session=Session.new({build=self.build})
    local response="HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: "..accept.."\r\n\r\n"
    addOutput(peer,response)
    peer.state="websocket";self.active=self.active+1
    function peer:send(name,args)
      local frame,err=self.session:encode(name,args or {})
      if not frame then return false,err end
      return addOutput(self,WS.encode(frame,2))
    end
    addOutput(peer,WS.encode(peer.session:handshakeFrame(),2))
    local ok,err=pcall(self.onConnect,peer,t)
    if not ok then self:drop(peer);error("Lua onConnect: "..tostring(err)) end
    return
  end
  if req.method=="GET" and path=="/ping" then
    local body='{"status":"ok","build":'..jsonString(self.build.buildId)..
      ',"servers":[{"region":"local","regionName":"Local","name":"LC","key":"LC","playerCount":'..
      self.active..',"playerCapacity":'..self.capacity..',"auth":false}]}'
    addOutput(peer,reply(200,body))
  elseif req.method=="GET" and path=="/mooio/protocol" then
    addOutput(peer,reply(200,publicBuild(self.build)))
  elseif req.method=="GET" and path=="/mooio/status" then
    addOutput(peer,reply(200,'{"project":"Moo-IO","runtime":"lua","mode":'..jsonString(self.mode)..'}'))
  elseif req.method=="POST" and path=="/api/join" then
    if not equal(h["x-mooio-code"],self.roomCode) then return bad(peer,403,"invite_required") end
    if not req.body:find('"captcha"%s*:%s*true') then return bad(peer,403,"captcha") end
    if req.body:find('"auth"%s*:') then return bad(peer,403,"auth_not_implemented") end
    if not req.body:find("/s/LC",1,true) then return bad(peer,400,"server") end
    local ticket=hex(Random.bytes(18))
    local did=req.body:match('"did"%s*:%s*"([0-9a-f]+)"')
    if not did or #did<16 or #did>64 then did=hex(Random.bytes(12)) end
    self.tickets[ticket]={did=did,created=os.time(),server="LC"}
    addOutput(peer,reply(200,'{"ticket":'..jsonString(ticket)..',"did":'..jsonString(did)..'}'))
  else
    bad(peer,404,"not_found")
  end
  peer.state="closing"
end
function Host:processPeer(peer)
  if peer.closed then return end
  if #peer.out>0 then
    local sent,err,last=peer.tcp:send(peer.out)
    local count=sent or last or 0
    if count>0 then peer.out=peer.out:sub(count+1) end
    if err and err~="timeout" then self:drop(peer);return end
  end
  if peer.state=="closing" then
    if #peer.out==0 then self:drop(peer) end
    return
  end
  local data,err,part=peer.tcp:receive(8192)
  local chunk=data or part or ""
  if #chunk>0 then peer.input=peer.input..chunk end
  if #peer.input>65536 then self:drop(peer);return end
  if peer.state=="http" then
    if #peer.input>16384 then self:drop(peer);return end
    local req,rest=parseHead(peer.input)
    if req==false then self:drop(peer);return end
    if req then
      peer.input=rest
      self:request(peer,req)
    end
  end
  if peer.state=="websocket" then
    for _=1,32 do
      local frame,remainder,why=WS.decode(peer.input)
      if why then self:drop(peer);return end
      if not frame then break end
      peer.input=remainder
      if frame.opcode==8 then
        addOutput(peer,WS.encode(frame.payload:sub(1,125),8))
        peer.state="closing";break
      elseif frame.opcode==9 then
        addOutput(peer,WS.encode(frame.payload:sub(1,125),10))
      elseif frame.opcode==2 then
        local msg,reason=peer.session:decode(frame.payload)
        if not msg then self:drop(peer);return end
        local ok,e=pcall(self.onPacket,peer,msg.name,msg.args)
        if not ok then self:drop(peer);error("Lua onPacket: "..tostring(e)) end
      end
    end
  end
  if err and err~="timeout" then self:drop(peer) end
end
function Host:update()
  if not self.listener then return end
  for _=1,12 do
    local tcp=self.listener:accept()
    if not tcp then break end
    if #self.peers>=self.maxPeers then tcp:close()
    else
      tcp:settimeout(0)
      self.peers[#self.peers+1]={tcp=tcp,state="http",input="",out="",closed=false}
    end
  end
  local alive={}
  for _,p in ipairs(self.peers) do
    self:processPeer(p)
    if not p.closed then alive[#alive+1]=p end
  end
  self.peers=alive
  for token,entry in pairs(self.tickets) do
    if os.time()-entry.created>45 then self.tickets[token]=nil end
  end
end
return Host
