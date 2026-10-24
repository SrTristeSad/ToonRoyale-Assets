-- SPDX-License-Identifier: AGPL-3.0-only
-- Ports AiManager.spawn, Game.animalPosition and Game.ensureAnimals.
-- Types are the 15 original AI_TYPES; boss AI.update remains separately gated.
local AI=require("server-lua.world.ai")
local Health=require("server-lua.world.animal_health")
local Rewards=require("server-lua.world.animal_rewards")
local Crab=require("server-lua.world.crab_king")
local CrabRewards=require("server-lua.world.crab_rewards")
local Types=require("server-lua.world.animal_types")
local Config=require("src.game.config")
local Animals={}
Animals.__index=Animals
local function jsTruthy(v) return v~=nil and v~=false and v~=0 end
local function round(v)return math.floor(v+0.5)end
function Animals.new(opts)
 opts=opts or {}
 local cfg=opts.config or Config
 assert(opts.world and type(opts.world.randomInt)=="function"
   and type(opts.world.canPlace)=="function",
   "real generated ObjectManager required")
 assert(type(opts.random)=="function","source Math.random-compatible generator required")
 local crabKilled=opts.onCrabKingKilled
 if not crabKilled and opts.crabKillers and opts.broadcast then
   crabKilled=function(ai,doer)
     return CrabRewards.onKill(ai,doer,{
       crabKillers=opts.crabKillers,broadcast=opts.broadcast,
       event=opts.event,key=opts.key
     })
   end
 end
 local self=setmetatable({
   config=cfg,world=opts.world,players=opts.players or {},
   ais=opts.ais or {},random=opts.random,
   types=opts.types or Types,
   respawnAt=opts.respawnAt,
   hit=opts.hit,disable=opts.disable,
   collision=opts.collision,send=opts.send,
   score=opts.score,
   onKill=opts.onKill or function(ai,doer)
     return Rewards.onKill(ai,doer,{onCrabKingKilled=crabKilled})
   end,
   killScore=opts.killScore or Rewards.killScore,
   dropAmount=opts.dropAmount or Rewards.dropAmount,
   health=opts.health,boss=opts.boss or Crab.attach,
   onCrabKingKilled=crabKilled,crabKillers=opts.crabKillers
 },Animals)
 if not self.health and type(self.score)=="function" and type(self.send)=="function" then
   self.health=function(actor,amount,doer,runFrom)
     return Health.changeHealth(actor,amount,doer,runFrom,actor.options)
   end
 end
 return self
end
function Animals:randomInt(min,max)
 return math.floor(self.random()*(max-min+1))+min
end
function Animals:randomFloat(min,max)
 -- Original UTILS.randFloat adds +1 to the upper/lower difference.
 return self.random()*(max-min+1)+min
end
function Animals:spawn(x,y,angle,index,overrides)
 local data=self.types[index]
 if not data then
   assert(self.types[0],"original default Cow type missing")
   return self:spawn(x,y,angle,0,overrides)
 end
 local ai
 for _,candidate in ipairs(self.ais) do
   if not candidate.active then ai=candidate;break end
 end
 if not ai then
   local opts={
     config=self.config,players=self.players,world=self.world,
     randInt=function(min,max)return self:randomInt(min,max)end,
     randFloat=function(min,max)return self:randomFloat(min,max)end,
     random=self.random,
     respawnAt=self.respawnAt,hit=self.hit,disable=self.disable,
     collision=self.collision,send=self.send,score=self.score,
     onKill=self.onKill,killScore=self.killScore,dropAmount=self.dropAmount
   }
   ai=AI.new(#self.ais,opts)
   self.ais[#self.ais+1]=ai
 end
 AI.init(ai,x,y,angle,index,data)
 if overrides then
   for k,v in pairs(overrides) do ai[k]=v end
 end
 if self.health then
   ai.changeHealth=function(actor,...)
     return self.health(actor,...)
   end
 end
 if data.boss and self.boss then
   self.boss(ai)
 end
 return ai
end
function Animals:animalPosition(plan)
 local data=assert(self.types[plan.index],"AI_TYPES original index missing")
 local cfg=self.config
 if plan.positions and #plan.positions>0 then
   local pos=plan.positions[1]
   if type(pos.x)=="number" then return {x=pos.x,y=pos.y} end
   return {x=round(cfg.mapScale*pos.xRatio),y=round(cfg.mapScale*pos.yRatio)}
 end
 if plan.area=="secret" then
   assert(type(self.respawnAt)=="function",
     "secret-pool position requires original Game.randomSecretPoint")
   return self.respawnAt({scale=data.scale,secret=true})
 end
 for _=1,40 do
   local x=self:randomInt(data.scale,cfg.mapScale-data.scale)
   local y=self:randomInt(data.scale,cfg.mapScale-data.scale)
   if plan.area=="snow" then
     y=self:randomInt(data.scale,cfg.snowBiomeTop-data.scale)
   end
   if plan.area=="river" then
     y=self:randomInt(cfg.mapScale/2-cfg.riverWidth,
       cfg.mapScale/2+cfg.riverWidth)
   end
   if self.world:canPlace(x,y,data.scale,0.6,nil,true) then
     return {x=x,y=y}
   end
 end
 return {x=self:randomInt(0,cfg.mapScale),y=self:randomInt(0,cfg.mapScale)}
end
function Animals:ensureAnimals()
 local plan=assert(self.config.server and self.config.server.animalSpawnPlan,
   "original server.animalSpawnPlan required")
 for _,entry in ipairs(plan) do
   local count=0
   for _,ai in ipairs(self.ais) do
     if ai.active and ai.index==entry.index and not jsTruthy(ai.despawnOnDeath) then
       count=count+1
     end
   end
   for _=count+1,entry.desired do
     local pos=self:animalPosition(entry)
     local overrides=entry.index==11 and {spawnDelay=10*60*1000} or nil
     self:spawn(pos.x,pos.y,self:randomFloat(-math.pi,math.pi),entry.index,overrides)
   end
 end
 return self.ais
end
return Animals
