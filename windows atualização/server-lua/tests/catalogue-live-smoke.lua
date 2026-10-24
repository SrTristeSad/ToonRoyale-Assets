-- SPDX-License-Identifier: AGPL-3.0-only
-- Host session -> Registry -> full native catalog -> Player.spawn -> Room.tick.
-- Fixture provides test-only account/anticheat dependencies explicitly.
-- Production cannot skip real name moderation or account and clan services.
local Catalogue=require("server-lua.world.catalogue")
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local Transport=require("server-lua.net.room_transport")
local room=Room.new({
  nowMs=10000,
  services={ensureAnimals=function()end}
})
assert(room.items==Catalogue,"Game must use original complete Lua catalogue by default")
assert(room.projectile_manager.items==Catalogue,
 "ProjectileManager must reference the same authoritative weapon/projectile entries")
local seq=0
local callbacks={
 randomString=function(n)
   assert(n==16);seq=seq+1
   return string.format("%016d",seq)
 end,
 -- Explicit fixture ONLY. Do not replace production original NAME_WORDS.
 nameWords={"qweir","discord"},
 anticheatFactory=function()
   return {allow=function()return true end,
     invalid=function()error("invalid packet")end,
     onGameStart=function()end,tick=function()end}
 end,
 onDeath=function()end,
 clanList=function()return {}end,
 recordLife=function()end,
 leaveTribe=function()end,
 forget=function()end,
 removeItems=function()end
}
local registry=Registry.new(room,callbacks)
assert(registry.options.hats==Catalogue.hats,
 "authoritative registry should use complete original hats by default")
assert(registry.options.accessories==Catalogue.accessories,
 "authoritative registry should use complete original accessories by default")
local bridge=Transport.new(registry:transportOptions())
local peer={ip="127.0.0.1",closed=false,sent={}}
peer.send=function(self,name,args)
 self.sent[#self.sent+1]={name=name,args=args}
 return true
end
local player=bridge:connected(peer,{did="guest"})
assert(player.skins[51]==1 and player.skins[50]==1,
 "free starter hats must be available from the real store")
assert(player.skins[45]==nil,
 "original Shame hat is marked dontSell and must not be free")
assert(player.tails[21]==nil,"paid wings must not be owned on join")
assert(peer.sent[1].name=="A","original welcome packet from registry")
bridge:packet(peer,"M",{{name="Original",skin=0}})
assert(player.alive and player.spawned,"player must be spawned by original input handler")
assert(player.name=="Original")
assert(player.items[1]==0 and player.items[2]==3 and player.items[4]==10)
assert(room.items.weapons[0].name=="tool hammer")
assert(room.items.list[3].name=="wood wall")
assert(room.items.projectiles[5].src=="bullet_1")
assert(player:canBuild(Catalogue.list[3])==false,
 "original resource cost must forbid free building")
player:addResource(0,30)
assert(player:canBuild(Catalogue.list[3])==true,
 "real resources enable the unchanged wall recipe")
bridge:packet(peer,"D",{1.25})
bridge:packet(peer,"9",{0.35})
assert(player.dir==1.25 and player.moveDir==0.35)
room:tick(10100)
assert(player.x==player.x and player.y==player.y,"physics must stay finite")
assert(player.alive,"ordinary input and one tick should not kill player")
local packetNames={}
for _,pack in ipairs(peer.sent) do packetNames[pack.name]=true end
assert(packetNames.A and packetNames.C and packetNames.D and packetNames.a,
 "original welcome, spawn and snapshot packets must reach peer")
assert(bridge:closed(peer))
assert(#room.players==0,"disconnect removes authoritative Player")
print("PASS complete 129 original definitions -> Registry -> Player -> Room tick")
print("PASS real welcome, spawn, inventory, building costs, snapshot and disconnect")
