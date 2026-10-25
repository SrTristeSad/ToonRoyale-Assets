-- End-to-end LOCAL room, user-defined cache and physical gate. Game
-- packet j keeps authority server-side, including all resources/collisions.
local Local=require("server-lua.local_server")
local Json=require("server-lua.vendor.dkjson")
local Maps=require("server-lua.world.map_profiles")
local Client=require("src.game.world_state")
local View=require("src.game.reference_view")
local base=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"))
local roomServer=Local.new({bind="127.0.0.1",port=18995,
 roomCode="mapinteractiontest",dataDir=base,guiHost=true,
 botCount=0,nowMs=function() return 100000 end,mode="lan",
 mapId="refugio-personalizado"})
local room=roomServer.rooms.LC.room
local zone=assert(room.mapSpaces:get("mod-sala-metal"))
assert(#zone.interactables==3)
local closed=zone.interactables[3]
assert(closed.closed and not
 room.mapSpaces:canOccupy(zone.id,closed.x,closed.y,35),
 "gate must be physically solid when closed")
local function newClient()
 local client=Client.new()
 local map=Maps.load("server-lua/maps","refugio-personalizado")
 assert(client:apply("A",{{map={
  id=map.id,name=map.name,portals=map.portals}}}))
 -- Serialize to simulate independent packet bytes, not a shared Lua table.
 local copied=assert(Json.decode(Json.encode(zone)))
 assert(client:apply("j",{zone.id,580,520,copied}))
 return client
end
local client1,client2=newClient(),newClient()
local events1,events2={},{}
local p1={
 id="interact-owner",alive=true,spaceId=zone.id,
 x=580,y=520,scale=35,wood=0,
 send=function(_,name,...) events1[#events1+1]={name=name,args={...}} end,
 addResource=function(self,kind,amount,auto)
  assert(kind==0 and amount==35 and auto==true)
  self.wood=self.wood+amount
 end,
 anticheat={invalid=function() return false end}
}
local p2={id="interact-witness",alive=true,spaceId=zone.id,
 x=500,y=520,scale=35,
 send=function(_,name,...) events2[#events2+1]={name=name,args={...}} end}
room.players[#room.players+1]=p1
room.players[#room.players+1]=p2
room.nowMs=200000
assert(room:handleInput(p1,"j",{"interact","bau-madeira"}))
assert(p1.wood==35 and zone.interactables[1].used)
local cachePackets=0
for _,event in ipairs(events1) do
 if event.name=="j" and event.args[1]=="interaction-update" then
  assert(client1:apply("j",event.args));cachePackets=cachePackets+1
 end
end
for _,event in ipairs(events2) do
 if event.name=="j" and event.args[1]=="interaction-update" then
  assert(client2:apply("j",event.args))
 end
end
assert(cachePackets==1 and client1.space.interactables[1].used
 and client2.space.interactables[1].used,
 "cache state not synchronized to both clients")
room.nowMs=201000
assert(room:handleInput(p1,"j",{"interact","bau-madeira"})==false
 and p1.wood==35,"resource cache duplicated")
p1.x=1300;p1.y=850
room.nowMs=202000
assert(not room:handleInput(p1,"j",{"interact","alavanca-portao"}),
 "server accepted interaction outside 150 radius")
assert(closed.closed)
p1.x=665;p1.y=740
room.nowMs=203000
assert(room:handleInput(p1,"j",{"interact","alavanca-portao"}))
assert(not closed.closed
 and room.mapSpaces:canOccupy(zone.id,closed.x,closed.y,35),
 "opening gate only changed its sprite instead of collision")
local synced1,synced2=false,false
for _,event in ipairs(events1) do
 if event.name=="j" and event.args[1]=="interaction-update"
  and event.args[4].kind=="lever" then
  synced1=client1:apply("j",event.args)
 end
end
for _,event in ipairs(events2) do
 if event.name=="j" and event.args[1]=="interaction-update"
  and event.args[4].kind=="lever" then
  synced2=client2:apply("j",event.args)
 end
end
assert(synced1 and synced2
 and client1.space.interactables[3].closed==false
 and client2.space.interactables[3].closed==false)
for _,client in ipairs({client1,client2}) do
 for _,wall in ipairs(client.space.obstacles) do
  assert(wall.interactiveGateId~="portao-metal",
    "client kept physical gate wall after server opened it")
 end
end
-- Late joiners receive current room state, including consumed caches and
-- opened gates; no client-triggered map reset can restore resources.
local late=newClient()
assert(late.space.interactables[1].used)
assert(late.space.interactables[3].closed==false)
assert(room:handleInput(p1,"j",{"interact","alavanca-portao"})==false)
local map=Maps.load("server-lua/maps","refugio-personalizado")
local bad=assert(Json.decode(Json.encode(map)))
bad.spaces[1].interactables[1].amount=99999
assert(not pcall(Maps.validate,Json.encode(bad),bad.id),
 "malicious resource cache allowed unlimited reward")
bad=assert(Json.decode(Json.encode(map)))
bad.spaces[1].interactables[2].target="not-existing"
assert(not pcall(Maps.validate,Json.encode(bad),bad.id),
 "unresolved switch target accepted")
assert(roomServer.rooms.MB.room.mapSpaces:get("mod-sala-metal")==nil)
roomServer:close()
print("PASS map interactivity: reward once, distance, gate physics, two clients, late join and MB isolation")
