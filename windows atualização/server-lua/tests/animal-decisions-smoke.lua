-- Focused server-side awareness and path-selection regressions.
local Brain=require("server-lua.world.animal_decisions")
local cfg={mapScale=14400,server={roomDifficulty="normal"}}
local p={x=570,y=500,alive=true,active=true,spaceId="surface",
 powers={invisible=0},skin={}}
local wolf={x=500,y=500,active=true,alive=true,spaceId="surface",
 hostile=true,chargePlayer=true,viewRange=800,waitCount=1900,
 moveCount=0,scale=72}
Brain.assess(wolf,800,{p},{wolf},cfg)
assert(wolf.waitCount<=0 and wolf.chargeTarget==p
 and wolf.moveCount>=650,"hostile animal did not recognize nearby moving target")
local cow={x=510,y=500,active=true,alive=true,spaceId="surface",
 hostile=false,viewRange=650,waitCount=1200,moveCount=0,
 scale=55}
Brain.assess(cow,800,{p},{cow,wolf},cfg)
assert(cow.runFrom and cow.waitCount==0
 and cow.moveCount>=1000 and not cow.chargeTarget,
 "passive animal must flee predator rather than stand motionless")
local behind={x=50,y=400,active=true,alive=true,
 hostile=false,scale=55,spaceId="surface"}
local direction=Brain.steer(behind,math.pi,nil,{behind},cfg)
assert(math.abs(direction-math.pi)>0.2,
 "animal must steer away from blocking world edge")
local moved=Brain.steer({x=700,y=700,scale=32,spaceId="cave",
 hostile=true,active=true,alive=true},0,{
  get=function()return {width=1000,height=1000}end,
  canOccupy=function(_,_,x,y) return x<755 end
 },{},cfg)
assert(math.abs(moved)>0.2,"indoor mob should detour around blocked tile")
print("PASS passive flight, hostile acquisition, border and cave obstacle detours")
