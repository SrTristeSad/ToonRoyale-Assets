-- A player dies and respawns in the SAME server session:
-- paid shop hats/accessories persist, placed objects remain in world,
-- while the life-specific age, XP, score and equipment are reset.
local Room=require("server-lua.world.room")
local Player=require("server-lua.world.player")
local Catalogue=require("server-lua.world.catalogue")
local Words=require("server-lua.world.name_words")
local MP=require("src.protocol.msgpack")
local messages={}
local room=Room.new({
 nowMs=10000,
 broadcast=function()end,
 services={ensureAnimals=function()end}
})
local p=Player.new("abcdefghijklmnop",2,room,{
 hats=Catalogue.hats,accessories=Catalogue.accessories,
 nameWords=Words,ip="127.0.0.1",did="same-device",
 send=function(name,...)
  messages[#messages+1]={name=name,args={...}}
 end,
 icon=function(player)return room:onPlayerDeath(player)end,
 anticheat={
  invalid=function(_,name,why)error("invalid "..name..":"..why)end,
  allow=function()return true end,
  onGameStart=function()end,
  tick=function()end
 }
})
room:bindPlayer(p)
room:handleInput(p,"M",{MP.map({name="Jogador",skin=0})})
assert(p.alive and p.age==1 and p.points==0)
-- Player earns and spends the gold on a paid hat and an accessory.
p:addResource(3,1800,true)
room:handleInput(p,"c",{1,5,0}) -- Cowboy Hat, 1000 gold
room:handleInput(p,"c",{0,5,0}) -- equip
room:handleInput(p,"c",{1,9,1}) -- Tree Cape, 1000 gold
-- The first purchase leaves 800, so acquiring Tree Cape requires more work.
assert(p.skins[5]==1 and p.skinIndex==5)
assert(not p.tails[9])
p:addResource(3,300,true)
room:handleInput(p,"c",{1,9,1})
room:handleInput(p,"c",{0,9,1})
assert(p.tails[9]==1 and p.tailIndex==9)
local structure=room.object_manager:addDynamic(1800,2000,0,40,2,
 {id=10,group={id=3,layer=1},health=400,doUpdate=true},p)
assert(structure and structure.active)
p.age=6;p.XP=123;p.weaponIndex=0
local beforeCount=#room.object_manager.objects
p:kill(nil,nil,nil)
assert(not p.alive,"death must be authoritative")
assert(#room.object_manager.objects==beforeCount and structure.active,
 "death must not remove placed server objects")
room:handleInput(p,"M",{MP.map({name="Jogador",skin=0})})
assert(p.alive and p.age==1 and p.XP==0,
 "respawn resets life progression without changing identity")
assert(p.skins[5]==1 and p.skinIndex==5,
 "paid hat and equipped appearance lost on respawn")
assert(p.tails[9]==1 and p.tailIndex==9,
 "paid accessory and equipped appearance lost on respawn")
assert(#room.object_manager.objects==beforeCount and structure.active,
 "respawn deleted previously constructed item from server")
assert(room.players[1]==p,"respawn created a second Player")
print("PASS death/respawn: life reset; same player owns hats, accessories and placed objects")
