-- Client-side geometry only: mouse picking never decides authoritative edits.
local Editor=require("src.game.house_editor")
local Camera=require("src.camera")
local editor=Editor.new()
local player={x=550,y=450,scale=35}
local world={
 map={id="test"},
 spaceId="casa-1",
 space={
  id="casa-1",type="interior",width=1400,height=1200,
  portals={{x=700,y=900}},
  obstacles={
   {x=100,y=100,width=1000,height=80},
   {x=100,y=100,width=80,height=1000},
   {x=1220,y=100,width=80,height=1000},
   {x=689,y=350,width=42,height=200,material="wood"}
  }
 },
 localPlayer=function()return player end,
 orderedPlayers=function()return {player}end
}
local cam=setmetatable({
 x=700,y=600,width=1280,height=720,zoom=1,hasTarget=true
},Camera)
local function screen(x,y)return cam:worldToScreen(x,y) end
assert(editor:toggle(world)==true)
local x,y=screen(502,701)
local proposal=assert(editor:placement(world,cam,x,y))
assert(proposal.x==500 and proposal.y==700
 and proposal.orientation=="h" and proposal.valid)
assert(proposal.rect.width==200 and proposal.rect.height==42)
local oldX,oldY=screen(700,450)
local id,r=editor:wallAt(world,cam,oldX,oldY)
assert(id==4 and r.material=="wood")
local invalid=assert(editor:placement(world,cam,screen(1300,700)))
assert(not invalid.valid,"client preview accepted a far-away wall")
editor:rotate()
assert(editor.orientation=="v")
local rotated=assert(editor:placement(world,cam,x,y))
assert(rotated.orientation=="v" and rotated.rect.width==42)
assert(editor:toggle(world)==false)
world.spaceId="mina"
assert(not editor:toggle(world),"editor must not open in mines")
print("PASS mouse editor: snap, orientation, blueprint, picking and floor gate")
