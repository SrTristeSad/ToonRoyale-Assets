-- LÖVE smoke: actually render both worlds, not just validate geometry JSON.
local World=require("src.game.world_state")
local Camera=require("src.camera")
local View=require("src.game.reference_view")
local function run()
 assert(View.doorOpenRatio(300)==0)
 assert(View.doorOpenRatio(185)==0)
 assert(View.doorOpenRatio(130)>0.49)
 assert(View.doorOpenRatio(75)==1)
 assert(View.doorOpenRatio(nil)==0)
 local floorPlan=assert(View.dungeonMapGeometry(
   {width=2000,height=1000},{x=1000,y=500},174))
 assert(math.abs(floorPlan.x-87)<0.001
   and math.abs(floorPlan.y-87)<0.001
   and floorPlan.scale>0
   and floorPlan.top>0,
   "floor plan must use exact level-world scale and centered avatar")
 assert(View.dungeonMapGeometry(nil,{},174)==nil)
 local vicinity={
  space={interactables={
   {id="cache-far",kind="cache",x=350,y=100,used=false},
   {id="cache-near",kind="cache",x=170,y=100,used=false},
   {id="lever-used",kind="lever",x=110,y=100,used=true}
  }},
  localPlayer=function() return {x=100,y=100} end
 }
 assert(View.nearestInteraction(vicinity).id=="cache-near")
 vicinity.space.interactables[2].used=true
 assert(View.nearestInteraction(vicinity)==nil)
 local world=World.new()
 local portal={id="entrar-cabana",x=1950,y=1950,to="cabana",
  targetX=600,targetY=900}
 assert(world:apply("A",{{teams={},animals={},map={
  id="cabana-e-mina",portals={portal}}}}))
 assert(world:apply("C",{0}))
 assert(world:apply("D",{{"test-player",0,"Jogador",1950,1950,
  0,100,100,35,0}}))
 local actor=assert(world:localPlayer())
 actor.buildIndex=-1;actor.weaponIndex=0;actor.variant=0;actor.skin=0
 local camera=Camera.new()
 camera:follow(1950,1950)
 local w,h=love.graphics.getDimensions()
 local surface=love.graphics.newCanvas(w,h)
 love.graphics.push("all")
 love.graphics.setCanvas(surface)
 love.graphics.clear(0,0,0,1)
 View.draw(world,camera,0.016,{showGrid=true,localAim=0})
 love.graphics.pop()
 assert(world.map and world.spaceId=="surface")
 assert(world:apply("j",{"cabana",600,900,{
  id="cabana",type="interior",width=1400,height=1200,
  obstacles={{x=100,y=100,width=1000,height=80}},
  portals={{id="escada-mina",x=1050,y=800,
    to="mina",targetX=400,targetY=500}}
 }}))
 assert(world.spaceId=="cabana" and #world:orderedObjects()==0)
 local own=assert(world:localPlayer())
 assert(own.x==600 and own.y==900)
 camera:follow(600,900)
 local interior=love.graphics.newCanvas(w,h)
 love.graphics.push("all")
 love.graphics.setCanvas(interior)
 love.graphics.clear(0,0,0,1)
 View.draw(world,camera,0.016,{showGrid=true,localAim=0,showDungeonMap=true})
 love.graphics.pop()
 local a=surface:newImageData()
 local b=interior:newImageData()
 local ar,ag,ab=a:getPixel(7,7)
 local br,bg,bb=b:getPixel(7,7)
 assert(math.abs(ar-br)+math.abs(ag-bg)+math.abs(ab-bb)>0.05,
  "inside house must look different from outdoor world")
 -- Render the REAL bunker and cave floors shipped with the server. This
 -- catches a regression where both levels show the same generic/overlay
 -- floor, instead of tiles and stairwells at collision coordinates.
 local MapProfiles=require("server-lua.world.map_profiles")
 local bunkerMap=MapProfiles.load("server-lua/maps","bunker-e-cavernas")
 assert(world:apply("A",{{teams={},animals={},map={
   id=bunkerMap.id,name=bunkerMap.name,portals=bunkerMap.portals}}}))
 local captures={}
 for _,test in ipairs({
  {name="bunker",id="bunker-01",x=750,y=850},
  {name="cavern",id="caverna-01",x=500,y=700}
 }) do
  local zone
  for _,z in ipairs(bunkerMap.spaces) do
   if z.id==test.id then zone=z;break end
  end
  assert(zone and world:apply("j",{test.id,test.x,test.y,zone}))
  camera:follow(test.x,test.y)
  local canvas=love.graphics.newCanvas(w,h)
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0,0,0,1)
  View.draw(world,camera,0.016,{showGrid=true,localAim=0})
  love.graphics.pop()
  captures[test.name]=canvas:newImageData()
  if os.getenv("MOO_IO_CAPTURE_UI")=="1" then
   local name="ui-map-"..test.name..".png"
   captures[test.name]:encode("png",name)
   print("UI CAPTURE "..name.." -> "..love.filesystem.getSaveDirectory())
  end
  canvas:release()
 end
 local bur,b_ug,bub=captures.bunker:getPixel(400,350)
 local cur,cug,cub=captures.cavern:getPixel(400,350)
 assert(math.abs(bur-cur)+math.abs(b_ug-cug)+math.abs(bub-cub)>0.1,
  "bunker floor and cave rock tiles should not look identical")
 surface:release();interior:release()
 assert(world:apply("j",{"surface",1950,1950,{
  id="surface",type="surface",width=14400,height=14400,
  obstacles={},portals={portal}}}))
 assert(world.spaceId=="surface" and world:localPlayer().x==1950)
 print("PASS map view: outdoor roof, indoor walls and server-authoritative zone reset")
end
return run
