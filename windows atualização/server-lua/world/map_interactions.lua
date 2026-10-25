-- Server-authoritative interactions for arbitrary data-only JSON maps.
-- The client only sends a nearby object ID, never a reward, gate state,
-- resource amount or coordinates. All runtime state is per LOCAL room.
local Interactions={}
local resourceCodes={wood=0,food=1,stone=2}
local function report(player,message,ok)
 player:send("j","interact-result",0,0,{message=message,ok=ok})
 return ok
end
local function gateRect(gate)
 return {x=gate.x-gate.width/2,y=gate.y-gate.height/2,
  width=gate.width,height=gate.height,material=gate.material or "metal",
  interactiveGateId=gate.id}
end
local function overlapsCircle(rect,x,y,radius)
 local px=math.max(rect.x,math.min(rect.x+rect.width,x))
 local py=math.max(rect.y,math.min(rect.y+rect.height,y))
 local dx,dy=x-px,y-py
 return dx*dx+dy*dy<=(radius or 0)^2
end
local function occupied(room,zone,gate)
 local rect=gateRect(gate)
 for _,player in ipairs(room.players or {}) do
  if player.alive and (player.spaceId or "surface")==zone.id
    and overlapsCircle(rect,player.x,player.y,player.scale) then return true end
 end
 for _,ai in ipairs(room.ais or {}) do
  if ai.active and (ai.spaceId or "surface")==zone.id
    and overlapsCircle(rect,ai.x,ai.y,ai.scale) then return true end
 end
 for _,portal in ipairs(zone.portals or {}) do
  if overlapsCircle(rect,portal.x,portal.y,80) then return true end
 end
 return false
end
local function setGate(room,zone,gate,closed)
 if closed==gate.closed then return false end
 if closed then
  if occupied(room,zone,gate) then return false end
  zone.obstacles[#zone.obstacles+1]=gateRect(gate)
 else
  local index
  for i,wall in ipairs(zone.obstacles or {}) do
   if wall.interactiveGateId==gate.id then index=i;break end
  end
  if not index then return false end
  table.remove(zone.obstacles,index)
 end
 gate.closed=closed
 return true
end
local function notify(room,zone,obj,gate)
 obj.version=(obj.version or 0)+1
 local payload={spaceId=zone.id,id=obj.id,kind=obj.kind,
   used=obj.used==true,version=obj.version}
 if obj.kind=="node" then payload.remaining=obj.remaining end
 if gate then
  payload.gateId=gate.id
  payload.gateClosed=gate.closed
 end
 for _,viewer in ipairs(room.players or {}) do
  if (viewer.spaceId or "surface")==zone.id then
   viewer:send("j","interaction-update",0,0,payload)
  end
 end
end
function Interactions.use(room,player,objectId)
 if room.key~="LC" or not room.customMap or not room.mapSpaces
   or not player.alive then return false end
 if type(objectId)~="string" or #objectId>48
   or not objectId:match("^[a-z][a-z0-9%-]+$") then return false end
 local zone=room.mapSpaces:get(player.spaceId or "surface")
 if not zone or type(zone.interactables)~="table" then return false end
 local now=room.nowMs or 0
 if now<(player.nextInteractAt or 0) then return false end
 local obj
 for _,item in ipairs(zone.interactables) do
  if item.id==objectId and item.kind~="gate" then obj=item;break end
 end
 if not obj then return false end
 local dx,dy=player.x-obj.x,player.y-obj.y
 if dx*dx+dy*dy>150*150
   or room.mapSpaces:lineBlocked(zone.id,player.x,player.y,obj.x,obj.y) then
  return report(player,"Aproxime-se do objeto para interagir.",false)
 end
 if obj.used then return report(player,"Este objeto ja foi utilizado.",false) end
 local gate
 local message
 if obj.kind=="cache" or obj.kind=="node" then
  if type(player.addResource)~="function" then return false end
  local resourceCode=resourceCodes[obj.resource]
  if not resourceCode then return false end
  if obj.kind=="node" then
   if (obj.remaining or 0)<=0 then return report(player,"Recurso esgotado.",false) end
   if now<(obj.nextReadyAt or 0) then
    return report(player,"Ponto de coleta em recuperacao.",false)
   end
   obj.remaining=obj.remaining-1
   obj.nextReadyAt=now+obj.cooldownMs
   obj.used=obj.remaining==0
  else
   obj.used=true
  end
  player.nextInteractAt=now+350
  player:addResource(resourceCode,obj.amount,true)
  message="Coletado: "..obj.amount.." de "..obj.resource
 elseif obj.kind=="lever" or obj.kind=="switch" then
  if obj.kind=="switch" and now<(obj.nextReadyAt or 0) then
   return report(player,"Interruptor em recuperacao.",false)
  end
  for _,candidate in ipairs(zone.interactables) do
   if candidate.id==obj.target and candidate.kind=="gate" then
    gate=candidate;break
   end
  end
  if not gate then return false end
  local shouldClose=obj.kind=="switch" and not gate.closed
  if not setGate(room,zone,gate,shouldClose) then
   local reason=shouldClose and "Portao ocupado: nao pode fechar."
      or "Esta passagem ja esta aberta."
   return report(player,reason,false)
  end
  if obj.kind=="lever" then obj.used=true
  else obj.nextReadyAt=now+obj.cooldownMs end
  player.nextInteractAt=now+350
  message=gate.closed and "Portao fechado." or "Passagem aberta!"
 else return false end
 notify(room,zone,obj,gate)
 return report(player,message,true)
end
return Interactions
