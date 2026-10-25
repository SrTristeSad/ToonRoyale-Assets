-- A community map's reusable resources and reversible mechanisms use
-- the same real Room, packet routing, collision and economy as any other map.
local Local=require("server-lua.local_server")
local Maps=require("server-lua.world.map_profiles")
local World=require("src.game.world_state")
local Json=require("server-lua.vendor.dkjson")
local data=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"))
local server=Local.new({bind="127.0.0.1",port=18996,
 roomCode="reusablemechanismtest",dataDir=data,guiHost=true,
 botCount=0,mode="lan",nowMs=function()return 100000 end,
 mapId="refugio-personalizado"})
local room=server.rooms.LC.room
local zone=assert(room.mapSpaces:get("mod-sala-metal"))
local objects={}
for _,obj in ipairs(zone.interactables) do objects[obj.id]=obj end
local node=assert(objects["mina-pedra"])
local switch=assert(objects["interruptor-portao"])
local gate=assert(objects["portao-metal"])
assert(node.kind=="node" and node.remaining==3 and node.version==0)
assert(gate.closed and switch.version==0)
local function client()
 local world=World.new()
 local map=Maps.load("server-lua/maps","refugio-personalizado")
 assert(world:apply("A",{{map={id=map.id,name=map.name,
  portals=map.portals}}}))
 assert(world:apply("j",{zone.id,550,930,
  assert(Json.decode(Json.encode(zone)))}))
 return world
end
local a,b=client(),client()
local eventsA,eventsB={},{}
local owner={id="miner",alive=true,spaceId=zone.id,
 x=550,y=930,scale=35,stone=0,
 send=function(_,name,...)eventsA[#eventsA+1]={name=name,args={...}}end,
 addResource=function(self,kind,amount,auto)
  assert(kind==2 and amount==8 and auto)
  self.stone=self.stone+amount
 end}
local friend={id="switcher",alive=true,spaceId=zone.id,
 x=690,y=880,scale=35,
 send=function(_,name,...)eventsB[#eventsB+1]={name=name,args={...}}end}
room.players[#room.players+1]=owner
room.players[#room.players+1]=friend
local function relay(packetName)
 local updates={}
 for _,list in ipairs({eventsA,eventsB}) do
  for _,evt in ipairs(list) do
   if evt.name=="j" and evt.args[1]=="interaction-update"
     and evt.args[4].id==packetName then
    updates[#updates+1]=evt.args
   end
  end
 end
 assert(#updates>=2,"missing authoritative multicast to both players")
 local last=updates[#updates]
 assert(a:apply("j",last) and b:apply("j",last))
 assert(not a:apply("j",last),"replayed version must not apply twice")
 return last
end
room.nowMs=200000
assert(room:handleInput(owner,"j",{"interact","mina-pedra"}))
assert(owner.stone==8 and node.remaining==2)
local first=relay("mina-pedra")
assert(first[4].remaining==2 and a.space.interactables[4].remaining==2)
room.nowMs=200450
assert(not room:handleInput(friend,"j",{"interact","mina-pedra"}),
 "another player bypassed shared node cooldown")
assert(not room:handleInput(owner,"j",{"interact","mina-pedra"}))
assert(owner.stone==8)
room.nowMs=201500
assert(room:handleInput(owner,"j",{"interact","mina-pedra"}))
assert(owner.stone==16 and node.remaining==1)
relay("mina-pedra")
room.nowMs=203000
assert(room:handleInput(owner,"j",{"interact","mina-pedra"}))
assert(owner.stone==24 and node.remaining==0 and node.used)
relay("mina-pedra")
room.nowMs=205000
assert(not room:handleInput(owner,"j",{"interact","mina-pedra"})
 and owner.stone==24,"depleted resource node granted extra resources")
assert(not room:handleInput(friend,"j",{"interact","mina-pedra"}),
 "depleted node was harvestable by second player")
-- Each close/open event updates an obstacle rectangle, not just a sprite.
room.nowMs=206000
assert(room:handleInput(friend,"j",{"interact","interruptor-portao"}))
assert(not gate.closed and room.mapSpaces:canOccupy(zone.id,gate.x,gate.y,35))
local opened=relay("interruptor-portao")
assert(opened[4].gateClosed==false and not a.space.interactables[3].closed)
assert(#a.space.obstacles==#zone.obstacles)
room.nowMs=206400
assert(not room:handleInput(friend,"j",{"interact","interruptor-portao"}),
 "shared switch cooldown was bypassed")
owner.x,owner.y=gate.x,gate.y
room.nowMs=207000
assert(not room:handleInput(friend,"j",{"interact","interruptor-portao"}),
 "gate closed on top of another live player")
assert(not gate.closed)
owner.x,owner.y=550,930
local occupyingAI
for _,mob in ipairs(room.ais) do
 if mob.active then occupyingAI=mob;break end
end
assert(occupyingAI)
local oldX,oldY,oldSpace=occupyingAI.x,occupyingAI.y,occupyingAI.spaceId
occupyingAI.spaceId=zone.id
occupyingAI.x,occupyingAI.y=gate.x,gate.y
room.nowMs=208000
assert(not room:handleInput(friend,"j",{"interact","interruptor-portao"}),
 "gate closed on top of live AI")
assert(not gate.closed)
occupyingAI.x,occupyingAI.y=oldX,oldY
occupyingAI.spaceId=oldSpace
room.nowMs=209000
assert(room:handleInput(friend,"j",{"interact","interruptor-portao"}))
assert(gate.closed and not room.mapSpaces:canOccupy(zone.id,gate.x,gate.y,35))
local closed=relay("interruptor-portao")
assert(closed[4].gateClosed==true)
assert(#a.space.obstacles==#zone.obstacles
 and #b.space.obstacles==#zone.obstacles)
local c=client()
assert(c.space.interactables[4].remaining==0
 and c.space.interactables[4].used and c.space.interactables[3].closed,
 "late arrival received stale node or gate state")
-- Invalid user map content cannot exceed finite resources, bypass time
-- controls or point a switch to a nonexistent physical gate.
local map=Maps.load("server-lua/maps","refugio-personalizado")
local function reject(edit)
 local obj=assert(Json.decode(Json.encode(map)))
 edit(obj)
 assert(not pcall(Maps.validate,Json.encode(obj),obj.id),
   "malformed mechanism accepted by map validator")
end
reject(function(m)m.spaces[1].interactables[4].charges=99999 end)
reject(function(m)m.spaces[1].interactables[4].cooldownMs=-1 end)
reject(function(m)m.spaces[1].interactables[5].target="nonexistent" end)
reject(function(m)m.spaces[1].interactables[5].cooldownMs=999999 end)
reject(function(m)
 m.spaces[1].interactables[3].x=859
 m.spaces[1].interactables[3].y=790
end)
local exterior=assert(Json.decode(Json.encode(map)))
exterior.interactables[#exterior.interactables+1]={
 id="outdoor-deposit",kind="node",x=3790,y=3700,
 resource="stone",amount=4,charges=2,cooldownMs=2000}
assert(Maps.validate(Json.encode(exterior),exterior.id),
 "custom-map surface must support finite gathering nodes")
assert(server.rooms.MB.room.mapSpaces:get(zone.id)==nil)
server:close()
print("PASS map mechanisms: limited harvest, cooldown, anti-crush, two clients, stale packets and late join")
