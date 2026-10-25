-- SPDX-License-Identifier: AGPL-3.0-only
-- Composition for the LOCAL Windows Node mode (MOO_IO_V2_PRIVATE_ROOM absent).
-- Maps directly to index.js: LC 40 + MB 80, Game, AccountStore,
-- ModerationStore, authenticated WebSocket and the original game loop.
-- Does NOT switch the shipped Windows launcher; parity must be proven first.
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
local Moderation=require("server-lua.anticheat.store")
local Build=require("server-lua.protocol.build")
local Local={}
Local.__index=Local

local ID_ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local function randomString(n)
 local bytes=Random.bytes(n)
 local chars={}
 for i=1,n do
  local index=bytes:byte(i)%#ID_ALPHABET+1
  chars[i]=ID_ALPHABET:sub(index,index)
 end
 return table.concat(chars)
end
function Local.new(opts)
 opts=opts or {}
 assert(opts.v2~=true,"V2 private room cannot be used for LOCAL server")
 local dir=assert(opts.dataDir,"LOCAL data directory required")
 local clock=opts.nowMs or function()return math.floor(Socket.gettime()*1000)end
 local accounts=opts.accounts or Accounts.open(dir.."/accounts.json",{nowMs=clock})
 local moderation=opts.moderation or Moderation.open(dir,{nowMs=clock})
 if moderation.migrateIds and accounts.migratedIds then
  moderation:migrateIds(accounts.migratedIds)
 end
 local logger=opts.log or function(message)io.stderr:write(tostring(message).."\n")end
 local definitions={
  LC={capacity=Config.maxPlayers,membersOnly=false},
  MB={capacity=80,membersOnly=true}
 }
 local rooms,registries,transports={},{},{}
 local facades={}
 for _,key in ipairs({"LC","MB"}) do
  local players,ais={},{}
  local world=World.new({config=Config})
  world:generate()
  local killer={}
  local room
  local function send(id,name,...)
   return assert(room,"room must exist before AI send"):sendId(id,name,...)
  end
  local function broadcast(name,...)
   assert(room,"real Game room required")
   for _,player in ipairs(room.players) do player:send(name,...) end
  end
  local animals=Animals.new({
   world=world,players=players,ais=ais,config=Config,
   random=math.random,crabKillers=killer,
   broadcast=broadcast,key=key,
   event=opts.event,
   send=send,
   disable=function(object)return world:disableObject(object)end,
   hit=function(object,direction)return room:hitObject(object,direction)end,
   score=function(player,amount)return room:score(player,amount)end
  })
  room=Room.new({
   key=key,nowMs=clock(),wallTimeMs=clock,
   world=world,players=players,ais=ais,
   crabKillers=killer,animalManager=animals,
   services={log=logger},
   accounts=accounts:callbacks(),moderation=moderation,
   broadcast=broadcast,chat=opts.chat,
   hooks=opts.hooks
  })
  rooms[key]=room
  animals:ensureAnimals()
 end
 local self=setmetatable({
  rooms=rooms,registries=registries,transports=transports,
  accounts=accounts,moderation=moderation,
  clock=clock,definitions=definitions,log=logger,host=nil
 },Local)
 for _,key in ipairs({"LC","MB"}) do
  local room=rooms[key]
  local registry=Registry.new(room,{
   nowMs=clock,moderation=moderation,
   randomString=randomString,
   log=function(player,msg)logger("["..key.."] "..tostring(msg))end,
   kickPeer=function(peer,reason)
    if self.host then self.host:drop(peer) end
   end,
   closePeer=function(peer,code)
    if self.host then self.host:drop(peer) end
   end,
   accountForTicket=function(ticket)
    if ticket.account and ticket.account~=Json.null then return ticket.account end
    return nil
   end,
   botCount=key=="LC" and (opts.botCount or 0) or 0,
   count=opts.count,
   presence=opts.presence
  })
  registries[key]=registry
  transports[key]=Transport.new(registry:transportOptions())
 end
 local function servers()
  local result={}
  for _,key in ipairs({"LC","MB"}) do
   local room=rooms[key]
   local def=definitions[key]
   result[#result+1]={
    region="local",regionName="Local",name=key,key=key,
    playerCount=room:playerCount(),playerCapacity=def.capacity,
    auth=def.membersOnly
   }
  end
  return result
 end
 self.host=Host.new({
  bind=assert(opts.bind,"LAN/VPN bind address required"),
  mode=opts.mode or "lan",port=opts.port or 8080,
  roomCode=assert(opts.roomCode,"room code required"),
  rooms=definitions,capacity=Config.maxPlayers,
  botCount=opts.botCount or 0,
  build=opts.build or Build.open(
   opts.protocolBuildFile or (dir.."/protocol-build.json"),
   {nowMs=clock,rotate=opts.rotateBuild==true}),
  guiHost=opts.guiHost==true,
  accounts=accounts,moderation=moderation,servers=servers,
  chat=opts.chat,nowMs=clock,
  onConnect=function(peer,ticket,key)
   return assert(transports[key],"unknown original game room"):connected(peer,ticket)
  end,
  onPacket=function(peer,name,args,key)
   return assert(transports[key],"unknown original game room"):packet(peer,name,args)
  end,
  onClose=function(peer,key)
   if transports[key] then return transports[key]:closed(peer) end
  end
 })
 return self
end
function Local:start() return self.host:start() end
function Local:update()
 self.host:update()
 if self.host.shutdownRequested then return false end
 local now=self.clock()
 for _,key in ipairs({"LC","MB"}) do self.rooms[key]:tick(now) end
 return true
end
function Local:close()
 return self.host:close()
end
return Local
