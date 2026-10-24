-- SPDX-License-Identifier: AGPL-3.0-only
local Vitals=require("server-lua.world.vitals")
local function fm(v) return string.format("%.3f",v or 0) end
local cases={
 {name="idle",steps={0,400,400,400}},
 {name="regen",steps={200,500,500,1000},skin={healthRegen=3}},
 {name="double-regen",steps={0,1050,1050},skin={healthRegen=3},tail={healthRegen=2}},
 {name="poison",steps={0,300,300,300,300},dmgOverTime={dmg=7,time=2,doer="enemy"}},
 {name="healer",steps={0,1000,1000},healCol=5},
 {name="mill",steps={0,500,500,1100},pps=3},
 {name="hat-pps",steps={0,1000,1000},skin={pps=4}},
 {name="mixed",steps={100,1100,1100},skin={healthRegen=2,pps=4},
  dmgOverTime={dmg=3,time=2,doer="enemy"},healCol=1,pps=5},
 {name="death",steps={0,200,1200},health=4,dmgOverTime={dmg=6,time=2,doer="enemy"},pps=6},
 {name="already-dead",steps={300,400},alive=false},
 {name="shame",steps={100,100,100,200},shameTimer=300,shameCount=8},
 {name="zero-values",steps={0,999,1,0},skin={healthRegen=0,pps=0},
  tail={healthRegen=0},healCol=0,pps=0}
}
for _,tc in ipairs(cases) do
 local events={}
 local p={
   id="p7",alive=true,health=70,maxHealth=100,
   shameTimer=0,shameCount=0,dmgOverTime={},healCol=0,
   pps=0,points=50
 }
 for k,v in pairs(tc) do
   if k~="name" and k~="steps" then p[k]=v end
 end
 p.changeHealth=function(self,value,source)
   local who=source==self and "self" or tostring(source or "-")
   events[#events+1]="H:"..fm(value)..":"..who
   self.health=math.min(self.maxHealth,self.health+value)
   if self.health<=0 then self.alive=false end
 end
 p.addResource=function(self,rtype,value,auto)
   events[#events+1]="R:"..rtype..":"..fm(value)..":"..(auto and 1 or 0)
   self.points=self.points+value
 end
 for i,delta in ipairs(tc.steps) do
   Vitals.step(p,delta)
   print(table.concat({"VITAL",tc.name,i,p.alive and 1 or 0,fm(p.health),
     fm(p.points),fm(p.shameTimer),p.shameCount,
     fm(p.dmgOverTime.dmg),fm(p.dmgOverTime.time),
     fm(p.regenTimer),table.concat(events,",")},"|"))
 end
end
