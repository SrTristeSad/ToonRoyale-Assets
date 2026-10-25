-- SPDX-License-Identifier: AGPL-3.0-only
-- Literal behavior port of server/src/mooio/bots.js (LOCAL non-V2 server).
-- Bots use actual Player/Room mechanics, not simulated combat/resources.
local Catalogue=require("server-lua.world.catalogue")
local Loadout=require("server-lua.world.bot_loadout")
local Goals=require("server-lua.world.bot_goals")
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
 player:setUserData({name=names[index+1],skin=index%7})
 player:spawn(false)
 local a={p=player,index=index,target=nil,targetUntil=0,wander=nil,at=0,
  prevX=player.x,prevY=player.y,stuck=0,detour=0,detourDir=0,respawn=0,
  lastTarget=nil,lastMode=nil,holdUntil=0,
  lastHeal=-10000,shopAt=2200+index*350,lastPurpose=nil,
  socialAt=12500+index*3400,prefersGroup=index%4~=3}
 self.agents[#self.agents+1]=a
 return a
end
-- Optional groups use the real in-world tribe manager. A bot may remain
-- independent, create a tribe, join a nearby friend, or later leave. This is
-- never a rule requiring every bot to form a team.
function Bots:socialize(a)
 local tribes=self.game.tribes
 if not tribes or type(tribes.create)~="function" then return false end
 local p=a.p
 if not p.alive or not a.prefersGroup then return false end
 if p.team then
  if math.random()<0.08 then
   tribes:leaveTribe(p)
   return true
  end
  return false
 end
 if math.random()>0.46 then return false end
 local friend,best=nil,650
 for _,other in ipairs(self.agents) do
  local peer=other.p
  if other~=a and peer.alive and other.prefersGroup
   and peer.spaceId==p.spaceId
   and (not peer.team or tribes.tribes[peer.team])
   and (not peer.team or peer.team~=p.team) then
   local d=dist(p,peer)
   if d<best then friend,best=peer,d end
  end
 end
 if not friend then return false end
 if friend.team then
  local tribe=tribes.tribes[friend.team]
  if not tribe or tribe.clan then return false end
  tribes:requestJoin(p,friend.team)
  tribes:answerRequest(tribe.owner,p.sid,true)
  return p.team==friend.team
 end
 local name="Tribo"..a.index
 if not tribes:create(name,p) then return false end
 tribes:requestJoin(friend,name)
 tribes:answerRequest(p,friend.sid,true)
 return true
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
 local enhanced=game.config and game.config.server~=nil
 local catalogue=game.items or Catalogue
 -- Real age points, no artificial levels or free weapons. Each step invokes
 -- the same Equipment.handle("H") validation used by a human player.
 if type(player.upgradePoints)=="number" and player.upgradePoints>0
   and player.weapons and player.items and type(player.addItem)=="function" then
  for _=1,3 do
   if not Loadout.upgrade(player,catalogue,a.index+1) then break end
  end
 end
 if enhanced and a.at>=a.shopAt and player.points~=nil then
  a.shopAt=a.at+2100+(a.index%3)*500
  Goals.purchase(player,a.index+1,catalogue)
 end
 if a.at>=a.socialAt and game.tribes then
  a.socialAt=a.at+15000+math.random()*17000
  self:socialize(a)
 end
 if player.health<player.maxHealth*0.84 and player.food>=10
   and a.at-a.lastHeal>=850 then
  player.buildIndex=0
  player:buildItem((catalogue.list and catalogue.list[0]) or Catalogue.list[0])
  player.buildIndex=-1
  a.lastHeal=a.at
  -- The unmodified JS compatibility fixture retains its original timer.
  -- Extended local rooms keep a monotonic clock for long-term decisions.
  if not enhanced then a.at=0 end
 end
 local threat,distance=nil,math.huge
 local extra=player.weapons and player.weapons[1]
 local secondary=extra and (game.items or Catalogue).weapons[extra]
 local longRange=(secondary and secondary.projectile~=nil)
   and Loadout.attackRange(secondary,game.items or Catalogue) or 490
 local sight=math.min(840,math.max(490,longRange))
 for _,opponent in ipairs(game.players) do
  if opponent~=player and opponent.alive
     and (opponent.spaceId or "surface")==(player.spaceId or "surface")
     and not (truth(player.team) and opponent.team==player.team) then
   local d=dist(player,opponent)
   if d<distance and d<sight then threat,distance=opponent,d end
  end
 end
 for _,animal in ipairs(game.ais) do
  if animal.alive and animal.active and not truth(animal.spawnCounter)
    and (animal.spaceId or "surface")==(player.spaceId or "surface")
    and not truth(animal.submerged) and animal.index<7 then
   local d=dist(player,animal)
   if d<distance and d<380 and (truth(animal.hostile) or animal.index==4) then
    threat,distance=animal,d
   end
  end
 end
 local target,mode=nil,"wander"
 local purpose=nil
 local weak=player.health<player.maxHealth*(enhanced and 0.49 or 0.37)
 if threat and distance<sight then
  target=threat
  local opponentStrong=enhanced and threat.isPlayer
    and (threat.health or 100)>player.health*1.5
  local unsafe=enhanced and not Goals.shouldFight(player,threat,distance)
  mode=(weak or opponentStrong or unsafe) and "flee" or "fight"
 else
  if enhanced then
   target,purpose=Goals.selectResource(player,game.game_objects,
     a.index+1,catalogue,1200)
  else
   local best=math.huge
   for _,object in ipairs(game.game_objects) do
    if (player.spaceId==nil or player.spaceId=="surface")
      and object.active and not truth(object.isItem) and
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
 
  end
  if target then mode="gather"
  else
   for _,animal in ipairs(game.ais) do
    if animal.alive and animal.active and not truth(animal.spawnCounter)
      and (animal.spaceId or "surface")==(player.spaceId or "surface")
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
   -- The original Node RoomBots persists a.heading between wander decisions.
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
 -- Reduce target thrashing between resource nodes and enemies; a real
 -- imminent threat can always interrupt gathering or roaming.
 if enhanced then
  if mode=="gather" and a.lastTarget and a.lastTarget.active
    and a.lastMode=="gather" and a.lastPurpose==purpose
    and a.at<a.holdUntil
    and dist(player,a.lastTarget)<620 then
    target=a.lastTarget
  end
  if a.lastTarget~=target or a.lastMode~=mode then
    a.lastTarget=target;a.lastMode=mode;a.holdUntil=a.at+1700
    a.lastPurpose=purpose
  end
  if player.team and mode=="wander" and math.random()<0.32 then
    for _,mate in ipairs(game.players) do
      if mate~=player and mate.alive and mate.team==player.team
        and dist(player,mate)>180 and dist(player,mate)<1000 then
        target=mate;mode="follow";break
      end
    end
  end
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
 if enhanced and (player.spaceId==nil or player.spaceId=="surface") then
  local limit=nilOr(game.config and game.config.mapScale,14400)
  local aheadX=player.x+math.cos(direction)*170
  local aheadY=player.y+math.sin(direction)*170
  if aheadX<85 or aheadX>limit-85
    or aheadY<85 or aheadY>limit-85 then
    -- Prefer a usable turn rather than blindly pushing against the border.
    local left=direction+pi/2
    local lx=player.x+math.cos(left)*170
    local ly=player.y+math.sin(left)*170
    direction=(lx>85 and lx<limit-85 and ly>85 and ly<limit-85)
      and left or (direction-pi/2)
  end
 end
 a.prevX=player.x;a.prevY=player.y
 player.dir=angle(player,target)
 if (mode=="gather" and d<85) or (mode=="wander" and d<45)
  or (mode=="follow" and d<180) then
  player.moveDir=nil
 else player.moveDir=direction end
 player.mouseState=0
 local catalogue=game.items or Catalogue
 if player.weapons then
  local best=Loadout.chooseWeapon(player,catalogue,mode,d,a.index+1)
  if catalogue.weapons[best] then
   player.weaponIndex=best
   -- Selecting a weapon dismisses any previously selected buildable item.
   player.buildIndex=-1
  end
 end
 local selected=catalogue.weapons[player.weaponIndex]
 local range=Loadout.attackRange(selected,catalogue)
 if (mode=="fight" or mode=="gather" or mode=="hunt")
  and d<range+nilOr(target.scale,0)*0.8+20 and mode~="flee" then
  player.mouseState=1
  player.gathering=1
 end
end
return Bots
