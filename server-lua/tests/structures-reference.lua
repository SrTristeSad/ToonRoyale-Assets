-- Lua counterpart of structures-reference.mjs. No fake turret simulation.
local World=require("server-lua.world.objects")
local Structures=require("server-lua.world.structures")
local Config=require("src.game.config")
local trials={
 {name="idle"},{name="windmill",windmill=true},
 {name="owner-only",turret=true,shootCount=20},
 {name="enemy",turret=true,shootCount=20,target={x=250}},
 {name="ally",turret=true,shootCount=20,team="RED",target={x=250,team="RED"}},
 {name="enemy-team",turret=true,shootCount=20,team="RED",target={x=250,team="BLUE"}},
 {name="invisible",turret=true,shootCount=20,target={x=250,powers={invisible=1}}},
 {name="hidden-hat",turret=true,shootCount=20,target={x=250,skin={invisTimer=10},noMovTimer=20}},
 {name="anti-turret",turret=true,shootCount=20,target={x=250,skin={antiTurret=true}}},
 {name="npc",turret=true,shootCount=20,target={x=250,isAI=true}},
 {name="npc-submerged",turret=true,shootCount=20,target={x=250,isAI=true,submerged=true}},
 {name="npc-spawning",turret=true,shootCount=20,target={x=250,isAI=true,spawnCounter=150}},
 {name="nearer",turret=true,shootCount=20,target={x=260},secondTarget={x=190}},
 {name="cooldown",turret=true,shootCount=400,target={x=200}},
 {name="range",turret=true,shootCount=20,target={x=785,scale=35}},
 {name="out-range",turret=true,shootCount=20,target={x=800,scale=35}},
 {name="no-visibility",turret=true,shootCount=20,target={x=200},see=false},
 {name="damaged",turret=true,shootCount=20,target={x=250},disabled=true},
 {name="two-turrets",turret=true,shootCount=20,target={x=250},secondTurret=true},
 {name="wiggle",windmill=true,xWiggle=8,yWiggle=-6}
}
local f=function(n)return string.format("%.6f",n or 0)end
local function fmtArg(v)
 if v==nil then return "-" end
 if type(v)=="number" then return f(v) end
 return tostring(v)
end
local items={projectiles={[1]={layer=1,dmg=25,scale=20}}}
for _,sc in ipairs(trials) do
 local events={}
 local function makePlayer(id,sid,opts)
   local p={id=id,sid=sid,x=100,y=100,scale=35,alive=true,active=true,
     powers={invisible=0},noMovTimer=0}
   for k,v in pairs(opts or {}) do p[k]=v end
   p.canSee=function()return sc.see~=false end
   p.send=function(self,name,...)
     local args={}
     for i=1,select("#",...) do args[i]=fmtArg(select(i,...)) end
     events[#events+1]="SEND:"..id..":"..name..":"..table.concat(args,",")
   end
   return p
 end
 local owner=makePlayer("owner",1,{team=sc.team})
 local players={owner}
 local ais={}
 local function makeTarget(s,id,sid)
   local p=makePlayer(id,sid,{
     x=s.x or 250,y=s.y or 100,scale=s.scale or 35,
     skin=s.skin,powers=s.powers or {invisible=0},
     team=s.team,noMovTimer=s.noMovTimer or 0,
     submerged=s.submerged or false,spawnCounter=s.spawnCounter or 0
   })
   if s.isAI then p.isAI=true;ais[#ais+1]=p else players[#players+1]=p end
   return p
 end
 if sc.target then makeTarget(sc.target,"enemy",2)end
 if sc.secondTarget then makeTarget(sc.secondTarget,"enemy2",3)end
 local world=World.new({config=Config,random=function()return 0.5 end})
 local function makeStructure(sid,x)
   local data
   if sc.turret then
     data={id=17,doUpdate=true,projectile=1,shootRate=2200,shootRange=700,
       health=800,group={id=7,layer=1}}
   else
     data={id=10,doUpdate=true,turnSpeed=0.0016,pps=1,health=400,
       group={id=3,layer=1}}
   end
   local obj=world:addDynamic(x,100,0,sc.turret and 43 or 45,nil,data,owner)
   assert(obj.sid==sid,"wrong reference structure SID")
   if sc.shootCount and sc.turret then obj.shootCount=sc.shootCount end
   if sc.xWiggle then obj.xWiggle=sc.xWiggle end
   if sc.yWiggle then obj.yWiggle=sc.yWiggle end
   for _,p in ipairs(players) do obj.sentTo[p.id]=1 end
   return obj
 end
 local structure=makeStructure(0,100)
 local second=sc.secondTurret and makeStructure(1,220) or nil
 if sc.disabled then world:disableObject(structure) end
 local options={addProjectile=function(...)
   local args={}
   for i=1,select("#",...) do
     local v=select(i,...)
     args[i]=v==owner and "owner" or fmtArg(v)
   end
   events[#events+1]="SHOT:"..table.concat(args,",")
 end}
 for tick=1,3 do
   Structures.update(world,players,ais,items,100,options)
   print(table.concat({"STRUCT",sc.name,tick,#world.updateObjects,
     f(structure.dir),f(structure.shootCount),f(structure.xWiggle),
     f(structure.yWiggle),structure.active and 1 or 0,
     second and f(second.dir) or "-",
     second and f(second.shootCount) or "-",
     table.concat(events,";")},"|"))
 end
end
