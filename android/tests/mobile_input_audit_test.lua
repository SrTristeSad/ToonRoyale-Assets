package.path="./?.lua;./?/init.lua;"..package.path
local Mobile=require("src.mobile.controls")
local m=Mobile.new()
local w,h=1280,720
local l=m:layout(w,h)
local count=24
local slots,bar=m:hotbar(count,w,h)
assert(#slots==count and bar.maxScroll==0 and bar.rows>=2,
 "Every available item must remain visible, with no scrolling")
local first,last=slots[1],slots[count]
for _,p in ipairs(slots) do
 assert(p.x-p.r>=bar.clipX and p.x+p.r<=bar.clipX+bar.clipW)
 assert(p.y-p.r>=bar.top and p.y+p.r<=bar.bottom)
 assert(m:isControlHit(p.x,p.y,w,h,count))
end
assert(m:isControlHit(l.auto.x,l.auto.y,w,h,count))
assert(m:isControlHit(l.minimap.x+20,l.minimap.y+20,w,h,count))
assert(not m:isControlHit(w*.5,h*.4,w,h,0),
 "World interactions must remain accessible with an empty tray")
assert(m:pressed(101,first.x,first.y,w,h,14400,count)=="bar_hold")
local act,index=m:released(101)
assert(act=="slot" and index==1)
assert(m:pressed(102,last.x,last.y,w,h,14400,count)=="bar_hold")
act,index=m:released(102)
assert(act=="slot" and index==count)
assert(m:pressed(103,last.x,last.y,w,h,14400,count)=="bar_hold")
assert(m:moved(103,last.x+150,last.y,w,h)=="bar_hold")
assert(m:released(103)=="bar_release",
 "Dragging must never activate an item")
m.editor.positions.resources={x=.08,y=.99}
local resources=m:resourceLayout(w,h)
assert(resources.bottom<=h+.0001 and resources.y>=0,
 "All four resource rows must remain inside the screen after editing")
local fh=assert(io.open("main.lua","rb"));local code=fh:read("*a");fh:close()
assert(code:find("not mobile:isControlHit(x,y,w,h,",1,true),
 "World interactions must explicitly exclude touch HUD")
assert(code:find("payload~=mobileAbilityLastSlot",1,true),
 "Rapid touches to different slots must not be dropped by global timer")
print("ANDROID INPUT AUDIT PASS: all icons visible, first/last taps, no accidental drag")
