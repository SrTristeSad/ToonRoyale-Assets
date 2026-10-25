-- End-to-end independent animation mod + JSON custom species, no map
-- dependency. Both run in the LOCAL LC room; original MB is unchanged.
local Mods=require("server-lua.world.room_mods")
local Types=require("server-lua.world.animal_types")
local Maps=require("server-lua.world.map_profiles")
local Local=require("server-lua.local_server")
local World=require("src.game.world_state")
local Json=require("server-lua.vendor.dkjson")
local Root="server-lua/mods"
local anim=Mods.build("normal",{"animacao-lobo"},Root)
assert(anim.animations["4"] and anim.animations["4"].walk.frames==6)
assert(anim.types[15]==nil and anim.config.server.animalSpawnPlan[1].index==0)
local fresh=Mods.build("normal",{"novas-especies"},Root)
assert(fresh.types[15].name=="Lobo Cinzento" and fresh.types[16].name=="Lebre do Bosque")
assert(fresh.types[4].health==Types[4].health,"custom species modified original animal")
assert(fresh.animations["15"].death.frames==4)
local added=0
for _,entry in ipairs(fresh.config.server.animalSpawnPlan) do
 if entry.index==15 then assert(entry.desired==3);added=added+3 end
 if entry.index==16 then assert(entry.desired==4);added=added+4 end
end
assert(added==7,"new species spawn plan did not register")
local mixed=Mods.build("normal",{"animacao-lobo","novas-especies"},Root)
assert(mixed.animations["4"] and mixed.animations["15"])
local function reject(t)
 local ok=pcall(Mods.build,"normal",t,Root)
 assert(not ok,"invalid or conflicting mods accepted")
end
reject({"novas-especies","novas-especies"})
local dir=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"))
local host=Local.new({bind="127.0.0.1",port=18998,
 roomCode="newcreaturessmoke",dataDir=dir,guiHost=true,
 nowMs=function()return 100000 end,botCount=0,
 difficulty="normal",modIds="animacao-lobo,novas-especies"})
local room=host.rooms.LC.room
assert(room.key=="LC" and room.customMap==nil)
assert(room.mobAnimations["4"] and room.mobAnimations["15"])
local kinds=host.rooms.LC.registry.animalKinds
local newKinds={}
for _,a in ipairs(kinds) do newKinds[a.id]=a end
assert(#kinds==17 and newKinds[15].src=="wolf_1"
 and newKinds[16].scale==55)
local classic=host.rooms.MB
assert(#classic.registry.animalKinds==15)
assert(classic.room.animal_manager.types[15]==nil
 and not next(classic.room.mobAnimations))
local active,total=0,0
for _,a in ipairs(room.ais) do
 if a.active then
  total=total+1
  if a.index>=15 then
   active=active+1
   assert(a.index==15 or a.index==16)
   assert((a.spaceId or "surface")=="surface")
   assert(a.maxHealth==room.animal_manager.types[a.index].health)
  end
 end
end
assert(active==7 and total==58,"independent mod must spawn 7 new animals, original 51 intact")
local w=World.new()
assert(w:apply("A",{{teams={},animals=kinds,animations=room.mobAnimations}}))
assert(w.map==nil and w.animationCatalog.animations["15"])
assert(w:animalKind(15).name=="Lobo Cinzento")
assert(w:animalKind(16).src=="sheep_1")
assert(w:apply("I",{{17,15,300,400,0,510,0,0},{}}))
w:update(0.04)
assert(w.animals[17].mobClip=="idle")
assert(w:apply("J",{17}))
w:update(0.04)
assert(w.animals[17].mobClip=="attack")
assert(w:apply("j",{"mob-death",0,0,{
 sid=17,index=15,x=300,y=400,dir=0}}),
 "animation-only LC death packet cannot require a custom map")
assert(#w.mobDeathEffects==1)
local plain=World.new()
assert(plain:apply("A",{{teams={},animals={}}}))
assert(plain.map==nil and next(plain.animationCatalog.animations)==nil)
host:close()
-- Map-authored spawns 15+ require that species mod.
local map=Maps.load("server-lua/maps","refugio-personalizado")
map.spaces[2].mobs={{kind=15,x=700,y=600}}
local loaded=Maps.validate(Json.encode(map),map.id)
assert(loaded.spaces[2].mobs[1].kind==15)
local merged=Mods.build("normal",{"novas-especies"},Root,loaded)
assert(merged.types[15],"map mob species missing")
local noSpecies=Mods.build("normal",{},Root,loaded)
assert(not noSpecies.types[15],"unselected species leaked into normal game")
-- Validation mirrors Local.new's authoritative map-requirement check.
local function validateMapSpecies(profile)
 for _,zone in ipairs(loaded.spaces) do
  for _,mob in ipairs(zone.mobs) do
   assert(profile.types[mob.kind],"required mod not enabled")
  end
 end
end
assert(pcall(validateMapSpecies,merged))
assert(not pcall(validateMapSpecies,noSpecies))
local Creatures=require("server-lua.world.mod_creatures")
local function deny(t)
 assert(not pcall(Creatures.newSpecies,t),
   "invalid user-defined mob bypassed sandbox")
end
deny({["14"]={}})
deny({["64"]={}})
deny({["15"]={name="unsafe",src="../escape",health=200,
 scale=80,speed=0.001,turnSpeed=0.002,weightM=0.5}})
deny({["15"]={name="boss",src="wolf_1",health=200,
 scale=80,speed=0.001,turnSpeed=0.002,weightM=0.5,dmg=99999}})
-- Full host integration: map names are arbitrary and species with IDs >=15
-- are only permitted when their independent mod has been selected.
assert(not pcall(Local.new,{bind="127.0.0.1",port=18999,
 roomCode="missingextraspecies",dataDir=dir,
 nowMs=function() return 100000 end,guiHost=true,botCount=0,
 mapId="reserva-criaturas",modIds=""}),
 "custom map unexpectedly accepted creature 15 without required mod")
local mapped=Local.new({bind="127.0.0.1",port=19000,
 roomCode="extraindoorcreatures",dataDir=dir,
 nowMs=function() return 100000 end,guiHost=true,botCount=0,
 mapId="reserva-criaturas",modIds="novas-especies"})
local mappedRoom=mapped.rooms.LC.room
local inside=0
for _,mob in ipairs(mappedRoom.ais) do
 if mob.active and mob.index>=15 and mob.spaceId=="mod-sala-gelo" then
  inside=inside+1
  assert(mob.mapSpawnId and mob.maxHealth>100)
 end
end
assert(inside==2,"new species not spawned in arbitrary mod-map region")
assert(mapped.rooms.MB.room.animal_manager.types[15]==nil)
mapped:close()
print("PASS animation-only mods + new species + surface & underground spawning + classic isolation")

