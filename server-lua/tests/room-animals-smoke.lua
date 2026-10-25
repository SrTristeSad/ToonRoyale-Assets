-- SPDX-License-Identifier: AGPL-3.0-only
-- Native animal manager -> Room.ensureAnimals -> Game.tick -> AI.update.
-- This exercises real non-boss AI; no hidden stubs for the Crab King.
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local Animals=require("server-lua.world.animals")
local Room=require("server-lua.world.room")
local Crypto=require("src.protocol.original_crypto")
local function same(a,b,msg)assert(a==b,(msg or "mismatch")..": "..tostring(a).." != "..tostring(b))end
local plan={
 {index=0,desired=1},
 {index=4,desired=1,area="snow"}
}
local server=setmetatable({animalSpawnPlan=plan},{__index=Config.server})
local cfg=setmetatable({server=server},{__index=Config})
local rng=Crypto.mulberry32(21)
local world=World.new({config=cfg,random=rng})
local players={}
local ais={}
local events={}
local animals=Animals.new({
  config=cfg,world=world,players=players,ais=ais,random=rng,
  health=function(ai,amount)ai.health=ai.health+amount;return ai.health<=0 end,
  send=function(id,name,...)events[#events+1]=name end
})
local items={
 weapons={[0]={id=0,gather=1,range=65,dmg=25,speed=300}},
 projectiles={[0]={dmg=25,scale=103,speed=1.6,range=1000,layer=0}}
}
local room=Room.new({
  nowMs=10000,config=cfg,world=world,items=items,
  players=players,ais=ais,animalManager=animals,services={}
})
same(room.animal_manager,animals,"manager retained")
for _,clock in ipairs({10000,10100,10500,11100,11300}) do
  room:tick(clock)
end
same(#room.ais,2,"native population")
same(room.ais[1].index,0,"original Cow")
same(room.ais[2].index,4,"original Wolf")
same(room.ais[1].sid,0,"Cow SID")
same(room.ais[2].sid,1,"Wolf SID")
assert(room.ais[1].active and room.ais[2].active,
  "animals are managed by the authoritative Game loop")
assert(room.ais[1].waitCount<=0 and room.ais[1].moveCount<10000,
  "native Cow behavior began after the original wait")
local before=#room.ais
room:ensureAnimals()
same(#room.ais,before,"no animals duplicated at spawn")
same(room.lastTick,11300,"native Room clock")
-- Never silently treat the Crab King as a Cow or skip its raid mechanics.
local bossCfg=setmetatable({
  server=setmetatable({animalSpawnPlan={{index=11,desired=1}}},{__index=Config.server})
},{__index=Config})
local ok=pcall(function()
  Room.new({nowMs=10000,config=bossCfg,world=world,
    items=items,players=players,ais=ais,animalManager=animals,services={}})
end)
assert(not ok,"boss cannot be run as common AI without raid implementation")
print("PASS native AI manager spawns Cow/Wolf and advances via Room.tick")
print("PASS boss requires real combat and dive callbacks")
