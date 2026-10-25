-- Death locations come exclusively from authoritative player position packets.
-- A marker survives respawn but never teleports between map floors.
local Marker={}
local labelFont
local function finite(v)return type(v)=="number" and v==v and math.abs(v)<1e8 end
function Marker.make(x,y,spaceId)
 if not finite(x) or not finite(y) then return nil end
 return {x=x,y=y,spaceId=spaceId or "surface"}
end
-- The room owner's Play button creates a NEW client/socket after death.
-- Only retain the last death for the same still-running hosted room.
-- Never leak coordinates into an unrelated server or a newly created room.
function Marker.forHostReconnect(world,wasHost,previous,target,hosted)
 if not wasHost or not world or not world.lastDeath then return nil end
 if not previous or not target or not hosted or hosted.state~="ready" then
  return nil
 end
 local previousPort=tonumber(previous.port)
 local targetPort=tonumber(target.port)
 local hostedPort=tonumber(hosted.port)
 if not previousPort or not targetPort or not hostedPort
  or previousPort~=targetPort or targetPort~=hostedPort
  or previous.host~=target.host or target.host~=hosted.hostIP
  or previous.inviteCode~=target.inviteCode
  or target.inviteCode~=hosted.code or type(target.inviteCode)~="string"
  or target.inviteCode=="" then
  return nil
 end
 local previousMark=world.lastDeath
 return Marker.make(previousMark.x,previousMark.y,previousMark.spaceId)
end
function Marker.sameArea(world)
 local mark=world and world.lastDeath
 return mark and finite(mark.x) and finite(mark.y)
  and (mark.spaceId or "surface")==(world.spaceId or "surface")
end
function Marker.minimapPoint(world,size,worldSize)
 if not Marker.sameArea(world) or world.spaceId~="surface" then return nil end
 local mark=world.lastDeath
 local max=worldSize or 14400
 if mark.x<0 or mark.x>max or mark.y<0 or mark.y>max then
  return nil -- The secret western pool is off the rectangular minimap.
 end
 return mark.x/max*size,mark.y/max*size
end
function Marker.drawMini(world,x,y,size,worldSize)
 local dx,dy=Marker.minimapPoint(world,size,worldSize)
 if not dx then return false end
 local g=love.graphics
 g.push("all")
 local mx,my=x+dx,y+dy
 -- MooMoo.io marks the most recent death with a conspicuous RED X.
 -- Keep it above player/team dots; do not use a corpse, circle or ping.
 local radius=9
 g.setLineWidth(6)
 g.setColor(0.04,0.01,0.01,0.96)
 g.line(mx-radius,my-radius,mx+radius,my+radius)
 g.line(mx-radius,my+radius,mx+radius,my-radius)
 g.setLineWidth(3.5)
 g.setColor(1,0.22,0.17,1)
 g.line(mx-radius,my-radius,mx+radius,my+radius)
 g.line(mx-radius,my+radius,mx+radius,my-radius)
 g.pop()
 return true
end
function Marker.drawWorld(world,camera,width,height)
 if not Marker.sameArea(world) then return false end
 local mark=world.lastDeath
 local x,y=camera:worldToScreen(mark.x,mark.y)
 if not finite(x) or not finite(y) or
    x< -85 or y< -85 or x>width+85 or y>height+85 then return false end
 local g=love.graphics
 g.push("all")
 -- Marker and label are UI pins at exact server coordinates, not a corpse
 -- or an object that can obstruct combat. The area remains traversable.
 g.setColor(0.02,0.02,0.02,0.82)
 g.circle("fill",x,y,21)
 g.setColor(1,0.28,0.25,0.98)
 g.setLineWidth(3)
 g.circle("line",x,y,19)
 g.line(x-10,y-10,x+10,y+10)
 g.line(x-10,y+10,x+10,y-10)
 local label="ULTIMA MORTE"
 if not labelFont then labelFont=g.newFont(14) end
 local f=labelFont
 local bw=math.max(124,f:getWidth(label)+18)
 local ty=y-57
 local tx=math.max(2,math.min(width-bw-2,x-bw/2))
 g.setColor(0.05,0.06,0.06,0.89)
 g.rectangle("fill",tx,ty,bw,26,4,4)
 g.setFont(f)
 g.setColor(1,0.82,0.76)
 g.printf(label,tx+4,ty+5,bw-8,"center")
 g.pop()
 return true
end
function Marker.drawFloorPlan(world,rect)
 if not Marker.sameArea(world) or world.spaceId=="surface" then return false end
 local zone=world.space
 if not zone or not finite(zone.width) or not finite(zone.height) then return false end
 local scale=rect.size/math.max(zone.width,zone.height)
 local ox=rect.left+(rect.size-zone.width*scale)/2
 local oy=rect.top+(rect.size-zone.height*scale)/2
 local x=ox+world.lastDeath.x*scale
 local y=oy+world.lastDeath.y*scale
 local g=love.graphics
 g.push("all")
 g.setColor(1,0.24,0.23)
 g.setLineWidth(2.5)
 g.circle("line",x,y,7)
 g.line(x-4,y-4,x+4,y+4)
 g.line(x-4,y+4,x+4,y-4)
 g.pop()
 return true
end
return Marker
