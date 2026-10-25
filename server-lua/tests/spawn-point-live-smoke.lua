-- Regression: Player.spawn must invoke the ORIGINAL ObjectManager.fetchSpawnObj
-- broadcast, deactivate the point, and decrement the owner's item counter.
local Player=require("server-lua.world.player")
local World=require("server-lua.world.objects")
local Config=require("src.game.config")
local broadcasts={}
local player={sid=7,powers={size=1,health=1},points=10,
  changeItemCount=function(self,group,amount)
    assert(group==42 and amount==-1)
    self.itemChanges=(self.itemChanges or 0)+1
  end}
local point={sid=91,x=513,y=726,active=true,owner=player,spawnPoint=true,
  group={id=42},gridLocations={},sentTo={}}
local world=setmetatable({objects={point},grids={}},World)
local room={config=Config,object_manager=world,nowMs=12345,
  broadcast=function(name,sid)
    broadcasts[#broadcasts+1]={name,sid}
  end,
  sendId=function()end}
player.room=room
setmetatable(player,{__index=Player})
player:spawn(false)
assert(player.x==513 and player.y==726,
  "Player.spawn must reuse the exact original owner spawn point")
assert(point.active==false and player.itemChanges==1,
  "spawn structure must be consumed with correct item count")
assert(#broadcasts==1 and broadcasts[1][1]=="Q" and broadcasts[1][2]==91,
  "ObjectManager.fetchSpawnObj must broadcast original Q packet")
print("PASS Player.spawn: spawn point removal, owner item count and Q broadcast")
