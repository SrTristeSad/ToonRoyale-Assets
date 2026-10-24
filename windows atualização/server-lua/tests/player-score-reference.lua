-- Exact same scenarios as player-score-reference.mjs.
local Config=require("src.game.config")
local Player=require("server-lua.world.player")
local Score=require("server-lua.world.score")
for _,xp in ipairs({0,2999,3000,6999,7000,11999,12000,29999,30000,40000}) do
 for _,member in ipairs({false,true}) do
  local p={
    room={config=Config},weaponIndex=0,weaponXP={[0]=xp},isMember=member
  }
  local v=Player.variant(p)
  print(table.concat({"VAR",xp,member and 1 or 0,v.id,v.src,v.val,
    v.poison and 1 or 0,v.lifesteal or 0,v.membersOnly and 1 or 0},"|"))
 end
end
local scenarios={
 {name="positive",amount=120},{name="negative",amount=-70},
 {name="zero",amount=0},{name="recover",amount=3000,points=400},
 {name="negative-limit",amount=-300,points=110},
 {name="statless",amount=20,noStats=true},
 {name="no-player",amount=150,isPlayer=false},
 {name="no-player-god",amount=-80,isPlayer=false}
}
local fmt=function(x)return string.format("%.3f",x)end
for _,tc in ipairs(scenarios) do
 local events={}
 local p={
   isPlayer=tc.isPlayer~=false,points=tc.points or 100,
   lifeStats=not tc.noStats and {gold=12,score=105} or nil
 }
 p.send=function(self,name,...)
   local values={}
   for i=1,select("#",...) do values[#values+1]=tostring(select(i,...))end
   events[#events+1]="SEND:"..name..":"..table.concat(values,",")
 end
 p.earnXP=function(self,amount)events[#events+1]="XP:"..amount end
 Score.add(p,tc.amount,Config)
 print(table.concat({"SCORE",tc.name,fmt(p.points),
   p.lifeStats and fmt(p.lifeStats.gold) or "-",
   p.lifeStats and fmt(p.lifeStats.score) or "-",
   table.concat(events,";")},"|"))
end
