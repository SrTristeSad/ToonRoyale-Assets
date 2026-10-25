-- Local custom-map houses: server-owned geometry, modular indoor walls,
-- saved with a validated, bounded JSON snapshot. V2/classic never use this.
local Json=require("server-lua.vendor.dkjson")
local House={}
local COST={req={"wood",70,"stone",35}}
local WALL_COST={req={"wood",15,"stone",5}}
local MAX_HOUSES,MAX_PER_PLAYER,MAX_WALLS=16,2,12
local function finite(v)
 return type(v)=="number" and v==v and v~=-math.huge and v~=math.huge
end
local function integer(v,a,b)
 return finite(v) and v%1==0 and v>=a and v<=b
end
local function fail(p,reason)
 if p and type(p.send)=="function" then
  p:send("j","build-result",0,0,{ok=false,message=reason})
 end
 return false
end
local function success(p,reason)
 p:send("j","build-result",0,0,{ok=true,message=reason})
 return true
end
local function rectNear(x,y,r)
 local cx=math.max(r.x,math.min(x,r.x+r.width))
 local cy=math.max(r.y,math.min(y,r.y+r.height))
 local dx,dy=x-cx,y-cy
 return dx*dx+dy*dy
end
local function overlap(a,b)
 return a.x<b.x+b.width and a.x+a.width>b.x
  and a.y<b.y+b.height and a.y+a.height>b.y
end
local function prefab(index,x,y)
 local id="casa-"..index
 local indoor={
  id=id,type="interior",width=1400,height=1200,
  obstacles={
   {x=100,y=100,width=1000,height=80},
   {x=100,y=100,width=80,height=1000},
   {x=1220,y=100,width=80,height=1000}
  },
  portals={{id="sair-"..id,x=700,y=900,to="surface",
   targetX=x,targetY=y}},mobs={}
 }
 local door={id="entrar-"..id,x=x,y=y,to=id,
   targetX=700,targetY=900,style="house"}
 return indoor,door
end
local function snapshot(room)
 local houses={}
 for _,h in ipairs(room.builtHouses or {}) do
  local walls={}
  local zone=assert(room.mapSpaces:get(h.id))
  for i=4,#zone.obstacles do
   local r=zone.obstacles[i]
   walls[#walls+1]={x=r.x,y=r.y,width=r.width,height=r.height}
  end
  houses[#houses+1]={x=h.x,y=h.y,ownerAccount=h.ownerAccount,
   walls=walls}
 end
 return {schemaVersion=1,mapId=room.mapId,houses=houses}
end
function House.save(room)
 if not room.houseStorePath then return true end
 local data,err=Json.encode(snapshot(room))
 if not data then return false,err end
 if #data>65536 then return false,"snapshot exceeds 64 KiB" end
 local path=room.houseStorePath
 local temp=path..".tmp"
 local handle,why=io.open(temp,"wb")
 if not handle then return false,why end
 local ok,werr=handle:write(data)
 handle:close()
 if not ok then os.remove(temp);return false,werr end
 -- POSIX replaces the destination atomically. On Windows os.rename() can
 -- refuse an existing destination; rotate the previous save and recover it.
 local moved=os.rename(temp,path)
 if moved then return true end
 local backup=path..".bak"
 os.remove(backup)
 local oldMoved=os.rename(path,backup)
 if not oldMoved then
  os.remove(temp)
  return false,"could not rotate previous snapshot"
 end
 local swapped=os.rename(temp,path)
 if not swapped then
  os.rename(backup,path)
  os.remove(temp)
  return false,"could not finish snapshot replacement"
 end
 os.remove(backup)
 return true
end
local function checkWalls(zone,walls)
 assert(type(walls)=="table" and #walls<=MAX_WALLS,"bad saved walls")
 for key in pairs(walls) do
  assert(integer(key,1,#walls),"saved walls must be a dense array")
 end
 for _,r in ipairs(walls) do
  assert(type(r)=="table" and integer(r.x,50,zone.width-50)
    and integer(r.y,50,zone.height-50)
    and integer(r.width,30,240) and integer(r.height,30,240)
    and r.x+r.width<=zone.width-50 and r.y+r.height<=zone.height-50,
    "invalid saved wall")
  for _,other in ipairs(zone.obstacles) do
   assert(not overlap(r,other),"overlapping saved wall")
  end
  for _,p in ipairs(zone.portals) do
   assert(rectNear(p.x,p.y,r)>140*140,"saved wall blocks an exit")
  end
  zone.obstacles[#zone.obstacles+1]={
   x=r.x,y=r.y,width=r.width,height=r.height,material="wood"
  }
 end
end
function House.load(room)
 room.builtHouses={}
 local path=room.houseStorePath
 if not path then return 0 end
 local handle=io.open(path,"rb")
 if not handle then return 0 end
 local raw=handle:read(65537)
 handle:close()
 assert(#raw<=65536,"saved house snapshot too large")
 local data,_,err=Json.decode(raw,1,Json.null)
 assert(not err and type(data)=="table"
  and data.schemaVersion==1 and data.mapId==room.mapId
  and type(data.houses)=="table" and #data.houses<=MAX_HOUSES,
  "invalid house snapshot for selected map")
 for key in pairs(data.houses) do
  assert(integer(key,1,#data.houses),"saved houses must be a dense array")
 end
 for i,record in ipairs(data.houses) do
  assert(type(record)=="table"
   and integer(record.x,310,room.config.mapScale-310)
   and integer(record.y,310,room.config.mapScale-310)
   and type(record.walls)=="table"
   and (record.ownerAccount==nil or
      (type(record.ownerAccount)=="string" and #record.ownerAccount<=128)),
   "invalid saved house")
  local z,p=prefab(i,record.x,record.y)
  checkWalls(z,record.walls)
  for _,other in ipairs(room.mapSpaces:get("surface").portals) do
   local dx,dy=p.x-other.x,p.y-other.y
   assert(dx*dx+dy*dy>=700*700,"saved houses overlap")
  end
  room.mapSpaces:addZone(z)
  room.mapSpaces:addSurfacePortal(p)
  room.builtHouses[#room.builtHouses+1]={
   id=z.id,x=record.x,y=record.y,
   ownerAccount=record.ownerAccount,ownerId=nil
  }
  -- Natural resource generation may differ when a map has no seed. Clear
  -- collisions under persisted roofs so entry is never obstructed.
  for _,obj in ipairs(room.object_manager.objects) do
   if obj.active and not obj.isItem then
    local dx,dy=obj.x-p.x,obj.y-p.y
    local radius=300+(obj.scale or 0)
    if dx*dx+dy*dy<radius*radius then
     room.object_manager:disableObject(obj)
    end
   end
  end
 end
 return #room.builtHouses
end
local function allowed(room,player)
 return room.key=="LC" and room.customMap and room.mapSpaces
    and player.alive
end
local function ownerAccount(player)
 return player.account and tostring(player.account.id) or nil
end
function House.build(room,player)
 if not allowed(room,player) or (player.spaceId or "surface")~="surface" then
  return fail(player,"Casa apenas na superficie do mapa personalizado.")
 end
 if room.nowMs<(player.nextHouseAt or 0) then
  return fail(player,"Aguarde antes de construir outra casa.")
 end
 room.builtHouses=room.builtHouses or {}
 if #room.builtHouses>=MAX_HOUSES then
  return fail(player,"Limite de casas desta sala atingido.")
 end
 local built=0
 local account=ownerAccount(player)
 for _,h in ipairs(room.builtHouses) do
  if (account and h.ownerAccount==account)
   or h.ownerId==player.id then built=built+1 end
 end
 if built>=MAX_PER_PLAYER then
  return fail(player,"Limite de duas casas por jogador.")
 end
 if not player:hasRes(COST) then
  return fail(player,"Casa exige 70 de madeira e 35 de pedra.")
 end
 local angle=player.dir or 0
 if not finite(angle) then return fail(player,"Direcao invalida.") end
 local x=math.floor(player.x+440*math.cos(angle)+0.5)
 local y=math.floor(player.y+440*math.sin(angle)+0.5)
 local cfg=room.config
 if x<310 or y<310 or x>cfg.mapScale-310 or y>cfg.mapScale-310 then
  return fail(player,"Muito perto do limite do mapa.")
 end
 if not room.object_manager:canPlace(x,y,310,0.6,nil,false) then
  return fail(player,"Espaco ocupado ou muito perto da agua.")
 end
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
 local zone,portal=prefab(index,x,y)
 if room.mapSpaces:get(zone.id) then
  return fail(player,"Este ID de casa ja e usado pelo mapa.")
 end
 for _,entry in ipairs(room.mapSpaces:get("surface").portals) do
  if entry.id==portal.id then
   return fail(player,"Este ID de entrada ja e usado pelo mapa.")
  end
 end
 room.mapSpaces:addZone(zone)
 room.mapSpaces:addSurfacePortal(portal)
 room.builtHouses[index]={id=zone.id,ownerId=player.id,
  ownerAccount=account,x=x,y=y}
 local saved,why=House.save(room)
 if not saved then
  room.builtHouses[index]=nil
  room.mapSpaces.zones[zone.id]=nil
  table.remove(room.mapSpaces:get("surface").portals)
  return fail(player,"Falha ao salvar casa: "..tostring(why):sub(1,60))
 end
 player:useRes(COST)
 player.nextHouseAt=room.nowMs+5000
 for _,viewer in ipairs(room.players) do
  viewer:send("j","add-house",x,y,portal)
 end
 return success(player,"Casa construida e salva. Use G para entrar.")
end
local function ownedHouse(room,player)
 local id=player.spaceId
 local house
 for _,h in ipairs(room.builtHouses or {}) do
  if h.id==id then house=h;break end
 end
 if not house then return nil,"Entre em uma casa construida para editar." end
 local account=ownerAccount(player)
 if house.ownerId~=player.id and not
   (account and house.ownerAccount==account) then
  return nil,"Somente o dono pode modificar esta casa."
 end
 return house
end
function House.wall(room,player,request)
 if not allowed(room,player) then
  return fail(player,"Paredes so podem ser colocadas em mapas personalizados.")
 end
 local id=player.spaceId
 local house,reason=ownedHouse(room,player)
 if not house then return fail(player,reason) end
 if room.nowMs<(player.nextWallAt or 0) then
  return fail(player,"Aguarde para construir outra parede.")
 end
 local zone=assert(room.mapSpaces:get(id))
 if #zone.obstacles-3>=MAX_WALLS then
  return fail(player,"Limite de paredes da casa atingido.")
 end
 if not player:hasRes(WALL_COST) then
  return fail(player,"Parede exige 15 de madeira e 5 de pedra.")
 end
 local direction=player.dir or 0
 if not finite(direction) then return fail(player,"Direcao invalida.") end
 local xx=player.x+160*math.cos(direction)
 local yy=player.y+160*math.sin(direction)
 local horizontal=math.abs(math.cos(direction))<math.abs(math.sin(direction))
 if request~=nil then
  if type(request)~="table" or
    not integer(request.x,0,4096) or not integer(request.y,0,4096)
    or request.x%20~=0 or request.y%20~=0
    or (request.orientation~="h" and request.orientation~="v") then
   return fail(player,"Posicao ou orientacao invalida.")
  end
  xx,yy=request.x,request.y
  horizontal=request.orientation=="h"
  local dx,dy=xx-player.x,yy-player.y
  if dx*dx+dy*dy>300*300 then
   return fail(player,"A parede deve ficar perto do jogador.")
  end
  if room.mapSpaces:lineBlocked(id,player.x,player.y,xx,yy) then
   return fail(player,"Nao e permitido construir atraves de paredes.")
  end
 end
 local w,h=horizontal and 200 or 42,horizontal and 42 or 200
 local rect={x=math.floor(xx-w/2+0.5),y=math.floor(yy-h/2+0.5),
  width=w,height=h,material="wood"}
 if rect.x<55 or rect.y<55 or
   rect.x+w>zone.width-55 or rect.y+h>zone.height-55 then
  return fail(player,"Parede fora da area de construcao.")
 end
 for _,other in ipairs(zone.obstacles) do
  if overlap(rect,other) then
   return fail(player,"A parede colide com outra estrutura.")
  end
 end
 for _,portal in ipairs(zone.portals) do
  if rectNear(portal.x,portal.y,rect)<140*140 then
   return fail(player,"Nao bloqueie as portas e escadas.")
  end
 end
 for _,other in ipairs(room.players) do
  if other.alive and other.spaceId==id
    and rectNear(other.x,other.y,rect)<
      ((other.scale or 35)+10)^2 then
   return fail(player,"Ha um jogador na posicao da parede.")
  end
 end
 zone.obstacles[#zone.obstacles+1]=rect
 local saved,why=House.save(room)
 if not saved then
  zone.obstacles[#zone.obstacles]=nil
  return fail(player,"Falha ao salvar parede: "..tostring(why):sub(1,60))
 end
 player:useRes(WALL_COST)
 player.nextWallAt=room.nowMs+350
 for _,viewer in ipairs(room.players) do
  if viewer.spaceId==id then
   viewer:send("j","add-wall",0,0,{spaceId=id,rect=rect})
  end
 end
 return success(player,"Parede colocada e salva.")
end
function House.removeWall(room,player,index)
 if not allowed(room,player) then
  return fail(player,"Edicao apenas em mapas personalizados.")
 end
 local house,reason=ownedHouse(room,player)
 if not house then return fail(player,reason) end
 if not integer(index,4,3+MAX_WALLS) then
  return fail(player,"Indice de parede invalido.")
 end
 if room.nowMs<(player.nextWallAt or 0) then
  return fail(player,"Aguarde antes de editar outra parede.")
 end
 local zone=assert(room.mapSpaces:get(house.id))
 local wall=zone.obstacles[index]
 if not wall or wall.material~="wood" then
  return fail(player,"Esta parede nao pode ser demolida.")
 end
 local x=math.max(wall.x,math.min(player.x,wall.x+wall.width))
 local y=math.max(wall.y,math.min(player.y,wall.y+wall.height))
 if (x-player.x)^2+(y-player.y)^2>300*300 then
  return fail(player,"Aproxime-se da parede para demolir.")
 end
 table.remove(zone.obstacles,index)
 local saved,why=House.save(room)
 if not saved then
  table.insert(zone.obstacles,index,wall)
  return fail(player,"Falha ao salvar demolicao: "..tostring(why):sub(1,60))
 end
 player.nextWallAt=room.nowMs+350
 for _,viewer in ipairs(room.players) do
  if viewer.spaceId==house.id then
   viewer:send("j","remove-wall",0,0,{spaceId=house.id,index=index})
  end
 end
 return success(player,"Parede demolida e alteracao salva.")
end
return House
