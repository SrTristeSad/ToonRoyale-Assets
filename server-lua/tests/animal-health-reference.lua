-- SPDX-License-Identifier: AGPL-3.0-only
-- Same cases as animal-health-reference.mjs, compared to actual Node AI class.
local AI=require("server-lua.world.ai")
local Types=require("server-lua.world.animal_types")
local Health=require("server-lua.world.animal_health")
local Config=require("src.game.config")
local Crypto=require("src.protocol.original_crypto")
local cases={
 {id="cow-hit",index=0,amount=-25},
 {id="cow-heal",index=0,amount=45},
 {id="cow-kill",index=0,amount=-600},
 {id="cow-kill-no-doer",index=0,amount=-600,noDoer=true},
 {id="pig-reward",index=1,amount=-900,overrideReward=850,overrideDrop=3},
 {id="bull-chase",index=2,amount=-50,runFrom=true},
 {id="wolf-run",index=4,amount=-25,runFrom=true},
 {id="wolf-no-run",index=4,amount=-25,runFrom=true,dontRun=true},
 {id="yeti-scare",index=10,amount=-40,runFrom=true,hitScare=1},
 {id="moostafa-hit",index=6,amount=-90,runFrom=true},
 {id="fixed-respawn",index=6,amount=-20000},
 {id="delayed-respawn",index=8,amount=-9000},
 {id="boss-dive",index=11,amount=-600000,submerged=true},
 {id="boss-kill",index=11,amount=-600000},
 {id="admin-despawn",index=0,amount=-900,despawnOnDeath=true},
 {id="custom-range",index=0,amount=-1000,minSpawnRange=0.2,maxSpawnRange=0.3},
 {id="no-damage",index=0,amount=10,active=false},
 {id="silent-hit",index=0,amount=-30,notVisible=true},
 {id="heal-run",index=0,amount=10,runFrom=true}
}
local fmt=function(v)return string.format("%.6f",v or 0)end
for _,sc in ipairs(cases) do
 local events={}
 local random=Crypto.mulberry32(20260+sc.index)
 local calls=0
 local function rand()
   calls=calls+1
   return random()
 end
 local doer={
   id="killer",isPlayer=true,alive=true,
   points=0,wood=0,food=0,stone=0,lifeStats={animalDamage=0}
 }
 doer.canSee=function()return not sc.notVisible end
 doer.addResource=function(self,id,amount)
   events[#events+1]="RESOURCE:"..id..":"..fmt(amount)
   local key=Config.resourceTypes[id+1]
   self[key]=self[key]+amount
 end
 local opts={
   config=Config,
   randInt=function(low,high)return math.floor(rand()*(high-low+1))+low end,
   onKill=function(actor,who)
     events[#events+1]="KILL:"..(who and "doer" or "none")..":"..actor.index
   end,
   killScore=function(actor)
     events[#events+1]="REWARD:"..actor.killScore
     return sc.overrideReward or actor.killScore
   end,
   dropAmount=function(actor,who,n)
     events[#events+1]="DROP:"..fmt(n)
     return n*(sc.overrideDrop or 1)
   end,
   respawnAt=function(actor)
     events[#events+1]="RESPAWN:"..actor.index
     return {x=-2500,y=7200}
   end,
   send=function(id,name,...)
     local args={}
     for i=1,select("#",...) do args[#args+1]=fmt(select(i,...))end
     events[#events+1]="SEND:"..id..":"..name..":"..table.concat(args,",")
   end,
   score=function(who,value)
     events[#events+1]="SCORE:"..fmt(value)
   end
 }
 local ai=AI.new(3,opts)
 AI.init(ai,500,520,0.25,sc.index,Types[sc.index])
 for _,key in ipairs({
   "submerged","despawnOnDeath","dontRun","hitScare",
   "minSpawnRange","maxSpawnRange","active"
 }) do if sc[key]~=nil then ai[key]=sc[key]end end
 if sc.index==6 then ai.startX=500;ai.startY=520 end
 local who=not sc.noDoer and doer or nil
 local result=Health.changeHealth(ai,sc.amount,who,sc.runFrom and doer or nil,opts)
 local damage=ai.damageBy[doer] or 0
 print(table.concat({
   "ANIMALHEALTH",sc.id,result and "1" or "0",calls,
   ai.active and "1" or "0",ai.alive and "1" or "0",fmt(ai.x),fmt(ai.y),
   fmt(ai.health),fmt(ai.spawnCounter),fmt(ai.waitCount),fmt(ai.moveCount),
   fmt(ai.hitWait),ai.runFrom and "1" or "0",ai.chargeTarget and "1" or "0",
   ai.state,ai.submerged and "1" or "0",fmt(damage),
   fmt(doer.lifeStats.animalDamage),fmt(doer.food),fmt(doer.points),
   table.concat(events,";")
 },"|"))
end
