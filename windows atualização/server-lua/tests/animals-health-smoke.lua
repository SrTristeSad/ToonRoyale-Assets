-- SPDX-License-Identifier: AGPL-3.0-only
-- Real native Manager -> AI.changeHealth -> Rewards -> Room.tick.
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local Animals=require("server-lua.world.animals")
local Room=require("server-lua.world.room")
local Crypto=require("src.protocol.original_crypto")
local cfg=setmetatable({server=setmetatable({
 animalSpawnPlan={{index=0,desired=1}}
},{__index=Config.server})},{__index=Config})
local random=Crypto.mulberry32(213)
local players,ais={},{}
local world=World.new({config=cfg,random=random})
local messages,scores={},{ }
local manager=Animals.new({
 config=cfg,world=world,random=random,players=players,ais=ais,
 send=function(id,name,...)messages[#messages+1]={id,name,...}end,
 score=function(who,amount)
   scores[#scores+1]=amount
   who.points=who.points+amount
 end
})
assert(type(manager.health)=="function","native health must be available when score/send are real")
local items={weapons={[0]={id=0,gather=1,range=65,dmg=25,speed=300}},
 projectiles={[0]={dmg=25,scale=103,speed=1.6,range=1000,layer=0}}}
local room=Room.new({
 nowMs=10000,config=cfg,world=world,players=players,ais=ais,
 animalManager=manager,services={},items=items
})
room:tick(10000)
assert(#ais==1 and ais[1].index==0,"spawned the original cow type")
local cow=ais[1]
local hunter={
 id="hunter",isPlayer=true,alive=true,points=0,food=0,
 tail={id=8},lifeStats={animalDamage=0,animals=0,bosses=0,animalKills={}},
 canSee=function()return true end,
 addResource=function(self,typ,value)
   assert(typ==1,"food is resourceType 1")
   self.food=self.food+value
 end
}
assert(cow:changeHealth(-25,hunter)==true)
assert(hunter.lifeStats.animalDamage==25)
assert(cow:changeHealth(-600,hunter,hunter)==true)
assert(hunter.food==75,"Cow Cape must yield 1.5x food")
assert(hunter.points==225,"Cow Cape must yield 1.5x cow kill score")
assert(hunter.lifeStats.animals==1 and hunter.lifeStats.animalKills.cow==1,
 "Game.onAnimalKilled original statistics required")
assert(#scores==1 and scores[1]==225)
assert(#messages==2 and messages[1][2]=="8" and messages[2][2]=="8")
assert(cow.health==500 and cow.active,"ordinary cow respawns instead of disappearing")
local admin=manager:spawn(700,800,0,0,{despawnOnDeath=true})
assert(admin:changeHealth(-1000,hunter)==true)
assert(not admin.active and not admin.alive,"admin animal must disappear")
assert(hunter.points==450,"admin kill awards score but never drops")
assert(hunter.food==75,"admin spawned animals must not drop food")
assert(hunter.lifeStats.animals==2 and hunter.lifeStats.animalKills.cow==2)
room:tick(10100)
assert(room.animal_manager==manager,"same native animal manager")
assert(room.lastTick==10100,"native Room tick succeeded")
print("PASS native cow kill: original food, Cow Cape, score and animalKills")
print("PASS admin animal despawn: score without resource drops")
