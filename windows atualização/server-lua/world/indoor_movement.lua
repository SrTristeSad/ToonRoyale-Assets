-- Server-authoritative interior physics. World grids and original river
-- modifiers belong to surface only and must never run in an interior.
local Vitals=require("server-lua.world.vitals")
local Indoor={}
local function clamp(v,min,max)return math.max(min,math.min(max,v))end
function Indoor.step(player,delta,room)
 assert(room.mapSpaces and player.spaceId~="surface","indoor room required")
 Vitals.step(player,delta,room.config)
 if not player.alive then return false end
 -- No projectile/melee/build activity from one space into another space.
 player.mouseState=0;player.hits=0;player.gathering=0;player.autoGather=false
 player.buildIndex=-1
 local area=assert(room.mapSpaces:get(player.spaceId),"zone removed during play")
 local dt=math.min(delta,250)
 local radius=player.scale
 local dir=player.moveDir
 local speed=player.speed*(player.powers and player.powers.speed or 1)
 local dx=not player.lockMove and type(dir)=="number" and math.cos(dir)*speed*dt or 0
 local dy=not player.lockMove and type(dir)=="number" and math.sin(dir)*speed*dt or 0
 player.lockMove=false
 player.xVel=0;player.yVel=0
 player.noMovTimer=(player.noMovTimer or 0)+dt
 if dx~=0 or dy~=0 then player.noMovTimer=0 end
 local count=math.max(1,math.min(12,math.ceil(math.sqrt(dx*dx+dy*dy)/16)))
 local x,y=player.x,player.y
 for _=1,count do
  local xx=clamp(x+dx/count,radius,area.width-radius)
  if room.mapSpaces:canOccupy(player.spaceId,xx,y,radius) then x=xx end
  local yy=clamp(y+dy/count,radius,area.height-radius)
  if room.mapSpaces:canOccupy(player.spaceId,x,yy,radius) then y=yy end
 end
 player.x=x;player.y=y;player.zIndex=0
 return true
end
return Indoor
