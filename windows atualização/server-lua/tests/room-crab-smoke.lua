-- SPDX-License-Identifier: AGPL-3.0-only
-- Native full Crab King in the Room tick, from spawn to telegraph to Shell.
-- Player fixture supplies the real Room interface; host/account adapters are
-- not silently invoked or substituted for a production Player constructor.
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local Animals=require("server-lua.world.animals")
local Room=require("server-lua.world.room")
local Crypto=require("src.protocol.original_crypto")
local plan={{index=11,desired=1,positions={{x=-2500,y=7200}}}}
local cfg=setmetatable({server=setmetatable({animalSpawnPlan=plan},{__index=Config.server})},{__index=Config})
local rng=Crypto.mulberry32(2026)
local world=World.new({config=cfg,random=rng})
local packets={}
local events={}
local crabKillers={}
local hunter={
 id="hunter",sid=0,name="Hero",isPlayer=true,
 x=-2420,y=7200,xVel=0,yVel=0,dir=0,scale=35,health=1000,
 points=0,kills=0,age=1,alive=true,active=true,spawned=true,
 zIndex=0,team=nil,watchStats=-1,
 chatCooldown=500,tribeCooldown=600,pingCooldown=700,
 weaponIndex=0,buildIndex=-1,skinIndex=0,tailIndex=0,
 iconIndex=0,skinColor=0,isLeader=false,
 powers={power=1,speed=1,invisible=0},skins={},
 visiblePlayers={},visibleAis={},attrCache={},
 lifeStats={animals=0,bosses=0,bossKills=0,animalKills={},animalDamage=0},
 send=function(self,name,...)
   packets[#packets+1]=name
 end,
 canSee=function()return true end,
 shownName=function(self)return self.name end,
 update=function()end,
 addResource=function()end,
 changeHealth=function(self,delta)
   self.health=self.health+delta
   events[#events+1]="DAMAGE"
 end
}
local players={hunter}
local ais={}
local animals=Animals.new({
 config=cfg,world=world,random=rng,players=players,ais=ais,
 crabKillers=crabKillers,key="LC",
 send=function(id,name,...)packets[#packets+1]=name end,
 score=function(who,amount)who.points=who.points+amount end,
 broadcast=function(name,...)
   events[#events+1]="BROADCAST:"..name
 end,
 event=function(e)events[#events+1]="EVENT:"..e.kind end
})
assert(type(animals.health)=="function" and type(animals.boss)=="function")
assert(type(animals.onCrabKingKilled)=="function")
local items={
 weapons={[0]={id=0,gather=1,range=65,dmg=25,speed=300}},
 projectiles={[0]={dmg=25,scale=103,speed=1.6,range=1000,layer=0}}
}
local room=Room.new({
 nowMs=10000,config=cfg,world=world,items=items,
 players=players,ais=ais,animalManager=animals,crabKillers=crabKillers,
 services={}
})
room:tick(10000)
assert(#ais==1,"original 1 Crab King spawn")
local boss=ais[1]
assert(boss.index==11 and boss.boss and boss.scale==280)
assert(type(boss.updateDive)=="function" and type(boss.updateBoss)=="function")
boss.nextAttack="slam";boss.bossCooldown=0
room:tick(10100)
assert(boss.bossAttack and boss.bossAttack.time==1300,"forced slam queued")
local hasW=false
for _,p in ipairs(packets) do if p=="W" then hasW=true end end
assert(hasW,"original telegraph packet W must be sent")
room:tick(11500)
assert(boss.bossAttack==nil,"slam should resolve after telegraph")
assert(hunter.health<1000,"real slam applies damage")
local healthBefore=hunter.health
boss:dive()
assert(boss.submerged and boss.state==1,"boss diving")
assert(not boss:changeHealth(-100,hunter),"diving boss is invulnerable")
assert(boss.health==boss.maxHealth,"diving boss cannot lose health")
boss:setState(0,0)
assert(boss:changeHealth(-boss.maxHealth-100,hunter,hunter),"boss kill confirmed")
assert(crabKillers[hunter.sid],"qualified raider must win Crab King")
assert(hunter.skins[61]==1,"real Crab Shell hat unlock")
assert(hunter.lifeStats.bosses==1 and hunter.lifeStats.bossKills==1)
assert(hunter.lifeStats.animalKills.crab_king==1)
assert(hunter.points==4000,"original 4000 kill score")
assert(boss.spawnCounter==600000,"Crab King respawn delay")
assert(boss.health==boss.maxHealth)
assert(hunter.health==healthBefore,"boss kill should not unexpectedly harm raider")
local found={W=false,J=false,["5"]=false}
for _,name in ipairs(packets) do if found[name]~=nil then found[name]=true end end
assert(found.W and found.J and found["5"],"W/J/Shell must reach player")
assert(events[#events-1]=="BROADCAST:6" and events[#events]=="EVENT:boss",
 "original boss event follows broadcast")
print("PASS Room.tick Crab King: telegraph W, slam J, dive immunity, victory")
print("PASS qualified winner: Crab Shell, 4000 score, boss stats and broadcast")
