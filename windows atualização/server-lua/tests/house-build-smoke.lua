-- Real LC world, ObjectManager, map-space graph, and original economy.
local Local=require("server-lua.local_server")
local Economy=require("server-lua.world.economy")
local ClientWorld=require("src.game.world_state")
local Config=require("src.game.config")
local folder=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"),"CI temp directory required")
local server=Local.new({bind="127.0.0.1",port=18964,roomCode="housetest1234567",
 dataDir=folder,guiHost=true,botCount=0,nowMs=function()return 100000 end,
 mapId="cabana-e-mina",mode="lan"})
local room=server.rooms.LC.room
assert(room and room.mapSpaces and room.customMap,"real custom room required")
local chosen
for x=1200,Config.mapScale-1200,250 do
 for y=1200,Config.mapScale-1200,250 do
  local good=room.object_manager:canPlace(x,y,310,0.6,nil,false)
  for _,p in ipairs(room.mapSpaces:get("surface").portals) do
   local dx,dy=x-p.x,y-p.y
   if dx*dx+dy*dy<700*700 then good=false end
  end
  local origin=room.customMap.spawn
  if origin and (x-origin.x)^2+(y-origin.y)^2<650*650 then good=false end
  if good then chosen={x=x,y=y};break end
 end
 if chosen then break end
end
assert(chosen,"no buildable location found")
local outbound={}
local player={
 id="builder-1",sid=3,x=chosen.x-440,y=chosen.y,
 dir=0,spaceId="surface",scale=35,active=true,alive=true,
 wood=150,stone=100,food=0,gold=0,
 send=function(self,name,...)
  outbound[#outbound+1]={name=name,args={...}}
 end,
 hasRes=function(self,item)return Economy.hasRes(self,item)end,
 useRes=function(self,item)
  Economy.useRes(self,item,nil,{
   config=room.config,send=function()end,score=function()end
  })
 end
}
local bad=0
player.anticheat={invalid=function()bad=bad+1;return false end}
room.players[#room.players+1]=player
room.nowMs=200000
assert(room:handleInput(player,"j",{"build"})==true)
assert(#room.builtHouses==1 and player.wood==80 and player.stone==65)
assert(room.mapSpaces:get("casa-1").type=="interior")
local portal=room.mapSpaces:get("surface").portals[#room.mapSpaces:get("surface").portals]
assert(portal.id=="entrar-casa-1" and portal.x==chosen.x)
assert(outbound[#outbound-1].name=="j" and
 outbound[#outbound-1].args[1]=="add-house")
assert(outbound[#outbound].args[4].ok==true)
-- Untrusted client never chooses x,y or house ID.
assert(room:handleInput(player,"j",{"build",999,999})==false and bad==1)
local c=ClientWorld.new()
assert(c:apply("A",{{map={id="test-build",portals={}},teams={},animals={}}}))
assert(c:apply("j",{"add-house",portal.x,portal.y,portal}))
assert(#c.map.portals==1)
assert(c:apply("j",{"build-result",0,0,{ok=true,message="Casa construida"}}))
assert(c.mapMessage=="Casa construida")
local previous=player.wood
assert(room:handleInput(player,"j",{"build"})==false)
assert(player.wood==previous,"building cooldown must not charge resources")
room.nowMs=206000
player.x=portal.x;player.y=portal.y
assert(room:handleInput(player,"j",{})==true)
assert(player.spaceId=="casa-1" and player.x==700 and player.y==900)
room.nowMs=207000
assert(room:handleInput(player,"j",{})==true)
assert(player.spaceId=="surface" and player.x==portal.x)
room.nowMs=208000
assert(room:handleInput(player,"j",{})==true and player.spaceId=="casa-1")
-- Individual indoor walls consume resources, respect ownership, and are
-- saved together with the house. Existing map exit remains unobstructed.
player.x=550;player.y=450;player.dir=0
room.nowMs=210000
local zone=assert(room.mapSpaces:get("casa-1"))
local beforeObstacles=#zone.obstacles
assert(room:handleInput(player,"j",{"wall"})==true)
assert(#zone.obstacles==beforeObstacles+1)
assert(zone.obstacles[#zone.obstacles].material=="wood")
assert(player.wood==65 and player.stone==60)
local lastRect=zone.obstacles[#zone.obstacles]
local clientZone={id=zone.id,type="interior",
 width=zone.width,height=zone.height,portals=zone.portals,
 obstacles={zone.obstacles[1],zone.obstacles[2],zone.obstacles[3]}}
assert(c:apply("j",{"casa-1",550,450,clientZone}))
assert(c:apply("j",{"add-wall",0,0,{spaceId="casa-1",rect=lastRect}}))
assert(#c.space.obstacles==4 and c.space.obstacles[4].material=="wood")
room.nowMs=211000
local oldWood,oldStone=player.wood,player.stone
assert(room:handleInput(player,"j",{"wall",{x=12000,y=700,orientation="h"}})==false)
assert(player.wood==oldWood and player.stone==oldStone,
 "untrusted coordinates cannot spend resources")
assert(room:handleInput(player,"j",{"wall",{x=500,y=700,orientation="h"}})==true)
assert(#zone.obstacles==5 and zone.obstacles[5].x==400
 and zone.obstacles[5].width==200,"mouse-positioned horizontal wall missing")
assert(player.wood==50 and player.stone==55)
assert(c:apply("j",{"add-wall",0,0,{spaceId="casa-1",
 rect=zone.obstacles[5]}}) and #c.space.obstacles==5)
room.nowMs=212000
assert(room:handleInput(player,"j",{"remove-wall",3})==false,
 "client demolished a permanent structural wall")
assert(room:handleInput(player,"j",{"remove-wall",5})==true)
assert(#zone.obstacles==4 and player.wood==50 and player.stone==55,
 "wall demolition removed wrong wall or refunded resources")
assert(c:apply("j",{"remove-wall",0,0,{spaceId="casa-1",index=5}}))
assert(#c.space.obstacles==4,
 "client did not remove same wall index as server")
local randomUser={id="intruder",alive=true,spaceId="casa-1",
 x=550,y=450,send=function()end,account=nil}
room.players[#room.players+1]=randomUser
room.nowMs=213000
assert(room:handleInput(randomUser,"j",{"remove-wall",4})==false,
 "non-owner guest was able to remove a house wall")
local saved=assert(io.open(folder.."/houses-cabana-e-mina.json","rb"))
local bytes=saved:read("*a");saved:close()
assert(bytes:find("walls",1,true),"house file does not save walls")
server:close()
-- Restart the SAME map with the SAME data directory: constructed geometry
-- must survive without charging resources or affecting the MB room.
local restarted=Local.new({bind="127.0.0.1",port=18965,
 roomCode="houseagain123456",dataDir=folder,guiHost=true,botCount=0,
 nowMs=function()return 100000 end,mapId="cabana-e-mina",mode="lan"})
local restored=restarted.rooms.LC.room
assert(#restored.builtHouses==1 and #restored.mapSpaces:get("casa-1").obstacles==4)
assert(restored.mapSpaces:get("surface").portals[2].id=="entrar-casa-1")
assert(#restarted.rooms.MB.room.mapSpaces:get("surface").portals==0)
restarted:close()
print("PASS house crafting: economy, abuse prevention, modular walls, saved geometry and restart isolation")
