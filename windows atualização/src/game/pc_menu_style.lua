-- Original Moo-IO Windows interface inspired by the organization of
-- classic PC sandbox games: framed stone-like panels and bevelled buttons.
-- All colors/patterns are drawn procedurally; no third-party game artwork.
local UI={}
UI.colors={
 background={0.105,0.119,0.111},
 stone={0.285,0.298,0.289},
 stoneDark={0.157,0.172,0.164},
 stoneLite={0.39,0.403,0.39},
 paper={0.973,0.975,0.963},
 muted={0.79,0.815,0.79},
 selected={0.43,0.61,0.38},
 highlight={0.72,0.83,0.70},
 amber={1,0.86,0.33}
}
local fonts={}
function UI.font(n)
 n=n or 17
 if not fonts[n] then fonts[n]=love.graphics.newFont(n) end
 return fonts[n]
end
function UI.text(message,x,y,size,color,w,align)
 love.graphics.setFont(UI.font(size))
 local c=color or UI.colors.paper
 love.graphics.setColor(c)
 if w then love.graphics.printf(tostring(message),x,y,w,align or "left")
 else love.graphics.print(tostring(message),x,y) end
end
function UI.panel(x,y,w,h,tint)
 tint=tint or UI.colors.stoneDark
 local g=love.graphics
 g.setColor(0.012,0.02,0.019,0.82)
 g.rectangle("fill",x+5,y+6,w,h)
 g.setColor(0.018,0.025,0.023,0.98)
 g.rectangle("fill",x-3,y-3,w+6,h+6)
 g.setColor(tint)
 g.rectangle("fill",x,y,w,h)
 -- Stepped chiseled edges; no smoothing, gradients or borrowed textures.
 g.setColor(1,1,1,0.11)
 g.rectangle("fill",x+2,y+2,w-4,3)
 g.rectangle("fill",x+2,y+2,3,h-4)
 g.setColor(0,0,0,0.36)
 g.rectangle("fill",x+3,y+h-5,w-6,3)
 g.rectangle("fill",x+w-5,y+3,3,h-7)
end
function UI.button(x,y,w,h,label,active,primary,hover)
 local g=love.graphics
 local base=primary and UI.colors.selected or
  active and UI.colors.stoneLite or UI.colors.stone
 if hover then base={math.min(1,base[1]+0.12),math.min(1,base[2]+0.13),
    math.min(1,base[3]+0.12)} end
 g.setColor(0,0,0,0.77)
 g.rectangle("fill",x+4,y+5,w,h)
 g.setColor(0.024,0.027,0.026,0.96)
 g.rectangle("fill",x-2,y-2,w+4,h+4)
 g.setColor(base)
 g.rectangle("fill",x,y,w,h)
 g.setColor(1,1,1,hover and 0.47 or 0.25)
 g.rectangle("fill",x+2,y+2,w-4,3)
 g.rectangle("fill",x+2,y+2,3,h-4)
 g.setColor(0,0,0,0.42)
 g.rectangle("fill",x+2,y+h-5,w-4,3)
 g.rectangle("fill",x+w-5,y+2,3,h-4)
 if hover then
  g.setColor(0.93,0.96,0.94,0.78)
  g.rectangle("line",x-1,y-1,w+2,h+2)
 end
 UI.text(label,x+12,y+math.max(5,math.floor((h-21)/2)-1),19,
    primary and {0.07,0.15,0.09} or UI.colors.paper,w-24,"center")
end
function UI.field(x,y,w,h,value,placeholder,focused)
 local g=love.graphics
 g.setColor(0.02,0.029,0.026,0.98)
 g.rectangle("fill",x-2,y-2,w+4,h+4)
 g.setColor(0.14,0.17,0.16)
 g.rectangle("fill",x,y,w,h)
 g.setColor(0,0,0,0.44)
 g.rectangle("fill",x+2,y+2,w-4,3)
 g.setColor(1,1,1,0.09)
 g.rectangle("fill",x+2,y+h-5,w-4,3)
 if focused then
  g.setColor(0.83,0.92,0.85)
  g.setLineWidth(2)
  g.rectangle("line",x-1,y-1,w+2,h+2)
 end
 local out=value~="" and value or placeholder
 if #out>51 then out="..."..out:sub(-48) end
 UI.text(out..(focused and "_" or ""),x+13,y+math.max(7,(h-20)/2),
  18,value=="" and UI.colors.muted or UI.colors.paper,w-26)
end
function UI.backdrop(showWorld)
 local g=love.graphics
 if showWorld then
  g.setColor(0.015,0.025,0.021,0.51)
  g.rectangle("fill",0,0,1280,720)
 else
  g.clear(0.105,0.119,0.111,1)
  for iy=0,30 do
   for ix=0,54 do
    local n=(ix*17+iy*23+ix*iy*3)%11
    local shade=0.13+n*0.004
    g.setColor(shade,shade+0.012,shade+0.007)
    g.rectangle("fill",ix*24,iy*24,23,23)
    g.setColor(0,0,0,0.13)
    g.rectangle("fill",ix*24,iy*24+21,23,2)
   end
  end
 end
 -- Pixel-cut shadow border and recessed content surface.
 g.setColor(0,0,0,0.48)
 g.rectangle("fill",0,0,1280,50)
 g.rectangle("fill",0,666,1280,54)
end
function UI.topbar(title,subtitle)
 local g=love.graphics
 g.setColor(0,0,0,0.36)
 g.rectangle("fill",0,52,1280,103)
 g.setColor(1,1,1,0.13)
 g.rectangle("fill",0,152,1280,2)
 UI.text(title,130,72,32,UI.colors.paper,1020,"center")
 if subtitle and subtitle~="" then
  UI.text(subtitle,130,119,15,UI.colors.muted,1020,"center")
 end
end
function UI.listRow(x,y,w,h,title,description,selected,hover)
 local g=love.graphics
 g.setColor(selected and UI.colors.selected or
   hover and UI.colors.stoneLite or UI.colors.stoneDark)
 g.rectangle("fill",x,y,w,h)
 g.setColor(selected and UI.colors.highlight or {0.34,0.38,0.35})
 g.rectangle("fill",x+5,y+5,5,h-10)
 if hover or selected then
  g.setColor(0.87,0.93,0.87,0.72)
  g.rectangle("line",x+1,y+1,w-2,h-2)
 end
 UI.text(title,x+22,y+6,18,UI.colors.paper,w-30)
 if description then UI.text(description,x+22,y+34,14,UI.colors.muted,w-30) end
end
return UI
