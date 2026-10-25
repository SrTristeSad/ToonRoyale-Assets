-- SPDX-License-Identifier: AGPL-3.0-only
-- Same order, winners and account/profile permutations as Node original.
local Rewards=require("server-lua.world.animal_rewards")
local CrabRewards=require("server-lua.world.crab_rewards")
local cases={
 {name="solo",contributors={}},
 {name="helpers",contributors={{sid=2,damage=25000},{sid=3,damage=35000}}},
 {name="threshold",contributors={{sid=2,damage=23999},{sid=3,damage=24000}}},
 {name="dead",contributors={{sid=2,damage=50000,alive=false}}},
 {name="same-killer",contributors={{sid=1,damage=25000},{sid=3,damage=25000}}},
 {name="previous-shell",contributors={{sid=2,damage=25000}},preowned={1,2}},
 {name="no-stat",contributors={{sid=2,damage=25000}},noStats={1,2}},
 {name="no-account",contributors={{sid=2,damage=25000}},noStats={3}},
 {name="other-animal",index=6,contributors={{sid=2,damage=50000}}},
 {name="cow",index=0,contributors={{sid=2,damage=50000}}},
 {name="not-player",notPlayer=true,contributors={}},
 {name="no-killer",noKiller=true,contributors={}}
}
local function includes(xs,n)
 for _,x in ipairs(xs or {}) do if x==n then return true end end
 return false
end
for _,tc in ipairs(cases) do
 local events,crabKillers={},{}
 local function makePlayer(sid)
   local name=sid==1 and "Hero" or ("Helper"..sid)
   local p={
     sid=sid,id="p"..sid,isPlayer=true,alive=true,
     skins=includes(tc.preowned,sid) and {[61]=1} or {},
     lifeStats=not includes(tc.noStats,sid) and
       {animals=0,bosses=0,bossKills=0,animalKills={}} or nil
   }
   p.shownName=function()return name end
   p.send=function(self,packet,...)
     local args={}
     for i=1,select("#",...) do args[#args+1]=tostring(select(i,...)) end
     events[#events+1]="HAT:"..self.sid..":"..packet..":"..table.concat(args,",")
   end
   return p
 end
 local killer=makePlayer(1)
 if tc.notPlayer then killer.isPlayer=false end
 local order={killer}
 local bySid={[1]=killer}
 local damageBy,damageOrder={},{}
 for _,entry in ipairs(tc.contributors) do
   local p=bySid[entry.sid]
   if not p then
     p=makePlayer(entry.sid)
     order[#order+1]=p
     bySid[entry.sid]=p
   end
   if entry.alive==false then p.alive=false end
   damageBy[p]=entry.damage
   damageOrder[#damageOrder+1]=p
 end
 local ai={index=tc.index or 11,damageBy=damageBy,
   damageOrder=damageOrder,maxHealth=480000}
 local ctx={
   key="LC",crabKillers=crabKillers,
   broadcast=function(packet,...)
     local args={}
     for i=1,select("#",...) do args[#args+1]=tostring(select(i,...)) end
     events[#events+1]="BROADCAST:"..packet..":"..table.concat(args,",")
   end,
   event=function(data)
     events[#events+1]="EVENT:"..data.kind..":"..data.server..":"..data.by
   end
 }
 Rewards.onKill(ai,not tc.noKiller and killer or nil,{
   onCrabKingKilled=function(a,who)return CrabRewards.onKill(a,who,ctx)end
 })
 local people={}
 for _,p in ipairs(order) do
   local stats=p.lifeStats
   local animalKills="-"
   if stats then
     local key,val=next(stats.animalKills)
     animalKills=key and ('{"'..key..'":'..val..'}') or "{}"
   end
   people[#people+1]=table.concat({
     p.sid,stats and stats.animals or "-",
     stats and stats.bosses or "-",
     stats and stats.bossKills or "-",
     animalKills,p.skins[61] or 0,crabKillers[p.sid] and 1 or 0
   },",")
 end
 print("CRABREWARD|"..tc.name.."|"..table.concat(people,";").."|"..table.concat(events,";"))
end
