-- Match-scoped craftable houses for custom LC maps. Server chooses every
-- position, charges original economy resources, and owns the new portal.
local House={}
local ITEM={req={"wood",70,"stone",35}}
local MAX_ROOM=16
local MAX_PLAYER=2
local function fail(p,reason)
 if p and type(p.send)=="function" then
  p:send("j","build-result",0,0,{ok=false,message=reason})
 end
 return false
end
function House.build(room,player)
 if room.key~="LC" or not room.customMap or not player.alive
   or (player.spaceId or "surface")~="surface" then
  return fail(player,"Casa apenas em mapa personalizado, na superficie.")
 end
 if room.nowMs<(player.nextHouseAt or 0) then
  return fail(player,"Aguarde antes de construir outra casa.")
 end
 room.builtHouses=room.builtHouses or {}
 if #room.builtHouses>=MAX_ROOM then
  return fail(player,"Limite de casas desta sala atingido.")
 end
 local built=0
 for _,house in ipairs(room.builtHouses) do
  if house.ownerId==player.id then built=built+1 end
 end
 if built>=MAX_PLAYER then return fail(player,"Limite de duas casas por jogador.") end
 if not player:hasRes(ITEM) then
  return fail(player,"Casa exige 70 de madeira e 35 de pedra.")
 end
 local angle=player.dir or 0
 local x=math.floor(player.x+440*math.cos(angle)+0.5)
 local y=math.floor(player.y+440*math.sin(angle)+0.5)
 local cfg=room.config
 if x<310 or y<310 or x>cfg.mapScale-310 or y>cfg.mapScale-310 then
  return fail(player,"Muito perto do limite do mapa.")
 end
 if not room.object_manager:canPlace(x,y,310,0.6,nil,false) then
  return fail(player,"Espaco ocupado ou muito perto da agua.")
 end
 -- Avoid overlapping roofs, existing portals and critical spawn sites.
 for _,entry in ipairs(room.mapSpaces:get("surface").portals) do
  local dx,dy=x-entry.x,y-entry.y
  if dx*dx+dy*dy<700*700 then
   return fail(player,"Afaste-se de outras construcoes e passagens.")
  end
 end
 if room.customMap.spawn then
  local dx,dy=x-room.customMap.spawn.x,y-room.customMap.spawn.y
  if dx*dx+dy*dy<650*650 then
   return fail(player,"Afaste-se do ponto inicial dos jogadores.")
  end
 end
 local index=#room.builtHouses+1
 local zoneId="casa-"..index
 local portalId="entrar-"..zoneId
 local indoor={
  id=zoneId,type="interior",width=1400,height=1200,
  obstacles={
   {x=100,y=100,width=1000,height=80},
   {x=100,y=100,width=80,height=1000},
   {x=1220,y=100,width=80,height=1000}
  },
  portals={{id="sair-"..zoneId,x=700,y=900,to="surface",
   targetX=x,targetY=y}},
  mobs={}
 }
 local portal={id=portalId,x=x,y=y,to=zoneId,targetX=700,targetY=900}
 room.mapSpaces:addZone(indoor)
 room.mapSpaces:addSurfacePortal(portal)
 room.builtHouses[index]={id=zoneId,ownerId=player.id,x=x,y=y}
 player:useRes(ITEM)
 player.nextHouseAt=room.nowMs+5000
 for _,viewer in ipairs(room.players) do
  viewer:send("j","add-house",x,y,portal)
 end
 player:send("j","build-result",0,0,{
  ok=true,message="Casa construida. Aproxime-se e pressione G para entrar."
 })
 return true
end
return House
