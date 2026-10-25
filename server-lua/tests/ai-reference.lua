-- SPDX-License-Identifier: AGPL-3.0-only
-- Counterpart to ai-reference.mjs; the JS test validates source AI_TYPES.
local AI=require("server-lua.world.ai")
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local Crypto=require("src.protocol.original_crypto")
local scenarios={
 {name="cow-idle",index=0,delta=100},
 {name="pig-roam",index=1,delta=350,waitCount=0,moveCount=1500,targetDir=1.3},
 {name="cow-wait",index=0,delta=800,waitCount=450},
 {name="cow-new-heading",index=0,delta=1200,waitCount=200},
 {name="cow-run",index=0,delta=120,waitCount=0,moveCount=500,runFrom=true},
 {name="bull-target",index=2,delta=300,waitCount=50,player={x=590,y=500}},
 {name="bull-charge",index=2,delta=180,waitCount=0,moveCount=800,
   chargeTarget=true,player={x=700,y=610}},
 {name="bull-no-target",index=2,delta=160,waitCount=50,player={x=2500,y=2500}},
 {name="bull-repel",index=2,delta=150,waitCount=50,
   player={x=600,y=500,skin={bullRepel=true}}},
 {name="wolf-shore",index=4,delta=350,y=7000,waitCount=0,moveCount=1500,targetDir=1.1},
 {name="wolf-locked",index=4,delta=150,lockMove=true,xVel=0.7,yVel=0.25},
 {name="wolf-bounds",index=4,delta=140,x=30,y=30,waitCount=0,moveCount=1400,targetDir=3.14},
 {name="wolf-contact",index=4,delta=100,waitCount=0,moveCount=1200,
   chargeTarget=true,player={x=565,y=500}},
 {name="wolf-hit",index=4,delta=400,hitWait=200,player={x=550,y=500}},
 {name="boar-poison",index=9,delta=500,dmgOverTime={dmg=4,time=2,doer="poison"}},
 {name="cow-spawn-delay",index=0,delta=1000,spawnCounter=2500},
 {name="cow-spawn-end",index=0,delta=1000,spawnCounter=400},
 {name="fixed-spawn",index=6,delta=1500,spawnCounter=400,x=950,y=850},
 {name="treasure-stand",index=7,delta=700,waitCount=0,moveCount=200},
 {name="boar-inactive",index=9,delta=600,active=false}
}
local types={
 [0]={src="cow_1",killScore=150,health=500,weightM=0.8,
   speed=0.00095,turnSpeed=0.001,scale=72,drop={"food",50}},
 [1]={src="pig_1",killScore=200,health=800,weightM=0.6,
   speed=0.00085,turnSpeed=0.001,scale=72,drop={"food",80}},
 [2]={name="Bull",src="bull_2",hostile=true,dmg=20,killScore=1000,
   health=1800,weightM=0.5,speed=0.00094,turnSpeed=0.00074,
   scale=78,viewRange=800,chargePlayer=true,drop={"food",100}},
 [4]={name="Wolf",src="wolf_1",hostile=true,dmg=8,killScore=500,
   health=300,weightM=0.45,speed=0.001,turnSpeed=0.002,
   scale=84,viewRange=800,chargePlayer=true,drop={"food",200}},
 [6]={name="MOOSTAFA",nameScale=50,src="enemy",hostile=true,
   dontRun=true,fixedSpawn=true,spawnDelay=60000,noTrap=true,
   colDmg=100,dmg=40,killScore=8000,health=18000,
   weightM=0.4,speed=0.0007,turnSpeed=0.01,
   scale=80,spriteMlt=1.8,leapForce=0.9,viewRange=1000,
   hitRange=210,hitDelay=1000,chargePlayer=true,drop={"food",100}},
 [7]={name="Treasure",hostile=true,nameScale=35,src="crate_1",
   fixedSpawn=true,spawnDelay=120000,colDmg=200,
   killScore=5000,health=20000,weightM=0.1,speed=0,
   turnSpeed=0,scale=70,spriteMlt=1},
 [9]={name="Boar",src="boar_1",hostile=true,dmg=14,
   killScore=800,health=900,weightM=0.55,speed=0.00105,
   turnSpeed=0.0012,scale=76,viewRange=700,chargePlayer=true,
   drop={"food",150}}
}
local function fmt(v)return string.format("%.6f",v or 0) end
local function txt(v)return v==nil and "~" or tostring(v)end
for _,tc in ipairs(scenarios) do
 local events={}
 local rng=Crypto.mulberry32(400+tc.index)
 local calls=0
 local function rand()calls=calls+1;return rng()end
 local actor=nil
 if tc.player then
   actor={
     id="enemy",sid=8,active=true,alive=true,isPlayer=true,
     x=tc.player.x,y=tc.player.y,scale=35,xVel=0,yVel=0,
     skin=tc.player.skin,powers={invisible=0}
   }
   actor.changeHealth=function(self,amount)
     events[#events+1]="HP:"..fmt(amount)
     return true
   end
   actor.canSee=function()return true end
 end
 local players=actor and {actor} or {}
 local world=World.new({config=Config,random=function()return 0.5 end})
 local options={
   config=Config,players=players,world=world,
   randInt=function(min,max)return math.floor(rand()*(max-min+1))+min end,
   randFloat=function(min,max)return rand()*(max-min+1)+min end,
   send=function(id,name,...)
     local a={}
     for i=1,select("#",...) do a[i]=txt(select(i,...)) end
     events[#events+1]="SEND:"..id..":"..name..":"..table.concat(a,",")
   end
 }
 local ai=AI.new(4,options)
 AI.init(ai,tc.x or 500,tc.y or 500,tc.dir or 0.2,tc.index,
   assert(types[tc.index],"validated animal type is required"))
 for key,v in pairs(tc) do
   if key~="name" and key~="index" and key~="delta"
     and key~="player" and key~="runFrom" and key~="chargeTarget" then
     ai[key]=v
   end
 end
 if tc.runFrom then
   ai.runFrom={x=600,y=510,active=true,alive=true,isPlayer=true}
 end
 if tc.chargeTarget then ai.chargeTarget=actor end
 if tc.dmgOverTime then
   ai.changeHealth=function(self,n,doer)
     events[#events+1]="DOT:"..fmt(n)..":"..txt(doer)
     self.health=self.health+n
     return true
   end
 end
 for tick=1,3 do
   ai:update(tc.delta)
   print(table.concat({
     "AI",tc.name,tick,calls,ai.sid,ai.nameIndex,ai.active and 1 or 0,
     fmt(ai.x),fmt(ai.y),fmt(ai.xVel),fmt(ai.yVel),fmt(ai.dir),
     fmt(ai.health),fmt(ai.waitCount),fmt(ai.moveCount),fmt(ai.hitWait),
     fmt(ai.targetDir),fmt(ai.spawnCounter),fmt(ai.dmgOverTime.dmg),
     fmt(ai.dmgOverTime.time),ai.chargeTarget and 1 or 0,ai.runFrom and 1 or 0,
     actor and fmt(actor.xVel) or "-",actor and fmt(actor.yVel) or "-",
     table.concat(events,";")
   },"|"))
 end
end
