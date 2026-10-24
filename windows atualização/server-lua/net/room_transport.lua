-- SPDX-License-Identifier: AGPL-3.0-only
-- Bridges the existing host.lua callbacks to a REAL, fully constructed
-- Room player. No provisional player class or account bypass is provided.
-- Room.bindPlayer is authoritative; the protocol remains Host/Session.
local Pack=require("src.protocol.msgpack")
local Transport={}
Transport.__index=Transport
local function encodeArgs(...)
 local out={}
 for i=1,select("#",...) do
   local value=select(i,...)
   out[i]=(value==nil) and Pack.null or value
 end
 return out
end
function Transport.new(options)
 options=options or {}
 local room=assert(options.room,"real Lua Room required")
 assert(type(room.bindPlayer)=="function" and type(room.handleInput)=="function",
   "Room.bindPlayer and Room.handleInput required")
 assert(type(options.createPlayer)=="function",
   "real authoritative Player constructor callback required")
 assert(type(options.onJoined)=="function",
   "original account/tribe/animal welcome packet handler required")
 assert(type(options.onDisconnect)=="function",
   "original cleanup of account, tribe and owned structures required")
 return setmetatable({
   room=room,
   createPlayer=options.createPlayer,
   onJoined=options.onJoined,
   onDisconnect=options.onDisconnect,
   onRemoved=options.onRemoved,
   peers=setmetatable({},{__mode="k"})
 },Transport)
end
function Transport:connected(peer,ticket)
 assert(peer and type(peer.send)=="function" and not self.peers[peer],
   "unique authenticated WebSocket peer required")
 assert(ticket and type(ticket.did)=="string" and #ticket.did>0,
   "one-use guest ticket required")
 local player=assert(self.createPlayer(peer,ticket,self.room),
   "real Player constructor must return a fully initialized Player")
 assert(type(player)=="table" and type(player.id)=="string"
   and type(player.sid)=="number",
   "original Player session id and SID required")
 assert(type(player.send)=="function","Player must supply its real send method")
 -- A Lua player must always transmit its array payload through the
 -- encrypted/session-keyed peer:send, never through a second raw WebSocket.
 player.send=function(_,name,...)
   return peer:send(name,encodeArgs(...))
 end
 self.room:bindPlayer(player)
 self.peers[peer]=player
 peer.player=player
 self.onJoined(player,peer,ticket,self.room)
 return player
end
function Transport:packet(peer,name,args)
 local player=assert(self.peers[peer],"unbound or closed connection packet")
 assert(not peer.closed,"closed WebSocket cannot issue gameplay commands")
 return self.room:handleInput(player,name,args)
end
function Transport:closed(peer)
 local player=self.peers[peer]
 if not player then return false end
 self.peers[peer]=nil
 peer.player=nil
 -- Run complete original cleanup before removing from simulation; callbacks
 -- handle clan state, persisted life, buildings and presence externally.
 self.onDisconnect(player,peer,self.room)
 for i=#self.room.players,1,-1 do
   if self.room.players[i]==player then
     table.remove(self.room.players,i)
     break
   end
 end
 -- Original Game.removePlayer sends presence/count/E after the splice.
 if self.onRemoved then self.onRemoved(player,peer,self.room) end
 return true
end
function Transport:callbacks()
 return {
   onConnect=function(peer,ticket)return self:connected(peer,ticket)end,
   onPacket=function(peer,name,args)return self:packet(peer,name,args)end,
   onClose=function(peer)return self:closed(peer)end
 }
end
return Transport
