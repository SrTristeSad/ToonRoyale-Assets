package.path="./?.lua;./?/init.lua;"..package.path
-- Regression for Android screenshot: game metrics include a 65px black
-- OS navigation strip, while the safe viewport ends 65px earlier.
local safe={x=0,y=0,w=1075,h=540}
love={window={getSafeArea=function()
 return safe.x,safe.y,safe.w,safe.h
end}}
local Mobile=require("src.mobile.controls")
local m=Mobile.new()
local w,h=1140,540
local l=m:layout(w,h)
assert(l.safe.right==1075,"Navigation strip must not count as gameplay space")
for _,name in ipairs({"shop","clan","tribe","chat","rank","pause","fold",
  "auto","lock","ping","mark"}) do
 local p=l[name]
 assert(p.x-p.r>=l.safe.left and p.x+p.r<=l.safe.right,
   name.." button is under black system navigation strip")
end
assert(l.hotbar.clipX>=l.safe.left and
  l.hotbar.clipX+l.hotbar.clipW<=l.safe.right,
  "Bottom hotbar viewport must not enter Android navigation strip")
local icons,bar=m:hotbar(8,w,h)
assert(#icons==8 and bar.maxScroll>0,
 "All eight unlocked items must remain reachable without overlapping joysticks")
local visible=0
for _,p in ipairs(icons) do
 if p.x-p.r>=bar.clipX and p.x+p.r<=bar.clipX+bar.clipW then
  visible=visible+1
 end
end
assert(visible>=6,"Full circles, not severed buttons, must occupy the strip")
-- Unlocks must not suddenly jump the bar to its rightmost items.
local many,manyBar=m:hotbar(25,w,h)
assert(#many==25 and manyBar.maxScroll>0 and manyBar.scroll==0)
assert(many[1].x-many[1].r>=manyBar.clipX)
m.barScroll=manyBar.maxScroll
local endIcons,endBar=m:hotbar(25,w,h)
assert(endIcons[25].x+endIcons[25].r<=endBar.clipX+endBar.clipW)
assert(m:pressed(80,endIcons[25].x,endIcons[25].y,w,h,14400,25)=="bar_hold")
local action,index=m:released(80)
assert(action=="slot" and index==25,"Last item remains reachable")
-- A swipe can settle between items but half-buttons are never hit targets.
local swipeX=endBar.clipX+endBar.clipW*.5
assert(m:pressed(81,swipeX,l.hotbar.y,w,h,14400,25)=="bar_hold")
assert(m:moved(81,swipeX+160,l.hotbar.y,w,h)=="bar_scroll")
assert(m:released(81)=="bar_release")
-- Previously saved customized positions may lie in the black strip;
-- clamp the loaded layout back inside the safe viewport.
local editor=Mobile.new()
editor:loadEditor("fold 0.98 0.08\nauto 0.98 0.50\nhotbar 0.96 0.89")
local el=editor:layout(w,h)
assert(el.fold.x+el.fold.r<=1075 and el.auto.x+el.auto.r<=1075)
assert(el.hotbar.clipX+el.hotbar.clipW<=1075)
-- Android insets can change without a graphics resolution change.
safe={x=42,y=0,w=1033,h=540}
local nextL=m:layout(w,h)
assert(nextL~=l and nextL.safe.left==42,
 "Layout cache must refresh when Android navigation insets change")
assert(nextL.minimap.x>=42)
local newIcons,newBar=m:hotbar(8,w,h)
assert(#newIcons==8)
assert(newBar.clipX>=42 and newBar.clipX+newBar.clipW<=1075)
assert(newIcons[1].x-newIcons[1].r>=newBar.clipX)
print("ANDROID SAFE AREA PASS: navigation bar, complete icons, 25 slots, editor")
