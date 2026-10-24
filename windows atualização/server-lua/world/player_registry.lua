-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.addPlayer / Game.removePlayer lifecycle and SID allocator from Node
-- server.js, using Player.new and real RoomTransport callbacks.
-- Account resolution, clan manager, moderation and persistence remain strict
-- externally owned services; this registry does not manufacture them.
local Player=require("server-lua.world.player")
local AntiCheat=require("server-lua.anticheat.index")
local SecureRandom=require("src.net.secure_random")
local NameWords=require("server-lua.world.name_words")
local Catalogue=require("server-lua.world.catalogue")
local Types=require("server-lua.world.animal_types")
local Sha=require("server-lua.protocol.sha256")
local Pack=require("src.protocol.msgpack")
local Registry={}
Registry.__index=Registry
local FIELDS={"id","name","src","scale","spriteMlt","nameScale",
  "health","boss","diver"}
local function binHex(raw)
 return (raw:gsub(".",function(c)return string.format("%02x",c:byte())end))
end
local function sendPeer(peer,name,...)
 local args={}
 for i=1,select("#",...) do
   local v=select(i,...)
   args[i]=v==nil and Pack.null or v
 end
 return peer:send(name,args)
end
local function kinds()
 local result={}
 for i=0,14 do
   local definition=assert(Types[i],"original type missing")
   local obj={}
   for _,key in ipairs(FIELDS) do
     if definition[key]~=nil then obj[key]=definition[key] end
   end
   result[#result+1]=obj
 end
 return result
end
function Registry.new(room,opts)
 opts=opts or {}
 opts.nameWords=opts.nameWords or NameWords
 if not opts.anticheatFactory then
  for _,name in ipairs({"nowMs","kickPeer","closePeer","log"}) do
   assert(type(opts[name])=="function",
     "native anticheat requires original service: "..name)
  end
  opts.anticheatFactory=function(id,sid,ip,account,player,peer)
   assert(peer.session and peer.session.pinned~=nil,
     "real keyed ProtocolSession required for native anticheat")
   local saltFn=opts.randomSalt or function()
    local raw=SecureRandom.bytes(4)
    assert(type(raw)=="string" and #raw==4,
      "fresh OS-backed 32-bit challenge salt required")
    local a,b,c,d=raw:byte(1,4)
    return a+b*256+c*65536+d*16777216
   end
   return AntiCheat.new({
     player=player,nowMs=opts.nowMs,session=peer.session,
     store=opts.moderation,randomSalt=saltFn,
     sendProbes=function(salt,probes)return player:send("q",salt,probes)end,
     log=function(msg)return opts.log(player,msg)end,
     kick=function(reason)return opts.kickPeer(peer,reason)end,
     close=function(code)return opts.closePeer(peer,code)end
   })
  end
 end
 if room.tribes then
   opts.clanList=opts.clanList or function()return room.tribes:list()end
   opts.leaveTribe=opts.leaveTribe or function(p)return room.tribes:leaveTribe(p)end
   opts.forget=opts.forget or function(p)return room.tribes:forget(p)end
 end
 -- Bind the native Room lifecycle by default; explicit test callbacks remain supported.
 opts.recordLife=opts.recordLife or function(player,died)
   return room:recordLife(player,died)
 end
 opts.hats=opts.hats or Catalogue.hats
 opts.accessories=opts.accessories or Catalogue.accessories
 assert(room and type(room.bindPlayer)=="function"
   and type(room.sendId)=="function","real Lua Room required")
 for _,name in ipairs({"randomString","anticheatFactory","onDeath",
   "clanList","recordLife","leaveTribe","forget","removeItems"}) do
   assert(type(opts[name])=="function",
     "original Game.addPlayer/removePlayer service required: "..name)
 end
 assert(type(opts.hats)=="table" and type(opts.accessories)=="table"
   and type(opts.nameWords)=="table" and #opts.nameWords>0,
   "original store and full NAME_WORDS required")
 assert(room.config and type(room.config.maxPlayersHard)=="number",
   "original maxPlayersHard required")
 local available={}
 for i=0,room.config.maxPlayersHard-1 do available[i]=true end
 return setmetatable({
   room=room,options=opts,available=available,
   playersById={},pending=setmetatable({},{__mode="k"}),
   animalKinds=kinds()
 },Registry)
end
local function peerIp(peer)
 if type(peer.ip)=="string" and #peer.ip>0 then return peer.ip end
 if peer.tcp and type(peer.tcp.getpeername)=="function" then
   local ip=peer.tcp:getpeername()
   if type(ip)=="string" and #ip>0 then return ip end
 end
 error("verified peer IP required for Node Player.ipHash")
end
function Registry:createPlayer(peer,ticket,room)
 assert(room==self.room,"peer attempted to enter a foreign game room")
 assert(peer and type(peer.send)=="function","authenticated host peer required")
 assert(ticket and type(ticket.did)=="string","original one-use join ticket required")
 local sid=nil
 for i=0,room.config.maxPlayersHard-1 do
   if self.available[i] then sid=i;break end
 end
 if sid==nil then return nil end
 local id=self.options.randomString(16)
 assert(type(id)=="string" and #id==16 and not self.playersById[id],
   "original randomString(16) must generate a new session ID")
 local ip=peerIp(peer)
 local account=self.options.accountForTicket and
   self.options.accountForTicket(ticket,peer) or nil
 local p=Player.new(id,sid,room,{
   hats=self.options.hats,accessories=self.options.accessories,
   nameWords=self.options.nameWords,ip=ip,did=ticket.did,account=account,
   anticheatFactory=function(player)
     return self.options.anticheatFactory(id,sid,ip,account,player,peer)
   end,
   icon=self.options.onDeath,
   send=function(name,...)return sendPeer(peer,name,...)end
 })
 p.ip=ip
 p.ipHash=binHex(Sha.digest(tostring(ip))):sub(1,12)
 p.connectedAt=room.nowMs
 p.reports=0
 p.visiblePlayers={}
 p.visibleAis={}
 p.attrCache={}
 if account then
   p.account=account;p.role=account.role
   p.isMember=true
   p.shadowed=account.verdict=="shadow"
   p.clanTag=account.clan
   if account.name then p.name=account.name end
 end
 self.available[sid]=false
 self.pending[peer]=p
 return p
end
function Registry:onJoined(player,peer,ticket,room)
 assert(room==self.room and self.pending[peer]==player,
   "session joining from unregistered peer")
 assert(room.players[#room.players]==player,
   "Room.bindPlayer must run before original welcome A")
 self.pending[peer]=nil
 self.playersById[player.id]=player
 player:send("A",{teams=self.options.clanList(),animals=self.animalKinds})
 if player.account and self.options.presence then
   self.options.presence(player.account,room.key)
 end
 if self.options.count then self.options.count(room.key,#room.players) end
end
function Registry:beforeRemove(player,peer,room)
 assert(room==self.room and self.playersById[player.id]==player,
   "cannot remove an unregistered session")
 -- Exact Node order before splice: recordLife -> leaveTribe -> forget
 -- -> removeAllItems. These services must not be skipped.
 self.options.recordLife(player,false)
 self.options.leaveTribe(player)
 self.options.forget(player)
 self.options.removeItems(player.sid,room)
end
function Registry:afterRemove(player,peer,room)
 assert(room==self.room and self.playersById[player.id]==player,
   "SID cannot be released twice")
 self.playersById[player.id]=nil
 self.available[player.sid]=true
 if player.account and self.options.presence then
   local same=false
   for _,other in ipairs(room.players) do
     if other.account==player.account then same=true;break end
   end
   if not same then self.options.presence(player.account,"") end
 end
 if self.options.count then self.options.count(room.key,#room.players) end
 room.crabKillers[player.sid]=nil
 for _,other in ipairs(room.players) do other:send("E",player.id) end
end
function Registry:transportOptions()
 return {
   room=self.room,
   createPlayer=function(...)return self:createPlayer(...)end,
   onJoined=function(...)return self:onJoined(...)end,
   onDisconnect=function(...)return self:beforeRemove(...)end,
   onRemoved=function(...)return self:afterRemove(...)end
 }
end
return Registry
