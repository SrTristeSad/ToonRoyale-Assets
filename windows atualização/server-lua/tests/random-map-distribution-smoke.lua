-- Universal generated maps use the SAME source grid resource generator as
-- original MooMoo. Mods affect quotas, not hidden fixed item locations.
local Base=require("src.game.config")
local Maps=require("server-lua.world.map_profiles")
local Mods=require("server-lua.world.room_mods")
local World=require("server-lua.world.objects")
local JSON=require("server-lua.vendor.dkjson")
local testMap="bunker-e-cavernas"
local function generated(seed,modIds,extra)
 local map=Maps.load("server-lua/maps",testMap)
 assert(map.mode=="generated" and next(map.generation)==nil
   and map.spawn==nil and map.portals[1].placement=="random"
   and map.portals[1].x==nil)
 if extra then
  map.surface={{kind=2,scale=80,placement="random",count=8}}
  map.interactables={{id="racao-solta",kind="cache",placement="random",
   resource="food",amount=30}}
  assert(Maps.validate(JSON.encode(map),testMap))
 end
 local profile=Mods.build("normal",modIds or {},"server-lua/mods",map)
 local world=World.new({config=profile.config,random=Maps.random(seed)})
 world:loadMap(map)
 return map,profile,world
end
local first,profile,w1=generated(45123,{},true)
local second,_,w2=generated(45123,{},true)
local third,_,w3=generated(912345,{},true)
assert(profile.config.treesPerArea==Base.treesPerArea
  and profile.config.bushesPerArea==Base.bushesPerArea
  and profile.config.totalRocks==Base.totalRocks
  and profile.config.goldOres==Base.goldOres,
  "generated map changed original MooMoo resource quota")
local function signature(map,world)
 local a={}
 for _,p in ipairs(map.portals) do a[#a+1]=p.id..":"..p.x..","..p.y end
 for _,o in ipairs(map.interactables) do a[#a+1]=o.id..":"..o.x..","..o.y end
 for i=1,10 do
  local o=assert(world.objects[i])
  a[#a+1]=o.type..":"..o.x..","..o.y
 end
 return table.concat(a,";")
end
assert(signature(first,w1)==signature(second,w2),
 "identical seed did not regenerate same world and entrance layout")
assert(signature(first,w1)~=signature(third,w3),
 "new seed still used old fixed map/item placement")
local p1,p2=first.portals[1],first.portals[2]
local dx,dy=p1.x-p2.x,p1.y-p2.y
assert(dx*dx+dy*dy>(Base.mapScale*0.20)^2,
 "bunker and cave entrances clustered instead of being spread out")
for _,p in ipairs(first.portals) do
 assert(p.x>=200 and p.x<=Base.mapScale-200)
 assert(p.y>=200 and p.y<=Base.mapScale-200)
 for _,zone in ipairs(first.spaces) do
  for _,back in ipairs(zone.portals) do
   if back.to=="surface" and p.to==zone.id then
    assert(back.targetX==p.x and back.targetY==p.y,
      "interior return portal failed to use randomly generated entrance")
   end
  end
 end
end
local item=first.interactables[1]
assert(type(item.x)=="number" and type(item.y)=="number"
 and (item.x~=p1.x or item.y~=p1.y))
local resourceCount=0
for _,obj in ipairs(w1.objects) do
 if obj.active and obj.type==2 then resourceCount=resourceCount+1 end
end
assert(resourceCount>=8,"random map resource additions did not spawn")
local forest,forestProfile=generated(45123,{"floresta-densa"})
assert(forestProfile.config.treesPerArea==17 and forestProfile.config.goldOres==12,
 "world mod no longer overrides original random generator")
assert(forest.portals[1].x and forest.portals[2].x)
local example=Maps.load("server-lua/maps","mapa-de-exemplo")
local exampleWorld=World.new({config=Base,random=Maps.random(721)})
exampleWorld:loadMap(example)
assert(example.mode=="generated" and #example.surface==0
  and #exampleWorld.objects>0,
  "example map must use original random resources")
-- Prevent "random" placement from being used to smuggle fixed coordinates
-- that could reveal all resources via a mod or bypass the collision rules.
local function reject(map,edit)
 local changed=assert(JSON.decode(JSON.encode(map)))
 edit(changed)
 assert(not pcall(Maps.validate,JSON.encode(changed),changed.id))
end
local template=Maps.load("server-lua/maps",testMap)
reject(template,function(m) m.portals[1].x=4200 end)
reject(template,function(m) m.interactables={{
  id="fixed-secret",kind="cache",placement="random",x=1000,
  resource="food",amount=10}} end)
reject(template,function(m) m.surface={{
  kind=2,scale=80,placement="random",x=1000,count=500}} end)
print("PASS real MooMoo procedural world, randomized doors/items, mod coupling and valid return exits")
