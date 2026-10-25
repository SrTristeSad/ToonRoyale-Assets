-- Same scenarios and snapshot format as bots-reference.mjs (original Node).
local Bots=require("server-lua.world.bots")
local originalRandom=math.random
math.random=function()return 0.5 end
local function num(x)
 if x==nil then return "nil" end
 return string.format("%.6f",x)
end
local function makeGame(modifier)
 local p={x=1000,y=1000,scale=35,maxHealth=100,health=100,food=50,
  moveDir=nil,dir=0,mouseState=0,buildIndex=-1,weaponIndex=0,
  alive=true,spawnCalls=0,buildCalls=0}
 function p:setUserData(data)self.name=data.name;self.skin=data.skin end
 function p:spawn(x)self.spawnCalls=self.spawnCalls+1;self.alive=true end
 function p:buildItem(item)
  assert(item and item.id==0,"original food item required")
  self.buildCalls=self.buildCalls+1
 end
 local game={players={p},ais={},game_objects={},config={mapScale=14400},
  items={weapons={[0]={range=70}}}}
 function game:addPlayer()return p end
 if modifier then modifier(p,game) end
 local bots=Bots.new(game,1)
 return {p=p,g=game,b=bots,a=bots.agents[1]}
end
local function dump(name,x)
 local p,a=x.p,x.a
 -- Differential fixture compares the original Node bot prefix; runtime UI does not.
 print(table.concat({name,"Bot "..p.name,tostring(p.isBot),tostring(p.spawnCalls),
  tostring(p.buildCalls),tostring(p.mouseState),num(p.dir),
  num(p.moveDir),tostring(p.gathering or 0),num(a.at),num(a.stuck)},"|"))
end
local scenarios={
 {"WANDER",function()end,270},
 {"GATHER",function(_,g)
   g.game_objects[1]={active=true,type=1,isItem=false,
    dontGather=false,x=1040,y=1000,scale=30}
  end,270},
 {"FIGHT",function(_,g)
   g.players[2]={alive=true,x=1060,y=1000,scale=35}
  end,270},
 {"FLEE",function(p,g)
   p.health=30;g.players[2]={alive=true,x=1060,y=1000,scale=35}
  end,270},
 {"HEAL",function(p)p.health=70;p.food=15 end,900},
 {"HUNT",function(p,g)
   p.food=20;g.ais[1]={index=0,alive=true,active=true,
     x=1070,y=1000,scale=20}
  end,270},
 {"STUCK",function(p)p.moveDir=1 end,1100}
}
for _,entry in ipairs(scenarios) do
 local x=makeGame(entry[2]);x.b:decide(x.a,entry[3]);dump(entry[1],x)
end
-- The original LOCAL Node RoomBots never stores the temporary heading.
math.random=function()return 0.75 end
local repeatWander=makeGame()
repeatWander.b:decide(repeatWander.a,270)
local firstX,firstY=repeatWander.a.wander.x,repeatWander.a.wander.y
repeatWander.a.targetUntil=0
repeatWander.b:decide(repeatWander.a,270)
print("WANDER_REPEAT|"..num(firstX).."|"..num(firstY)..
 "|"..num(repeatWander.a.wander.x).."|"..
 num(repeatWander.a.wander.y).."|"..num(repeatWander.a.heading))
math.random=function()return 0.5 end
local dead=makeGame(function(p)p.alive=false end)
dead.b:decide(dead.a,2200);dead.b:decide(dead.a,2200)
dump("RESPAWN",dead)
local tick=makeGame()
tick.b:tick(100);tick.b:tick(170)
dump("TICK_270",tick)
for _,n in ipairs({"null","", "0",0,8,9,-1,1.5,"03",true}) do
 local raw=n
 if n=="null" then raw=nil end
 local ok,result=pcall(Bots.parseBotCount,raw)
 print("COUNT|"..(raw==nil and "null" or tostring(raw))..
  "|"..(ok and tostring(result) or "error"))
end
math.random=originalRandom
