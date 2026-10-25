-- Data-only optional mob animation specs: no changes to classic/V2,
-- server combat logic, sprite filenames or required map fields.
local Maps=require("server-lua.world.map_profiles")
local JSON=require("server-lua.vendor.dkjson")
local World=require("src.game.world_state")
local Anim=require("src.game.mob_animations")
local base=Maps.load("server-lua/maps","refugio-personalizado")
assert(base.animalAnimations and next(base.animalAnimations)==nil)
local modified=assert(JSON.decode(JSON.encode(base)))
local set={
 sheet="wolf_custom.png",frameWidth=64,frameHeight=64,
 idle={row=0,frames=4,fps=5},
 walk={row=1,frames=6,fps=12},
 attack={row=2,frames=5,fps=10,loop=false},
 hurt={row=3,frames=3,fps=8,loop=false},
 death={row=4,frames=7,fps=7,loop=false}
}
modified.animalAnimations={["4"]=set}
assert(Maps.validate(JSON.encode(modified),base.id))
local function reject(change)
 local obj=assert(JSON.decode(JSON.encode(modified)))
 change(obj)
 assert(not pcall(Maps.validate,JSON.encode(obj),obj.id),
  "unsafe or unbounded mob animation fields accepted")
end
reject(function(m)m.animalAnimations["4"].sheet="../run.lua" end)
reject(function(m)m.animalAnimations["4"].sheet="wolf.gif" end)
reject(function(m)m.animalAnimations["4"].walk.frames=100000 end)
reject(function(m)m.animalAnimations["4"].attack.fps=0 end)
reject(function(m)m.animalAnimations["4"].idle.row=-1 end)
reject(function(m)m.animalAnimations["4"].frameWidth=8192 end)
reject(function(m)m.animalAnimations["22"]=set end)
reject(function(m)m.animalAnimations["4"].attack.newLua="evil" end)
local world=World.new()
assert(world:apply("A",{{map={
 id=modified.id,name=modified.name,portals=modified.portals,
 animations=modified.animalAnimations}}}))
assert(world.map.animations["4"].sheet=="wolf_custom.png")
assert(world:apply("I",{{101,4,600,550,0,300,0,0},{}}))
local wolf=assert(world.animals[101])
world:update(0.04)
assert(wolf.mobClip=="idle")
local f=assert(Anim.frame(wolf,Anim.definition(world.map,wolf)))
assert(f.name=="idle" and f.frame==1 and f.row==0)
world:update(0.20)
assert(Anim.frame(wolf,set).frame==2)
assert(world:apply("I",{{101,4,660,550,0,300,0,0},{}}))
world:update(0.05)
assert(wolf.mobClip=="walk")
assert(Anim.frame(wolf,set).row==1)
assert(world:apply("J",{101}))
world:update(0.05)
assert(wolf.mobClip=="attack" and Anim.frame(wolf,set).row==2)
assert(world:apply("I",{{101,4,670,550,0,280,0,0},{}}))
world:update(0.04)
assert(wolf.mobClip=="hurt" and Anim.frame(wolf,set).row==3)
assert(world:apply("I",{{101,4,675,550,0,0,0,0},{}}))
world:update(0.04)
assert(wolf.mobClip=="death" and Anim.frame(wolf,set).row==4)
world:update(2)
assert(Anim.frame(wolf,set).frame==7,"death must hold the last frame")
local missing={sheet="missing.png",frameWidth=32,frameHeight=32,
 idle={row=0,frames=2,fps=5}}
local aux={index=4,x=0,y=0}
Anim.onPosition(aux,2000,2000)
assert(not aux.mobWalkLeft or aux.mobWalkLeft==0,"teleport must not animate walking")
Anim.onAttack(aux,missing)
Anim.update(aux,missing,0.1)
assert(aux.mobClip=="idle","missing attack clip must fall back to idle")
assert(Anim.frame(aux,missing).frame==1)
assert(not Anim.draw(aux,missing,0,0,80,0,1),"missing LÖVE PNG must fall back to static")
local legacy=World.new()
assert(legacy:apply("A",{{teams={},animals={}}}))
assert(Anim.definition(legacy.map,{index=4})==nil)
assert(Anim.definition({},nil)==nil)
local bundled=World.new()
assert(bundled:apply("A",{{map={id=base.id,portals=base.portals}}}))
assert(next(bundled.map.animations)==nil,"animations became mandatory")
print("PASS optional mob animations: idle/walk/attack/hurt/death, missing sprite, JSON validation and classic")
