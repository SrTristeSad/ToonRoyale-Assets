-- SPDX-License-Identifier: AGPL-3.0-only
-- Faithful port of AI.changeHealth from server/src/moomoo/modules/ai.js.
-- Hooks map to the exact Node hooks; score and send must be real callbacks.
-- Zero-based original resourceTypes map to zero-based Player.addResource.
local Config=require("src.game.config")
local Health={}
local function truth(v) return v~=nil and v~=false and v~=0 end
local function jsOr(v,default) return truth(v) and v or default end
local function round(v) return math.floor(v+0.5) end
local function randInt(opts,lo,hi)
 assert(type(opts.randInt)=="function","original UTILS.randInt required")
 return opts.randInt(lo,hi)
end
local function spawnRandomOrFixed(ai,key,opts,config)
 local fixed=ai[key]
 if truth(fixed) then return fixed end
 return randInt(opts,0,config.mapScale)
end

function Health.changeHealth(ai,amount,doer,runFrom,opts)
 opts=opts or ai.options or {}
 assert(type(amount)=="number","numeric damage/heal amount required")
 if not ai.active then return false end
 -- Boss submerged damage immunity applies before *all* side effects.
 if amount<0 and ai.submerged then return false end
 ai.health=ai.health+amount
 if truth(runFrom) then
   if truth(ai.hitScare) and randInt(opts,0,ai.hitScare)==0 then
     ai.runFrom=runFrom;ai.waitCount=0;ai.moveCount=2000
   elseif ai.hostile and ai.chargePlayer and runFrom.isPlayer then
     ai.chargeTarget=runFrom;ai.waitCount=0;ai.moveCount=8000
   elseif not truth(ai.dontRun) then
     ai.runFrom=runFrom;ai.waitCount=0;ai.moveCount=2000
   end
 end
 if amount<0 and truth(ai.hitRange) and randInt(opts,0,1)~=0 then
   ai.hitWait=500
 end
 if doer and type(doer.canSee)=="function" and doer:canSee(ai) and amount<0 then
   assert(type(opts.send)=="function","real server.send needed for animal damage number")
   opts.send(doer.id,"8",round(ai.x),round(ai.y),round(-amount),1)
 end
 if amount<0 and doer and doer.isPlayer then
   ai.damageBy=ai.damageBy or {}
   ai.damageOrder=ai.damageOrder or {}
   if ai.damageBy[doer]==nil then ai.damageOrder[#ai.damageOrder+1]=doer end
   ai.damageBy[doer]=jsOr(ai.damageBy[doer],0)-amount
   if doer.lifeStats then
     doer.lifeStats.animalDamage=doer.lifeStats.animalDamage-amount
   end
 end
 if ai.health<=0 then
   -- Custom local-map death animation: cosmetic packet only, emitted
   -- BEFORE the classic respawn reset. Clients without the optional
   -- spritesheet simply keep the original animal presentation.
   local definitions=opts.mapAnimations
   local artwork=type(definitions)=="table"
     and definitions[tostring(ai.index)]
   if type(artwork)=="table" and type(artwork.death)=="table"
     and type(opts.send)=="function" then
     for _,viewer in ipairs(opts.players or {}) do
       if viewer.alive and type(viewer.id)=="string"
         and (viewer.spaceId or "surface")==(ai.spaceId or "surface")
         and type(viewer.x)=="number" and type(viewer.y)=="number" then
         local dx,dy=viewer.x-ai.x,viewer.y-ai.y
         if dx*dx+dy*dy<=2000*2000 then
           opts.send(viewer.id,"j","mob-death",0,0,{
             sid=ai.sid,index=ai.index,x=ai.x,y=ai.y,dir=ai.dir})
         end
       end
     end
   end
   if opts.onKill then opts.onKill(ai,doer) end
   local reward=opts.killScore and opts.killScore(ai,doer) or ai.killScore
   -- Admin-spawned animals permanently disappear: no resource drops here.
   if ai.despawnOnDeath then
     ai.active=false;ai.alive=false
     ai.x=-1000000;ai.y=-1000000
     if doer then
       assert(type(opts.score)=="function","real scoreCallback required")
       opts.score(doer,reward)
     end
     return true
   end
   local respawn=opts.respawnAt and opts.respawnAt(ai) or nil
   local cfg=opts.config or Config
   if truth(ai.spawnDelay) then
     ai.spawnCounter=ai.spawnDelay
     ai.x=-1000000;ai.y=-1000000
   elseif truth(ai.minSpawnRange) or truth(ai.maxSpawnRange) then
     ai.x=randInt(opts,cfg.mapScale*ai.minSpawnRange,
       cfg.mapScale*ai.maxSpawnRange)
     ai.y=randInt(opts,cfg.mapScale*ai.minSpawnRange,
       cfg.mapScale*ai.maxSpawnRange)
   elseif respawn and not truth(ai.startX) then
     ai.x=respawn.x;ai.y=respawn.y
   else
     ai.x=spawnRandomOrFixed(ai,"startX",opts,cfg)
     ai.y=spawnRandomOrFixed(ai,"startY",opts,cfg)
   end
   ai.health=ai.maxHealth
   ai.runFrom=nil
   ai.damageBy={}
   ai.damageOrder={}
   ai.state=0;ai.submerged=false;ai.bossAttack=nil
   if doer then
     assert(type(opts.score)=="function","real scoreCallback required")
     opts.score(doer,reward)
     if ai.drop then
       assert(type(doer.addResource)=="function","original Player.addResource required")
       for i=1,#ai.drop,2 do
         local typeId=nil
         for j,name in ipairs(cfg.resourceTypes) do
           if name==ai.drop[i] then typeId=j-1;break end
         end
         assert(typeId~=nil,"unknown original animal drop type")
         local amountToDrop=opts.dropAmount
           and opts.dropAmount(ai,doer,ai.drop[i+1]) or ai.drop[i+1]
         doer:addResource(typeId,amountToDrop)
       end
     end
   end
 end
 return true
end
return Health
