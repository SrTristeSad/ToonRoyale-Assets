-- SPDX-License-Identifier: AGPL-3.0-only
-- Compose the actual LOCAL Node Game subsystems, not V2 workers.
local Socket=require("socket")
local Config=require("src.game.config")
local Random=require("src.net.secure_random")
local Json=require("server-lua.vendor.dkjson")
local World=require("server-lua.world.objects")
local Animals=require("server-lua.world.animals")
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local Transport=require("server-lua.net.room_transport")
local Host=require("server-lua.net.host")
local Accounts=require("server-lua.world.account_store")
local Moderation=require("server-lua.anticheat.moderation_store")
local Local={}
Local.__index=Local
local function stamp()return math.floor(Socket.gettime()*1000)end
local function newSessionId()
 local bytes=Random.bytes(16)
 local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
 local out={}
 for i=1,16 do
  local n=bytes:byte(i)%#chars+1
  out[i]=chars:sub(n,n)
 end
 return table.concat(out)
end
local function addWorld(key,capacity,botCount,accounts,moderation,clock,log)
 local players,ais={},{}
 local world=World.new({config=Config,random=math.random})
 world:generate()
 local room
 local function broadcast(name,...)
  for _,player in ipairs(players) do player:send(name,...) end
 end
 local crabKillers={}
 local services={
  ensureAnimals=function()return room.animal_manager:ensureAnimals()end,
  log=log
 }
 room=Room.new({key=key,config=Config,nowMs=clock(),wallTimeMs=clock,
  players=players,ais=ais,world=world,crabKillers=crabKillers,
  services=services,accounts=accounts:callbacks(),
  moderation=moderation:callbacks(),broadcast=broadcast})
 local animals=Animals.new({
  world=world,players=players,ais=ais,config=Config,random=math.random,
  score=function(player,amount) return room:score(player,amount)end,
  send=function(id,name,...)return room:sendId(id,name,...)end,
  disable=function(obj)return world:disableObject(obj)end,
  hit=function(obj,direction)return room:hitObject(obj,direction)end,
  crabKillers=crabKillers,broadcast=broadcast,key=key
 })
 room.animal_manager=animals
 animals:ensureAnimals()
 local registry=Registry.new(room,{
  botCount=botCount,
  randomString=function(length)
   assert(length==16,"original session ID length")
   return newSessionId()
  end,
  accountForTicket=function(ticket)
   return ticket.account~=Json.null and ticket.account or nil
  end,
  nowMs=clock,
  moderation=moderation,
  kickPeer=function(peer,reason)
   if peer.send then peer:send("B",{reason})end
   if peer.host then peer.host:drop(peer)end
  end,
  closePeer=function(peer)
   if peer.host then peer.host:drop(peer)end
  end,
  log=function(player,msg)
   if log then log("["..key.."] "..player.name..": "..msg)end
  end
 })
 return {room=room,registry=registry,
  transport=Transport.new(registry:transportOptions()),
  capacity=capacity,membersOnly=key=="MB"}
end
function Local.new(opts)
 opts=opts or {}
 assert(type(opts.dataDir)=="string" and opts.dataDir~="",
  "separate LOCAL Lua data directory required")
 local now=opts.nowMs or stamp
 local accounts=Accounts.open(opts.dataDir.."/accounts.json",{nowMs=now})
 local moderation=Moderation.open(opts.dataDir,{nowMs=now})
 moderation:migrateIds(accounts.migratedIds)
 local log=opts.log or function()end
 local rooms={}
 rooms.LC=addWorld("LC",Config.maxPlayers,opts.botCount or 0,
  accounts,moderation,now,log)
 rooms.MB=addWorld("MB",80,0,accounts,moderation,now,log)
 local function serverList()
  local result={}
  for _,key in ipairs({"LC","MB"}) do
   local def=rooms[key]
   result[#result+1]={region="local",regionName="Local",
    name=key,key=key,playerCount=def.room:playerCount(),
    playerCapacity=def.capacity,auth=def.membersOnly}
  end
  return result
 end
 local host
 host=Host.new({bind=assert(opts.bind,"LAN/VPN binding required"),
  port=opts.port or 8080,mode=opts.mode or "lan",
  roomCode=assert(opts.roomCode,"MOO_IO_ROOM_CODE required"),
  rooms={LC={capacity=Config.maxPlayers,membersOnly=false},
    MB={capacity=80,membersOnly=true}},
  maxPeers=120,guiHost=opts.guiHost==true,
  accounts=accounts,moderation=moderation,servers=serverList,
  nowMs=now,
  onConnect=function(peer,ticket,key)
   peer.host=host
   return assert(rooms[key],"unknown Node room").transport:connected(peer,ticket)
  end,
  onPacket=function(peer,name,args,key)
   return assert(rooms[key],"unknown Node room").transport:packet(peer,name,args)
  end,
  onClose=function(peer,key)
   return assert(rooms[key],"unknown Node room").transport:closed(peer)
  end})
 return setmetatable({host=host,rooms=rooms,accounts=accounts,
  moderation=moderation,clock=now,nextTick=now(),step=1000/Config.serverUpdateRate},
  Local)
end
function Local:start()return self.host:start()end
function Local:update()
 self.host:update()
 if self.host.shutdownRequested then self:close();return false end
 local now=self.clock()
 local ticks=0
 while now-self.nextTick>=self.step and ticks<5 do
  self.nextTick=self.nextTick+self.step
  for _,key in ipairs({"LC","MB"}) do self.rooms[key].room:tick(self.nextTick)end
  ticks=ticks+1
 end
 return true
end
function Local:close()return self.host:close()end
return Local
