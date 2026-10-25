-- SPDX-License-Identifier: AGPL-3.0-only
-- Authoritative Player composed from differential-tested Node ports.
-- Original methods are wired to the ONE Room, World and economic model.
-- Name-filter vocabulary, catalogs, anticheat and death lifecycle are strict
-- dependencies: a production connection may not fabricate them.
local Identity=require("server-lua.world.player_identity")
local Spawn=require("server-lua.world.spawn")
local Health=require("server-lua.world.health")
local Economy=require("server-lua.world.economy")
local Gather=require("server-lua.world.gather")
local Build=require("server-lua.world.build")
local Snapshot=require("server-lua.world.snapshot")
local Player={}
Player.__index=Player
setmetatable(Player,{__index=Identity})
local function truth(v)return v~=nil and v~=false and v~=0 end
local function jsOr(v,default)return truth(v) and v or default end
local function distance(x,y,x2,y2)return math.sqrt((x-x2)^2+(y-y2)^2)end
function Player.new(id,sid,room,opts)
  opts=opts or {}
  assert(room and type(room.score)=="function" and room.object_manager
    and room.projectile_manager and type(room.hitObject)=="function",
    "the real Lua Room must own this Player")
  assert(type(opts.send)=="function","real network send callback required")
  assert(type(opts.icon)=="function","real Game.onPlayerDeath callback required")
  assert(type(opts.nameWords)=="table" and #opts.nameWords>0,
    "full authoritative NAME_WORDS dictionary required")
  -- Node Game.addPlayer creates internal room bots without any network session.
  local internalBot=opts.internalBot==true
  if internalBot then
    assert(id:match("^mooio%-bot%-%d+$") and opts.ip=="internal-bot"
      and opts.account==nil,
      "bot bypass may only be used by the original internal RoomBots")
  else
    assert(opts.anticheat or type(opts.anticheatFactory)=="function",
      "authoritative anticheat or real Player anticheatFactory required")
  end
  local p=Identity.new(id,sid,{
    hats=opts.hats,accessories=opts.accessories,config=room.config,
    nameWords=opts.nameWords
  })
  p.room=room
  p.ip=opts.ip
  p.did=opts.did
  p.account=opts.account
  p._icon=opts.icon
  p.send=function(_,name,...)return opts.send(name,...) end
  p.animRatio=0;p.animIndex=0
  p.sentTo={}
  -- Construct the anticheat with the *actual* Player, not a proxy with
  -- incomplete identity or a different packet/skin state.
  setmetatable(p,Player)
  if not internalBot then
    p.anticheat=opts.anticheatFactory and opts.anticheatFactory(p) or opts.anticheat
    assert(p.anticheat and type(p.anticheat.invalid)=="function"
      and type(p.anticheat.allow)=="function"
      and type(p.anticheat.onGameStart)=="function"
      and type(p.anticheat.tick)=="function",
      "complete anti-cheat allow/invalid/onGameStart/tick required")
  end
  return p
end
function Player:sendTo(id,name,...)
 return self.room:sendId(id,name,...)
end
function Player:canSee(other)
 return Snapshot.canSee(self,other,self.room.config)
end
function Player:spawn(moofoll)
 self.spaceId="surface"
 return Spawn.spawn(self,moofoll,self.room.object_manager,{
   config=self.room.config,nowMs=self.room.nowMs,
   send=function(...)return self.room:sendId(...)end,
   broadcast=assert(self.room.broadcast,
     "original ObjectManager.fetchSpawnObj requires Game.server.broadcast")
 })
end
function Player:variant()
 local cfg=self.room.config
 local variants=assert(cfg.weaponVariants,"original weapon variants required")
 local xp=jsOr(self.weaponXP and self.weaponXP[self.weaponIndex],0)
 for i=#variants,1,-1 do
   local variant=variants[i]
   if xp>=variant.xp then
     if variant.membersOnly and not self.isMember then
       return assert(variants[variant.id],"previous original nonmember variant")
     end
     return variant
   end
 end
 error("original weapon variant zero missing")
end
function Player:addItem(id)
  return Identity.addItem(self,id,self.room.items)
end
function Player:score(amount)
 return self.room:score(self,amount)
end
local function economyOptions(self)
 return {
   config=self.room.config,
   send=function(id,name,...)return self.room:sendId(id,name,...)end,
   score=function(player,amount)return self.room:score(player,amount)end
 }
end
function Player:addWeaponXP(amount)
 return Economy.addWeaponXP(self,amount)
end
function Player:earnXP(amount)
 return Economy.earnXP(self,amount,economyOptions(self))
end
function Player:addResource(resource,amount,auto)
 return Economy.addResource(self,resource,amount,auto,economyOptions(self))
end
function Player:changeItemCount(group,amount)
 return Economy.changeItemCount(self,group,amount,economyOptions(self))
end
function Player:hasRes(item,multiplier)
 return Economy.hasRes(self,item,multiplier)
end
function Player:useRes(item,multiplier)
 return Economy.useRes(self,item,multiplier,economyOptions(self))
end
function Player:canBuild(item)
 return Economy.canBuild(self,item,economyOptions(self))
end
function Player:buildItem(item)
 return Build.use(self,item,self.room.object_manager,{nowMs=self.room.nowMs})
end
function Player:changeHealth(amount,doer,source,projectile)
 return Health.change(self,amount,doer,source,projectile,{
   nowMs=self.room.nowMs,
   players=self.room.players,
   send=function(id,name,...)return self.room:sendId(id,name,...)end,
   score=function(player,score)return self.room:score(player,score)end,
   icon=self._icon
 })
end
function Player:kill(doer,source,projectile)
 return Health.kill(self,doer,source,projectile,{
   nowMs=self.room.nowMs,
   players=self.room.players,
   send=function(id,name,...)return self.room:sendId(id,name,...)end,
   score=function(player,score)return self.room:score(player,score)end,
   icon=self._icon
 })
end
function Player:gather()
 local items=self.room.items
 return Gather.step(self,{
   config=self.room.config,
   weapon=assert(items.weapons[self.weaponIndex],"original weapon required"),
   weapons=items.weapons,players=self.room.players,ais=self.room.ais,
   world=self.room.object_manager,nowMs=self.room.nowMs,
   disableObject=function(o)return self.room.object_manager:disableObject(o)end,
   hitObject=function(o,d)return self.room:hitObject(o,d)end
 })
end
function Player:sendAnimation(hit)
 local speed=self.skin and jsOr(self.skin.atkSpd,1) or 1
 for _,viewer in ipairs(self.room.players) do
   if self.sentTo[viewer.id] and self:canSee(viewer) then
     if speed~=1 then
       viewer:send("K",self.sid,truth(hit) and 1 or 0,self.weaponIndex,1/speed)
     else
       viewer:send("K",self.sid,truth(hit) and 1 or 0,self.weaponIndex)
     end
   end
 end
end
function Player:startAnim(hit,index,speed)
 local w=assert(self.room.items.weapons[index],"original animation weapon missing")
 self.animTime=w.speed/jsOr(speed,1)
 self.animSpeed=self.animTime
 self.targetAngle=truth(hit) and -self.room.config.hitAngle or -math.pi
 self.animRatio=0
 self.animIndex=0
end
function Player:animate(delta)
 if self.animTime and self.animTime>0 then
   self.animTime=self.animTime-delta
   if self.animTime<=0 then
     self.animTime=0;self.dirPlus=0;self.animRatio=0;self.animIndex=0
   elseif self.animIndex==0 then
     self.animRatio=self.animRatio+delta/(self.animSpeed*self.room.config.hitReturnRatio)
     self.dirPlus=self.targetAngle*math.min(1,self.animRatio)
     if self.animRatio>=1 then self.animRatio=1;self.animIndex=1 end
   else
     self.animRatio=self.animRatio-delta/(self.animSpeed*
       (1-self.room.config.hitReturnRatio))
     self.dirPlus=self.targetAngle*math.max(0,self.animRatio)
   end
 end
end
function Player:shootTurret()
 local turret=assert(self.skin and self.skin.turret,
   "Turret Gear properties missing from original hat")
 local target,nearest=nil,math.huge
 for _,other in ipairs(self.room.players) do
   if other.alive and other~=self
     and not (truth(self.team) and other.team==self.team)
     and not (other.skin and truth(other.skin.antiTurret)) then
     local d=distance(self.x,self.y,other.x,other.y)
     if d<=turret.range and d<nearest then target=other;nearest=d end
   end
 end
 if not target then self.shootCount=250;return end
 local direction=math.atan(target.y-self.y,target.x-self.x)
 self.room.projectile_manager:addProjectile(self.x,self.y,direction,
   turret.range,1.6,turret.proj,self,nil,self.zIndex)
 self.shootCount=turret.rate
end
return Player
