-- Real LÖVE GPU test: sprite-sheet frames are actually drawn as quads.
-- A synthetic image lives only in test RAM; no new artwork is shipped.
return function()
 local Mob=require("src.game.mob_animations")
 local set={sheet="test_wolf.png",frameWidth=32,frameHeight=32,
  idle={row=0,frames=3,fps=10},
  walk={row=0,frames=3,fps=10},
  attack={row=0,frames=3,fps=10,loop=false},
  hurt={row=0,frames=3,fps=10,loop=false},
  death={row=0,frames=3,fps=10,loop=false}}
 local src=love.image.newImageData(96,32)
 for x=0,95 do for y=0,31 do
  local idx=math.floor(x/32)
  src:setPixel(x,y,idx==0 and 1 or 0,idx==1 and 1 or 0,
    idx==2 and 1 or 0,1)
 end end
 local texture=love.graphics.newImage(src)
 texture:setFilter("nearest","nearest")
 local function imageLoader()return texture end
 local canvas=love.graphics.newCanvas(128,128)
 local entity={index=4,x=100,y=100}
 local function sample()
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0,0,0,0)
  assert(Mob.draw(entity,set,64,64,64,0,1,imageLoader))
  love.graphics.pop()
  local img=canvas:newImageData()
  return {img:getPixel(64,64)}
 end
 Mob.update(entity,set,0.01)
 local red=sample()
 assert(red[1]>0.9 and red[2]<0.1 and red[3]<0.1)
 Mob.update(entity,set,0.12)
 local green=sample()
 assert(green[2]>0.9 and green[1]<0.1)
 Mob.onAttack(entity,set)
 Mob.update(entity,set,0.01)
 assert(Mob.frame(entity,set).frame==1)
 Mob.update(entity,set,0.27)
 local blue=sample()
 assert(blue[3]>0.9 and blue[1]<0.1,
   "animation did not advance to final attack frame")
 Mob.update(entity,set,0.3)
 assert(entity.mobClip=="idle" and Mob.frame(entity,set).frame==1,
   "non-looping attack should return to idle")
 assert(not Mob.draw(entity,{sheet="../evil.png"},64,64,64,0,1,imageLoader))
 assert(not Mob.draw(entity,set,64,64,64,0,1,function()return nil end),
   "missing PNG should preserve original static art fallback")
 canvas:release()
 Mob.clearCache()
 print("PASS LÖVE mob sprite-sheet rendering: frames, attack one-shot, missing image fallback")
end
