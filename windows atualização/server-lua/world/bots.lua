-- SPDX-License-Identifier: AGPL-3.0-only
-- Literal behavior port of server/src/mooio/bots.js (LOCAL non-V2 server).
-- Bots use actual Player/Room mechanics, not simulated combat/resources.
local Catalogue=require("server-lua.world.catalogue")
local Bots={}
Bots.__index=Bots
local names={"Lince","Ari","Raposa","Falcao","Rubi","Tora","Lua","Caio"}
local pi=math.pi
local function dist(a,b)
 local x,y=a.x-b.x,a.y-b.y
 return math.sqrt(x*x+y*y)
end
local function angle(a,b)
 local y,x=b.y-a.y,b.x-a.x
 if math.atan2 then return math.atan2(y,x) end
 if x>0 then return math.atan(y/x) end
 if x<0 then return math.atan(y/x)+(y>=0 and pi or -pi) end
 if y>0 then return pi/2 end
 if y<0 then return -pi/2 end
 return 0
end
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function truth(v)return v~=nil and v~=false and v~=0 and v~="" end
local function nilOr(v,default) return truth(v) and v or default end
function Bots.parseBotCount(raw)
 if raw==nil or raw=="" then return 0 end
 local s=tostring(raw)
 assert(#s==1 and s:match("^[0-8]$"),
   "MOO_IO_BOT_COUNT must be an integer 0..8")
 return tonumber(s)
end
function Bots.new(game,count)
 local self=setmetatable({
  game=assert(game,"original Game required"),agents={},elapsed=0,
  thinkMs=270,count=Bots.parseBotCount(count)
 },Bots)
 for i=0,self.count-1 do self:create(i) end
 return self
end
function Bots:create(index)
 local game=self.game
 assert(type(game.addPlayer)=="function","original Game.addPlayer required for bot")
 local player=game:addPlayer({
   id="mooio-bot-"..index,ip="internal-bot",
   send=function()end
 })
 assert(player,"Room bot could not reserve a player slot")
 player.isBot=true
 player:setUserData({name="Bot "..names[index+1],skin=index%7})
 player:spawn(false)
 local a={p=player,index=index,target=nil,targetUntil=0,wander=nil,at=0,
  prevX=player.x,prevY=player.y,stuck=0,detour=0,detourDir=0,respawn=0}
 self.agents[#self.agents+1]=a
 return a
end
function Bots:tick(delta)
 self.elapsed=self.elapsed+delta
 if self.elapsed<self.thinkMs then return end
 local ms=self.elapsed
 self.elapsed=0
 for _,agent in ipairs(self.agents) do self:decide(agent,ms) end
end
function Bots:decide(a,delta)
 local game,player=self.game,a.p
 if not player.alive then
  a.respawn=a.respawn+delta
  if a.respawn>=4300 then
   a.respawn=0
   player:spawn(false)
   a.target=nil;a.wander=nil;a.stuck=0
  end
  return
 end
 a.respawn=0
 a.at=a.at+delta
 if player.health<player.maxHealth*0.74 and player.food>=10 and a.at>=850 then
  player.buildIndex=0
  player:buildItem(Catalogue.list[0])
  player.buildIndex=-1
  a.at=0
 end
 local threat,distance=nil,math.huge
 for _,opponent in ipairs(game.players) do
  if opponent~=player and opponent.alive and
     not (truth(player.team) and opponent.team==player.team) then
   local d=dist(player,opponent)
   if d<distance and d<490 then threat,distance=opponent,d end
  end
 end
 for _,animal in ipairs(game.ais) do
  if animal.alive and animal.active and not truth(animal.spawnCounter)
    and not truth(animal.submerged) and animal.index<7 then
   local d=dist(player,animal)
   if d<distance and d<380 and (truth(animal.hostile) or animal.index==4) then
    threat,distance=animal,d
   end
  end
 end
 local target,mode=nil,"wander"
 local weak=player.health<player.maxHealth*0.37
 if threat and distance<480 then
  target=threat
  mode=weak and "flee" or "fight"
 else
  local best=math.huge
  for _,object in ipairs(game.game_objects) do
   if object.active and not truth(object.isItem) and
      not truth(object.dontGather) and
      object.type>=0 and object.type<=3 then
    local d=dist(player,object)
    if d<=500 then
     local foodNeed=player.food<30 or player.health<75
     local score=d+((foodNeed and object.type~=1) and 125 or 0)
       +(object.type==3 and -25 or 0)
     if score<best then best=score;target=object end
    end
   end
  end
  if target then mode="gather"
  else
   for _,animal in ipairs(game.ais) do
    if animal.alive and animal.active and not truth(animal.spawnCounter)
      and not truth(animal.submerged) and animal.index<=1 then
     local d=dist(player,animal)
     if d<400 and (player.food<35 or player.health<70) then
      target=animal;mode="hunt";break
     end
    end
   end
  end
 end
 if not target then
  if not a.wander or a.targetUntil<a.at or dist(player,a.wander)<55 then
   local turn=(math.random()*2-1)*pi
   local heading=nilOr(a.heading,0)+turn
   a.heading=heading
   local limit=nilOr(game.config and game.config.mapScale,14400)
   a.wander={
    x=clamp(player.x+math.cos(heading)*470,80,limit-80),
    y=clamp(player.y+math.sin(heading)*470,80,limit-80)
   }
   a.targetUntil=a.at+2500+math.random()*2100
  end
  target=a.wander
 end
 local direction,d=angle(player,target),dist(player,target)
 if mode=="flee" then direction=direction+pi end
 if mode=="fight" and d<94 and player.health>35 then
  direction=direction+pi/2*(a.index%2==1 and 1 or -1)
 end
 if dist(player,{x=a.prevX,y=a.prevY})<4 and player.moveDir~=nil then
  a.stuck=a.stuck+delta
 else a.stuck=0 end
 if a.stuck>900 then
  a.detour=a.at+1300
  a.detourDir=direction+pi/2*(a.index%2==1 and 1 or -1)
  a.stuck=0
 end
 if a.at<a.detour then direction=a.detourDir end
 a.prevX=player.x;a.prevY=player.y
 player.dir=angle(player,target)
 if (mode=="gather" and d<85) or (mode=="wander" and d<45) then
  player.moveDir=nil
 else player.moveDir=direction end
 player.mouseState=0
 local weapon=game.items and game.items.weapons or Catalogue.weapons
 local selected=weapon[player.weaponIndex]
 local range=nilOr(selected and selected.range,70)
 if (mode=="fight" or mode=="gather" or mode=="hunt")
  and d<range+nilOr(target.scale,0)*0.8+20 and mode~="flee" then
  player.mouseState=1
  player.gathering=1
 end
end
return Bots
