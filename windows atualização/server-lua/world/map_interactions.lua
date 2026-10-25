-- Data-only interactive objects for LOCAL custom maps. All item rewards,
-- gate opening and player authorization are server-owned. No code from mods.
local Interactions={}
local codes={wood=0,food=1,stone=2}
local function report(player,message,ok)
 player:send("j","interact-result",0,0,{message=message,ok=ok})
 return ok
end
function Interactions.use(room,player,objectId)
 if room.key~="LC" or not room.customMap or not room.mapSpaces
   or not player.alive then return false end
 if type(objectId)~="string" or #objectId>48
   or not objectId:match("^[a-z][a-z0-9%-]+$") then return false end
 local zone=room.mapSpaces:get(player.spaceId or "surface")
 if not zone or type(zone.interactables)~="table" then return false end
 if (room.nowMs or 0)<(player.nextInteractAt or 0) then return false end
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
 if obj.kind=="cache" then
  if type(player.addResource)~="function" then return false end
  local resourceCode=codes[obj.resource]
  if not resourceCode then return false end
  -- Mutate state BEFORE rewarding to prohibit duplicate requests in the
  -- same server tick, including identical packets from other clients.
  obj.used=true
  player.nextInteractAt=(room.nowMs or 0)+350
  player:addResource(resourceCode,obj.amount,true)
 elseif obj.kind=="lever" then
  local gate
  for _,item in ipairs(zone.interactables) do
   if item.id==obj.target and item.kind=="gate" then gate=item;break end
  end
  if not gate or gate.closed==false then
   return report(player,"Esta passagem ja esta aberta.",false)
  end
  -- Gate obstacle is part of the authoritative physics world. Opening
  -- removes the actual rectangle, not a client-side visual placeholder.
  local removed=false
  for i=#zone.obstacles,1,-1 do
   if zone.obstacles[i].interactiveGateId==gate.id then
    table.remove(zone.obstacles,i);removed=true;break
   end
  end
  if not removed then return false end
  gate.closed=false
  obj.used=true
  player.nextInteractAt=(room.nowMs or 0)+350
 else return false end
 for _,viewer in ipairs(room.players) do
  if (viewer.spaceId or "surface")==zone.id then
   viewer:send("j","interaction-update",0,0,{
    spaceId=zone.id,id=obj.id,kind=obj.kind,used=true,
    gateId=obj.kind=="lever" and obj.target or nil
   })
  end
 end
 local message=obj.kind=="cache"
   and ("Coletado: "..obj.amount.." de "..obj.resource)
   or "Passagem destravada!"
 return report(player,message,true)
end
return Interactions
