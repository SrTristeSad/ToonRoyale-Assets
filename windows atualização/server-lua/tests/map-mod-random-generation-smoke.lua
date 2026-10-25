-- Regression: mod world rules and custom generated maps use the same
-- random MooMoo world generator. Only indoor geometry has fixed coordinates.
local Maps=require("server-lua.world.map_profiles")
local Mods=require("server-lua.world.room_mods")
local World=require("server-lua.world.objects")

local function run(seed)
 local map=Maps.load("server-lua/maps","mapa-de-exemplo")
 assert(map.mode=="generated" and next(map.generation)==nil)
 assert(map.spawn==nil and #map.surface==0,"example must not pin resources")
 local profile=Mods.build("normal",{"floresta-densa"},"server-lua/mods",map)
 assert(profile.config.treesPerArea==17
   and profile.config.bushesPerArea==7
   and profile.config.totalRocks==54
   and profile.config.goldOres==12,"mod rules did not reach world config")
 local world=World.new({config=profile.config,random=Maps.random(seed)})
 world:loadMap(map)
 assert(#world.objects>0,"generated world is empty")
 local points={}
 for _,obj in ipairs(world.objects) do
  if obj.active then points[#points+1]=tostring(obj.x)..":"..tostring(obj.y) end
  if #points==20 then break end
 end
 assert(#points==20,"not enough generated world resources")
 return table.concat(points,"|")
end

local first=run(12345)
assert(first==run(12345),"same random seed must reproduce the map")
assert(first~=run(54321),"different seeds must change resource positions")

local dungeon=Maps.load("server-lua/maps","bunker-e-cavernas")
assert(dungeon.mode=="generated" and not dungeon.spawn)
for _,portal in ipairs(dungeon.portals) do
 assert(portal.placement=="random" and portal.x==nil and portal.y==nil,
  "surface entrances must not use fixed coordinates")
end
print("PASS map and mod integration: original generator, random positions, mod quantities")
