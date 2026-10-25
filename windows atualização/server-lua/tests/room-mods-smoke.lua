-- Mods must never alter the reference and cannot execute Lua payloads.
local Mods=require("server-lua.world.room_mods")
local Config=require("src.game.config")
local Types=require("server-lua.world.animal_types")
local function count(profile,index)
 for _,entry in ipairs(profile.config.server.animalSpawnPlan) do
  if entry.index==index then return entry.desired end
 end
 error("missing original spawn entry "..index)
end
local normal=Mods.build("normal",{},"server-lua/mods")
assert(normal.types[4].dmg==Types[4].dmg)
assert(normal.config.server.animalSpawnPlan[1].desired==Config.server.animalSpawnPlan[1].desired)
local hard=Mods.build("dificil",{},"server-lua/mods")
local extreme=Mods.build("extremo",{},"server-lua/mods")
assert(hard.types[4].dmg>normal.types[4].dmg)
assert(extreme.types[4].dmg>hard.types[4].dmg)
assert(extreme.types[4].viewRange>normal.types[4].viewRange)
assert(count(extreme,4)>=count(hard,4) and count(hard,4)>=count(normal,4))
assert(normal.types[11].dmg==hard.types[11].dmg,
 "original Crab King behavior must not be silently changed")
local modified=Mods.build("normal",Mods.ids("mais-lobos,fauna-hostil"),"server-lua/mods")
assert(count(modified,4)==18)
assert(modified.types[4].dmg==16 and modified.types[2].dmg==30)
assert(Types[4].dmg~=modified.types[4].dmg,"mod leaked into global source")
assert(Config.server.animalSpawnPlan~=modified.config.server.animalSpawnPlan)
assert(#Mods.ids("")==0)
for _,bad in ipairs({"../private","mais-lobos,,fauna-hostil","mais-lobos,mais-lobos"}) do
 assert(not pcall(Mods.ids,bad),"unsafe or repeated mod ID accepted: "..bad)
end
assert(not pcall(Mods.build,"unknown",{},"server-lua/mods"))
assert(not pcall(Mods.build,"normal",{"does-not-exist"},"server-lua/mods"))
-- New core groups are applied to copies of the authoritative game config.
local forest=Mods.build("normal",{"floresta-densa"},"server-lua/mods")
assert(forest.config.treesPerArea==17 and forest.config.bushesPerArea==7)
assert(forest.config.totalRocks==54 and forest.config.goldOres==12)
assert(Config.treesPerArea~=forest.config.treesPerArea,
  "a world mod must never mutate the original base map configuration")
local pack=Mods.build("normal",{"lobos-em-matilha"},"server-lua/mods")
assert(pack.config.server.roomRules.cooperativeWolves==true)
assert(normal.config.server.roomRules.cooperativeWolves==false)
assert(Mods.build("pacifico",{},"server-lua/mods").config.server.roomRules.healthRegenPerSecond==6)
local parsed=Mods.describe("server-lua/mods","floresta-densa")
assert(parsed.id=="floresta-densa" and parsed.name=="Floresta Densa")
-- Mod picker discovery uses the same validation but read-only LÖVE filesystem.
local directory={"lobos-em-matilha.json","floresta-densa.json","mais-lobos.json",
  "unauthorized.lua","does-not-exist.json"}
local fs={
 getDirectoryItems=function()return directory end,
 read=function(path)
  local f=io.open(path,"rb")
  if not f then return nil end
  local text=f:read("*a");f:close();return text
 end
}
local installed=Mods.available(fs,"server-lua/mods")
assert(#installed==3 and installed[1].id=="floresta-densa"
  and installed[2].id=="lobos-em-matilha"
  and installed[3].id=="mais-lobos","mod picker must ignore invalid/unreadable files")
assert(not pcall(Mods.build,"normal",{"../secrets"},"server-lua/mods"))
print("PASS mods JSON + dificuldade isolados, limites, sem execucao de codigo")
