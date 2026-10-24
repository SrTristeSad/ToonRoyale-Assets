-- SPDX-License-Identifier: AGPL-3.0-only
-- State and config taken from shared/config/items.js and verified by the JS fixture.
local Tick=require("server-lua.world.weapon_tick")
local weapons={
  [0]={id=0,gather=1,speed=300},
  [9]={id=9,projectile=0,speed=600},
  [11]={id=11,shield=0.2},
  [15]={id=15,projectile=5,speed=1500,rec=0.35}
}
local projectiles={[0]={range=1000,speed=1.6},[5]={range=1400,speed=3.6}}
local scenarios={
  {name="idle"}, {name="gather-click",hits=1,mouseState=0},
  {name="gather-held",gathering=1,mouseState=1},
  {name="auto-hammer",autoGather=1},
  {name="reload",reload=120,gathering=1,mouseState=0},
  {name="building",buildIndex=2,hits=1,autoGather=1},
  {name="bow",weaponIndex=9,gathering=1,mouseState=0},
  {name="bow-empty",weaponIndex=9,gathering=1,hasResources=false},
  {name="bow-auto",weaponIndex=9,autoGather=1,skin={aMlt=1.25,atkSpd=0.8,projCost=0.5}},
  {name="bow-reload",weaponIndex=9,autoGather=1,reload=100},
  {name="musket",weaponIndex=15,gathering=1,dir=0.75,xVel=0.5,yVel=-0.15},
  {name="musket-no-res",weaponIndex=15,gathering=1,hasResources=false},
  {name="shield",weaponIndex=11,gathering=1},
  {name="turret",skin={turret={range=500}},shootCount=50},
  {name="turret-gather",skin={turret={range=500}},shootCount=25,autoGather=1}
}
local function fixed(x)return string.format("%.6f",x)end
local function fmt(...)
  local parts={}
  for i=1,select("#",...) do
    local v=select(i,...)
    if type(v)=="number" then parts[i]=fixed(v)
    elseif v==nil then parts[i]="-" else parts[i]=tostring(v) end
  end
  return table.concat(parts,",")
end
for _,sc in ipairs(scenarios) do
  local events={}
  local p={
    weaponIndex=0,buildIndex=-1,autoGather=0,gathering=0,mouseState=0,
    reloads={},hits=0,scale=35,x=123,y=456,dir=0.25,xVel=0,yVel=0,
    noMovTimer=200,zIndex=0,shootCount=200,hasResources=true
  }
  for key,value in pairs(sc) do if key~="name" and key~="reload" then p[key]=value end end
  if sc.reload~=nil then p.reloads[p.weaponIndex]=sc.reload end
  p.gather=function()events[#events+1]="GATHER"end
  p.hasRes=function(self,weapon,mult)
    events[#events+1]="HAS:"..fmt(weapon.id,mult)
    return self.hasResources
  end
  p.useRes=function(self,weapon,mult)events[#events+1]="USE:"..fmt(weapon.id,mult)end
  p.shootTurret=function(self)
    events[#events+1]="TURRET";self.shootCount=250
  end
  local opts={
    players={p},weapon=weapons[p.weaponIndex],projectiles=projectiles,
    addProjectile=function(x,y,dir,range,speed,index,owner,ignore,layer)
      events[#events+1]="SHOT:"..fmt(x,y,dir,range,speed,index,layer)
    end
  }
  for tick=1,3 do
    Tick.step(p,100,opts)
    print(table.concat({"WEAPON",sc.name,tick,p.weaponIndex,p.gathering,p.hits,
      p.noMovTimer,p.reloads[p.weaponIndex] and fixed(p.reloads[p.weaponIndex]) or "-",
      fixed(p.xVel),fixed(p.yVel),fixed(p.shootCount),table.concat(events,";")},"|"))
  end
end
