-- Regression: creator-defined houses/interiors are data-only map features.
-- Players must never be able to create, edit or persist house geometry.
local Local=require("server-lua.local_server")
local Maps=require("server-lua.world.map_profiles")
local ClientWorld=require("src.game.world_state")
local folder=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"),"CI data directory required")
local server=Local.new({bind="127.0.0.1",port=18964,roomCode="mapauthortest42",
 dataDir=folder,guiHost=true,botCount=0,nowMs=function()return 100000 end,
 mapId="cabana-e-mina",mode="lan"})
local room=server.rooms.LC.room
assert(room and room.mapSpaces and room.customMap)
assert(room.buildHouse==nil and room.buildWall==nil and room.removeWall==nil,
 "player-facing dynamic house commands must not be exported")
assert(room.houseStorePath==nil and room.builtHouses==nil,
 "legacy player house persistence still active")
local authored=Maps.load("server-lua/maps","cabana-e-mina")
for _,zone in ipairs(authored.spaces) do
 local loaded=assert(room.mapSpaces:get(zone.id),"author-defined room missing")
 assert(loaded.width==zone.width and loaded.height==zone.height)
 assert(#loaded.obstacles>=#zone.obstacles,"authored geometry was lost")
end
local oldPortalCount=#room.mapSpaces:get("surface").portals
local count=0
local player={id="test-player",sid=8,alive=true,active=true,
 x=1800,y=1800,scale=35,spaceId="surface",wood=999,stone=999,
 send=function()end,
 anticheat={invalid=function() count=count+1;return false end}}
room.players[#room.players+1]=player
local commands={
 {"build"},{"build",2000,2000},{"wall"},{"wall",{x=500,y=700,orientation="h"}},
 {"remove-wall",4}
}
for _,args in ipairs(commands) do
 assert(room:handleInput(player,"j",args)==false,
   "legacy house action accepted by server")
end
assert(count==#commands,"legacy commands must be rejected by anticheat")
assert(player.wood==999 and player.stone==999,"rejected build spent resources")
assert(#room.mapSpaces:get("surface").portals==oldPortalCount,
 "legacy command changed map portals")
assert(room.mapSpaces:get("casa-1")==nil,"legacy house appeared in live world")
local legacy=io.open(folder.."/houses-cabana-e-mina.json","rb")
assert(not legacy,"legacy house save file created")
local client=ClientWorld.new()
assert(client:apply("A",{{map={id="cabana-e-mina",portals={}},teams={},animals={}}}))
assert(not client:apply("j",{"add-house",500,500,
  {id="fake-house",to="casa-1",x=500,y=500,targetX=500,targetY=500}}))
assert(not client:apply("j",{"add-wall",0,0,{spaceId="cabana",rect={}}}))
assert(not client:apply("j",{"remove-wall",0,0,{spaceId="cabana",index=4}}))
assert(not client:apply("j",{"build-result",0,0,{ok=true,message="built"}}))
server:close()
print("PASS map-author-only geometry; no player house commands, runtime hooks or saves")
