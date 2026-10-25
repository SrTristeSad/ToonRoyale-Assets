-- Real local room: walk into cave/bunker doors without the old j/G packet;
-- map rules precede JSON mods; Normal respects the original 51 AI budget.
local Local=require("server-lua.local_server")
local Base=require("src.game.config")
local Maps=require("server-lua.world.map_profiles")
local Mods=require("server-lua.world.room_mods")
local ClientWorld=require("src.game.world_state")
local dataDir=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"),"temporary test data dir required")
local map=Maps.load("server-lua/maps","bunker-e-cavernas")
local baseline=0
for _,entry in ipairs(Base.server.animalSpawnPlan) do
 baseline=baseline+entry.desired
end
assert(baseline==51,"Node original normal reference baseline changed")
assert(#map.spaces==4)
local opts={bind="127.0.0.1",port=18987,roomCode="walkingdoorstest",
 dataDir=dataDir,guiHost=true,botCount=0,
 nowMs=function()return 100000 end,mapId=map.id,mode="lan",
 difficulty="normal",modIds=""}
local instance=Local.new(opts)
local room=instance.rooms.LC.room
local active,surface,indoor=0,0,0
for _,mob in ipairs(room.ais) do
 if mob.active then
  active=active+1
  if (mob.spaceId or "surface")=="surface" then surface=surface+1
  else indoor=indoor+1 end
 end
end
assert(indoor==6 and surface==45 and active==baseline,
 "Normal map unexpectedly adds underground mobs on top of classic budget")
assert(#instance.rooms.MB.room.ais==baseline,
 "MB must retain the original normal animal plan")
local killed
for _,mob in ipairs(room.ais) do
 if mob.mapSpawnId=="caverna-02:1" then killed=mob;break end
end
assert(killed and killed.spaceId=="caverna-02")
killed.active=false
room.animal_manager:ensureAnimals()
local restored=0
for _,mob in ipairs(room.ais) do
 if mob.active then
  restored=restored+1
  if mob.mapSpawnId=="caverna-02:1" then
   assert(mob.spaceId=="caverna-02",
    "recycled AI entered the wrong zone")
  end
 end
end
assert(restored==baseline,
 "the authored cave mob must respawn without exceeding normal budget")
local packets={}
local player={
 id="walking-player",x=4200,y=4840,dir=0,moveDir=0,scale=35,
 spaceId="surface",alive=true,send=function(self,name,...)
  packets[#packets+1]={name=name,args={...}}
 end
}
room.players[#room.players+1]=player
room.nowMs=200000
assert(not room:checkPortalCrossing(player),"must not teleport from too far away")
player.y=4760
assert(room:checkPortalCrossing(player),"walking toward bunker must enter")
assert(player.spaceId=="bunker-01" and player.x==750)
assert(packets[#packets].name=="j" and packets[#packets].args[1]=="bunker-01")
room.nowMs=202000
-- The server zeroes movement on transfer; the native client resends held WASD.
player.moveDir=0
assert(not room:checkPortalCrossing(player),
 "arrival pad cannot immediately teleport player outside")
player.x=930;player.y=850
assert(not room:checkPortalCrossing(player),
 "walking away re-arms but must not teleport yet")
player.x=750;player.y=850
assert(room:checkPortalCrossing(player) and player.spaceId=="surface",
 "return doorway must work by walking onto it")
room.nowMs=204000
player.moveDir=0
player.x=4670;player.y=4780
assert(room:checkPortalCrossing(player) and player.spaceId=="caverna-01",
 "walking into cave entrance must cross without keypress")
local client=ClientWorld.new()
assert(client:apply("A",{{map={
 id=map.id,name=map.name,portals=map.portals}}}))
assert(client:apply("j",packets[#packets].args))
assert(client.spaceId=="caverna-01",
 "real packet did not switch the client cave level")
instance:close()
-- Map generation and explicit world mods: mod values must win.
local profile=Mods.build("normal",{"floresta-densa"},"server-lua/mods",map)
assert(profile.config.treesPerArea==17 and profile.config.goldOres==12)
assert(map.generation.treesPerArea==8,
 "mod mutated the installed map")
opts.port=18988
opts.modIds="floresta-densa,mais-lobos"
opts.dataDir=dataDir
local modded=Local.new(opts)
local changed=modded.rooms.LC.room
assert(changed.config.treesPerArea==17 and changed.config.goldOres==12,
 "custom map overwrote active world mod configuration")
assert(changed.activeMods[1]=="floresta-densa"
 and changed.activeMods[2]=="mais-lobos",
 "selected mods were not applied to the actual LC room")
assert(changed.animal_manager.types[4].dmg==16,
 "wolf combat mod was not applied to local AI")
local count=0
for _,ai in ipairs(changed.ais) do
 if ai.active then count=count+1 end
end
assert(count==63,
 "selected wolf mod did not raise total active AI from 51 to 63")
assert(modded.rooms.MB.room.config.treesPerArea==Base.treesPerArea,
 "custom LC world mod contaminated classic MB room")
modded:close()
print("PASS seamless rooms + original 51 normal mobs + map-before-mod precedence")
