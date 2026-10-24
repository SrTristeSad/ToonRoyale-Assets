-- Differential reference for original AccountStore methods, same cases as .mjs.
local Json=require("server-lua.vendor.dkjson")
local Store=require("server-lua.world.account_store")
local id="abc123"
local function base()
 return {kills=0,deaths=0,damage=0,healing=0,wood=0,food=0,stone=0,
 gold=0,animalDamage=0,animalKills={},bestScore=0,maxKills=0,lives=0,playtime=0,periods={}}
end
local a={id=id,name="Tester",role=Json.null,verdict=Json.null,clan="ABC",
 stats=base(),unlocks={hats={5},accs={7},weapons={["2"]=3}},
 prefs={friendRequests=false}}
local clan={name="ABC",members={{id=id,role="officer",kills=1,periods={}}},
 requests={"someone"},invites={},stats={kills=0,raidKills=0,periods={}}}
local store=Store.open("server-lua/tests/.does-not-exist.json",{
 nowMs=function()return 1792864800000 end})
store.data={accounts={[id]=a},names={tester=id},emails={["a@example.com"]=id},
 clans={ABC=clan},social={friends={[id]={{id="friend"}}},
 requests={{id="r1",senderId="friend",recipientId=id}}},legacyIds={legacy=id}}
local saves=0
store.save=function() saves=saves+1 end
local function n(x)
 if x==nil or x==Json.null then return "~" end
 if type(x)=="boolean" then return tostring(x) end
 return tostring(x)
end
local function out(label,...)
 local a={label}
 for i=1,select("#",...) do a[#a+1]=n(select(i,...)) end
 print(table.concat(a,"|"))
end
local p=store:prefsOf(a)
out("PREFS",p.friendNotifs,p.friendRequests,p.clanChat)
p=store:setPrefs(a,{friendRequests=true,clanInvites=false,role=true})
out("PREFS_EDIT",p.friendRequests,p.clanInvites,p.friendNotifs)
local opts=store:lookOptions(a)
out("LOOK_OPTIONS",table.concat(opts.hats,","),table.concat(opts.accs,","),
 opts.weapons["0"],opts.weapons["2"])
local z=store:setLook(a,{hat=5,acc=7,weapon=2,variant=2,color=4})
out("LOOK_OK",z.status,z.body.look.hat,z.body.look.variant)
z=store:setLook(a,{hat=99,acc=7,weapon=2,variant=0,color=1})
out("LOOK_BAD",z.status,z.body.error)
local info=store:accountInfo(a)
out("ACCOUNT_INFO",info.name,info.clan.name,info.clan.role,info.clanNotes)
out("SELECTORS",store:accountByEmail(" A@example.com ")==a,
 store:accountById("legacy")==a,store:nameOwner(" TESTER ")==a)
out("SOCIAL",store:areFriends(id,"friend"),#store:requestsFor(id),#store:requestsFrom(id))
out("NAMES",store:namesFor({id,"legacy","nonexistent"})[id],
 store:namesFor({"legacy"}).legacy,store:namesFor({"nonexistent"}).nonexistent)
store:setRole("Tester","mod")
out("ROLE_VALID",a.role)
store:setRole("Tester","invalid")
out("ROLE_CLEAR",a.role)
store:setVerdict("Tester","shadow")
out("VERDICT_SHADOW",a.verdict)
store:setVerdict("Tester","clear")
out("VERDICT_CLEAR",a.verdict)
store:setClanShadow("ABC",true)
out("CLAN_SHADOW",clan.shadowed)
store:setClanShadow("ABC",false)
store:recordUnlocks(a,{hat=5})
store:recordUnlocks(a,{weapon=2,variant=4})
out("UNLOCK",#a.unlocks.hats,a.unlocks.weapons["2"])
local life={died=true,kills=4,damage=10,healing=2,wood=50,food=30,stone=20,
 gold=11,animalDamage=8,playtime=15000,score=60,
 animalKills={wolf=2},bossKills=1,look={hat=5,weapon=2}}
store:recordLife(a,life)
out("LIFE",a.stats.lives,a.stats.deaths,a.stats.kills,a.stats.gold,
 a.stats.animalKills.wolf,a.stats.bestScore,a.stats.playtime)
out("MEMBER_PERIODS",clan.members[1].kills,clan.members[1].periods.week.key,
 clan.members[1].periods.week.kills,clan.members[1].periods.month.kills)
out("CLAN_PERIODS",clan.stats.kills,clan.stats.raidKills,clan.stats.periods.week.kills)
out("WEEKLY_TOP",store:weeklyTopClan())
local profile=store:profile(a)
out("PROFILE",profile.name,profile.clan.name,profile.periods.week.kills)
out("SAVES",saves)
