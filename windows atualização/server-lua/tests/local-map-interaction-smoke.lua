-- Exercise a real Room's local-only packet dispatch and physics without
-- networking shortcuts, browser mocks or modifying the V2 server.
local Config=require("src.game.config")
local Room=require("server-lua.world.room")
local Profiles=require("server-lua.world.map_profiles")
local Spaces=require("server-lua.world.map_spaces")
local Indoor=require("server-lua.world.indoor_movement")
local map=Profiles.load("server-lua/maps","cabana-e-mina")
local events={}
local strikes=0
local player={
 id="test-player",sid=1,active=true,alive=true,spaceId="surface",
 x=room.customMap.portals[1].x,y=room.customMap.portals[1].y,
 scale=35,xVel=0,yVel=0,speed=Config.playerSpeed,
 moveDir=nil,dir=0,powers={speed=1},shameTimer=0,
 weaponIndex=0,buildIndex=-1,reloads={[0]=300},hits=0,mouseState=0,
 regenTimer=1000,dmgOverTime={},healCol=0,pps=0,slowMult=1,
 sentTo={["second-player"]=true},visiblePlayers={2},visibleAis={1},
 attrCache={[2]="cached"},lockMove=false,
 send=function(_,name,...)
  events[#events+1]={name=name,args={...}}
 end,
 anticheat={invalid=function()strikes=strikes+1;return false end}
}
local other={id="second-player",alive=true,spaceId="surface",
 x=3000,y=3000,scale=35,sentTo={["test-player"]=true}}
local obj={sentTo={["test-player"]=true}}
local room=setmetatable({key="LC",customMap=map,mapSpaces=Spaces.new(map,Config.mapScale),
 config=Config,nowMs=5000,players={player,other},services={},
 items={weapons={[0]={speed=500,gather=1}},list={},projectiles={}},
 object_manager={objects={obj}}},Room)
assert(room:handleInput(player,"j",{})==true)
assert(player.spaceId=="cabana" and player.x==600 and player.y==900)
assert(events[#events].name=="j" and events[#events].args[4].type=="interior")
assert(player.xVel==0 and player.moveDir==nil)
assert(obj.sentTo[player.id]==nil and other.sentTo[player.id]==nil)
assert(player.sentTo[other.id]==nil)
assert(not room:usePortal(player),"portal cannot be used during cooldown")
assert(room:handleInput(player,"j",{"mine"})==false and strikes==1,
 "client must never send an arbitrary destination")
room.nowMs=5701
assert(room:handleInput(player,"j",{})==true)
assert(player.spaceId=="surface" and player.x==room.customMap.portals[1].x)
room.nowMs=6402
assert(room:handleInput(player,"j",{})==true)
player.x=1050;player.y=800
room.nowMs=7103
assert(room:handleInput(player,"j",{})==true)
assert(player.spaceId=="mina" and player.x==400 and player.y==500)
room.nowMs=7804
assert(room:handleInput(player,"j",{})==true)
assert(player.spaceId=="cabana")
room.nowMs=8505
player.x=600;player.y=300;player.moveDir=-math.pi/2
assert(Indoor.step(player,200,room))
assert(player.y>=215 and player.y<300,"solid house wall must stop the player")
assert(player.spaceId=="cabana")
player.moveDir=math.pi/2;player.x=1050;player.y=800
local before=#events
room.nowMs=8506
assert(room:usePortal(player)==true)
assert(player.spaceId=="mina" and #events==before+1)
local legacy=setmetatable({key="MB",customMap=nil,mapSpaces=Spaces.new(nil,Config.mapScale),
 players={player},services={},items={weapons={},list={}}},Room)
local previous=player.spaceId
assert(legacy:handleInput(player,"j",{})==false)
assert(player.spaceId==previous,"classic room accepted custom-map transition")
assert(strikes==2)
print("PASS local map space: real packet dispatch, cooldown, solid wall, portal chain and classic isolation")
