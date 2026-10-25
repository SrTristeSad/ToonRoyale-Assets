-- SPDX-License-Identifier: AGPL-3.0-only
local Life=require("server-lua.world.life_persistence")
local recorded={}
local account={id="abc",name="Player"}
local p={account=account,spawnedAt=100,lifeStats={kills=2},skinIndex=3,
 tailIndex=0,weaponIndex=5,skinColor=2,variant=function()return {id=1}end}
local top="OLD"
local game={key="LC",wallTimeMs=function()return 1100 end,
 accounts={data={accounts={abc=account}},
 weeklyTopClan=function()return top end,
 recordLife=function(a,life)
  assert(a==account and life.died==true and life.playtime==1000)
  assert(life.look.hat==3 and life.look.weapon==5 and life.look.variant==1)
  recorded[#recorded+1]="life"
  top="NEW"
 end},
 hooks={event=function(e)
 assert(e.kind=="clan_top" and e.server=="LC" and e.clan=="NEW")
 recorded[#recorded+1]="event"
 end},
 recordUnlocks=function(_,player)assert(player==p);recorded[#recorded+1]="unlocks" end}
Life.record(game,p,true)
assert(p.lifeStats==nil and table.concat(recorded,",")=="unlocks,life,event")
p.lifeStats={kills=5}
p.account.verdict="shadow"
recorded={}
Life.record(game,p,false)
assert(p.lifeStats==nil and table.concat(recorded,",")=="unlocks")
p.account=nil
p.lifeStats={kills=1}
recorded={}
Life.record(game,p,false)
assert(p.lifeStats==nil and #recorded==0)
print("PASS life persistence: conta, shadow e convidado")
