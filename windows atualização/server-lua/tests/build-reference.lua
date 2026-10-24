-- Compare original buildItem semantics with Node test/build-reference.mjs.
local World=require("server-lua.world.objects")
local Build=require("server-lua.world.build")
local Config=require("src.game.config")
local function fmt(n)return string.format("%.5f",n)end
local function number(v)
 if v==nil then return "-" end
 if type(v)=="number" and v==math.floor(v) then return string.format("%.0f",v) end
 return tostring(v)
end
local groupFood={id=0,layer=0}
local groupWalls={id=1,layer=0,limit=30}
local groupMill={id=3,layer=1,limit=200}
local items={
 [3]={id=3,name="wood wall",scale=50,placeOffset=-5,group=groupWalls,
    req={"wood",10},health=380,projDmg=true},
 [10]={id=10,name="windmill",scale=45,placeOffset=5,group=groupMill,
    req={"wood",50,"stone",10},pps=1,health=400,turnSpeed=0.0016},
 [0]={id=0,name="apple",scale=22,group=groupFood,req={"food",10}},
 [2]={id=2,name="cheese",scale=27,group=groupFood,req={"food",25}}
}
items[0].consume=function(p)return p:changeHealth(20,p)end
items[2].consume=function(p)
 if p:changeHealth(30,p) or p.health<100 then
   p.dmgOverTime.dmg=-10
   p.dmgOverTime.doer=p
   p.dmgOverTime.time=5
   return true
 end
 return false
end
local trials={
 {name="wall",item=3},{name="windmill",item=10},
 {name="wall-angle",item=3,dir=1.2},
 {name="water",item=3,y=7200},{name="overlap",item=3,obstacle=true},
 {name="denied",item=3,canBuild=false},{name="noEat",item=0,skin={noEat=true}},
 {name="apple",item=0},{name="apple-full",item=0,health=100},
 {name="cheese",item=2},{name="cheese-full",item=2,health=100},
 {name="shame-trigger",item=0,hitTime=9950,shameCount=7},
 {name="shame-fading",item=0,hitTime=9700,shameCount=5},
 {name="shame-existing",item=0,shameTimer=1000},
 {name="reused-object",item=3,reuse=true},
 {name="short-respawn",item=3,buildIndex=3}
}
for _,sc in ipairs(trials) do
 local events={}
 local world=World.new({config=Config,random=function()return 0.5 end})
 local item=items[sc.item]
 local p={id="p",sid=7,x=500,y=sc.y or 500,dir=sc.dir or 0,
   scale=35,skin=sc.skin,
   health=sc.health or 60,maxHealth=100,
   hitTime=sc.hitTime or 0,shameCount=sc.shameCount or 0,
   shameTimer=sc.shameTimer or 0,buildIndex=sc.buildIndex or sc.item,
   pps=0,wood=100,food=100,stone=100,points=0,
   dmgOverTime={},itemCounts={}
 }
 p.canBuild=function(self,i)
   events[#events+1]="CAN:"..i.id
   return sc.canBuild~=false
 end
 p.changeItemCount=function(self,index,count)
   self.itemCounts[index]=(self.itemCounts[index] or 0)+count
   events[#events+1]="COUNT:"..index..":"..count
 end
 p.changeHealth=function(self,amount)
   events[#events+1]="HEALTH:"..amount
   if self.health>=self.maxHealth and amount>0 then return false end
   self.health=math.min(self.maxHealth,self.health+amount)
   return true
 end
 p.useRes=function(self,i)events[#events+1]="USE:"..i.id end
 if sc.obstacle then world:addDynamic(580,500,0,50,2,{},nil) end
 if sc.reuse then local o=world:addDynamic(4000,4000,0,50,2,{},nil);world:disableObject(o) end
 Build.use(p,item,world,{nowMs=10000})
 local descriptions={}
 for _,o in ipairs(world.objects) do
   descriptions[#descriptions+1]=table.concat({
      number(o.sid),o.active and 1 or 0,fmt(o.x),fmt(o.y),fmt(o.dir),
      number(o.scale),number(o.id),number(o.type),
      number(o.group and o.group.id),number(o.owner and o.owner.sid),
      number(o.health),#o.gridLocations,0
   },",")
 end
 print(table.concat({
   "BUILD",sc.name,p.buildIndex,p.health,p.shameCount,p.shameTimer,p.hitTime,p.pps,
   p.itemCounts[item.group.id] or 0,#world.objects,table.concat(descriptions,";"),
   table.concat(events,";")
 },"|"))
end
