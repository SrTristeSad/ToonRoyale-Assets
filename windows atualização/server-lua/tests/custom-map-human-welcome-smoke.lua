-- Regression: the HUMAN onJoined welcome packet must include custom-map
-- metadata, not just the internal-bot addBot welcome. This used to cause
-- clients to render the classic world regardless of the selected map.
local Registry=require("server-lua.world.player_registry")
local Spaces=require("server-lua.world.map_spaces")
local Maps=require("server-lua.world.map_profiles")
local World=require("src.game.world_state")
local Config=require("src.game.config")

local map=Maps.load("server-lua/maps","bunker-e-cavernas")
local function joined(room)
 local peer={}
 local received
 local player={id="human-test",send=function(self,name,info)
  assert(name=="A")
  received=info
 end}
 room.players={player}
 local instance=setmetatable({
  room=room,pending={[peer]=player},playersById={},
  options={clanList=function()return {}end},animalKinds={}
 },{__index=Registry})
 Registry.onJoined(instance,player,peer,{},room)
 assert(instance.playersById[player.id]==nil or instance.playersById[player.id]==player)
 assert(type(received)=="table")
 return received
end
local room={key="LC",mapId=map.id,customMap=map,
 mapSpaces=Spaces.new(map,Config.mapScale)}
local data=joined(room)
assert(data.map and data.map.id=="bunker-e-cavernas"
 and data.map.name=="Bunker e Cavernas"
 and #data.map.portals==2,"real player was not given custom map portals")
local client=World.new()
assert(client:apply("A",{data}))
assert(client.map.id==map.id and client.map.name==map.name)
assert(client.map.portals[2].style=="cave")
local roomMB={key="MB",mapId="classico",customMap=nil,
 mapSpaces=Spaces.new(nil,Config.mapScale)}
assert(joined(roomMB).map==nil,"classic MB must stay unmodified")
print("PASS human custom-map handshake: cave entrances, map name and MB isolation")
