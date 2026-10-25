-- Local custom-map construction editor. Coordinates sent by the client are
-- proposals only: the authoritative Lua Room validates every edit.
local Editor={}
Editor.__index=Editor
local function snap(v) return math.floor(v/20+0.5)*20 end
local function nearRect(x,y,r)
 local cx=math.max(r.x,math.min(x,r.x+r.width))
 local cy=math.max(r.y,math.min(y,r.y+r.height))
 return (x-cx)^2+(y-cy)^2
end
local function overlap(a,b)
 return a.x<b.x+b.width and a.x+a.width>b.x
  and a.y<b.y+b.height and a.y+a.height>b.y
end
function Editor.new()
 return setmetatable({active=false,orientation="h"},Editor)
end
function Editor:canEdit(world)
 return world and world.map and type(world.spaceId)=="string"
  and world.spaceId:match("^casa%-%d+$")~=nil
  and world.space and type(world.space.obstacles)=="table"
end
function Editor:reset() self.active=false end
function Editor:toggle(world)
 if not self:canEdit(world) then self.active=false;return false end
 self.active=not self.active
 return self.active
end
function Editor:rotate()
 self.orientation=self.orientation=="h" and "v" or "h"
end
function Editor:placement(world,camera,screenX,screenY)
 if not self:canEdit(world) or not camera then return nil end
 local x,y=camera:screenToWorld(screenX,screenY)
 if type(x)~="number" or type(y)~="number" then return nil end
 x,y=snap(x),snap(y)
 local horizontal=self.orientation=="h"
 local width,height=horizontal and 200 or 42,horizontal and 42 or 200
 local r={x=x-width/2,y=y-height/2,width=width,height=height}
 local area=world.space
 local player=world:localPlayer()
 local ok=player and type(player.x)=="number" and type(player.y)=="number"
  and (x-player.x)^2+(y-player.y)^2<=300*300
  and r.x>=55 and r.y>=55
  and r.x+r.width<=area.width-55
  and r.y+r.height<=area.height-55
  and #area.obstacles<15
 if ok then
  for _,wall in ipairs(area.obstacles) do
   if overlap(r,wall) then ok=false;break end
  end
 end
 if ok then
  for _,portal in ipairs(area.portals or {}) do
   if nearRect(portal.x,portal.y,r)<=140*140 then ok=false;break end
  end
 end
 if ok then
  for _,other in ipairs(world:orderedPlayers()) do
   if type(other.x)=="number" and type(other.y)=="number"
    and nearRect(other.x,other.y,r)<((other.scale or 35)+10)^2 then
    ok=false;break
   end
  end
 end
 return {x=x,y=y,orientation=self.orientation,rect=r,valid=not not ok}
end
function Editor:wallAt(world,camera,screenX,screenY)
 if not self:canEdit(world) or not camera then return nil end
 local x,y=camera:screenToWorld(screenX,screenY)
 local area=world.space
 for i=#area.obstacles,4,-1 do
  local r=area.obstacles[i]
  if r.material=="wood" and x>=r.x and x<=r.x+r.width
   and y>=r.y and y<=r.y+r.height then
   return i,r
  end
 end
 return nil
end
function Editor:draw(world,camera,screenX,screenY)
 if not self.active or not self:canEdit(world) then return end
 local love=assert(_G.love,"LÖVE graphics required")
 local g=love.graphics
 local w,h=g.getDimensions()
 local preview=self:placement(world,camera,screenX,screenY)
 if preview then
  local r=preview.rect
  local x,y=camera:worldToScreen(r.x,r.y)
  if preview.valid then g.setColor(0.25,0.85,0.47,0.25)
  else g.setColor(0.92,0.30,0.24,0.25) end
  g.rectangle("fill",x,y,r.width*camera.zoom,r.height*camera.zoom)
  if preview.valid then g.setColor(0.28,0.96,0.50,0.9)
  else g.setColor(1,0.38,0.22,0.9) end
  g.setLineWidth(2)
  g.rectangle("line",x,y,r.width*camera.zoom,r.height*camera.zoom)
  g.setLineWidth(1)
 end
 local id,wall=self:wallAt(world,camera,screenX,screenY)
 if id and wall then
  local x,y=camera:worldToScreen(wall.x,wall.y)
  g.setColor(1,0.43,0.29,0.75)
  g.rectangle("line",x-2,y-2,wall.width*camera.zoom+4,
   wall.height*camera.zoom+4)
 end
 g.setColor(0.08,0.11,0.12,0.91)
 g.rectangle("fill",w/2-325,14,650,64,6,6)
 g.setColor(1,0.87,0.45,1)
 g.printf("EDITOR DE PAREDES  |  15 madeira + 5 pedra",w/2-315,21,630,"center")
 g.setColor(0.94,0.96,0.96,1)
 g.printf("Clique esquerdo: construir  |  Direito: demolir  |  R: girar  |  H/Esc: sair",
  w/2-315,47,630,"center")
end
return Editor
