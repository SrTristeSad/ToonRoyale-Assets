package.path="./?.lua;./?/init.lua;"..package.path
-- All unlocked Android items/abilities are always visible, without swiping.
local Mobile=require("src.mobile.controls")
local sizes={{1600,757},{1280,720},{1140,540},{800,360}}
local amounts={1,3,7,10,20,25,60}
for _,size in ipairs(sizes) do
 local w,h=size[1],size[2]
 local m=Mobile.new()
 local l=m:layout(w,h)
 for _,count in ipairs(amounts) do
  local icons,b=m:hotbar(count,w,h)
  assert(#icons==count and b.maxScroll==0,
   "No item may be hidden beyond a horizontal scroll")
  assert(b.rows>=1 and b.columns>=1)
  for _,p in ipairs(icons) do
   assert(p.x-p.r>=b.clipX-0.001 and
     p.x+p.r<=b.clipX+b.clipW+0.001,
     "Every icon must fit horizontally within the tray")
   assert(p.y-p.r>=l.safe.top-0.001 and
     p.y+p.r<=l.safe.bottom+0.001,
     "Every icon must be visible vertically within the safe viewport")
   assert(m:isControlHit(p.x,p.y,w,h,count),
     "Every visible icon must accept touches")
  end
  local status=m:statusLayout(w,h,count)
  assert(status.level.y+status.level.h<b.top,
    "HP/XP capsules cannot cover multirow item icons")
  for _,index in ipairs({1,count}) do
   local p=icons[index]
   assert(m:pressed(100+index,p.x,p.y,w,h,14400,count)=="bar_hold",
     "Every first/last icon must be clickable")
   local action,selected=m:released(100+index)
   assert(action=="slot" and selected==index,
     "Tap must select the actual server slot")
  end
 end
end
-- Multirow inventory must not introduce pages or a swipe requirement.
local m=Mobile.new()
local w,h=1600,757
local before,b=m:hotbar(60,w,h)
local last=before[60]
assert(b.rows>=2 and b.maxScroll==0)
assert(m:pressed(900,last.x,last.y,w,h,14400,60)=="bar_hold")
assert(m:moved(900,last.x+200,last.y,w,h)=="bar_hold")
assert(m:released(900)=="bar_release",
  "Dragging an icon must not silently equip or trigger movement")
local cached=m:hotbar(60,w,h)
assert(cached==before,"Per-frame layout must be reused without allocations")
local after,b2=m:hotbar(61,w,h)
assert(#after==61 and b2.maxScroll==0,"New unlocks remain visible")
local f=assert(io.open("src/mobile/controls.lua","rb"))
local source=f:read("*a");f:close()
assert(not source:find('g.print(">"',1,true) and
 not source:find('g.print("<"',1,true),"No paging arrows")
assert(source:find('Tray.layout(total,l.hotbar,l.safe,l.u)',1,true))
local main=assert(io.open("main.lua","rb"))
local code=main:read("*a");main:close()
assert(code:find('if framePacer and not appFocused',1,true),
  "Android VSync must not be doubled with a draw-time timer")
print("ANDROID FULLY VISIBLE TRAY PASS: all icons, layouts, taps, VSync")
