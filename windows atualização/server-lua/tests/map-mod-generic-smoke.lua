-- A modded map with arbitrary zone IDs MUST use the same room physics,
-- tile materials, map UI, live packet and modded rules as bundled examples.
local Maps=require("server-lua.world.map_profiles")
local Spaces=require("server-lua.world.map_spaces")
local Materials=require("src.game.map_materials")
local Mods=require("server-lua.world.room_mods")
local Local=require("server-lua.local_server")
local Config=require("src.game.config")
local Json=require("server-lua.vendor.dkjson")
local World=require("src.game.world_state")
local id="refugio-personalizado"
local map=Maps.load("server-lua/maps",id)
assert(map.id==id and #map.spaces==2)
assert(map.spaces[1].id=="mod-sala-metal"
 and map.spaces[1].visual.floor=="metal"
 and map.spaces[1].visual.wall=="brick"
 and map.spaces[1].visual.tileSize==96)
assert(map.spaces[2].visual.floor=="ice"
 and map.spaces[2].visual.tileSize==64)
assert(Materials.visual(map.spaces[1]).floor=="metal"
 and Materials.visual(map.spaces[2]).floor=="ice")
assert(Materials.portalStyle(map.spaces[1],map.spaces[1].portals[2])=="door")
assert(Materials.portalStyle(map.spaces[2],map.spaces[2].portals[1])=="stairs")
local spaces=Spaces.new(map,Config.mapScale)
assert(spaces:get("mod-sala-metal").type=="interior")
assert(spaces:get("mod-sala-gelo").type=="underground")
local first=assert(spaces:destination("surface","entrada-refugio",35))
assert(first.spaceId=="mod-sala-metal")
local second=assert(spaces:destination("mod-sala-metal","porta-gelo",35))
assert(second.spaceId=="mod-sala-gelo")
assert(not spaces:canOccupy("mod-sala-metal",110,120,35),
 "mod-defined brick wall must be physically collidable")
assert(spaces:canOccupy("mod-sala-metal",530,710,35))
-- Reject unsupported themes, external image paths or unsafe style strings.
local bogus=Json.decode(Json.encode(map))
bogus.spaces[1].visual.floor="../scripts/inject.lua"
assert(not pcall(Maps.validate,Json.encode(bogus),id),
 "arbitrary renderer path was accepted")
bogus=Json.decode(Json.encode(map))
bogus.portals[1].style="execute-on-enter"
assert(not pcall(Maps.validate,Json.encode(bogus),id),
 "arbitrary entrance operation was accepted")
bogus=Json.decode(Json.encode(map))
bogus.spaces[1].obstacles[1].material="javascript"
assert(not pcall(Maps.validate,Json.encode(bogus),id),
 "unsafe wall material was accepted")
-- Catalog includes a JSON map from mods/maps without duplicate entries.
local fs={
 getDirectoryItems=function(dir)
  if dir=="server-lua/mods/maps" then
   return {"refugio-personalizado.json","payload.lua"}
  end
  return {"cabana-e-mina.json","refugio-personalizado.json"}
 end,
 read=function(path)
  local f=io.open(path,"rb")
  if not f then error("not installed") end
  local data=f:read("*a")
  f:close()
  return data
 end
}
local found=Maps.available(fs,"server-lua/maps")
assert(#found==2 and found[2].id==id and found[2].source=="mod",
 "custom map mod must appear in the map picker")
local dataDir=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"))
local server=Local.new({bind="127.0.0.1",port=18991,
 roomCode="genericmodmaptest",dataDir=dataDir,guiHost=true,botCount=0,
 nowMs=function()return 100000 end,mode="lan",
 mapId=id,difficulty="normal",modIds="floresta-densa"})
local room=server.rooms.LC.room
assert(room.mapId==id and room.customMap.id==id)
assert(room.config.treesPerArea==17,"selected world mod lost to installed map")
assert(room.mapSpaces:get("mod-sala-metal").visual.floor=="metal")
assert(room.mapSpaces:get("mod-sala-gelo").visual.floor=="ice")
assert(server.rooms.MB.room.mapSpaces:get("mod-sala-metal")==nil)
local packets={}
local player={id="map-mod-player",alive=true,spaceId="surface",
 x=3520,y=3520,moveDir=0,scale=35,send=function(_,name,...)
  packets[#packets+1]={name=name,args={...}}
 end}
room.players[#room.players+1]=player
room.nowMs=150000
assert(room:checkPortalCrossing(player) and player.spaceId=="mod-sala-metal")
local client=World.new()
assert(client:apply("A",{{map={
 id=map.id,name=map.name,portals=map.portals}}}))
assert(client:apply("j",packets[#packets].args))
assert(client.spaceId=="mod-sala-metal" and client.space.visual.floor=="metal")
assert(client.space.visual.wall=="brick")
-- Move off arrival, then traverse the user-defined door into another mod zone.
player.x=700;player.y=710
room.nowMs=151000
assert(not room:checkPortalCrossing(player))
player.x=900;player.y=850
local crossing=room:checkPortalCrossing(player)
assert(crossing and player.spaceId=="mod-sala-gelo",
 "generic door failed: state="..tostring(player.spaceId)
 .." cooldown="..tostring(player.nextPortalAt)
 .." armed="..tostring(player.portalInside)
 .." at="..tostring(room.nowMs)
 .." destination="..tostring(room.mapSpaces:destination(
   "mod-sala-metal","porta-gelo",35)))
assert(client:apply("j",packets[#packets].args))
assert(client.space.visual.floor=="ice")
server:close()
print("PASS arbitrary mod map: discovery, palette, real physics, room transitions and original isolation")
