-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact reference scenarios for the original AI_TYPES and Game.ensureAnimals.
local Types=require("server-lua.world.animal_types")
local Animals=require("server-lua.world.animals")
local World=require("server-lua.world.objects")
local Crypto=require("src.protocol.original_crypto")
local Config=require("src.game.config")
local function normalized(value)
 if type(value)=="table" then
   local values={}
   for _,v in ipairs(value) do values[#values+1]=normalized(v)end
   return "["..table.concat(values,",").."]"
 end
 return tostring(value)
end
for i=0,14 do
 local obj=assert(Types[i],"missing original type id")
 local fields={}
 local keys={}
 for key in pairs(obj) do keys[#keys+1]=key end
 table.sort(keys)
 for _,key in ipairs(keys) do
   fields[#fields+1]=key.."="..normalized(obj[key])
 end
 print("TYPE|"..i.."|"..table.concat(fields,"|"))
end
local plan={
 {index=0,desired=2},{index=2,desired=1},
 {index=4,desired=1,area="snow"},{index=5,desired=1,area="river"},
 {index=6,desired=1,positions={{xRatio=0.5,yRatio=0.93}}},
 {index=11,desired=1,area="secret",positions={{x=-2500,y=7200}}}
}
local cfg=setmetatable({
 server={animalSpawnPlan=plan}
},{__index=Config})
local rng=Crypto.mulberry32(2026)
local world=World.new({config=cfg,random=rng})
local manager=Animals.new({
 world=world,config=cfg,random=rng,
 respawnAt=function()return {x=-2500,y=7200}end
})
local checks={
 {index=0},{index=4,area="snow"},{index=5,area="river"},
 {index=6,positions={{xRatio=0.5,yRatio=0.93}}},
 {index=11,positions={{x=-2500,y=7200}}}
}
for _,entry in ipairs(checks) do
 local pos=manager:animalPosition(entry)
 print("POS|"..entry.index.."|"..(entry.area or "normal").."|"..
   pos.x.."|"..pos.y)
end
manager:ensureAnimals()
local list=manager.ais
for i,a in ipairs(list) do
 print("SPAWN|"..(i-1).."|"..a.sid.."|"..a.index.."|"..a.x.."|"..a.y.."|"..
   string.format("%.6f",a.dir).."|"..a.nameIndex.."|"..a.health.."|"..
   (a.spawnDelay or 0).."|"..(a.boss and 1 or 0))
end
manager:ensureAnimals()
print("NO_DUP|"..#list)
local first=list[1]
first.active=false
local reused=manager:spawn(850,920,0.4,9,{spawnDelay=2500})
print("REUSE|"..reused.sid.."|"..reused.index.."|"..reused.x.."|"..reused.y..
  "|"..reused.nameIndex.."|"..reused.spawnDelay.."|"..#list)
local missing=manager:spawn(700,750,0.5,99)
print("MISSING|"..missing.sid.."|"..missing.index.."|"..missing.x.."|"..#list)
