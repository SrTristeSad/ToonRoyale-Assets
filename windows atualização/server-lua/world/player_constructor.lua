-- SPDX-License-Identifier: AGPL-3.0-only
-- Constructor-only port of Node modules/player.js: Player.constructor lines
-- 17-71; does not masquerade as completed Player methods. No spawn occurs.
local Config=require("src.game.config")
local Spawn=require("server-lua.world.spawn")
local Snapshot=require("server-lua.world.snapshot")
local Pack=require("src.protocol.msgpack")
local Player={}
local function freeOwnership(catalogue)
 local owned={}
 for _,entry in ipairs(catalogue) do
   if entry.price<=0 and not entry.dontSell then owned[entry.id]=1 end
 end
 return owned
end
function Player.new(id,sid,opts)
 opts=opts or {}
 assert(type(id)=="string" and #id>0,"original Player connection ID required")
 assert(type(sid)=="number" and sid>=0 and sid%1==0,"original Player SID required")
 local hats=assert(opts.hats,"original shared config/store hats required")
 local accessories=assert(opts.accessories,"original shared config/store accessories required")
 local p={
   id=id,sid=sid,tmpScore=0,team=nil,skinIndex=0,tailIndex=0,
   hitTime=0,tails=freeOwnership(accessories),skins=freeOwnership(hats),
   points=0,dt=0,hidden=false,itemCounts={},isPlayer=true,
   pps=0,moveDir=nil,skinRot=0,lastPing=0,iconIndex=0,skinColor=0,
   account=nil,role=nil,isMember=false,isOwner=false,isLeader=false,
   flagged=false,shadowed=false,name="unknown",alive=false,
   active=false,spawned=false,sentTo={},lifeStats=nil,watchStats=-1,
   joinRequests={},powers={
     god=0,aura=0,godlike=0,boss=0,invisible=0,size=1,power=1,
     speed=1,health=1
   },
   morph=-1,dive=0,disguised=false,anon=false,tribeCooldown=0,
   chatCooldown=0,pingCooldown=0
 }
 -- Original Player instance operations that are independent of accounts.
 p.resetResources=function(self,moofoll)
   return Spawn.resetResources(self,moofoll,opts.config or Config)
 end
 p.spawn=function(self,moofoll)
   local world=assert(opts.world,"authoritative world required for Player.spawn")
   assert(type(opts.nowMs)=="function",
     "monotonic server clock callback required for Player.spawn")
   return Spawn.spawn(self,moofoll,world,{
     config=opts.config or Config,nowMs=opts.nowMs()
   })
 end
 p.addItem=function(self,id)
   local catalogue=assert(opts.items and opts.items.list,
     "original items.list catalogue required for Player.addItem")
   local item=catalogue[id]
   if not item then return false end
   assert(self.items,"Player.spawn required before addItem")
   for index,oldId in ipairs(self.items) do
     local oldItem=assert(catalogue[oldId],
       "existing inventory item missing from authoritative catalogue")
     if oldItem.group==item.group then
       if self.buildIndex==oldId then self.buildIndex=id end
       self.items[index]=id
       return true
     end
   end
   self.items[#self.items+1]=id
   return true
 end
 p.getData=function(self,viewer)
   return Snapshot.playerData(self,viewer)
 end
 p.setData=function(self,data)
   -- Original Player.setData accepts client wire array with zero-based JS keys;
   -- leave aura/bossMode/clan standalone just like the source.
   assert(type(data)=="table","original Player.setData data array required")
   self.id=data[1];self.sid=data[2];self.name=data[3]
   self.x=data[4];self.y=data[5];self.dir=data[6]
   self.health=data[7];self.maxHealth=data[8]
   self.scale=data[9];self.skinColor=data[10]
   self.aura=(data[11]~=nil and data[11]~=false and data[11]~=0
     and data[11]~=Pack.null)
   self.bossMode=(data[12]~=nil and data[12]~=false and data[12]~=0
     and data[12]~=Pack.null)
   self.clan=(data[13]==Pack.null) and nil or data[13]
 end
 -- First original instance methods that do not depend on unported game services.
 p.resetMoveDir=function(self)self.moveDir=nil end
 p.shownName=function(self,viewer)
   return self.anon and viewer~=self and ("Anon#"..self.sid) or self.name
 end
 p.canSee=function(self,other)
   if not other then return false end
   if other.skin and other.skin.invisTimer
      and other.noMovTimer>=other.skin.invisTimer then return false end
   if other.isPlayer and other.powers and other.powers.invisible
      and other.powers.invisible~=0 and other~=self and not self.role then return false end
   local cfg=opts.config or Config
   local dx=math.abs(other.x-self.x)-other.scale
   local dy=math.abs(other.y-self.y)-other.scale
   return dx<=cfg.maxScreenWidth/2*1.3
      and dy<=cfg.maxScreenHeight/2*1.3
 end
 p.applyPowers=function(self)
   if not self.alive then return end
   local ratio=self.maxHealth~=0 and self.health/self.maxHealth or 1
   local cfg=opts.config or Config
   self.scale=cfg.playerScale*self.powers.size
   self.maxHealth=100*self.powers.health
   self.health=math.max(1,math.floor(self.maxHealth*ratio+0.5))
 end
 p.displaySkin=function(self)
   return self.shameTimer and self.shameTimer>0 and 45 or self.skinIndex
 end
 return p
end
return Player
