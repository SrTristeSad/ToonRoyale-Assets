-- SPDX-License-Identifier: AGPL-3.0-only
-- Matches crab-reference.mjs using the original shared AI_TYPES for ID 11.
local AI=require("server-lua.world.ai")
local Crab=require("server-lua.world.crab_king")
local Config=require("src.game.config")
local Types=require("server-lua.world.animal_types")
local Crypto=require("src.protocol.original_crypto")
local cases={
 {name="idle",steps={100,200,300}},
 {name="walk",steps={100,200,300},raider=true,raiderPos={-2100,7200}},
 {name="no-target",steps={800,800,800},raider=true,raiderPos={300,7200}},
 {name="invisible",steps={800,800,800},raider=true,invisible=true},
 {name="force-slam",steps={100,600,800},raider=true,forced="slam"},
 {name="force-claw",steps={100,400,800},raider=true,forced="claw"},
 {name="force-geysers",steps={100,600,1100},raider=true,forced="geysers"},
 {name="force-dive",steps={100,600,2000},raider=true,forced="dive"},
 {name="dive-cycle",steps={700,3600,1650},state=1,stateTimer=700,raider=true},
 {name="submerged",steps={100,400,1100},state=2,stateTimer=2400,raider=true},
 {name="emerging",steps={100,1650,100},state=3,stateTimer=1200,raider=true},
 {name="slam-near",steps={100,1300,100},raider=true,forced="slam",raiderPos={-2430,7200}},
 {name="claw-multi",steps={100,1200,100},raider=true,forced="claw",extraRaider=true},
 {name="geysers-multi",steps={100,1700,100},raider=true,forced="geysers",extraRaider=true},
 {name="forced-wait",steps={100,300,300},forced="claw"},
 {name="boundary",steps={100,100,100},x=-1435,y=7200,xVel=1.5,yVel=0.4,raider=true}
}
local fmt=function(v)return string.format("%.6f",v or 0)end
local function val(v)
 if v==nil then return "~" end
 if type(v)=="number" then return fmt(v) end
 return tostring(v)
end
for cindex,tc in ipairs(cases) do
 local events={}
 local count=0
 local rng=Crypto.mulberry32(18000+cindex-1)
 local function random()count=count+1;return rng()end
 local function makeRaider(id,x,y,invisible)
  local p={
   id=id,sid=id=="raider" and 7 or 8,isPlayer=true,alive=true,
   x=x,y=y,scale=35,xVel=0,yVel=0,health=100,
   powers={invisible=invisible and 1 or 0}
  }
  p.canSee=function()return true end
  p.changeHealth=function(self,amount)
    self.health=self.health+amount
    events[#events+1]="HP:"..self.id..":"..fmt(amount)
    return false
  end
  return p
 end
 local players={}
 if tc.raider then
   local xy=tc.raiderPos or {-2350,7200}
   players[#players+1]=makeRaider("raider",xy[1],xy[2],tc.invisible)
 end
 if tc.extraRaider then
   players[#players+1]=makeRaider("raider2",-2700,7480,false)
 end
 local function argsText(...)
   local parts={}
   for i=1,select("#",...) do parts[#parts+1]=val(select(i,...)) end
   return table.concat(parts,",")
 end
 local opts={
   config=Config,players=players,
   randInt=function(lo,hi)return math.floor(random()*(hi-lo+1))+lo end,
   randFloat=function(lo,hi)return random()*(hi-lo+1)+lo end,
   random=random,
   send=function(id,name,...)
     events[#events+1]="SEND:"..id..":"..name..":"..argsText(...)
   end
 }
 local ai=AI.new(5,opts)
 AI.init(ai,tc.x or -2500,tc.y or 7200,0.2,11,Types[11])
 Crab.attach(ai)
 if tc.state~=nil then
  ai.state=tc.state;ai.stateTimer=tc.stateTimer
  ai.submerged=(tc.state==1 or tc.state==2)
 end
 if tc.forced then ai.nextAttack=tc.forced end
 if tc.xVel then ai.xVel=tc.xVel end
 if tc.yVel then ai.yVel=tc.yVel end
 for tick=1,3 do
   ai:update(tc.steps[tick])
   local a=ai.bossAttack
   local primary=players[1]
   print(table.concat({
     "CRAB",tc.name,tick,count,ai.state,ai.submerged and 1 or 0,
     fmt(ai.stateTimer),fmt(ai.x),fmt(ai.y),fmt(ai.dir),
     fmt(ai.xVel),fmt(ai.yVel),fmt(ai.targetDir),
     fmt(ai.bossCooldown),a and fmt(a.time) or "~",
     a and #a.strikes or 0,val(ai.nextAttack),
     primary and fmt(primary.health) or "~",
     primary and fmt(primary.xVel) or "~",
     primary and fmt(primary.yVel) or "~",table.concat(events,";")
   },"|"))
 end
end
