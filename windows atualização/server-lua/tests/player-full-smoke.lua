-- SPDX-License-Identifier: AGPL-3.0-only
-- Full real Player Lua: signed spawn packets -> Game.tick -> player methods.
-- Catalog is a test fixture: actual server must inject original hats, items
-- and NAME_WORDS through Player.new.
local Room=require("server-lua.world.room")
local Player=require("server-lua.world.player")
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local events={}
local function send(name,...)
  events[#events+1]=name
end
local groups={{id=0},{id=1,limit=30},{id=2},{id=3}}
local items={
 weapons={[0]={id=0,type=0,gather=1,range=65,speed=300,dmg=25,hitSlow=0.3}},
 projectiles={[0]={id=0,dmg=25,scale=103,speed=1.6,range=1000,layer=0}},
 list={
   [0]={id=0,group=groups[1]},
   [3]={id=3,group=groups[2],scale=50,req={"wood",10},
     type=2,health=380,projDmg=true},
   [4]={id=4,group=groups[2],scale=55,req={"wood",14},
     type=2,health=500,projDmg=true},
   [6]={id=6,group=groups[3],scale=75,req={"stone",10}},
   [10]={id=10,group=groups[4],scale=45,req={"wood",50},
     pps=1}
 }
}
local world=World.new({config=Config,random=function()return 0.5 end})
local room=Room.new({
 nowMs=10000,world=world,items=items,
 services={ensureAnimals=function()end}
})
local anti={
 invalid=function(_,name,reason)error("invalid packet "..name..":"..reason)end,
 onGameStart=function()events[#events+1]="ACSTART"end,
 tick=function()end
}
local player=Player.new("test-client",0,room,{
 nameWords={"qweir","badword"},
 hats={{id=0,price=0},{id=61,price=1}},
 accessories={{id=0,price=0},{id=1,price=100}},
 anticheat=anti,
 send=send,
 icon=function(p)events[#events+1]="DEATH"end
})
assert(not player.alive and not player.spawned)
assert(player.skins[0]==1 and player.tails[0]==1)
room:bindPlayer(player)
room:handleInput(player,"M",{{name="Builder",skin=2,moofoll=true}})
assert(player.alive and player.spawned and player.name=="Builder")
assert(player.wood==100 and player.food==100 and player.stone==100)
assert(player.lifeStats.animals==0 and player.lifeStats.score==0)
assert(player.weaponIndex==0 and player.items[2]==3)
assert(player.skinColor==2)
room:tick(10000)
local found={}
for _,name in ipairs(events) do found[name]=true end
assert(found.ACSTART and found.C and found.D and found.a,
  "original game start and player snapshots required")
player:addResource(0,20)
assert(player.wood==120)
player:addResource(3,250)
assert(player.points==250 and player.XP==250)
assert(player.lifeStats.gold==250 and player.lifeStats.score==250)
player.weaponXP[0]=33000
assert(player:variant().id==3,"emerald restricted to actual members")
player.isMember=true
assert(player:variant().id==4,"emerald unlock for members")
local startX=player.x
room:handleInput(player,"D",{0})
room:handleInput(player,"9",{0})
room:tick(10100)
assert(player.x>startX,"Player.update physics actually moved Player")
player.moveDir=nil
player.buildIndex=3
player:buildItem(items.list[3])
assert(player.buildIndex==-1 and player.wood==110)
assert(#world.objects==1 and world.objects[1].id==3)
assert(world.objects[1].owner==player)
assert(player.itemCounts[1]==1)
player.buildIndex=3
assert(player:addItem(4))
assert(player.items[2]==4 and player.buildIndex==4,
  "original AddItem group replacement and selected building")
local life=player.health
assert(player:changeHealth(-20))
assert(player.health==life-20 and player.hitTime==room.nowMs)
assert(player:changeHealth(5,player))
assert(player.health==life-15 and player.lifeStats.healing==5)
player:sendAnimation(1)
assert(events[#events]=="K","real animation packet")
assert(player:hasRes(items.list[4]))
player:startAnim(true,0,1)
assert(player.animTime==300)
player:animate(75)
assert(player.dirPlus<0,"original strike anim advances")
player:animate(500)
assert(player.animTime==0 and player.dirPlus==0)
player:addResource(3,1000)
assert(player.age>=2 and player.upgradePoints>=1,
  "Game.scoreCallback must award age XP")
assert(player.room==room and player.isPlayer,"same room/identity throughout")
print("PASS full Player constructor -> packet M -> spawn -> Game.tick movement")
print("PASS resources/score/XP, variants, buildings, health and animation")
