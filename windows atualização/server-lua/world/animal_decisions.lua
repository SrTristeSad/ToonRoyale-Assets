-- Additional survival decision layer for local rooms.
-- Leaves pure reference AI untouched when no roomDifficulty was selected.
-- No client-side authority and no global forced pack behavior.
local Brain={}
local function distance(a,b)
 local dx,dy=a.x-b.x,a.y-b.y
 return math.sqrt(dx*dx+dy*dy)
end
local function compatible(ai,peer)
 return peer and peer.alive and (peer.spaceId or "surface")==
   (ai.spaceId or "surface") and type(peer.x)=="number"
   and type(peer.y)=="number"
end
function Brain.assess(ai,delta,players,animals,cfg)
 local difficulty=cfg.server and cfg.server.roomDifficulty
 if not difficulty or ai.boss then return end
 ai.brainClock=(ai.brainClock or 0)-delta
 if ai.brainClock>0 then return end
 ai.brainClock=difficulty=="extremo" and 260
   or difficulty=="dificil" and 380 or 650
 local near,dmin=nil,math.huge
 local radius=(ai.viewRange or 350)*(ai.hostile and 1 or 0.55)
 for _,p in ipairs(players) do
  if compatible(ai,p) and not (p.powers and p.powers.invisible)
   and not (p.skin and p.skin.bullRepel and ai.chargePlayer) then
   local d=distance(ai,p)
   if d<radius and d<dmin then near,dmin=p,d end
  end
 end
 if ai.hostile and ai.chargePlayer and near then
  -- Don't remain sleeping next to a visible target; refresh position often.
  if ai.waitCount>0 then ai.waitCount=0 end
  if not ai.chargeTarget or not compatible(ai,ai.chargeTarget)
   or dmin<distance(ai,ai.chargeTarget)*0.72 then
   ai.chargeTarget=near
   ai.moveCount=math.max(ai.moveCount,650)
  end
 elseif not ai.hostile and not ai.dontRun then
  -- Grazing animals retreat from close approaching players or nearby predators.
  -- They do not become permanently aggressive or attack without provocation.
  local threat=near
  local closest=dmin
  for _,other in ipairs(animals or {}) do
   if other~=ai and other.active and other.hostile and compatible(ai,other) then
    local d=distance(ai,other)
    if d<360 and d<closest then threat,closest=other,d end
   end
  end
  if threat and closest<math.min(radius,330) then
   ai.runFrom=threat
   ai.chargeTarget=nil
   ai.moveCount=math.max(ai.moveCount,1000)
   ai.waitCount=0
  end
 end
end
function Brain.steer(ai,heading,spaces,animals,cfg)
 local zone=ai.spaceId or "surface"
 local length=(ai.scale or 60)+100
 local nx=ai.x+math.cos(heading)*length
 local ny=ai.y+math.sin(heading)*length
 local w,h=cfg.mapScale,cfg.mapScale
 if zone~="surface" and spaces then
  local region=spaces:get(zone)
  if region then w,h=region.width,region.height end
 end
 local clearance=ai.scale or 35
 local blocked=nx<clearance or ny<clearance
  or nx>w-clearance or ny>h-clearance
 if not blocked and zone~="surface" and spaces then
  blocked=not spaces:canOccupy(zone,nx,ny,clearance)
 end
 if blocked then
  -- Side-step until a valid direction exists; preserve collision authority.
  for _,sign in ipairs({1,-1}) do
   local detour=heading+sign*math.pi*0.5
   local x=ai.x+math.cos(detour)*length
   local y=ai.y+math.sin(detour)*length
   if x>clearance and x<w-clearance and y>clearance and y<h-clearance
    and (zone=="surface" or not spaces
      or spaces:canOccupy(zone,x,y,clearance)) then
    return detour
   end
  end
  return heading+math.pi
 end
 -- Unthreatened passive animals keep modest space between each other.
 if not ai.hostile and not ai.runFrom then
  local ax,ay=0,0
  for _,peer in ipairs(animals or {}) do
   if peer~=ai and peer.active and not peer.hostile
    and compatible(ai,peer) and distance(ai,peer)<clearance*2.5 then
    ax=ax+(ai.x-peer.x)
    ay=ay+(ai.y-peer.y)
   end
  end
  if ax*ax+ay*ay>1 then
   local desired=(math.atan2 and math.atan2(ay,ax))
     or (math.atan and math.atan(ay,ax)) or heading
   return heading*0.7+desired*0.3
  end
 end
 return heading
end
return Brain
