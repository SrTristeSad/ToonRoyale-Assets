-- SPDX-License-Identifier: AGPL-3.0-only
-- Same 18 scenarios and 3 steps as whole original Player.update JS fixture.
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local PlayerUpdate=require("server-lua.world.player_update")
local scenarios={
 {name="idle",delta=33},
 {name="walk",delta=100,moveDir=0.75},
 {name="coast",delta=95,moveDir=false,xVel=0.24,yVel=-0.12},
 {name="slow",delta=111,slowMult=0.3,moveDir=2.35},
 {name="river",delta=111,x=7200,y=7200},
 {name="snow",delta=111,y=200},
 {name="regen",delta=310,skin={healthRegen=3,spdMult=0.85}},
 {name="poison",delta=200,dmgOverTime={dmg=3,time=2,doer="enemy"}},
 {name="hammer-hit",delta=100,hits=1,mouseState=0},
 {name="hammer-auto",delta=100,autoGather=1},
 {name="build-walk",delta=111,buildIndex=0,gathering=1},
 {name="bow",delta=100,weaponIndex=9,gathering=1},
 {name="bow-nothing",delta=100,weaponIndex=9,gathering=1,resources=false},
 {name="musket",delta=100,weaponIndex=15,gathering=1,dir=0.75},
 {name="turret-hat",delta=100,skin={turret=true},shootCount=25},
 {name="locked",delta=100,lockMove=true,xVel=0.3,yVel=0.2},
 {name="stone-collision",delta=100,obstacle=true},
 {name="death-mid-tick",delta=100,dmgOverTime={dmg=150,time=1,doer="enemy"}}
}
local function fmt(x)return string.format("%.6f",x or 0)end
local function g(x)
 if x==nil then return "~" end
 if x==true then return "true" end
 if x==false then return "false" end
 if type(x)=="number" then return fmt(x) end
 return tostring(x)
end
-- Values correspond to the original shared/config/items.js, checked by
-- the Node fixture; the future gameplay adapter must supply full tables.
local items={
 weapons={
  [0]={id=0,gather=1,range=65,dmg=25,speed=300},
  [9]={id=9,projectile=0,spdMult=0.75,speed=600,req={"wood",4}},
  [15]={id=15,projectile=5,spdMult=0.6,rec=0.35,speed=1500,req={"stone",10}}
 },
 projectiles={
  [0]={range=1000,speed=1.6,dmg=25,scale=103,layer=0},
  [5]={range=1400,speed=3.6,dmg=50,scale=160,layer=0}
 }
}
for _,s in ipairs(scenarios) do
 local events={}
 local p={
  id="p",sid=1,alive=true,isPlayer=true,
  x=s.x or 500,y=s.y or 500,scale=Config.playerScale,
  speed=Config.playerSpeed,xVel=s.xVel or 0,yVel=s.yVel or 0,
  dir=s.dir or 0.25,moveDir=s.moveDir==nil and 0.4 or s.moveDir,
  buildIndex=s.buildIndex or -1,weaponIndex=s.weaponIndex or 0,
  hits=s.hits or 0,gathering=s.gathering or 0,
  mouseState=s.mouseState or 0,autoGather=s.autoGather or 0,
  lockMove=s.lockMove or false,noMovTimer=0,slowMult=s.slowMult or 1,
  zIndex=0,healCol=0,reloads={},shootCount=s.shootCount or 250,
  skin=s.skin,tail=nil,powers={speed=1,power=1,god=0},
  health=100,maxHealth=100,
  shameTimer=0,shameCount=0,pps=0,dmgOverTime=s.dmgOverTime or {},
  superUntil=0,dragonUntil=0
 }
 if s.moveDir==false then p.moveDir=nil end
 p.changeHealth=function(self,amount,who)
   events[#events+1]="HP:"..fmt(amount)..":"..(who==self and "self" or g(who))
   self.health=math.min(100,self.health+amount)
   if self.health<=0 then self.alive=false end
 end
 p.addResource=function(self,rtype,amount,auto)
   events[#events+1]="RES:"..rtype..":"..fmt(amount)..":"..(auto and 1 or 0)
 end
 p.gather=function(self)
   events[#events+1]="GATHER"
   self.noMovTimer=0
   self.slowMult=math.max(0,self.slowMult-0.3)
 end
 p.hasRes=function(self,weapon,cost)
   events[#events+1]="HAS:"..weapon.id..":"..g(cost)
   return s.resources~=false
 end
 p.useRes=function(self,weapon,cost)
   events[#events+1]="USE:"..weapon.id..":"..g(cost)
 end
 p.shootTurret=function(self)
   events[#events+1]="TURRET"
   self.shootCount=250
 end
 local players={p}
 local world=World.new({config=Config,random=function()return 0.5 end})
 if s.obstacle then world:addObject(555,500,30,2) end
 local ctx={
   items=items,config=Config,world=world,players=players,ais={},nowMs=10000,
   addProjectile=function(...)
     local a={}
     for i=1,select("#",...) do
       local x=select(i,...)
       a[i]=x==p and "self" or g(x)
     end
     events[#events+1]="SHOT:"..table.concat(a,",")
   end
 }
 for tick=1,3 do
   PlayerUpdate.step(p,s.delta,ctx)
   print(table.concat({"FULL",s.name,tick,p.alive and 1 or 0,fmt(p.x),fmt(p.y),
     fmt(p.xVel),fmt(p.yVel),fmt(p.health),fmt(p.slowMult),
     fmt(p.noMovTimer),p.hits,p.gathering,
     p.reloads[p.weaponIndex] and fmt(p.reloads[p.weaponIndex]) or "~",
     fmt(p.shootCount),fmt(p.shameTimer),fmt(p.zIndex),
     table.concat(events,";")},"|"))
 end
end
