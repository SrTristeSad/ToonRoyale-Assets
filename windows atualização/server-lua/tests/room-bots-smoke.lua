-- SPDX-License-Identifier: AGPL-3.0-only
-- Native integration of original LOCAL RoomBots -> Registry -> real Player.
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local messages={}
local room=Room.new({
 nowMs=10000,services={ensureAnimals=function()end},
 broadcast=function(name,...)
  messages[#messages+1]={name=name,args={...}}
 end
})
local countEvents={}
local registry=Registry.new(room,{
 randomString=function(n)assert(n==16);return string.rep("h",n)end,
 anticheatFactory=function()
  error("internal bots MUST NOT request fake authenticated socket")
 end,
 count=function(key,n) countEvents[#countEvents+1]={key,n}end,
 botCount=2
})
assert(#room.players==2 and #room.bots.agents==2)
assert(room.bots.count==2 and room:playerCount()==0,
 "bots take real player SIDs but no client-facing human slots")
assert(room.bots.agents[1].p==room.players[1])
assert(room.bots.agents[2].p==room.players[2])
assert(room.players[1].id=="mooio-bot-0" and room.players[2].id=="mooio-bot-1")
assert(room.players[1].sid==0 and room.players[2].sid==1)
assert(room.players[1].name=="Lince" and room.players[2].name=="Ari")
assert(room.players[1].alive and room.players[2].alive)
assert(room.players[1].isBot and room.players[1].anticheat==nil)
assert(registry.available[0]==false and registry.available[1]==false)
assert(countEvents[1][2]==1 and countEvents[2][2]==2)
room.bots:tick(270)
assert(room.bots.agents[1].at==270 and room.bots.agents[2].at==270)
assert(room.players[1].moveDir~=nil and room.players[2].moveDir~=nil,
 "bots must produce movement using the original decision logic")
-- Joining is optional, not a mandatory property of all AI participants.
local one,two=room.bots.agents[1],room.bots.agents[2]
one.p.x=1000;one.p.y=1000;two.p.x=1070;two.p.y=1050
one.prefersGroup=true;two.prefersGroup=true
local random=math.random
math.random=function()return 0.10 end
assert(room.bots:socialize(one),"a bot should sometimes create a genuine tribe")
math.random=random
assert(one.p.team and one.p.team==two.p.team,
 "voluntary teammates must share the game's real tribe membership")
assert(room.tribes.tribes[one.p.team].owner==one.p)
assert(one.p.name=="Lince" and two.p.name=="Ari",
 "bot display names should look like regular players")
print("PASS original local bots: real Player spawn, SID, slots, movement")
