-- Server-authoritative indoor physics. Mirrors the original acceleration and
-- exponential friction while resolving against the SAME zone obstacle rectangles
-- rendered by the client. The original outdoor river/snow grids do not apply.
local Vitals=require("server-lua.world.vitals")
local WeaponTick=require("server-lua.world.weapon_tick")
local Indoor={}
local function clamp(v,min,max)return math.max(min,math.min(max,v))end
local function jsOr(v,fallback)
 return v~=nil and v~=false and v~=0 and v or fallback
end
local function finite(v)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
function Indoor.step(player,delta,room)
 assert(room.mapSpaces and player.spaceId~="surface","indoor room required")
 assert(finite(delta) and delta>=0,"valid indoor delta required")
 Vitals.step(player,delta,room.config)
 if not player.alive then return false end
 local area=assert(room.mapSpaces:get(player.spaceId),"zone removed during play")
 local dt=math.min(delta,250)
 local radius=assert(player.scale,"original player scale required")
 local dir=player.moveDir
 local weapon=assert(room.items.weapons[player.weaponIndex],"original weapon required")
 local cfg=room.config
 local vx,vy=player.xVel or 0,player.yVel or 0
 if player.lockMove then
  vx,vy=0,0
 else
  local skin,tail=player.skin,player.tail
  local factor=(player.buildIndex and player.buildIndex>=0 and 0.5 or 1)
     *jsOr(weapon.spdMult,1)
     *(skin and jsOr(skin.spdMult,1) or 1)
     *(tail and jsOr(tail.spdMult,1) or 1)
     *jsOr(player.slowMult,1)
     *(player.powers and jsOr(player.powers.speed,1) or 1)
  if tail and tail.id==5 then factor=factor*1.05 end
  if (player.superUntil or 0)>room.nowMs then factor=factor*1.15 end
  if type(dir)=="number" and finite(dir) then
   vx=vx+math.cos(dir)*player.speed*factor*dt
   vy=vy+math.sin(dir)*player.speed*factor*dt
  end
 end
 player.lockMove=false
 local dx,dy=vx*dt,vy*dt
 local count=math.max(1,math.min(64,math.ceil(math.sqrt(dx*dx+dy*dy)/12)))
 local x,y=player.x,player.y
 local function clearOfPlayers(xx,yy)
  for _,other in ipairs(room.players or {}) do
   if other~=player and other.alive and
     (other.spaceId or "surface")==player.spaceId then
    local ddx,ddy=xx-other.x,yy-other.y
    local combined=radius+other.scale
    if ddx*ddx+ddy*ddy<combined*combined then return false end
   end
  end
  return true
 end
 local collidedX,collidedY=false,false
 for _=1,count do
  local xx=clamp(x+dx/count,radius,area.width-radius)
  if room.mapSpaces:canOccupy(player.spaceId,xx,y,radius)
    and clearOfPlayers(xx,y) then x=xx
  else collidedX=true end
  local yy=clamp(y+dy/count,radius,area.height-radius)
  if room.mapSpaces:canOccupy(player.spaceId,x,yy,radius)
    and clearOfPlayers(x,yy) then y=yy
  else collidedY=true end
 end
 player.x,player.y=x,y
 if collidedX then vx=0 end
 if collidedY then vy=0 end
 local friction=cfg.playerDecel^dt
 player.xVel=vx*friction
 player.yVel=vy*friction
 if math.abs(player.xVel)<0.01 then player.xVel=0 end
 if math.abs(player.yVel)<0.01 then player.yVel=0 end
 player.noMovTimer=(player.noMovTimer or 0)+dt
 if x~=player.x or y~=player.y or dx~=0 or dy~=0 then
  player.noMovTimer=0
 end
 player.zIndex=0
 WeaponTick.step(player,delta,{
  weapon=weapon,projectiles=room.items.projectiles,
  players=room.players,
  addProjectile=function(...)return room.projectile_manager:addProjectile(...) end
 })
 return true
end
return Indoor
