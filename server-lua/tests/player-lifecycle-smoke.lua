-- SPDX-License-Identifier: AGPL-3.0-only
-- Cross-module smoke for the NEW constructor hookups, reusing original
-- Spawn.spawn, Snapshot.playerData and 23 original group IDs.
local Player=require("server-lua.world.player_constructor")
local Items=require("server-lua.world.item_groups")
local World=require("server-lua.world.objects")
local Config=require("src.game.config")
local Room=require("server-lua.world.room")
local Pack=require("src.protocol.msgpack")
local t=11200
local world=World.new({config=Config,random=function()return 0.52 end})
local options={
 hats={},accessories={},config=Config,world=world,items=Items,
 nowMs=function()return t end
}
local p=Player.new("test-session",7,options)
assert(not p.alive and not p.spawned and p.watchStats==-1)
p:resetResources(false)
for _,name in ipairs(Config.resourceTypes) do assert(p[name]==0) end
p:spawn(true)
assert(p.alive and p.active and p.spawned)
assert(p.spawnedAt==11200 and p.health==p.maxHealth)
assert(p.weaponIndex==0 and p.buildIndex==-1)
assert(#p.items==4 and p.items[2]==3)
for _,name in ipairs(Config.resourceTypes) do assert(p[name]==100) end
assert(p.x>=0 and p.y>=0 and p.x<=Config.mapScale and p.y<=Config.mapScale)
p.buildIndex=3
assert(p:addItem(4))
assert(p.items[2]==4 and p.buildIndex==4)
assert(p:addItem(5))
assert(p.items[2]==5 and p.buildIndex==5)
assert(p:addItem(11))
assert(p.items[4]==11)
assert(p:addItem(15))
assert(#p.items==5 and p.items[5]==15)
assert(not p:addItem(99))
local data=p:getData(p)
assert(#data==17 and data[1]=="test-session" and data[2]==7)
assert(data[13]==Pack.null and data[14]==-1)
local clone=Player.new("other",8,options)
clone:setData(data)
assert(clone.id==p.id and clone.sid==p.sid and clone.name==p.name)
assert(clone.x==data[4] and clone.y==data[5])
assert(clone.clan==nil and clone.aura==false and clone.bossMode==false)
-- Construction is NOT complete yet; fail safely instead of accepting a
-- half-functional player in a production Room/WebSocket session.
local room=Room.new({
 nowMs=t,world=world,items={list=Items.list,
 weapons={[0]={id=0,gather=1,range=65,speed=300,dmg=25}},
 projectiles={[0]={range=1000,speed=1.6,dmg=25,scale=103,layer=0}}},
 services={ensureAnimals=function()end}
})
assert(not pcall(function()room:bindPlayer(p)end),
 "unfinished Player must not be bound as a playable client")
assert(#room.players==0,"no incomplete Player may enter the room")
print("PASS Player.new -> resetResources -> spawn -> addItem -> getData/setData")
print("PASS Room still rejects incomplete Player methods")
