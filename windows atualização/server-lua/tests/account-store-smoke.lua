-- SPDX-License-Identifier: AGPL-3.0-only
-- Uses a disposable copy of the original accounts.json shape, never production.
local Json=require("server-lua.vendor.dkjson")
local Store=require("server-lua.world.account_store")
local path="server-lua/tests/.accounts-store-smoke.json"
local id="1234567890abcdef12345678"
local function stats()
 return {kills=0,deaths=0,damage=0,healing=0,wood=0,food=0,stone=0,gold=0,
  animalDamage=0,animalKills={},bestScore=0,maxKills=0,lives=0,playtime=0,periods={}}
end
local account={id=id,name="Tester",clan="ABC",role=Json.null,verdict=Json.null,
 stats=stats(),socials={discord="visible"},custom={unported=true}}
local fixture={accounts={[id]=account},names={tester=id},emails={},clans={
 ABC={name="ABC",stats={kills=0,raidKills=0,periods={}},
 members={{id=id,role="leader",kills=0}},shadowed=false}
},social={friends={},requests={{senderId=id,recipientId="another",note="keep"}}},
 legacyIds={},futureField={kept="yes",emptyObj=setmetatable({},{__jsontype="object"})}}
local f=assert(io.open(path,"wb"))
assert(f:write(Json.encode(fixture)))
assert(f:close())
local function remove() os.remove(path);os.remove(path..".lua-backup");os.remove(path..".lua-new") end
local ok,err=pcall(function()
 local store=Store.open(path,{nowMs=function()return 1792864800000 end})
 local a=assert(store:nameOwner("  TESTER  "))
 assert(a.id==id)
 store:recordUnlocks(a,{hat=5})
 store:recordUnlocks(a,{hat=5})
 store:recordUnlocks(a,{acc=7})
 store:recordUnlocks(a,{weapon=2,variant=3})
 store:recordUnlocks(a,{weapon=2,variant=1})
 assert(#a.unlocks.hats==1 and #a.unlocks.accs==1 and a.unlocks.weapons["2"]==3)
 local life={died=true,kills=4,damage=10,healing=2,wood=50,food=40,stone=30,
  gold=20,animalDamage=9,animalKills={wolf=2},playtime=60000,score=100,
  bossKills=1,look={hat=5,weapon=2}}
 local api=store:callbacks()
 assert(api.data==store.data)
 api.recordLife(a,life)
 assert(a.stats.lives==1 and a.stats.deaths==1 and a.stats.kills==4)
 assert(a.stats.animalKills.wolf==2 and a.stats.bestScore==100)
 assert(a.bestLook.hat==5 and store.data.clans.ABC.stats.raidKills==1)
 assert(store.data.clans.ABC.members[1].kills==4)
 assert(api.weeklyTopClan()=="ABC")
 local profile=api.profile(a)
 assert(profile.periods.week.kills==4 and profile.clan.name=="ABC")
 assert(api.setVerdict("tester","shadow"))
 assert(a.verdict=="shadow")
 assert(api.setVerdict("tester","clear"))
 assert(a.verdict==Json.null)
 assert(not api.setVerdict("missing","ban"))
 local restored=Store.open(path,{nowMs=function()return 1792864800000 end})
 local a2=restored.data.accounts[id]
 assert(a2.stats.kills==4 and a2.unlocks.weapons["2"]==3)
 assert(restored.data.futureField.kept=="yes")
 assert(restored.data.social.requests[1].note=="keep")
 assert(getmetatable(restored.data.futureField.emptyObj).__jsontype=="object")
 assert(restored.data.accounts[id].verdict==Json.null)
 local rawFile=assert(io.open(path,"rb"));local raw=rawFile:read("*a");rawFile:close()
 assert(raw:find('"accounts"',1,true) and raw:find('"requests"',1,true))
end)
remove()
assert(ok,err)
print("PASS AccountStore Lua: arquivo, reload, unlocks, vida, clã, campos preservados e null")
