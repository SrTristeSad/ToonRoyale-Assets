package.path="./?.lua;./?/init.lua;"..package.path
local Mobile=require("src.mobile.controls")
local m=Mobile.new()
local w,h=1280,720
local l=m:layout(w,h)
local count=24
local slots,bar=m:hotbar(count,w,h)
assert(#slots==count and bar.maxScroll>0,
 "New items must remain accessible without a five-slot limit")
local cx=bar.clipX+bar.clipW*.5
assert(m:isControlHit(cx,l.hotbar.y,w,h,count),
 "Contextual map interactions must never capture a quick-item tap")
assert(m:isControlHit(l.auto.x,l.auto.y,w,h,count),
 "AUTO button must take precedence over map interactions")
assert(m:isControlHit(l.minimap.x+20,l.minimap.y+20,w,h,count),
 "Minimap click must take precedence")
assert(not m:isControlHit(w*.5,h*.4,w,h,count),
 "World interactions must still be available in unobstructed playfield")
m.barScroll=math.min(400,bar.maxScroll)
local _,before=m:hotbar(count,w,h)
local initial=before.scroll
assert(m:pressed(100,cx,l.hotbar.y,w,h,14400,count)=="bar_hold")
assert(m:moved(100,cx+10,l.hotbar.y,w,h)=="bar_hold",
 "Small finger tremor must preserve tap")
assert(m:moved(100,cx+160,l.hotbar.y,w,h)=="bar_scroll")
local _,after=m:hotbar(count,w,h)
assert(math.abs(after.scroll-math.max(0,initial-160))<.01,
 "Swipe must include the entire drag, not lose the first 24 pixels")
assert(m:released(100)=="bar_release","Scroll must not activate an item")
local id
for _,p in ipairs(slots) do
 if p.x>=bar.clipX+p.r and p.x<=bar.clipX+bar.clipW-p.r then id=p;break end
end
assert(id,"Expected a fully visible unlocked item")
local _,nowBar=m:hotbar(count,w,h)
local visibleId
for _,p in ipairs(m:hotbar(count,w,h)) do
 if p.x>=nowBar.clipX+p.r and p.x<=nowBar.clipX+nowBar.clipW-p.r then visibleId=p;break end
end
assert(visibleId)
assert(m:pressed(101,visibleId.x,visibleId.y,w,h,14400,count)=="bar_hold")
local act,index=m:released(101)
assert(act=="slot" and index==visibleId.index,
 "Tap must emit real server-unlocked item index")
local x=visibleId.x
assert(m:pressed(102,x,nowBar.top+1,w,h,14400,count)=="bar_hold")
assert(m:released(102)=="bar_release",
 "Tapping empty top margin of inventory must not select a hidden item")
m.editor.positions.resources={x=.08,y=.99}
local resources=m:resourceLayout(w,h)
assert(resources.bottom<=h+.0001 and resources.y>=0,
 "All four resource rows must remain inside the screen after editing")
local fh=assert(io.open("main.lua","rb"));local code=fh:read("*a");fh:close()
assert(code:find("not mobile:isControlHit(x,y,w,h,",1,true),
 "World interactions must explicitly exclude touch HUD")
assert(code:find("payload~=mobileAbilityLastSlot",1,true),
 "Rapid touches to different slots must not be dropped by global timer")
print("ANDROID INPUT AUDIT PASS: exclusive quickbar, no lost drag, no hidden items")
