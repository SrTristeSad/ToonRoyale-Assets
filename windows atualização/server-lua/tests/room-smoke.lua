-- SPDX-License-Identifier: AGPL-3.0-only
-- Integration smoke: Room -> GameLoop -> complete PlayerUpdate,
-- Projectile.update, Structures.update, SyncPlayers and SyncObjects.
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local Room=require("server-lua.world.room")
local function assertEqual(a,b,msg)
  assert(a==b,(msg or "mismatch")..": "..tostring(a).." != "..tostring(b))
end
local items={
 weapons={[0]={id=0,gather=1,range=65,speed=300,dmg=25}},
 projectiles={[0]={dmg=25,scale=103,speed=1.6,range=1000,layer=0}}
}
local events={}
local function log(s) events[#events+1]=s end
local services={
 ensureAnimals=function()log("animals.spawn")end,
 updateLeaders=function()log("leaderboard.rank")end,
 sendLeaderboard=function()log("leaderboard.send")end,
 sendMinimap=function(_,p)log("minimap:"..p.sid)end,
 sendStats=function(_,p,sid)log("stats:"..p.sid..":"..sid)end,
 syncAnimals=function(_,p)log("animals.sync:"..p.sid)end
}
local ok=pcall(function()Room.new({items=items,nowMs=10000,services={}})end)
assert(not ok,"unported services must never be silently stubbed")
local world=World.new({config=Config,random=function()return 0.5 end})
local room=Room.new({items=items,world=world,nowMs=10000,services=services})
local player={
 id="guest",sid=0,active=true,alive=true,spawned=true,isPlayer=true,
 x=500,y=500,dir=0.4,scale=35,speed=Config.playerSpeed,
 xVel=0,yVel=0,moveDir=0.25,zIndex=0,healCol=0,
 health=100,maxHealth=100,points=0,age=1,
 name="Guest",skinColor=0,skinIndex=0,tailIndex=0,iconIndex=0,
 isLeader=false,anon=false,disguised=false,morph=0,dive=0,
 powers={speed=1,power=1,god=0},
 buildIndex=-1,weaponIndex=0,weaponXP={},
 gathering=0,autoGather=0,mouseState=0,hits=0,reloads={},
 noMovTimer=0,slowMult=1,shootCount=0,
 shameTimer=0,shameCount=0,dmgOverTime={},pps=0,
 chatCooldown=500,tribeCooldown=1000,pingCooldown=1500,
 watchStats=0,visiblePlayers={},attrCache={},sentTo={},
 send=function(self,name,...) log("packet:"..name)end,
 canSee=function()return true end,
 variant=function()return {id=0,val=1}end,
 gather=function()log("gather")end,
 changeHealth=function(self,delta)self.health=self.health+delta end,
 addResource=function(self,kind,amount)log("resource:"..kind)end,
 shootTurret=function(self)log("turret")end
}
room:bindPlayer(player)
assertEqual(#room.players,1,"bound player")
assertEqual(room.players[1],player,"same player")
-- Bind does not duplicate identity when an existing player is passed.
room:bindPlayer(player)
assertEqual(#room.players,1,"no duplicate players")
local building=world:addDynamic(1000,500,0,45,2,
  {id=10,group={id=3,layer=1},health=400,doUpdate=true,turnSpeed=0.0016},player)
assertEqual(#world.updateObjects,1,"real updating building")
local shot=room.projectile_manager:addProjectile(130,800,0,1000,1.6,0,player,nil,0)
assertEqual(type(shot.update),"function","real Projectile.update bound")
assertEqual(#room.projectiles,1,"shared projectile collection")
for _,now in ipairs({10000,10100,10200,10300}) do
  room:tick(now)
end
assert(player.x>500,"real player physics moved player")
assert(shot.x>130,"real projectile moved after spawn-frame skip")
assert(building.dir>0,"real structure animation advanced")
assertEqual(player.chatCooldown,200,"original Game.tick chat timer")
local names={}
for _,event in ipairs(events) do names[event]=true end
for _,name in ipairs({"packet:D","packet:a","packet:H","packet:X",
  "animals.spawn","animals.sync:0","leaderboard.rank",
  "leaderboard.send","minimap:0","stats:0:0"}) do
  assert(names[name],"missing real integration callback "..name)
end
-- Crucial Node order: player movement, projectile, structure, leaderboard, sync.
local first={}
for i,event in ipairs(events) do
  if not first[event] then first[event]=i end
end
assert(first["animals.spawn"]<first["leaderboard.rank"],"Game.tick phase ordering")
assert(first["leaderboard.rank"]<first["packet:D"],"sync follows rankings")
assertEqual(room.lastTick,10300,"room clock")
print("PASS Room.tick -> Player.update -> Projectile -> Structures -> S2C packets")
print("PASS missing subsystems require explicit services; no fallback game invented")
