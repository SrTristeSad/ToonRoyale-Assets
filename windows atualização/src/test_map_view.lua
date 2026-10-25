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
 View.draw(world,camera,0.016,{showGrid=true,localAim=0})
 love.graphics.pop()
 local a=surface:newImageData()
 local b=interior:newImageData()
 local ar,ag,ab=a:getPixel(7,7)
 local br,bg,bb=b:getPixel(7,7)
 assert(math.abs(ar-br)+math.abs(ag-bg)+math.abs(ab-bb)>0.05,
  "inside house must look different from outdoor world")
 surface:release();interior:release()
 assert(world:apply("j",{"surface",1950,1950,{
  id="surface",type="surface",width=14400,height=14400,
  obstacles={},portals={portal}}}))
 assert(world.spaceId=="surface" and world:localPlayer().x==1950)
 print("PASS map view: outdoor roof, indoor walls and server-authoritative zone reset")
end
return run
