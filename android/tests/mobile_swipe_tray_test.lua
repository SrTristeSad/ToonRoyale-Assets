package.path="./?.lua;./?/init.lua;"..package.path
-- A continuous, swipe-only mobile tray: never hide unlocked items behind arrows.
local Mobile=require("src.mobile.controls")
local w,h=1600,757 -- User's landscape Android screenshot dimensions.
local m=Mobile.new()
local count=60
local l=m:layout(w,h)
local items,bounds=m:hotbar(count,w,h)
assert(#items==count and bounds.maxScroll>0,
  "The whole unlocked catalogue must live in a single scrollable row")
assert(m.page==nil and l.stripPrev==nil and l.stripNext==nil,
  "No paging button or second inventory screen may be introduced")
local cx=bounds.clipX+bounds.clipW*.5
local cy=l.hotbar.y
assert(items[1].x-items[1].r>=bounds.clipX,
  "The first circle cannot start cut off by the clipping edge")
local first=items[1]
assert(m:pressed(10,first.x,first.y,w,h,14400,count)=="bar_hold")
local act,index=m:released(10)
assert(act=="slot" and index==1,"The first unlocked item must be selectable")

-- Each swipe is made directly over the item row; no arrows are ever tapped.
local foundLast=false
for i=1,100 do
  local shown,b=m:hotbar(count,w,h)
  local last=shown[count]
  if last.x-last.r>=b.clipX and last.x+last.r<=b.clipX+b.clipW then
    foundLast=true
    break
  end
  assert(m:pressed(100+i,cx,cy,w,h,14400,count)=="bar_hold")
  assert(m:moved(100+i,cx-190,cy,w,h)=="bar_scroll")
  assert(m:released(100+i)=="bar_release",
    "A scroll gesture must not accidentally select an item")
end
assert(foundLast,"Repeated finger swipes must reach the very last available item")
local last=m:hotbar(count,w,h)[count]
assert(m:pressed(300,last.x,last.y,w,h,14400,count)=="bar_hold")
act,index=m:released(300)
assert(act=="slot" and index==count,
  "The last available item must be directly selectable, without any arrow")
assert(not m:attacking() and m.moveId==nil,
  "Scrolling the tray cannot trigger character movement or combat")

-- Unlocking more items must extend this same strip, not jump its scroll.
local old=m.barScroll
local _,added=m:hotbar(count+1,w,h)
assert(m.barScroll==old and added.maxScroll>bounds.maxScroll,
  "New server unlocks must append without switching pages or jumping")
-- Restoring the first item also works by swiping the very same strip.
for i=1,100 do
  local shown,b=m:hotbar(count+1,w,h)
  if shown[1].x-shown[1].r>=b.clipX then break end
  assert(m:pressed(400+i,cx,cy,w,h,14400,count+1)=="bar_hold")
  assert(m:moved(400+i,cx+190,cy,w,h)=="bar_scroll")
  assert(m:released(400+i)=="bar_release")
end
local back=m:hotbar(count+1,w,h)
assert(back[1].x-back[1].r>=bounds.clipX,
  "Swiping right must reach the first item again")

-- The UI renders a passive progress rail instead of fake clickable arrows.
local f=assert(io.open("src/mobile/controls.lua","rb"))
local source=f:read("*a");f:close()
assert(not source:find('g.print(">"',1,true) and
  not source:find('g.print("<"',1,true),
  "Legacy < and > glyphs must not masquerade as inventory buttons")
assert(source:find('thumbX=trackX+',1,true),
  "The passive progress rail must indicate how far the tray has moved")
print("ANDROID SWIPE TRAY PASS: 60 items, no arrows, first/last taps, unlocks")
