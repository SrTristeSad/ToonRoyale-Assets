-- Confirm new world interactions use a contextual screen tap, without
-- replacing any original Moo-IO joystick, attack or inventory control.
package.path="./?.lua;./?/init.lua;"..package.path
local View=require("src.game.reference_view")
local Mobile=require("src.mobile.controls")
local w,h=1280,720
local player={x=550,y=490}
local objects={
  {id="cache-close",kind="cache",x=610,y=490,used=false},
  {id="lever-far",kind="lever",x=740,y=490,used=false},
  {id="gate-unusable",kind="gate",x=560,y=490,closed=true}
}
local world={map={id="custom"},
  space={id="surface",interactables=objects},
  localPlayer=function()return player end}
local function expect(v,want,msg)
  assert(v==want,(msg or "wrong result")..
    " expected "..tostring(want).." got "..tostring(v))
end
local x,y=w/2,h-151
expect(View.touchInteraction(world,x,y,w,h),"cache-close",
 "Tap should match Windows [F] nearest valid object")
expect(View.touchInteraction(world,w/2-206,y,w,h),nil,
 "Touch outside hint should be ordinary gameplay touch")
expect(View.touchInteraction(world,x,h-132,w,h),nil,
 "Touch below hint should not activate map action")
expect(View.touchInteraction(world,0/0,y,w,h),nil,"NaN touch")
objects[1].used=true
expect(View.touchInteraction(world,x,y,w,h),nil,
 "Used cache and distant lever cannot trigger interaction")
objects[2].x=624
expect(View.touchInteraction(world,x,y,w,h),"lever-far",
 "Newly reachable map lever should become tappable")
world.space=nil
expect(View.touchInteraction(world,x,y,w,h),nil,
 "Classic server or no custom area must not gain map interaction")
world.map=nil
expect(View.touchInteraction(world,x,y,w,h),nil,
 "Classic game never changes original touch actions")
local m=Mobile.new()
local l=m:layout(w,h)
expect(m:pressed(10,l.move.x,l.move.y,w,h,14400,8),"move",
 "Left stick must still capture finger")
expect(m:pressed(11,l.fire.x,l.fire.y,w,h,14400,8),"attack",
 "Right original ATACAR must still capture a separate finger")
expect(m:moved(11,l.fire.x,l.fire.y-90,w,h),"aim",
 "ATACAR itself still points weapon")
assert(m:attacking() and m.moveId==10 and m.fireId==11)
expect(m:released(11),"attack")
expect(m:released(10),"move")
expect(m:pressed(12,l.auto.x,l.auto.y,w,h,14400,8),"server_auto")
expect(m:pressed(13,l.mark.x,l.mark.y,w,h,14400,8),"map_open")
expect(m:pressed(14,l.close.x,l.close.y,w,h,14400,8),"map_close")
expect(m:pressed(15,l.pause.x,l.pause.y,w,h,14400,8),"pause")
print("ANDROID MOO-IO ORIGINAL CONTROLS + LATEST WINDOWS MAP TOUCH PASS")
