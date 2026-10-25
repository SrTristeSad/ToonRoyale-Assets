-- Separate interior/underground geometry and portal graph; never overload
-- the original visual object.layer field or classic wire protocol.
local Spaces={}
Spaces.__index=Spaces
local function copy(v)
 if type(v)~="table" then return v end
 local t={}
 for k,x in pairs(v) do t[k]=copy(x) end
 return t
end
function Spaces.new(map,mapScale)
 local self=setmetatable({zones={},name=map and map.name or "Classico"},Spaces)
 self.zones.surface={id="surface",type="surface",width=mapScale,
  height=mapScale,obstacles={},portals=copy(map and map.portals or {})}
 for _,space in ipairs(map and map.spaces or {}) do
  self.zones[space.id]=copy(space)
 end
 return self
end
function Spaces:get(id)
 return self.zones[id or "surface"]
end
function Spaces:canOccupy(id,x,y,radius)
 local zone=self:get(id)
 radius=radius or 0
 if not zone or type(x)~="number" or type(y)~="number"
  or x~=x or y~=y or type(radius)~="number" or radius<0 then
  return false
 end
 if x-radius<0 or y-radius<0 or x+radius>zone.width
  or y+radius>zone.height then return false end
 for _,rect in ipairs(zone.obstacles or {}) do
  local px=math.max(rect.x,math.min(rect.x+rect.width,x))
  local py=math.max(rect.y,math.min(rect.y+rect.height,y))
  local dx,dy=x-px,y-py
  if dx*dx+dy*dy<=radius*radius then return false end
 end
 return true
end
-- Returns an authoritative destination; does not mutate Player or send
-- unrecognized packets to legacy clients. Wire integration comes later.
function Spaces:destination(from,portalId,radius)
 local zone=self:get(from)
 if not zone then return nil,"space not found" end
 for _,portal in ipairs(zone.portals or {}) do
  if portal.id==portalId then
   if not self:canOccupy(portal.to,portal.targetX,portal.targetY,radius or 0) then
    return nil,"portal destination blocked"
   end
   return {spaceId=portal.to,x=portal.targetX,y=portal.targetY}
  end
 end
 return nil,"portal not found"
end
return Spaces
