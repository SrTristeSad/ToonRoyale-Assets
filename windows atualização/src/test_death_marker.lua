-- Live-world smoke: death markers stay after respawn, are shown in
-- both minimap and rendered terrain, and do not leak between floors.
return function()
 local World=require("src.game.world_state")
 local Marker=require("src.game.death_marker")
 local Hud=require("src.game.reference_hud")
 local Camera=require("src.camera")
 local View=require("src.game.reference_view")
 local world=World.new()
 local sid=17
 assert(world:apply("C",{sid}))
 assert(world:apply("D",{{18,sid,"Jogador",7200,8100,0,100,100,35,0}}))
 assert(world:apply("a",{{sid,7460,8280,0},{},{}}))
 local p=world:localPlayer()
 assert(p and p.x==7460 and p.y==8280)
 assert(world:apply("P",{}))
 assert(world.dead and not world:localPlayer())
 local mark=assert(world.lastDeath)
 assert(mark.x==7460 and mark.y==8280 and mark.spaceId=="surface",
   "death marker must use last server-confirmed position")
 local mx,my=Marker.minimapPoint(world,130,14400)
 assert(mx and math.abs(mx-7460/14400*130)<0.01
  and math.abs(my-8280/14400*130)<0.01)
 local camera=Camera.new()
 camera:follow(7460,8280)
 assert(Marker.drawWorld(world,camera,1280,720),
   "death pin must render even when local player has been removed")
 assert(Marker.drawMini(world,20,570,130,14400),
   "death location should render on death screen minimap")
 Hud.drawDeathMap(world)
 -- Server C packet clears the previous avatar, not the last death location.
 assert(world:apply("C",{sid}))
 assert(world.lastDeath==mark,
   "last death position was wrongly removed by respawn")
 assert(world:apply("D",{{20,sid,"Jogador",6200,6600,0,100,100,35,0}}))
 Hud.draw(world,false,"",true)
 assert(Marker.drawWorld(world,camera,1280,720))
 -- A new death overwrites the previous mark, even if a player snapshot
 -- was removed before packet P arrived: fallback is authoritative a.
 assert(world:apply("a",{{sid,6205,6612,0},{},{}}))
 world.players[sid]=nil
 assert(world:apply("P",{}))
 assert(world.lastDeath.x==6205 and world.lastDeath.y==6612)
 -- Cave coordinates MUST not become false surface map coordinates.
 world.lastDeath=Marker.make(530,710,"caverna-01")
 world.spaceId="surface"
 assert(not Marker.sameArea(world))
 assert(Marker.minimapPoint(world,130,14400)==nil)
 assert(not Marker.drawWorld(world,camera,1280,720))
 world.spaceId="caverna-01"
 world.space={width=1500,height=1200}
 assert(Marker.sameArea(world))
 assert(Marker.drawFloorPlan(world,{left=20,top=20,size=200}))
 assert(not Marker.drawMini(world,20,570,130,14400))
 -- Last death is scoped to a connection and not persisted to a new match.
 local newWorld=World.new()
 assert(newWorld.lastDeath==nil)
 print("PASS last-death marker: authoritative coordinates, death screen, respawn, layer-safe map")
end
