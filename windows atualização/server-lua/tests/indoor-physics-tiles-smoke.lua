-- Regression for the reported frozen bunker player: exercise the actual
-- numeric speed from src.game.config, not an artificial fast test actor.
local Local=require("server-lua.local_server")
local Map=require("server-lua.world.map_profiles")
local Physics=require("server-lua.world.indoor_movement")
local Config=require("src.game.config")
local dataDir=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"),
  "temporary data dir must be supplied")
local map=Map.load("server-lua/maps","bunker-e-cavernas")
local localGame=Local.new({bind="127.0.0.1",port=18989,
 roomCode="indoorphysicstest",dataDir=dataDir,mode="lan",
 nowMs=function()return 100000 end,guiHost=true,botCount=0,mapId=map.id})
local room=localGame.rooms.LC.room
local zone=room.mapSpaces:get("bunker-01")
local player={
 id="physics-test",spaceId="bunker-01",x=750,y=850,scale=35,
 xVel=0,yVel=0,speed=Config.playerSpeed,moveDir=0,dir=0,
 alive=true,active=true,shameTimer=0,shameCount=0,
 powers={speed=1},slowMult=1,regenTimer=1000,dmgOverTime={},
 healCol=0,pps=0,weaponIndex=0,buildIndex=-1,reloads={[0]=300},
 hits=0,gathering=0,mouseState=0,autoGather=false,lockMove=false,
 noMovTimer=0,changeHealth=function()error("unexpected regeneration")end
}
room.players[#room.players+1]=player
local initialX=player.x
for i=1,60 do
 room.nowMs=100000+i*16
 assert(Physics.step(player,16,room))
end
assert(player.x>initialX+90,
 "indoor movement was too slow to be playable with original speed")
assert(room.mapSpaces:canOccupy("bunker-01",player.x,player.y,player.scale),
 "player stepped into solid geometry")
-- Collision is not a picture: the original map's steel column at x1250
-- blocks the physical actor independently of its render pass.
player.x=1170;player.y=700
player.xVel=0;player.yVel=0;player.moveDir=0
for i=1,70 do
 room.nowMs=101000+i*16
 assert(Physics.step(player,16,room))
end
assert(player.x<1250-player.scale+0.01,
 "player went through the visible steel wall")
assert(player.x>1180,"player failed to move up to the wall")
-- Sliding along the wall must remain possible.
local oldY=player.y
player.moveDir=math.pi/2
player.xVel=0;player.yVel=0
for i=1,45 do
 room.nowMs=102500+i*16
 assert(Physics.step(player,16,room))
end
assert(player.y>oldY+60,"player cannot move along collision wall")
-- Perimeter collision must follow the real map, not a HUD overlay.
player.x=118;player.y=650
player.xVel=0;player.yVel=0;player.moveDir=math.pi
for i=1,65 do
 room.nowMs=104000+i*16
 assert(Physics.step(player,16,room))
end
assert(player.x>=105-0.01,"player escaped through outer bunker wall")
-- 4 new boundary segments are collidable in each map region.
for _,area in ipairs(map.spaces) do
 local z=room.mapSpaces:get(area.id)
 assert(z and #z.obstacles>=6)
 assert(not room.mapSpaces:canOccupy(area.id,85,85,35),
   "floor collision does not include the outer tiles: "..area.id)
end
-- Real dungeon AI: on an angled approach against bunker-02's vertical
-- wall, the blocked horizontal component must not cancel free movement.
local wolf
for _,ai in ipairs(room.ais) do
 if ai.active and ai.spaceId=="bunker-02" and ai.index==4 then
  wolf=ai;break end
end
assert(wolf and wolf.scale==84)
wolf.x=800;wolf.y=500
wolf.xVel=0.7;wolf.yVel=0.7
wolf.moveCount=0;wolf.waitCount=2000;wolf.hitWait=0
assert(room.mapSpaces:canOccupy("bunker-02",wolf.x,wolf.y,wolf.scale))
wolf:update(100)
assert(wolf.x<=816 and wolf.y>520,
 "dungeon wolf stopped on both axes or went through physical wall")
assert(room.mapSpaces:canOccupy("bunker-02",wolf.x,wolf.y,wolf.scale))
localGame:close()
print("PASS indoor physics: original speed, collidable walls, sliding AI, 4 level boundaries")
