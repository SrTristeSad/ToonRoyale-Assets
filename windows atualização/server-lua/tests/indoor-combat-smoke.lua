-- Verify that the actual Lua Room and original weapon/AI modules operate
-- inside custom map zones without damaging actors across walls or floors.
local Local=require("server-lua.local_server")
local Snapshot=require("server-lua.world.snapshot")
local Combat=require("server-lua.world.indoor_combat")
local folder=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"),"CI temp folder required")
local server=Local.new({
 bind="127.0.0.1",port=18967,roomCode="indoorfight1234",dataDir=folder,
 mode="lan",guiHost=true,botCount=0,mapId="cabana-e-mina",
 nowMs=function()return 100000 end
})
local room=server.rooms.LC.room
local beasts={}
for _,ai in ipairs(room.ais) do
 if ai.spaceId=="mina" then
  beasts[#beasts+1]=ai
  assert(ai.options.mapSpaces==room.mapSpaces,
   "subsoil animal has no authoritative floor geometry")
 end
end
assert(#beasts==3,"exactly three authored underground mobs required")
local sample=beasts[1]
assert(sample.alive and sample.active)
local visitor={x=sample.x,y=sample.y,scale=35,spaceId="cabana",noMovTimer=0}
assert(not Snapshot.canSee(visitor,sample,room.config),
 "different-floor animal visible to indoor player")
visitor.spaceId="mina"
assert(Snapshot.canSee(visitor,sample,room.config),
 "mine animal not visible to mine player")
local attacker={
 room=room,id="fighter",sid=8,isPlayer=true,alive=true,active=true,
 spaceId="cabana",x=600,y=850,scale=35,dir=0,weaponIndex=0,
 xVel=0,yVel=0,slowMult=1,noMovTimer=0,dragonUntil=0,superUntil=0,
 powers={power=1},skin=nil,tail=nil,
 variant=function()return {val=1}end,
 changeHealth=function()end,
 sendAnimation=function()end
}
local hp=100
local target={
 id="victim",sid=9,isPlayer=true,active=true,alive=true,
 spaceId="cabana",x=640,y=850,scale=35,dir=0,
 xVel=0,yVel=0,dmgOverTime={},health=100,
 changeHealth=function(self,change)
  hp=hp+change;self.health=hp
  if hp<=0 then self.alive=false end
  return true
 end
}
room.players[#room.players+1]=attacker
room.players[#room.players+1]=target
room.nowMs=100000
assert(Combat.melee(attacker)==true and hp<100,
 "real melee did not damage another player in the same room")
target.spaceId="mina";hp=100;target.health=100
assert(Combat.melee(attacker)==false and hp==100,
 "melee hit an actor in another floor")
target.spaceId="cabana";target.health=100
local wall={x=615,y=800,width=12,height=100}
local zone=room.mapSpaces:get("cabana")
zone.obstacles[#zone.obstacles+1]=wall
assert(room.mapSpaces:lineBlocked("cabana",attacker.x,attacker.y,target.x,target.y),
 "test wall does not block ray")
assert(Combat.melee(attacker)==false and hp==100,
 "melee passed through house wall")
-- A projectile fired toward the target must be intercepted by the wall.
local projectileIndex
for i=0,20 do
 if room.items.projectiles[i] then projectileIndex=i;break end
end
assert(projectileIndex~=nil,"original projectile catalogue empty")
attacker.canSee=function()return false end
target.canSee=function()return false end
local proj=room.projectile_manager:addProjectile(600,850,0,400,300,
 projectileIndex,attacker,nil,0)
assert(proj.spaceId=="cabana","projectile was created above ground")
room.projectile_manager:updateOne(proj,1)
assert(proj.active==false and hp==100,
 "projectile crossed solid interior wall")
server:close()
print("PASS indoor combat: real weapon damage, wall/level isolation, mine mobs and ranged interception")
