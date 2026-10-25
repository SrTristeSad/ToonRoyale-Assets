local Pack=require("server-lua.world.wolf_pack")
local Mods=require("server-lua.world.room_mods")
local player={x=420,y=350,xVel=0.05,yVel=0,alive=true}
local wolves={
 {index=4,active=true,alive=true,sid=1,x=100,y=340,chargeTarget=player},
 {index=4,active=true,alive=true,sid=2,x=120,y=360},
 {index=4,active=true,alive=true,sid=3,x=150,y=320}
}
local nbr=Pack.neighbors(wolves[1],wolves)
assert(#nbr==3,"wolves in 650px range must form a pack")
assert(Pack.sharedTarget(wolves[2],wolves)==player,"pack must share target")
local dirs={}
for i,wolf in ipairs(wolves) do
 local direction=Pack.direction(wolf,player,wolves,"dificil")
 assert(type(direction)=="number" and direction==direction)
 dirs[#dirs+1]=direction
end
assert(math.abs(dirs[1]-dirs[2])>0.01 or math.abs(dirs[1]-dirs[3])>0.01,
 "cooperating wolves must take separate flanking approaches")
local far={index=4,active=true,alive=true,sid=4,x=4000,y=4000}
assert(Pack.sharedTarget(far,wolves)==nil,"pack must not share target across world")
local classic=Mods.build("normal",{},"server-lua/mods")
local peaceful=Mods.build("pacifico",{},"server-lua/mods")
local hard=Mods.build("dificil",{},"server-lua/mods")
assert(classic.config.server.roomDifficulty=="normal")
assert(peaceful.config.server.roomDifficulty=="pacifico")
assert(hard.config.server.roomDifficulty=="dificil")
assert(classic.types[4].hostile and classic.types[4].chargePlayer)
assert(peaceful.types[4].hostile==false and peaceful.types[4].chargePlayer==false)
assert(peaceful.config.server.animalSpawnPlan~=classic.config.server.animalSpawnPlan)
local Vitals=require("server-lua.world.vitals")
local function fake()
 local p={alive=true,shameTimer=0,regenTimer=0,skin={},tail={},
 dmgOverTime={dmg=0},healCol=0,pps=0,health=40,maxHealth=100}
 function p:changeHealth(amount)
  self.health=math.max(0,math.min(self.maxHealth,self.health+amount))
 end
 return p
end
local p1=fake();Vitals.step(p1,1000,classic.config)
assert(p1.health==40,"original mode must not grant passive regeneration")
local p2=fake();Vitals.step(p2,1000,peaceful.config)
assert(p2.health==46,"peaceful mode must restore 6 health per second")
print("PASS coordinated wolf attacks and original-vs-peaceful health behavior")
