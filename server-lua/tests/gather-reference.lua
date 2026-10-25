-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact fixtures from gather-reference.mjs; JS validates these weapon data against
-- the existing server/src/moomoo/modules/items.js original shared config.
local World=require("server-lua.world.objects")
local Gather=require("server-lua.world.gather")
local Config=require("src.game.config")
local weapons={
 [0]={id=0,dmg=25,range=65,gather=1},
 [7]={id=7,dmg=20,range=65,gather=1,hitSlow=0.1,knock=0.1},
 [11]={id=11,shield=0.2},
 [14]={id=14,dmg=0,range=125,gather=0,steal=250,knock=0.2}
}
local pi=math.pi
local fixtures={
 {name="empty"},
 {name="tree",obj={type=0}},
 {name="stone",obj={type=2}},
 {name="bush",obj={type=1}},
 {name="gold",obj={type=3}},
 {name="tree-cape",obj={type=0},tail={id=9}},
 {name="stone-cape",obj={type=2},tail={id=10}},
 {name="cookie-cape",obj={type=1},tail={id=3}},
 {name="gold-hat",obj={type=0},skin={extraGold=true}},
 {name="hidden",obj={type=0,hideFromEnemy=true,hostileOwner=true}},
 {name="blocked",obj={type=0,dontGather=true}},
 {name="behind",obj={type=0,x=415}},
 {name="far",obj={type=0,x=900}},
 {name="two-resources",obj={type=0},secondObj={type=2,x=575,y=545}},
 {name="double-grid",x=1420,obj={type=0,x=1450,scale=70}},
 {name="wall-hit",obj={type=2,health=40,req={"wood",10},owner=true}},
 {name="wall-break",obj={type=2,health=10,req={"wood",10},owner=true}},
 {name="wall-high-damage",obj={type=2,health=40,req={"stone",15},owner=true},skin={bDmg=2}},
 {name="melee",target={}},
 {name="defended",target={weaponIndex=11,dir=pi}},
 {name="ally",team="RED",target={team="RED"}},
 {name="submerged",target={submerged=true}},
 {name="melee-behind",target={x=410}},
 {name="npc",target={isAI=true,isPlayer=false}},
 {name="steal",weaponIndex=14,target={points=120}},
 {name="dagger",weaponIndex=7,target={}},
 {name="poison",target={},variant={val=1.18,poison=true}},
 {name="poison-resist",skin={poisonDmg=3,poisonTime=2},target={skin={poisonRes=true}}},
 {name="poison-gear",skin={poisonDmg=4,poisonTime=2},target={}},
 {name="devils-tail",tail={id=20},target={}},
 {name="thorns",tail={id=14},target={}},
 {name="dragon-cape",tail={id=2},target={}},
 {name="emerald",variant={val=1.18,lifesteal=0.15},target={}},
 {name="lifesteal-skin",skin={healD=0.2},target={}},
 {name="reflection",target={skin={dmg=0.2,dmgK=0.4}}},
 {name="knockback",weaponIndex=7,target={weightM=1.5}}
}
local function f(v) return string.format("%.6f",v or 0) end
local function fix(v,precision)
 local m=10^precision
 return math.floor(v*m+0.5)/m
end
local function j(v) if v==nil then return "-" end return tostring(v) end
for _,v in ipairs(fixtures) do
 local events={}
 local player={
   id="self",sid=7,isPlayer=true,team=v.team,active=true,alive=true,
   x=v.x or 500,y=500,dir=0,scale=35,weaponIndex=v.weaponIndex or 0,
   xVel=0,yVel=0,noMovTimer=220,slowMult=1,health=60,maxHealth=100,
   wood=0,food=0,stone=0,points=0,XP=0,skin=v.skin,tail=v.tail,
   powers={power=1},dragonUntil=0,superUntil=0,sentTo={self=true}
 }
 player.canSee=function()return true end
 player.variant=function()return v.variant or {val=1}end
 player.addResource=function(self,rtype,amount)
   events[#events+1]="RES:"..rtype..":"..f(amount)
   if rtype==3 then self.points=self.points+amount
   else
     local name=Config.resourceTypes[rtype+1]
     self[name]=self[name]+amount
   end
 end
 player.earnXP=function(self,amount)
   events[#events+1]="XP:"..f(amount)
   self.XP=self.XP+amount
 end
 player.changeHealth=function(self,amount,doer)
   events[#events+1]="SELFHP:"..f(amount)
   self.health=self.health+amount
   return self.health<=0
 end
 player.sendAnimation=function(self,hit)
   events[#events+1]="ANIM:"..hit
 end
 player.changeItemCount=function(self,index,n)
   events[#events+1]="ITEM:"..index..":"..n
 end
 player.send=function(self,name,...)
   local fields={}
   for i=1,select("#",...) do
     local val=select(i,...)
     fields[i]=type(val)=="number" and f(val) or j(val)
   end
   events[#events+1]="SEND:"..name..":"..table.concat(fields,",")
 end
 local players={player}
 local ais={}
 local target=nil
 if v.target then
   local spec=v.target
   target={
     id="target",sid=8,team=spec.team,isPlayer=spec.isPlayer~=false,
     isAI=spec.isAI or false,alive=true,submerged=spec.submerged or false,
     x=spec.x or 570,y=spec.y or 500,scale=35,dir=spec.dir or 1.5,
     xVel=0,yVel=0,health=100,points=spec.points or 120,
     weightM=spec.weightM or 1,weaponIndex=spec.weaponIndex,
     skin=spec.skin,tail=spec.tail,dmgOverTime={}
   }
   target.changeHealth=function(self,amount)
     events[#events+1]="ENEMYHP:"..f(amount)
     self.health=self.health+amount
     return self.health<=0
   end
   target.addResource=function(self,rtype,amount)
     events[#events+1]="ENEMYRES:"..rtype..":"..f(amount)
     if rtype==3 then self.points=self.points+amount end
   end
   if target.isAI then ais[#ais+1]=target
   else players[#players+1]=target end
 end
 local world=World.new({config=Config,random=function()return 0.5 end})
 local function makeObj(spec)
   local owner
   if spec.hostileOwner then owner={sid=13,team="BLUE"}
   elseif spec.owner then owner=player end
   local obj=world:addObject(spec.x or 570,spec.y or 500,spec.scale or 30,spec.type)
   obj.owner=owner
   obj.hideFromEnemy=spec.hideFromEnemy
   obj.dontGather=spec.dontGather
   obj.health=spec.health
   obj.req=spec.req
   obj.group=spec.owner and {id=1,layer=0} or nil
   obj.sentTo={[player.id]=true}
   obj.changeHealth=function(self,amount)
     self.health=self.health+amount
     return self.health<=0
   end
   return obj
 end
 local obj=v.obj and makeObj(v.obj) or nil
 local second=v.secondObj and makeObj(v.secondObj) or nil
 local function hitObject(object,dir)
   if player.active and object.sentTo[player.id] then
     if not object.active then player:send("Q",object.sid)
     elseif player:canSee(object) then player:send("L",fix(dir,1),object.sid) end
   end
   if not object.active and object.owner==player then
     player:changeItemCount(object.group.id,-1)
   end
 end
 Gather.step(player,{
   config=Config,weapon=weapons[player.weaponIndex],
   weapons=weapons,world=world,players=players,ais=ais,nowMs=10000,
   hitObject=hitObject,disableObject=function(object)world:disableObject(object)end
 })
 local fields={
   "GATHER",v.name,f(player.noMovTimer),f(player.slowMult),
   f(player.wood),f(player.food),f(player.stone),f(player.points),f(player.XP),
   f(player.health),f(player.xVel),f(player.yVel),f(player.dragonUntil),
   obj and (obj.active and 1 or 0) or "-",
   obj and f(obj.health) or "-",
   second and (second.active and 1 or 0) or "-",
   target and f(target.health) or "-",
   target and f(target.xVel) or "-",
   target and f(target.yVel) or "-",
   target and f(target.points) or "-",
   target and f(target.dmgOverTime.dmg) or "-",
   target and f(target.dmgOverTime.time) or "-",
   table.concat(events,";")
 }
 print(table.concat(fields,"|"))
end
