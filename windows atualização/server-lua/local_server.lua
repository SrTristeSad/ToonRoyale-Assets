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
local Chat=require("server-lua.world.local_chat")
local Build=require("server-lua.protocol.build")
local Mods=require("server-lua.world.room_mods")
local Maps=require("server-lua.world.map_profiles")
local Spaces=require("server-lua.world.map_spaces")
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
local function addWorld(key,capacity,botCount,accounts,moderation,clock,log,profile,houseStorePath)
 local players,ais={},{}
 local rules=profile or {config=Config,types=require("server-lua.world.animal_types")}
 local gameConfig=rules.config
 local map=rules.map
 local random=map and map.generation.seed
  and Maps.random(map.generation.seed) or math.random
 local world=World.new({config=gameConfig,random=random})
 world:loadMap(map)
 local room
 local function broadcast(name,...)
  for _,player in ipairs(players) do player:send(name,...) end
 end
 local crabKillers={}
 local services={
  ensureAnimals=function()return room.animal_manager:ensureAnimals()end,
  log=log
 }
 room=Room.new({key=key,config=gameConfig,nowMs=clock(),wallTimeMs=clock,
  players=players,ais=ais,world=world,crabKillers=crabKillers,
  services=services,accounts=accounts:callbacks(),
  moderation=moderation:callbacks(),broadcast=broadcast})
 local animals=Animals.new({
  world=world,players=players,ais=ais,config=gameConfig,types=rules.types,random=math.random,
  score=function(player,amount) return room:score(player,amount)end,
  send=function(id,name,...)return room:sendId(id,name,...)end,
  disable=function(obj)return world:disableObject(obj)end,
  hit=function(obj,direction)return room:hitObject(obj,direction)end,
  crabKillers=crabKillers,broadcast=broadcast,key=key
 })
 room.animal_manager=animals
 room.mapId=map and map.id or "classico"
 room.mapSpaces=Spaces.new(map,gameConfig.mapScale)
 room.customMap=map
 room.activeMods=rules.mods or {}
 room.selectedDifficulty=rules.difficulty or "normal"
 room.projectile_manager.mapSpaces=room.mapSpaces
 animals.mapSpaces=room.mapSpaces
 room.mobAnimations=rules.animations or {}
 animals.mapAnimations=room.mobAnimations
 if map and key=="LC" then
  for _,zone in ipairs(map.spaces or {}) do
   for _,mob in ipairs(zone.mobs or {}) do
    assert(rules.types[mob.kind],
      "map requires unknown mob "..mob.kind..
      " (select the species mod before starting this room)")
   end
  end
 end
 if map and key=="LC" then
  room.houseStorePath=houseStorePath
  require("server-lua.world.house_build").load(room)
 end
 if map and key=="LC" then
   -- A normal game uses the original 51-animal total, not 51 outdoors
   -- plus six additional animals below ground. Count authored mobs
   -- toward each species' configured budget before surface spawning.
   local byType={}
   for _,zone in ipairs(map.spaces or {}) do
    for _,mob in ipairs(zone.mobs or {}) do
     byType[mob.kind]=(byType[mob.kind] or 0)+1
    end
   end
   for _,entry in ipairs(room.config.server.animalSpawnPlan) do
    if byType[entry.index] then
     entry.desired=math.max(0,entry.desired-byType[entry.index])
    end
   end
   for _,zone in ipairs(map.spaces or {}) do
     for i,mob in ipairs(zone.mobs or {}) do
       animals:spawn(mob.x,mob.y,0,mob.kind,{
         spaceId=zone.id,startX=mob.x,startY=mob.y,
         mapSpawnId=zone.id..":"..i
       })
     end
   end
 end
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
   if peer.send and not peer.closed then
    peer:send("B",{reason})
    peer.state="closing"
   elseif peer.host then peer.host:drop(peer)end
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
 -- Validate difficulty and every enabled mod before creating accounts,
 -- directories, AI actors or the generated world.
 local map
 if opts.mapId and opts.mapId~="" and opts.mapId~="classico" then
  map=Maps.load(opts.mapDir or "server-lua/maps",opts.mapId)
 end
 local profile=Mods.build(opts.difficulty or "normal",
   Mods.ids(opts.modIds or ""),opts.modDir or "server-lua/mods",map)
 profile.map=map
 local now=opts.nowMs or stamp
 local entropy=Random.bytes(4)
 local a,b,c,d=entropy:byte(1,4)
 math.randomseed(a+b*256+c*65536+d*16777216)
 local accounts=Accounts.open(opts.dataDir.."/accounts.json",{nowMs=now})
 local moderation=Moderation.open(opts.dataDir,{nowMs=now})
 moderation:migrateIds(accounts.migratedIds)
 local log=opts.log or function()end
 local rooms={}
 rooms.LC=addWorld("LC",Config.maxPlayers,opts.botCount or 0,
  accounts,moderation,now,log,profile,profile.map and
   (opts.dataDir.."/houses-"..profile.map.id..".json") or nil)
 rooms.MB=addWorld("MB",80,0,accounts,moderation,now,log)
 local chat=Chat.new(opts.dataDir.."/chat.json",{nowMs=now,store=accounts})
 rooms.LC.room.chat=chat
 rooms.MB.room.chat=chat
 accounts.onClanEvent=function(name,message)return chat:clanSystem(name,message)end
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
 local game={}
 game.playerBySession=function(id)
  for _,key in ipairs({"LC","MB"}) do
   for _,player in ipairs(rooms[key].room.players) do
    if player.id==id then return player end
   end
  end
 end
 game.sessionOf=function(player)
  for _,key in ipairs({"LC","MB"}) do
   for _,p in ipairs(rooms[key].room.players) do
    if p==player then
     return {at=p.connectedAt,server=key,ipHash=p.ipHash,reports=p.reports}
    end
   end
  end
 end
 game.sessionFor=function(id)
  for _,key in ipairs({"LC","MB"}) do
   for _,p in ipairs(rooms[key].room.players) do
    if p.account and p.account.id==id then return game.sessionOf(p) end
   end
  end
 end
 game.kickAccount=function(id,reason)
  local n=0
  for _,key in ipairs({"LC","MB"}) do
   for _,p in ipairs(rooms[key].room.players) do
    if p.account and p.account.id==id and p.kick then p.kick(reason);n=n+1 end
   end
  end
  return n
 end
 game.setShadow=function(id,on)
  for _,key in ipairs({"LC","MB"}) do
   for _,p in ipairs(rooms[key].room.players) do
    if p.account and p.account.id==id then p.shadowed=on end
   end
  end
 end
 local host
 host=Host.new({bind=assert(opts.bind,"LAN/VPN binding required"),
  port=opts.port or 8080,mode=opts.mode or "lan",
  roomCode=assert(opts.roomCode,"MOO_IO_ROOM_CODE required"),
  rooms={LC={capacity=Config.maxPlayers,membersOnly=false},
    MB={capacity=80,membersOnly=true}},
  maxPeers=120,guiHost=opts.guiHost==true,botCount=opts.botCount or 0,
  build=opts.build or Build.open(
    opts.protocolBuildFile or (opts.dataDir.."/protocol-build.json"),
    {nowMs=now,rotate=opts.rotateBuild==true}),
  accounts=accounts,moderation=moderation,servers=serverList,game=game,chat=chat,
  nowMs=now,
  onConnect=function(peer,ticket,key)
   peer.host=host
   local player=assert(rooms[key],"unknown Node room").transport:connected(peer,ticket)
   if player.account then
    player.account.lastSeen={ip=player.ip,did=ticket.did,at=now(),server=key}
    accounts:save()
   end
   return player
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
 local now=self.clock()
 if self.host.shutdownRequested and not self.shutdownAt then
  self.shutdownAt=now+1500
  self.kickAt=now+1100
  for _,key in ipairs({"LC","MB"}) do self.rooms[key].room:announceShutdown(3) end
 end
 if self.kickAt and now>=self.kickAt then
  self.kickAt=nil
  for _,key in ipairs({"LC","MB"}) do self.rooms[key].room:closeAll() end
 end
 if self.shutdownAt and now>=self.shutdownAt then
  self:close()
  return false
 end
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
