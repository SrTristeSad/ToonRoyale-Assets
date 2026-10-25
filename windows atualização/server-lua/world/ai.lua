-- SPDX-License-Identifier: AGPL-3.0-only
-- Normal-animal portion of the original server/src/moomoo/modules/ai.js.
-- Conserves init state, per-instance 1000ms DoT timer, behaviors,
-- acquisition, turning, velocities, object and player hits, map bounds.
-- Crab King raid boss is NOT treated as a normal animal: it requires
-- its original dive/raid callbacks rather than an invented behavior.
local Collision=require("server-lua.world.collision")
local Pack=require("server-lua.world.wolf_pack")
local Angles=require("server-lua.world.atan2")
local DefaultConfig=require("src.game.config")
local AI={}
AI.__index=AI
local PI=math.pi
local TWO_PI=PI*2
local function truth(v) return v~=nil and v~=false and v~=0 end
local function jsOr(v,default)return truth(v) and v or default end
local function rem(v,divisor) return v-math.modf(v/divisor)*divisor end
local function dir(x1,y1,x2,y2)return Angles.atan2(y1-y2,x1-x2) end
local function distance(x1,y1,x2,y2)
 local a,b=x1-x2,y1-y2
 return math.sqrt(a*a+b*b)
end
local function round(v) return math.floor(v+0.5) end
local function randInt(opts,min,max)
 assert(type(opts.randInt)=="function","original UTILS.randInt source required")
 return opts.randInt(min,max)
end
local function randFloat(opts,min,max)
 assert(type(opts.randFloat)=="function","original UTILS.randFloat source required")
 return opts.randFloat(min,max)
end
local function checkCollision(ai,object,multiplier,opts)
 if opts.collision then return opts.collision(ai,object,multiplier) end
 return Collision.checkCollision(ai,object,multiplier,{
   disable=opts.disable,hit=opts.hit,
   config=opts.config or DefaultConfig,randomInt=opts.randInt
 })
end
function AI.init(ai,x,y,direction,index,data)
 assert(data and type(data)=="table","source AI type definition required")
 ai.x=x;ai.y=y
 ai.startX=truth(data.fixedSpawn) and x or nil
 ai.startY=truth(data.fixedSpawn) and y or nil
 ai.xVel=0;ai.yVel=0;ai.zIndex=0;ai.dir=direction;ai.dirPlus=0
 ai.index=index;ai.src=data.src
 if truth(data.name) then ai.name=data.name end
 for _,key in ipairs({"weightM","speed","killScore","turnSpeed","scale",
    "leapForce","chargePlayer","viewRange","drop","dmg","hostile",
    "dontRun","hitRange","hitDelay","hitScare","spriteMlt",
    "nameScale","colDmg","noTrap","spawnDelay",
    "minSpawnRange","maxSpawnRange"}) do
   ai[key]=data[key]
 end
 ai.maxHealth=data.health;ai.health=ai.maxHealth
 ai.hitWait=0;ai.waitCount=1000;ai.moveCount=0;ai.targetDir=0
 ai.active=true;ai.alive=true
 ai.runFrom=nil;ai.chargeTarget=nil;ai.dmgOverTime={}
 ai.boss=not not data.boss;ai.secret=ai.boss
 ai.state=0;ai.stateTimer=0;ai.submerged=false
 ai.damageBy={};ai.damageOrder={};ai.bossAttack=nil;ai.bossCooldown=3000
 return ai
end
function AI.new(sid,opts)
 opts=opts or {}
 assert(type(sid)=="number","source AI SID required")
 local self=setmetatable({
   sid=sid,isAI=true,
   nameIndex=randInt(opts,0,#(opts.config or DefaultConfig).cowNames-1),
   options=opts,timerCount=0
 },AI)
 return self
end
function AI:update(delta)
 local opts=self.options
 local cfg=opts.config or DefaultConfig
 assert(type(delta)=="number" and delta>=0 and delta==delta,
   "valid original server tick required")
 if not self.active then return end
 if truth(self.spawnCounter) then
   self.spawnCounter=self.spawnCounter-delta
   if self.spawnCounter<=0 then
     self.spawnCounter=0
     if truth(self.minSpawnRange) or truth(self.maxSpawnRange) then
       local low=cfg.mapScale*self.minSpawnRange
       local high=cfg.mapScale*self.maxSpawnRange
       self.x=randInt(opts,low,high);self.y=randInt(opts,low,high)
     elseif self.secret and not truth(self.startX) and opts.respawnAt then
       local spot=opts.respawnAt(self)
       self.x=spot.x;self.y=spot.y
     else
       -- JS `startX || randInt(...)` short circuits: never advance RNG
       -- for a fixed, nonzero spawn coordinate.
       if truth(self.startX) then self.x=self.startX
       else self.x=randInt(opts,0,cfg.mapScale) end
       if truth(self.startY) then self.y=self.startY
       else self.y=randInt(opts,0,cfg.mapScale) end
     end
   end
   return
 end
 self.timerCount=self.timerCount-delta
 if self.timerCount<=0 then
   if truth(self.dmgOverTime.dmg) then
     assert(type(self.changeHealth)=="function","AI.changeHealth required")
     self:changeHealth(-self.dmgOverTime.dmg,self.dmgOverTime.doer)
     self.dmgOverTime.time=self.dmgOverTime.time-1
     if self.dmgOverTime.time<=0 then self.dmgOverTime.dmg=0 end
   end
   self.timerCount=1000
 end
 if self.boss then
   assert(type(self.updateDive)=="function" and type(self.updateBoss)=="function",
     "Crab King needs original raid and dive methods")
   self:updateDive(delta)
   self:updateBoss(delta)
   return
 end
 local players=assert(opts.players,"original player array required")
 local world=assert(opts.world,"original ObjectManager required")
 local charging=false
 local slow=1
 if not truth(self.zIndex) and not truth(self.lockMove)
   and self.x>=0 and self.y>=cfg.mapScale/2-cfg.riverWidth/2
   and self.y<=cfg.mapScale/2+cfg.riverWidth/2 then
   slow=0.33
   self.xVel=self.xVel+cfg.waterCurrent*delta
 end
 if truth(self.lockMove) then
   self.xVel=0;self.yVel=0
 elseif self.waitCount>0 then
   self.waitCount=self.waitCount-delta
   if self.waitCount<=0 then
     if truth(self.chargePlayer) then
       local target,closest
       for _,player in ipairs(players) do
         if player.alive
           and not (player.skin and truth(player.skin.bullRepel))
           and not (player.powers and truth(player.powers.invisible))
           and (not self.secret or player.x<0) then
           local d=distance(self.x,self.y,player.x,player.y)
           if d<=self.viewRange and (not target or d<closest) then
             target=player;closest=d
           end
         end
       end
       if target then
         self.chargeTarget=target
         self.moveCount=randInt(opts,8000,12000)
       else
         self.moveCount=randInt(opts,1000,2000)
         self.targetDir=randFloat(opts,-PI,PI)
       end
     else
       self.moveCount=randInt(opts,4000,10000)
       self.targetDir=randFloat(opts,-PI,PI)
     end
   end
 elseif self.moveCount>0 then
   -- SPEED_RANDOM is 0 in original AI.js, so MAX_SPEED multiplies by 0.
   local speed=self.speed*slow
   if self.runFrom and self.runFrom.active
     and not (self.runFrom.isPlayer and not self.runFrom.alive) then
     self.targetDir=dir(self.x,self.y,self.runFrom.x,self.runFrom.y)
     speed=speed*1.42
   elseif self.chargeTarget and self.chargeTarget.alive then
     self.targetDir=dir(self.chargeTarget.x,self.chargeTarget.y,self.x,self.y)
     speed=speed*1.75
     charging=true
   end
   if truth(self.hitWait) then speed=speed*0.3 end
   if self.submerged then speed=speed*1.6 end
   if self.dir~=self.targetDir then
     self.dir=rem(self.dir,TWO_PI)
     local net=rem(self.dir-self.targetDir+TWO_PI,TWO_PI)
     local amount=math.min(math.abs(net-TWO_PI),net,self.turnSpeed*delta)
     local sign=(net-PI>=0) and 1 or -1
     self.dir=self.dir+sign*amount+TWO_PI
   end
   self.dir=rem(self.dir,TWO_PI)
   self.xVel=self.xVel+speed*delta*math.cos(self.dir)
   self.yVel=self.yVel+speed*delta*math.sin(self.dir)
   self.moveCount=self.moveCount-delta
   if self.moveCount<=0 then
     self.runFrom=nil;self.chargeTarget=nil
     self.waitCount=truth(self.hostile) and 1500 or randInt(opts,1500,6000)
   end
 end

 self.zIndex=0;self.lockMove=false
 local speed=distance(0,0,self.xVel*delta,self.yVel*delta)
 local depth=math.min(4,math.max(1,round(speed/40)))
 local multiplier=1/depth
 for _=1,depth do
   local prevX,prevY=self.x,self.y
   if truth(self.xVel) then self.x=self.x+self.xVel*delta*multiplier end
   if truth(self.yVel) then self.y=self.y+self.yVel*delta*multiplier end
   if self.secret then
     assert(type(self.keepInSecret)=="function","original secret AI boundary required")
     self:keepInSecret(prevX,prevY)
   end
   for _,grid in ipairs(world:getGridArrays(self.x,self.y,self.scale)) do
     for _,obj in ipairs(grid) do
       if obj.active then checkCollision(self,obj,multiplier,opts) end
     end
   end
 end

 local hitting=false
 if self.hitWait>0 then
   self.hitWait=self.hitWait-delta
   if self.hitWait<=0 then
     hitting=true;self.hitWait=0
     if truth(self.leapForce) and randInt(opts,0,2)==0 then
       self.xVel=self.xVel+self.leapForce*math.cos(self.dir)
       self.yVel=self.yVel+self.leapForce*math.sin(self.dir)
     end
     for _,grid in ipairs(world:getGridArrays(self.x,self.y,self.hitRange or 0)) do
       for _,obj in ipairs(grid) do
         if truth(obj.health) then
           local d=distance(self.x,self.y,obj.x,obj.y)
           if d<obj.scale+self.hitRange then
             assert(type(obj.changeHealth)=="function" and type(opts.disable)=="function"
               and type(opts.hit)=="function","real ObjectManager damage callbacks required")
             if obj:changeHealth(-self.dmg*5) then opts.disable(obj) end
             opts.hit(obj,dir(self.x,self.y,obj.x,obj.y))
           end
         end
       end
     end
     for _,player in ipairs(players) do
       if player:canSee(self) then
         assert(type(opts.send)=="function","real Server.send required")
         opts.send(player.id,"J",self.sid)
       end
     end
   end
 end
 if (charging or hitting) and not self.submerged then
   for _,player in ipairs(players) do
     if player and player.alive then
       local d=distance(self.x,self.y,player.x,player.y)
       if truth(self.hitRange) then
         if not truth(self.hitWait) and d<=self.hitRange+player.scale then
           if hitting then
             local angle=dir(player.x,player.y,self.x,self.y)
             assert(type(player.changeHealth)=="function","real Player.changeHealth required")
             player:changeHealth(-self.dmg)
             player.xVel=player.xVel+0.6*math.cos(angle)
             player.yVel=player.yVel+0.6*math.sin(angle)
             self.runFrom=nil;self.chargeTarget=nil;self.waitCount=3000
             self.hitWait=randInt(opts,0,2)==0 and 600 or 0
           else
             self.hitWait=self.hitDelay
           end
         end
       elseif d<=self.scale+player.scale then
         local angle=dir(player.x,player.y,self.x,self.y)
         assert(type(player.changeHealth)=="function","real Player.changeHealth required")
         player:changeHealth(-self.dmg)
         player.xVel=player.xVel+0.55*math.cos(angle)
         player.yVel=player.yVel+0.55*math.sin(angle)
       end
     end
   end
 end

 if truth(self.xVel) then self.xVel=self.xVel*cfg.playerDecel^delta end
 if truth(self.yVel) then self.yVel=self.yVel*cfg.playerDecel^delta end
 if not self.secret then
   if self.x-self.scale<0 then self.x=self.scale;self.xVel=0
   elseif self.x+self.scale>cfg.mapScale then
     self.x=cfg.mapScale-self.scale;self.xVel=0
   end
 end
 if self.y-self.scale<0 then self.y=self.scale;self.yVel=0
 elseif self.y+self.scale>cfg.mapScale then
   self.y=cfg.mapScale-self.scale;self.yVel=0
 end
end

return AI
