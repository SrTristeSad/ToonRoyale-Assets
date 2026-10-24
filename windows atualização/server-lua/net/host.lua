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
local Json=require("server-lua.vendor.dkjson")
local LocalAPI=require("server-lua.net.local_api")
local Control=require("server-lua.net.control")
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
  if not length or length%1~=0 or length<0 or length>32768 then return false,"bad body length" end
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
  local capacity=options.capacity or 40
  assert(type(capacity)=="number" and capacity%1==0 and capacity>=1 and capacity<=80,"capacity must be 1..80")
  local rooms=options.rooms or {LC={capacity=capacity,membersOnly=false}}
  assert(rooms.LC and type(rooms.LC.capacity)=="number","LOCAL LC definition required")
  local maxPeers=options.maxPeers or math.max(40,capacity)
  assert(type(maxPeers)=="number" and maxPeers%1==0 and maxPeers>=capacity,"invalid max peers")
  local build=options.build or Build.new()
  local api
  if options.accounts then
    api=LocalAPI.new({store=options.accounts,moderation=options.moderation,
      roomCode=code,servers=assert(options.servers,"LC/MB list from original Node required"),
      nowMs=options.nowMs})
  end
  return setmetatable({
    bind=ip,mode=mode,port=port,roomCode=code,build=build,
    onConnect=options.onConnect,onPacket=options.onPacket,onClose=options.onClose,
    accounts=options.accounts,api=api,
    rooms=rooms,activeByRoom={},activeByIp={},capacity=capacity,maxPeers=maxPeers,
    guiHost=options.guiHost==true,controller=nil,shutdownRequested=false,
    botCount=options.botCount or 0,
    tickets={},peers={},listener=nil,active=0
  },Host)
end
function Host:start()
  if self.listener then return false,"already started" end
  local sock,err=Socket.bind(self.bind,self.port)
  if not sock then return false,err end
  sock:settimeout(0)
  self.listener=sock
  if self.guiHost then
    self.controller=Control.new({port=self.port,roomCode=self.roomCode,
      host=self.bind,mode=self.mode})
    local ok,why=self.controller:start()
    if not ok then
      self.listener:close();self.listener=nil;self.controller=nil
      return false,why
    end
  end
  return true
end
function Host:drop(peer)
  if peer.closed then return end
  peer.closed=true
  pcall(function() peer.tcp:close() end)
  if peer.upgraded then
    self.active=math.max(0,self.active-1)
    if peer.ip then
      self.activeByIp[peer.ip]=math.max(0,(self.activeByIp[peer.ip] or 0)-1)
    end
    if peer.roomKey then
      self.activeByRoom[peer.roomKey]=math.max(0,(self.activeByRoom[peer.roomKey] or 0)-1)
    end
    if self.onClose then pcall(self.onClose,peer,peer.roomKey) end
  end
end
function Host:close()
  if self.controller then self.controller:close();self.controller=nil end
  if self.listener then self.listener:close();self.listener=nil end
  for _,p in ipairs(self.peers) do self:drop(p) end
  self.peers={};self.tickets={};self.active=0;self.activeByRoom={};self.activeByIp={}
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
    local room=key and self.rooms[key]
    if not room or build~=self.build.buildId then return bad(peer,403,"build") end
    local token=req.target:match("[?&]token=tk:([0-9a-f]+)")
    local t
    if self.accounts then
      t=token and self.accounts:consumeTicket(token,45000) or nil
      if t==Json.null then t=nil end
      if t and t.server~=nil and t.server~=Json.null and t.server~=key then
        return bad(peer,403,"ticket")
      end
    else
      t=token and self.tickets[token] or nil
      if t then
        -- Legacy host fixtures: one-use ticket, consumed before upgrade.
        self.tickets[token]=nil
        if os.time()-t.created>45 then return bad(peer,403,"expired ticket") end
      end
    end
    if not t then return bad(peer,403,"ticket") end
    local remoteIp=peer.tcp and peer.tcp:getpeername() or peer.ip
    if not remoteIp then return bad(peer,403,"ip") end
    if (self.activeByIp[remoteIp] or 0)>=5 then return bad(peer,403,"too many connections") end
    local account=t.account and t.account~=Json.null and t.account or nil
    if self.api and
      (self.api.moderation:isBanned(remoteIp,account and account.id or nil,t.did)
       or (account and account.verdict=="ban")) then
      return bad(peer,403,"banned")
    end
    if room.membersOnly and not (t.account and t.account~=Json.null) then
      return bad(peer,403,"members-only server")
    end
    if (self.activeByRoom[key] or 0)>=room.capacity then return bad(peer,409,"server full") end
    if h.origin~="http://"..self.bind..":"..self.port
      or h.host~=self.bind..":"..self.port then return bad(peer,403,"origin") end
    if h["sec-websocket-version"]~="13" then return bad(peer,400,"ws version") end
    if not (h.connection or ""):lower():find("upgrade",1,true) then return bad(peer,400,"upgrade") end
    local accept=WS.acceptKey(h["sec-websocket-key"])
    if not accept then return bad(peer,400,"ws key") end
    peer.session=Session.new({build=self.build})
    local response="HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: "..accept.."\r\n\r\n"
    addOutput(peer,response)
    peer.state="websocket";peer.upgraded=true;self.active=self.active+1
    peer.roomKey=key
    peer.ip=remoteIp
    self.activeByIp[remoteIp]=(self.activeByIp[remoteIp] or 0)+1
    self.activeByRoom[key]=(self.activeByRoom[key] or 0)+1
    function peer:send(name,args)
      local frame,err=self.session:encode(name,args or {})
      if not frame then return false,err end
      return addOutput(self,WS.encode(frame,2))
    end
    addOutput(peer,WS.encode(peer.session:handshakeFrame(),2))
    local ok,err=pcall(self.onConnect,peer,t,key)
    if not ok then self:drop(peer);error("Lua onConnect: "..tostring(err)) end
    return
  end
  if self.api and path:sub(1,5)=="/api/" then
    local ip
    if peer.tcp and type(peer.tcp.getpeername)=="function" then
      ip=peer.tcp:getpeername()
    end
    ip=ip or peer.ip or "unknown"
    local status,payload=self.api:handle(req.method,req.target,h,req.body,ip)
    if status then
      local body= status==204 and "" or assert(Json.encode(payload))
      addOutput(peer,reply(status,body))
      peer.state="closing"
      return
    end
  end
  if req.method=="GET" and path=="/ping" then
    local listed={}
    if self.api then listed=self.api.servers() else
      for _,roomKey in ipairs({"LC","MB"}) do
        local def=self.rooms[roomKey]
        if def then listed[#listed+1]={region="local",regionName="Local",name=roomKey,
          key=roomKey,playerCount=self.activeByRoom[roomKey] or 0,
          playerCapacity=def.capacity,auth=def.membersOnly or false} end
      end
    end
    local body=assert(Json.encode({status="ok",build=self.build.buildId,servers=listed}))
    addOutput(peer,reply(200,body))
  elseif req.method=="GET" and ((path=="/s/LC/ping" and self.rooms.LC) or (path=="/s/MB/ping" and self.rooms.MB)) then
    addOutput(peer,reply(200,"ok","text/plain"))
  elseif req.method=="GET" and path=="/mooio/protocol" then
    addOutput(peer,reply(200,publicBuild(self.build)))
  elseif req.method=="GET" and path=="/mooio/status" then
    addOutput(peer,reply(200,assert(Json.encode({project="Moo-IO",mode=self.mode,build=self.build.buildId,bots=self.botCount}))))
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
    if #peer.input>34816 then self:drop(peer);return end
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
        if not msg then
          local ac=peer.player and peer.player.anticheat
          if ac then
            assert(type(ac.onTransportError)=="function",
              "original anticheat.onTransportError required")
            ac:onTransportError(reason)
          end
          self:drop(peer)
          return
        end
        local ok,e=pcall(self.onPacket,peer,msg.name,msg.args)
        if not ok then self:drop(peer);error("Lua onPacket: "..tostring(e)) end
      end
    end
  end
  if err and err~="timeout" then self:drop(peer) end
end
function Host:update()
  if not self.listener then return end
  if self.controller and self.controller:update() then
    self.shutdownRequested=true
    return
  end
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
