-- SPDX-License-Identifier: AGPL-3.0-only
local Ranking=require("server-lua.world.mobile_rankings")
local Input=require("server-lua.world.input")
local packets={}
local viewer={sid=8,alive=true,spawned=true,points=40,health=50,kills=1,food=5,wood=1,stone=1}
local leader={sid=4,alive=true,spawned=true,points=100,health=99,kills=5,food=20,wood=30,stone=4}
local hidden={sid=2,alive=true,spawned=true,shadowed=true,points=500,health=100}
for _,p in ipairs({viewer,leader,hidden}) do
  p.shownName=function(self) return "P"..self.sid end
end
viewer.send=function(_,name,category,rows)
  packets[#packets+1]={name,category,rows}
end
viewer.anticheat={invalid=function(_,name,reason) packets[#packets+1]={name,reason} end}
local players={viewer,leader,hidden}
local function same(actual,expected)
  assert(#actual==#expected,"wrong ranking payload length")
  for i=1,#expected do assert(actual[i]==expected[i],tostring(i)) end
end
same(Ranking.build(players,viewer,"gold"),{4,"P4",100,8,"P8",40})
same(Ranking.build(players,viewer,"kills"),{4,"P4",5,8,"P8",1})
same(Ranking.build(players,viewer,"health"),{4,"P4",99,8,"P8",50})
assert(not Ranking.valid("invalid"))
local now=2000
local ctx={items={weapons={},list={}},players=players,wallTimeMs=function() return now end}
Input.handle(ctx,viewer,"Y",{"gold"})
assert(#packets==1 and packets[1][1]=="n" and packets[1][2]=="gold")
same(packets[1][3],{4,"P4",100,8,"P8",40})
now=2500
Input.handle(ctx,viewer,"Y",{"gold"})
assert(#packets==1,"cooldown must suppress response")
now=3000
Input.handle(ctx,viewer,"Y",{"kills"})
assert(#packets==2 and packets[2][2]=="kills")
Input.handle(ctx,viewer,"Y",{"invalid"})
assert(#packets==3 and packets[3][2]=="ranking category")
Input.handle(ctx,viewer,"Y",{"gold","extra"})
assert(#packets==4 and packets[4][2]=="ranking category")
viewer.alive=false
now=5000
Input.handle(ctx,viewer,"Y",{"gold"})
assert(#packets==4,"dead player cannot request ranking")
print("PASS 10 verificacoes ranking Y, cooldown, filtro e validacao")
