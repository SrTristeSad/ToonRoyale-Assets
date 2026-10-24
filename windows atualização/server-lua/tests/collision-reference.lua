-- Native Lua collision snapshots for original Node ObjectManager scenarios.
local Collision=require("server-lua.world.collision")
local Random=require("src.protocol.original_crypto")
local Config=require("src.game.config")
local fmt=function(n) return string.format("%.9f",n or 0) end
for _,kind in ipairs({"solid","apart","player","trap","boost","heal","damage","teleport"}) do
  local owner={team="Blue",sid=22}
  local player={sid=1,x=50,y=70,xVel=0.24,yVel=-0.10,scale=35,zIndex=0,team="Red",
    health=100,skin=nil,lockMove=false,healCol=0,dmgOverTime={},colDmg=0}
  player.changeHealth=function(self,v) self.health=self.health+v;return self.health<=0 end
  local other={sid=10,x=75,y=75,dir=0,scale=20,type=2,active=true,
    owner=owner,colDiv=1,isItem=false}
  if kind=="apart" then other.x=500;other.y=700 end
  if kind=="player" then other.x=75;other.y=75;other.isPlayer=true;other.scale=35 end
  if kind=="trap" then other.ignoreCollision=true;other.trap=true;other.zIndex=2 end
  if kind=="boost" then other.ignoreCollision=true;other.boostSpeed=0.003;other.dir=1.1 end
  if kind=="heal" then other.ignoreCollision=true;other.healCol=8 end
  if kind=="damage" then other.dmg=20;other.pDmg=3;other.weightM=1.2 end
  if kind=="teleport" then other.ignoreCollision=true;other.teleport=true end
  local rng=Random.mulberry32(24680)
  local randInt=function(a,b) return math.floor(rng()*(b-a+1))+a end
  local result=Collision.checkCollision(player,other,0.5,{randomInt=randInt,config=Config})
  print(table.concat({"COL",kind,result and 1 or 0,fmt(player.x),fmt(player.y),
    fmt(player.xVel),fmt(player.yVel),fmt(other.x),fmt(other.y),player.health,
    player.lockMove and 1 or 0,player.healCol or 0,player.zIndex,
    player.dmgOverTime.dmg or 0,player.dmgOverTime.time or 0,
    other.hideFromEnemy==false and 1 or 0},"|"))
end
