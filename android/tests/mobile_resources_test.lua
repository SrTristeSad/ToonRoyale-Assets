package.path="./?.lua;./?/init.lua;"..package.path
-- Regression: only the real MooMoo resources appear beneath the minimap.
-- The server's points field is the original gold display.
local images={},texts={},icons={}
local function nop() end
local function font(size)
 return {getHeight=function()return size end,getWidth=function(_,s)return #tostring(s)*size*.5 end}
end
love={
 graphics={
  getDimensions=function()return 1280,720 end,
  newFont=font, setFont=nop, setColor=nop,
  circle=nop, rectangle=nop, line=nop, arc=nop,polygon=nop,
  setLineWidth=nop, push=nop, pop=nop, translate=nop,
  scale=nop, rotate=nop, setScissor=nop,
  print=function(t)table.insert(texts,tostring(t))end,
  printf=function(t)table.insert(texts,tostring(t))end
 }
}
package.loaded["src.game.reference_assets"]={
 draw=function(category,name)
  if category=="resources" then images[#images+1]=name end
  return true
 end
}
package.loaded["src.game.reference_icons"]={
 draw=function(kind,item,x,y,size,large)
  icons[#icons+1]={kind=kind,size=size,large=large}
  return true
 end
}
local Mobile=require("src.mobile.controls")
assert(#Mobile.resourceRows==4)
local expected={"food","wood","stone","points"}
for i,r in ipairs(Mobile.resourceRows) do assert(r.key==expected[i]) end
local hud=Mobile.new()
local world={
 resources={food=11,wood=22,stone=33,points=44,kills=77,health=66},
 resourceGain={wood={amount=3,remaining=1}},
 inventory={weapons={0,1},items={0,3,6}},
 age=4,xp=3,maxXP=300,minimapData={},mapPings={},
 localPlayer=function()return {health=60,maxHealth=100,buildIndex=-1,weaponIndex=0,x=500,y=300}end
}
local layout=hud:resourceLayout(1280,720)
local mini=hud:layout(1280,720).minimap
assert(layout.y>mini.y+mini.h,"Resources must be below minimap")
assert(layout.bottom<720-170,"Resources must not overlap lower skill bar")
hud:draw(world,14400)
local expectedIcons={"food_ico.png","wood_ico.png","stone_ico.png","gold_ico.png"}
assert(#images==4,"Only four authentic material icons may be rendered")
for i,name in ipairs(expectedIcons) do assert(images[i]==name,images[i] or "missing") end
local function has(s)
 for _,t in ipairs(texts) do if t==s then return true end end
 return false
end
for _,n in ipairs({"11","22","33","44","+3"}) do
 assert(has(n),"Resource count not rendered: "..n)
end
assert(not has("77") and not has("66"),"Kills/health are NOT extra materials")
assert(#icons==5,"Real inventory of 5 items must be drawn")
for _,item in ipairs(icons) do assert(item.large==true) end
local slots,bounds=hud:hotbar(5,1280,720)
local again,same=hud:hotbar(5,1280,720)
assert(again==slots and same==bounds,"Stable hotbar should reuse layout")
assert(slots[1].r>40,"Item circles must be enlarged")
hud.barScroll=70
local nextSlots=hud:hotbar(5,1280,720)
-- No actual overflow for five items: scrolling stays clamped to zero.
assert(nextSlots==slots)
local more,overflow=hud:hotbar(10,1280,720)
assert(overflow.maxScroll>0)
hud.barScroll=math.max(0,overflow.maxScroll-50)
local moved=hud:hotbar(10,1280,720)
assert(moved~=more,"Scrolling must invalidate cached hitboxes")
print("ANDROID RESOURCES PASS: food/wood/stone/gold and enlarged cached hotbar")
