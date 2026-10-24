-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of the original Crab King methods in modules/ai.js (keepInSecret,
-- setState, dive, updateDive, telegraph, bossTarget, raiders, landAttack,
-- queueAttack, attackSlam, attackGeysers, attackClaw, updateBoss).
-- Never use simplified NPC combat here; packet W is the original renderer.
local DefaultConfig=require("src.game.config")
local Crab={}
local TAU=2*math.pi
local STATE={SURFACE=0,DIVING=1,SUBMERGED=2,EMERGING=3}
local KIND={SPLASH=1,GEYSER=2,SLAM=3,CLAW=4}
local DAMAGE={[1]=1.5,[2]=0.8,[3]=1.5,[4]=1.2}
local KNOCK={[1]=1.2,[2]=0.6,[3]=1.4,[4]=0.9}
local function truth(v)return v~=nil and v~=false and v~=0 end
local function rem(x,m)return x-math.modf(x/m)*m end
local function dist(x,y,x2,y2)return math.sqrt((x-x2)^2+(y-y2)^2)end
local function round(x)return math.floor(x+0.5)end
local function direction(x1,y1,x2,y2)return math.atan(y1-y2,x1-x2)end
local function segment(px,py,x1,y1,x2,y2)
 local dx,dy=x2-x1,y2-y1
 local len=dx*dx+dy*dy
 local t=len~=0 and ((px-x1)*dx+(py-y1)*dy)/len or 0
 t=math.max(0,math.min(1,t))
 return dist(px,py,x1+t*dx,y1+t*dy)
end
local function secretDistance(cfg,x,y)
 local z=cfg.secretPool
 local mid=cfg.mapScale/2
 local n=-x
 local band=math.abs(y-mid)-z.gorgeHalf
 if x>=z.gorgeX0 then n=math.min(n,math.max(band,0)) end
 for _,p in ipairs(z.pool) do n=math.min(n,dist(x,y,p[1],p[2])-p[3]) end
 if math.abs(y-z.waterfall.y)<z.waterfall.half+60 and x<z.waterfall.x then
   n=math.min(n,math.abs(y-z.waterfall.y)-z.waterfall.half)
 end
 return n
end
local function inPool(cfg,x,y,margin)
 for _,p in ipairs(cfg.secretPool.pool) do
   if dist(x,y,p[1],p[2])<=p[3]-margin then return true end
 end
 return false
end
local function randomInt(ai,a,b)
 local fn=assert(ai.options.randInt,"original random integer service required")
 return fn(a,b)
end
local function random(ai)
 local fn=assert(ai.options.random,"original Math.random service required for boss")
 return fn()
end
local function send(ai,id,name,...)
 local fn=assert(ai.options.send,"real server.send required for Crab King")
 return fn(id,name,...)
end
local function players(ai)
 return assert(ai.options.players,"real active players array required for boss")
end
local function config(ai)return ai.options.config or DefaultConfig end
function Crab.keepInSecret(ai,prevX,prevY)
 local margin=ai.scale*0.5
 local cfg=config(ai)
 local function inside(x,y)
   return x< -margin and secretDistance(cfg,x+margin,y)<=0
 end
 if inside(ai.x,ai.y) then return end
 if inside(prevX,ai.y) then
   ai.x=prevX;ai.xVel=0
 elseif inside(ai.x,prevY) then
   ai.y=prevY;ai.yVel=0
 else
   ai.x=prevX;ai.y=prevY;ai.xVel=0;ai.yVel=0
 end
 ai.targetDir=ai.targetDir+math.pi/2
end
function Crab.setState(ai,state,time)
 ai.state=state
 ai.stateTimer=truth(time) and time or 0
 ai.submerged=(state==STATE.SUBMERGED or state==STATE.DIVING)
end
function Crab.dive(ai)
 if ai.state~=STATE.SURFACE then return end
 Crab.setState(ai,STATE.DIVING,700)
end
function Crab.updateDive(ai,delta)
 if ai.state==STATE.SURFACE then return end
 ai.stateTimer=ai.stateTimer-delta
 if ai.stateTimer>0 then return end
 if ai.state==STATE.DIVING then
   Crab.setState(ai,STATE.SUBMERGED,randomInt(ai,1800,3600))
 elseif ai.state==STATE.SUBMERGED then
   Crab.setState(ai,STATE.EMERGING,1650)
   if ai.boss then Crab.telegraph(ai,KIND.SPLASH,ai.x,ai.y,ai.scale+220,1650) end
 elseif ai.state==STATE.EMERGING then
   Crab.setState(ai,STATE.SURFACE,0)
   if ai.boss then Crab.landAttack(ai,{kind=KIND.SPLASH,x=ai.x,y=ai.y,r=ai.scale+220}) end
 end
end
function Crab.telegraph(ai,kind,x,y,r,duration,x2,y2)
 for _,p in ipairs(players(ai)) do
   if p.alive and (p:canSee(ai) or dist(p.x,p.y,x,y)<1600) then
     if x2==nil then
       send(ai,p.id,"W",kind,round(x),round(y),round(r),duration)
     else
       send(ai,p.id,"W",kind,round(x),round(y),round(r),duration,round(x2),round(y2))
     end
   end
 end
end
function Crab.bossTarget(ai)
 local chosen,closest=nil,math.huge
 for _,p in ipairs(players(ai)) do
   if p.alive and p.x<0 and not (p.powers and truth(p.powers.invisible)) then
     local d=dist(ai.x,ai.y,p.x,p.y)
     if d<=ai.viewRange and d<closest then chosen=p;closest=d end
   end
 end
 return chosen
end
function Crab.raiders(ai)
 local result={}
 for _,p in ipairs(players(ai)) do
   if p.alive and p.x<0 and dist(ai.x,ai.y,p.x,p.y)<=ai.viewRange then
     result[#result+1]=p
   end
 end
 return result
end
function Crab.landAttack(ai,attack)
 for _,p in ipairs(players(ai)) do
   if p.alive then
     local hit=attack.kind==KIND.CLAW
       and segment(p.x,p.y,attack.x,attack.y,attack.x2,attack.y2)<=attack.r+p.scale
       or attack.kind~=KIND.CLAW
       and dist(p.x,p.y,attack.x,attack.y)<=attack.r+p.scale
     if hit then
       local dir=attack.kind==KIND.CLAW
         and direction(attack.x2,attack.y2,attack.x,attack.y)
         or direction(p.x,p.y,attack.x,attack.y)
       p:changeHealth(-ai.dmg*(DAMAGE[attack.kind] or 1))
       p.xVel=p.xVel+KNOCK[attack.kind]*math.cos(dir)
       p.yVel=p.yVel+KNOCK[attack.kind]*math.sin(dir)
     end
   end
 end
end
function Crab.queueAttack(ai,time,strikes,onLand)
 for _,s in ipairs(strikes) do
   Crab.telegraph(ai,s.kind,s.x,s.y,s.r,time,s.x2,s.y2)
 end
 ai.bossAttack={time=time,strikes=strikes,onLand=onLand}
end
function Crab.attackSlam(ai)
 Crab.queueAttack(ai,1300,{{kind=KIND.SLAM,x=ai.x,y=ai.y,r=ai.scale+260}})
end
function Crab.attackGeysers(ai)
 local strikes={}
 local pools=config(ai).secretPool.pool
 local radius=110
 local function fits(x,y)
   if not inPool(config(ai),x,y,radius*0.6) then return false end
   for _,s in ipairs(strikes) do
     if dist(s.x,s.y,x,y)<=radius*2.4 then return false end
   end
   return true
 end
 for _,p in ipairs(Crab.raiders(ai)) do
   if fits(p.x,p.y) then
     strikes[#strikes+1]={kind=KIND.GEYSER,x=p.x,y=p.y,r=radius}
   end
 end
 for _=1,400 do
   if #strikes>=26 then break end
   local pool=pools[randomInt(ai,0,#pools-1)+1]
   local angle=random(ai)*TAU
   local radiusFromCenter=math.sqrt(random(ai))*pool[3]
   local x=pool[1]+math.cos(angle)*radiusFromCenter
   local y=pool[2]+math.sin(angle)*radiusFromCenter
   if fits(x,y) then
     strikes[#strikes+1]={kind=KIND.GEYSER,x=x,y=y,r=radius}
   end
 end
 Crab.queueAttack(ai,1600,strikes)
end
function Crab.attackClaw(ai,target)
 local strikes,targets={},{}
 if target then targets[1]=target end
 for _,p in ipairs(Crab.raiders(ai)) do
   if #targets<3 then
     local found=false
     for _,v in ipairs(targets) do if v==p then found=true;break end end
     if not found then targets[#targets+1]=p end
   end
 end
 for _,p in ipairs(targets) do
   local dir=direction(p.x,p.y,ai.x,ai.y)
   local len=math.min(1800,dist(ai.x,ai.y,p.x,p.y)+600)
   strikes[#strikes+1]={kind=KIND.CLAW,x=ai.x,y=ai.y,r=130,
     x2=ai.x+math.cos(dir)*len,y2=ai.y+math.sin(dir)*len}
 end
 if #strikes>0 then ai.dir=direction(strikes[1].x2,strikes[1].y2,ai.x,ai.y) end
 Crab.queueAttack(ai,1150,strikes)
end
function Crab.updateBoss(ai,delta)
 local target=Crab.bossTarget(ai)
 if (ai.state==STATE.SURFACE and not ai.bossAttack) or ai.state==STATE.SUBMERGED then
   local goal=target or {x=ai.startX,y=ai.startY}
   local d=dist(ai.x,ai.y,goal.x,goal.y)
   if d>ai.scale*0.8 then
     ai.targetDir=direction(goal.x,goal.y,ai.x,ai.y)
     local speed=ai.speed*(ai.submerged and 3.2 or 1)
     local net=rem(ai.dir-ai.targetDir+TAU,TAU)
     local amount=math.min(math.abs(net-TAU),net,ai.turnSpeed*delta*(ai.submerged and 3 or 1))
     ai.dir=rem(ai.dir+((net-math.pi>=0) and 1 or -1)*amount+TAU,TAU)
     ai.xVel=ai.xVel+speed*delta*math.cos(ai.dir)
     ai.yVel=ai.yVel+speed*delta*math.sin(ai.dir)
   end
 end
 local px,py=ai.x,ai.y
 ai.x=ai.x+ai.xVel*delta
 ai.y=ai.y+ai.yVel*delta
 Crab.keepInSecret(ai,px,py)
 ai.xVel=ai.xVel*config(ai).playerDecel^delta
 ai.yVel=ai.yVel*config(ai).playerDecel^delta
 if ai.bossAttack then
   ai.bossAttack.time=ai.bossAttack.time-delta
   if ai.bossAttack.time<=0 then
     local attack=ai.bossAttack
     ai.bossAttack=nil
     for _,s in ipairs(attack.strikes) do Crab.landAttack(ai,s) end
     for _,p in ipairs(players(ai)) do
       if p:canSee(ai) then send(ai,p.id,"J",ai.sid) end
     end
   end
   return
 end
 if ai.state~=STATE.SURFACE then return end
 local forced=ai.nextAttack
 if not target then return end
 if truth(forced) then ai.nextAttack=nil;ai.bossCooldown=0 end
 ai.bossCooldown=ai.bossCooldown-delta
 if ai.bossCooldown>0 then return end
 ai.bossCooldown=randomInt(ai,2000,3400)*(0.6+0.4*ai.health/ai.maxHealth)
 local near=dist(ai.x,ai.y,target.x,target.y)<=ai.scale+420
 local move=forced
 if not truth(move) then
   local roll=random(ai)
   move=roll<0.15 and "dive" or roll<0.45 and (near and "slam" or "claw")
     or roll<0.75 and "geysers" or "claw"
 end
 if move=="dive" then Crab.dive(ai)
 elseif move=="slam" then Crab.attackSlam(ai)
 elseif move=="geysers" then Crab.attackGeysers(ai)
 else Crab.attackClaw(ai,target) end
end
function Crab.attach(ai)
 assert(ai.boss and ai.index==11,"Crab King AI type 11 required")
 ai.keepInSecret=function(actor,x,y)return Crab.keepInSecret(actor,x,y)end
 ai.setState=function(actor,s,t)return Crab.setState(actor,s,t)end
 ai.dive=function(actor)return Crab.dive(actor)end
 ai.updateDive=function(actor,d)return Crab.updateDive(actor,d)end
 ai.updateBoss=function(actor,d)return Crab.updateBoss(actor,d)end
 ai.telegraph=function(actor,...)return Crab.telegraph(actor,...)end
 ai.landAttack=function(actor,... )return Crab.landAttack(actor,...)end
 return ai
end
Crab.STATE=STATE
Crab.KIND=KIND
return Crab
