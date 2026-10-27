-- Touch HUD editor. Positions are normalized to the current screen size so
-- portrait/landscape resizes keep controls within reach.
local E={}
E.__index=E
local ids={"minimap","resources","ping","mark","shop","clan","tribe",
 "chat","rank","pause","fold","auto","lock","hotbar","move","fire"}
local allowed={}
for _,id in ipairs(ids) do allowed[id]=true end
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
local function copy(src)
 local dst={}
 for id,p in pairs(src) do dst[id]={x=p.x,y=p.y} end
 return dst
end
function E.new()
 return setmetatable({positions={},dragId=nil,dragPointer=nil,
  original=nil,buttonPointer=nil},E)
end
function E:serialize()
 local lines={}
 for _,id in ipairs(ids) do
  local p=self.positions[id]
  if p then lines[#lines+1]=string.format("%s %.5f %.5f",id,p.x,p.y) end
 end
 return table.concat(lines,"\n")
end
function E:load(s)
 self.positions={}
 if type(s)~="string" then return end
 for line in s:gmatch("[^\r\n]+") do
  local id,x,y=line:match("^(%a+)%s+([%d%.]+)%s+([%d%.]+)%s*$")
  x=tonumber(x);y=tonumber(y)
  if allowed[id] and x and y and x==x and y==y
    and x>=0 and x<=1 and y>=0 and y<=1 then
    self.positions[id]={x=x,y=y}
  end
 end
end
function E:begin()
 self.original=copy(self.positions)
 self.dragId=nil;self.dragPointer=nil;self.buttonPointer=nil
end
function E:finish(save)
 if not save and self.original then self.positions=self.original end
 self.original=nil;self.dragId=nil;self.dragPointer=nil
 self.buttonPointer=nil
end
function E:reset()
 self.positions={}
 self.dragId=nil;self.dragPointer=nil
end
function E:apply(layout,w,h,safe)
 -- Persisted positions are relative to the full display for compatibility,
 -- but every draggable control must remain INSIDE Android's safe viewport.
 safe=safe or {left=0,top=0,right=w,bottom=h}
 local u=layout.u
 for _,id in ipairs(ids) do
  local p=self.positions[id]
  local target=layout[id]
  if p and target then
   local radius=target.r or math.max(target.w or 0,target.h or 0)*.5
   local minX=math.min(safe.right-radius,safe.left+radius)
   local maxX=math.max(minX,safe.right-radius)
   local minY=math.min(safe.bottom-radius,safe.top+radius)
   local maxY=math.max(minY,safe.bottom-radius)
   local x=clamp(p.x*w,minX,maxX)
   local y=clamp(p.y*h,minY,maxY)
   if id=="minimap" then
    target.x=clamp(x-target.w*.5,safe.left,
     math.max(safe.left,safe.right-target.w))
    target.y=clamp(y-target.h*.5,safe.top,
     math.max(safe.top,safe.bottom-target.h))
   elseif id=="hotbar" then
    local width=math.min(target.clipW,safe.right-safe.left)
    target.clipW=width
    target.clipX=clamp(x-width*.5,safe.left,
     math.max(safe.left,safe.right-width))
    target.x=target.clipX+width*.5
    target.y=clamp(y,safe.top+52*u,safe.bottom-48*u)
   else
    target.x=x;target.y=y
   end
  end
 end
end
function E:resourcePosition(default,w,h)
 local p=self.positions.resources
 if not p then return default.x,default.y end
 return clamp(p.x*w-default.width*.5,0,w-default.width),
  clamp(p.y*h-default.height*.5,0,h-default.height)
end
function E:anchor(layout,id,w,h,resource)
 if id=="resources" then
  return resource.x+resource.width*.5,
   resource.y+resource.step*1.5+resource.height*.5,
   math.max(resource.width*.5,resource.height*2)
 end
 local p=layout[id]
 if not p then return nil end
 if id=="minimap" then return p.x+p.w*.5,p.y+p.h*.5,
  math.max(p.w,p.h)*.5 end
 if id=="hotbar" then return p.x,p.y,math.max(44*layout.u,layout.hotbar.r) end
 return p.x,p.y,(p.r or 30*layout.u)
end
function E:buttons(w,h)
 -- Editor actions must remain usable above system bars and display cutouts.
 local Safe=require("src.mobile.safe_area")
 local safe=Safe.bounds(w,h)
 local z=math.max(.45,math.min(safe.width/1280,safe.height/720))
 local gap=12*z
 local bw=math.min(155*z,(safe.width-24*z-2*gap)/3)
 local bh=54*z
 local x=safe.left+(safe.width-(bw*3+gap*2))*.5
 local y=safe.top+8*z
 return {
  save={x=x,y=y,w=bw,h=bh},
  reset={x=x+bw+gap,y=y,w=bw,h=bh},
  cancel={x=x+2*(bw+gap),y=y,w=bw,h=bh}
 }
end
local function boxHit(x,y,b)
 return x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h
end
function E:pressed(pointer,x,y,layout,w,h,resource)
 local toolbar=self:buttons(w,h)
 for _,name in ipairs({"save","reset","cancel"}) do
  if boxHit(x,y,toolbar[name]) then
   self.buttonPointer=pointer
   return "editor_"..name
  end
 end
 -- Check frontmost circles before the minimap/large resource group.
 local order={"hotbar","auto","lock","fold","pause","rank","chat",
  "tribe","clan","shop","ping","mark","move","fire","resources","minimap"}
 for _,id in ipairs(order) do
  local cx,cy,rad=self:anchor(layout,id,w,h,resource)
  if cx and (x-cx)^2+(y-cy)^2<=math.max(rad,35*layout.u)^2 then
   self.dragId=id;self.dragPointer=pointer
   return "editor_drag",id
  end
 end
 return nil
end
function E:moved(pointer,x,y,layout,w,h)
 if pointer~=self.dragPointer or not self.dragId then return false end
 local margin=26*layout.u
 self.positions[self.dragId]={x=clamp(x,margin,w-margin)/w,
  y=clamp(y,margin,h-margin)/h}
 return true
end
function E:released(pointer)
 if pointer==self.dragPointer then
  self.dragId=nil;self.dragPointer=nil
 end
 if pointer==self.buttonPointer then self.buttonPointer=nil end
end
function E:draw(g,layout,w,h,resource)
 local font=g.getFont()
 local z=math.max(.65,math.min(w/1280,h/720))
 local b=self:buttons(w,h)
 g.push("all")
 g.setColor(0,0,0,.24);g.rectangle("fill",0,0,w,h)
 for _,id in ipairs(ids) do
  local x,y,r=self:anchor(layout,id,w,h,resource)
  if x then
   g.setColor(.96,.8,.30,.80)
   g.setLineWidth(2*z)
   g.circle("line",x,y,math.max(24*z,math.min(r,56*z)))
   g.setColor(.07,.12,.11,.9)
   g.rectangle("fill",x-52*z,y-16*z,104*z,24*z,5*z)
   g.setColor(1,1,1,1)
   g.printf(id:upper(),x-52*z,y-11*z,104*z,"center")
  end
 end
 for _,id in ipairs({"save","reset","cancel"}) do
  local r=b[id]
  g.setColor(id=="save" and .23 or .18,id=="save" and .47 or .26,.29,.96)
  g.rectangle("fill",r.x,r.y,r.w,r.h,7*z)
  g.setColor(.95,.98,.93,1)
  g.rectangle("line",r.x,r.y,r.w,r.h,7*z)
  g.printf(({save="SALVAR",reset="PADRAO",cancel="CANCELAR"})[id],
   r.x,r.y+r.h*.30,r.w,"center")
 end
 g.setColor(.98,.96,.89,1)
 g.printf("ARRASTE CONTROLES | A BARRA CONTINUA COM TODOS OS ITENS",
  w*.20,h-32*z,w*.60,"center")
 g.setFont(font)
 g.pop()
end
return E
