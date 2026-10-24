-- Same cases as projectile-reference.mjs, executed by the Lua port.
local World=require("server-lua.world.objects")
local Projectiles=require("server-lua.world.projectiles")
local Config=require("src.game.config")
local cases={
 {name="fly"},{name="moving-expiry",range=70},{name="near-expiry",range=1},
 {name="player",target={x=145}},{name="shield",target={x=145,weaponIndex=11,dir=math.pi}},
 {name="team",team="BLUE",target={x=145,team="BLUE"}},
 {name="enemy-team",team="BLUE",target={x=145,team="RED"}},
 {name="npc",target={x=145,isAI=true}},
 {name="far-enemy",target={x=400}},
 {name="wall",structure={x=145,health=50,projDmg=true}},
 {name="break-wall",structure={x=145,health=10,projDmg=true,owner=true}},
 {name="solid",structure={x=145,health=10,projDmg=false}},
 {name="ignore-wall",structure={x=145,health=10,projDmg=true},ignoreObj=0},
 {name="invisible-wall",structure={x=145,health=10,projDmg=true,ignoreCollision=true}},
 {name="hidden-layer",structure={x=145,layer=-1,health=10,projDmg=true}},
 {name="two-structures",structure={x=155,health=10,projDmg=true},secondStructure={x=135,health=10,projDmg=true}},
 {name="closer-player",target={x=150},secondTarget={x=130}},
 {name="offscreen",see=false,target={x=145}},
 {name="observer",target={x=145},observer=true},
 {name="reuse-projectile",range=1,reuse=true}
}
local function num(v)
 if v==nil then return "-" end
 if type(v)=="number" then
   if v==math.floor(v) then return string.format("%.0f",v) end
   return string.format("%.6f",v)
 end
 return tostring(v)
end
local function fmt(n)return string.format("%.6f",n or 0)end
local items={
 projectiles={[0]={dmg=25,scale=103,range=1000,speed=1.6,layer=0}},
 weapons={[0]={},[11]={shield=0.2}}
}
for _,sc in ipairs(cases) do
 local events={}
 local function makePlayer(id,sid,opts)
   local p={
     id=id,sid=sid,active=true,alive=true,isPlayer=true,
     x=100,y=100,dir=0,scale=35,weaponIndex=0,
     xVel=0,yVel=0,health=100,sentTo={}
   }
   for k,v in pairs(opts or {}) do p[k]=v end
   p.canSee=function()return sc.see~=false end
   p.send=function(self,name,...)
     local fields={}
     for i=1,select("#",...) do fields[i]=num(select(i,...)) end
     events[#events+1]="SEND:"..self.id..":"..name..":"..table.concat(fields,",")
   end
   p.changeHealth=function(self,amount)
     events[#events+1]="HP:"..self.id..":"..fmt(amount)
     self.health=self.health+amount
     return self.health<=0
   end
   p.changeItemCount=function(self,group,amount)
     events[#events+1]="COUNT:"..self.id..":"..group..":"..amount
   end
   return p
 end
 local owner=makePlayer("owner",1,{team=sc.team})
 local players={owner}
 local ais={}
 local function createTarget(def,id,sid)
   local p=makePlayer(id,sid,{x=def.x or 145,y=def.y or 100,
     team=def.team,weaponIndex=def.weaponIndex or 0,dir=def.dir or 0,
     scale=def.scale or 35})
   if def.isAI then
     p.isPlayer=false;p.isAI=true
     ais[#ais+1]=p
   else players[#players+1]=p end
   return p
 end
 local target=sc.target and createTarget(sc.target,"enemy",2) or nil
 local secondTarget=sc.secondTarget and createTarget(sc.secondTarget,"enemy2",3) or nil
 if sc.observer then players[#players+1]=makePlayer("observer",4,{x=600,y=600}) end
 local world=World.new({config=Config,random=function()return 0.5 end})
 local function makeObject(def)
   local itemOwner=def.owner and owner or nil
   local data={health=def.health,projDmg=def.projDmg,
     ignoreCollision=def.ignoreCollision,id=5,
     group={id=1,layer=def.layer or 0},req={"wood",10}}
   local obj=world:addDynamic(def.x or 145,def.y or 100,0,def.scale or 40,2,data,itemOwner)
   for _,player in ipairs(players) do obj.sentTo[player.id]=1 end
   return obj
 end
 local obj=sc.structure and makeObject(sc.structure) or nil
 local secondObj=sc.secondStructure and makeObject(sc.secondStructure) or nil
 local manager=Projectiles.new({world=world,players=players,ais=ais,items=items,config=Config})
 if sc.reuse then
   local old=manager:addProjectile(5000,5000,0,10,1.6,0,owner,nil,0)
   old.active=false
 end
 local proj=manager:addProjectile(100,100,0,sc.range or 1000,1.6,0,owner,sc.ignoreObj,0)
 for tick=1,3 do
   manager:update(40)
   print(table.concat({
     "PROJ",sc.name,tick,#manager.projectiles,proj.sid,
     proj.active and 1 or 0,proj.skipMov and 1 or 0,
     fmt(proj.x),fmt(proj.y),fmt(proj.range),
     target and fmt(target.health) or "-",
     target and fmt(target.xVel) or "-",
     secondTarget and fmt(secondTarget.health) or "-",
     obj and fmt(obj.health) or "-",
     obj and (obj.active and 1 or 0) or "-",
     secondObj and fmt(secondObj.health) or "-",
     table.concat(events,";")
   },"|"))
 end
end
