package.path="./?.lua;./?/init.lua;"..package.path
-- Upgrades must not cover the Android toolbar; rendered cells and touch
-- hitboxes use the same coordinates. The PC layout remains unchanged.
local rectangles={}
love={
 system={getOS=function()return "Android" end},
 graphics={
  getDimensions=function()return 1280,720 end,
  getFont=function()return {} end, setFont=function()end,
  setColor=function()end,
  rectangle=function(mode,x,y,w,h) if mode=="fill" then rectangles[#rectangles+1]={x=x,y=y,w=w,h=h} end end,
  printf=function()end
 }
}
package.loaded["src.game.reference_icons"]={draw=function()end}
local U=require("src.game.reference_upgrades")
local world={upgradeAge=2,upgradePoints=1,inventory={weapons={0},items={0,3}}}
local offers=U.offers(world)
assert(#offers>0,"Test requires server-authored age-2 choices")
local top=U.top()
assert(top>=92,"Upgrade row must sit below Android top toolbar")
U.draw(world,1280)
assert(#rectangles==#offers,"Must draw exactly one square per real upgrade")
local r=rectangles[1]
assert(math.abs(r.y-top)<.001,"Draw must use Android upgrade top")
assert(U.hitTest(world,1280,r.x+10,r.y+10)==offers[1].index,
  "Tapping visible Android upgrade must select the same offer")
assert(U.hitTest(world,1280,r.x+10,10)==nil,
  "Old invisible desktop upgrade hitbox must not capture touches")
-- Windows UI is not moved by an Android-only adaptation.
love.system.getOS=function()return "Windows" end
rectangles={}
assert(U.top()==10,"Windows upgrade layout must remain unchanged")
U.draw(world,1280)
assert(rectangles[1].y==10)
assert(U.hitTest(world,1280,rectangles[1].x+10,20)==offers[1].index)
print("ANDROID UPGRADE POSITION PASS: unobstructed mobile row and exact touch mapping")
