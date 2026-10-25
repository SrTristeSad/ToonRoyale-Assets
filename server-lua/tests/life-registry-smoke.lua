-- SPDX-License-Identifier: AGPL-3.0-only
-- The real registry disconnect path defaults to Room.recordLife, not a test stub.
local Registry=require("server-lua.world.player_registry")
local events={}
local room={
 config={maxPlayersHard=2},
 bindPlayer=function()end,sendId=function()end,
 recordLife=function(_,p,died)
  events[#events+1]="life:"..p.sid..":"..tostring(died)
 end,
 onPlayerDeath=function(_,p)
  events[#events+1]="death:"..p.sid
 end
}
local registry=Registry.new(room,{
 randomString=function()return "1234567890123456" end,
 anticheatFactory=function()return {} end,
 onDeath=function()end,
 clanList=function()return {} end,
 leaveTribe=function(p)events[#events+1]="leave:"..p.sid end,
 forget=function(p)events[#events+1]="forget:"..p.sid end,
 removeItems=function(sid)events[#events+1]="items:"..sid end
})
local player={id="test",sid=1}
registry.playersById[player.id]=player
registry:beforeRemove(player,{},room)
assert(table.concat(events,",")=="life:1:false,leave:1,forget:1,items:1")
assert(type(registry.options.recordLife)=="function")
assert(type(registry.options.onDeath)=="function")
registry.options.onDeath(player)
assert(events[#events]=="death:1","native onPlayerDeath must be bound by default")
print("PASS recordLife nativo no PlayerRegistry: ordem de desconexao")
