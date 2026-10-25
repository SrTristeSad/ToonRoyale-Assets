-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.crownOf from server/src/moomoo/server.js: 60s cache, anonymity.
local Room=require("server-lua.world.room")
local now=100000
local calls=0
local ranks={A=1,B=2}
local room={
 accounts={weeklyCrowns=function()
  calls=calls+1
  local copy={}
  for id,value in pairs(ranks) do copy[id]=value end
  return copy
 end},
 wallTimeMs=function()return now end,
 crowns={},crownsAt=0,
 leaderboardTimer=750,
 recordLife=function(_,p,died)
  assert(p.sid==10 and died==true)
  calls=calls+10
 end
}
local a={account={id="A"},anon=false}
local b={account={id="B"},anon=false}
local guest={account=nil,anon=false}
local hidden={account={id="A"},anon=true}
assert(Room.crownOf(room,guest)==0)
assert(Room.crownOf(room,hidden)==0)
assert(calls==0)
assert(Room.crownOf(room,a)==1 and Room.crownOf(room,b)==2)
assert(calls==1)
ranks.A=3
now=160000
assert(Room.crownOf(room,a)==1 and calls==1,
 "Node refreshes crowns only when age > 60000ms")
now=160001
assert(Room.crownOf(room,a)==3 and calls==2)
Room.onPlayerDeath(room,{sid=10})
assert(room.leaderboardTimer==0 and calls==12)
print("PASS Game.crownOf cache 60s, anonimato, convidados e onPlayerDeath")
