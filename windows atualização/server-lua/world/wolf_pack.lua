-- Cooperative wolves are opt-in per-room; 'normal' runs the original AI.
-- Coordinates and movement remain server-authoritative. No new client packet.
local Pack={}
local function dist2(a,b)
 local dx=a.x-b.x;local dy=a.y-b.y
 return dx*dx+dy*dy
end
function Pack.neighbors(wolf,ais)
 local members={}
 for _,peer in ipairs(ais or {}) do
  if peer.active and peer.alive and peer.index==4
    and type(peer.x)=="number" and type(peer.y)=="number"
    and dist2(wolf,peer)<=650*650 then
   members[#members+1]=peer
  end
 end
 table.sort(members,function(a,b)return a.sid<b.sid end)
 return members
end
function Pack.sharedTarget(wolf,ais)
 for _,ally in ipairs(Pack.neighbors(wolf,ais)) do
  if ally~=wolf and ally.chargeTarget and ally.chargeTarget.alive then
   return ally.chargeTarget
  end
 end
 return nil
end
-- Predict running direction, while two or more wolves occupy separate flanks.
-- Roles derived from stable server-side SIDs so clients observe same movement.
function Pack.direction(wolf,target,ais,difficulty)
 if not target or not target.alive then return nil end
 local members=Pack.neighbors(wolf,ais)
 local rank=1
 for i,member in ipairs(members) do if member==wolf then rank=i;break end end
 local dx=target.x-wolf.x;local dy=target.y-wolf.y
 local magnitude=math.sqrt(dx*dx+dy*dy)
 if magnitude<1 then magnitude=1 end
 local nx,ny=dx/magnitude,dy/magnitude
 local lead=(difficulty=="extremo" and 420 or 260)
 -- Player velocities are expressed in world units/ms in original physics.
 local tx=target.x+math.max(-120,math.min(120,(target.xVel or 0)*lead))
 local ty=target.y+math.max(-120,math.min(120,(target.yVel or 0)*lead))
 if #members>=2 then
  local slot=(rank-1)%3
  local side=slot==0 and 0 or (slot==1 and 1 or -1)
  local radius=difficulty=="extremo" and 150 or 110
  tx=tx-ny*radius*side
  ty=ty+nx*radius*side
  if side~=0 then
   -- While approaching, spread formation; close in on the target at contact.
   local factor=math.max(0,math.min(1,(magnitude-85)/240))
   tx=target.x+(tx-target.x)*factor
   ty=target.y+(ty-target.y)*factor
  end
 end
 -- atan2 equivalent for LuaJIT and Lua 5.4.
 local vx,vy=tx-wolf.x,ty-wolf.y
 if math.atan2 then return math.atan2(vy,vx) end
 if vx>0 then return math.atan(vy/vx) end
 if vx<0 then return math.atan(vy/vx)+(vy>=0 and math.pi or -math.pi) end
 return vy>=0 and math.pi/2 or -math.pi/2
end
return Pack
