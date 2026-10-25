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
 nowMs=function()return 1792864800000 end,
 isRude=function(value) return value=="badword" end,
 randomBytes=function(n) assert(n==8); return "abcdefgh" end})
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

local creator={id="creator",name="Creator",clan=Json.null,stats=base(),role=Json.null}
local joiner={id="joiner",name="Joiner",clan=Json.null,stats=base(),role=Json.null}
store.data.accounts.creator=creator
store.data.accounts.joiner=joiner
store.data.names.creator="creator"
store.data.names.joiner="joiner"
local log={}
store.onClanEvent=function(name,msg)log[#log+1]=name..":"..msg end
local cr=store:clanAction(creator,"create",{name="DEF"})
out("CLAN_CREATE",cr.status,creator.clan,store.data.clans.DEF.members[1].role)
local req=store:clanAction(joiner,"request",{clan="def"})
out("CLAN_REQUEST",req.status,#store.data.clans.DEF.requests)
local cv=store:myClan(creator)
out("CLAN_MINE",cv.role,table.concat(cv.requests,","),cv.clan.members[1].role)
local decide=store:clanAction(creator,"decide",{name="Joiner",accept=true})
out("CLAN_DECIDE",decide.status,joiner.clan,#store.data.clans.DEF.members)
local rank=store:clanAction(creator,"role",{name="Joiner",role="owner"})
local roles={}
for _,m in ipairs(store.data.clans.DEF.members) do roles[#roles+1]=m.role end
out("CLAN_TRANSFER",rank.status,table.concat(roles,","))
local leave=store:clanAction(creator,"leave",{})
out("CLAN_LEAVE",leave.status,creator.clan,#store.data.clans.DEF.members)
local disband=store:clanAction(joiner,"disband",{})
out("CLAN_DISBAND",disband.status,store.data.clans.DEF~=nil,joiner.clan)
out("CLAN_EVENTS",#log,log[1],log[2])

for _,who in ipairs({"one","two","three"}) do
 store.data.accounts[who]={id=who,name=who,clan=Json.null,stats=base()}
 store.data.names[who]=who
end
local r1=store:createFriendRequest("one","two")
out("FRIEND_CREATE",r1.status,
 #r1.request.id==24 and r1.request.id:match("^[a-f0-9]+$")~=nil,
 #r1.request.createdAt==24 and r1.request.createdAt:sub(-1)=="Z")
out("FRIEND_PENDING",#store:requestsFor("two"),#store:requestsFrom("one"))
out("FRIEND_DUPLICATE",store:createFriendRequest("one","two").status)
out("FRIEND_ANSWER",store:answerFriendRequest("two",r1.request.id,true)~=false,
 #store:friendsOf("one"),#store:friendsOf("two"))
out("FRIEND_ALREADY",store:createFriendRequest("one","two").status)
local reverse=store:createFriendRequest("three","two")
out("FRIEND_REVERSE_PENDING",reverse.status)
local merged=store:createFriendRequest("two","three")
out("FRIEND_REVERSE_MERGE",merged.status,merged.friends,store:areFriends("two","three"))
local canceled=store:createFriendRequest("one","three")
out("FRIEND_CANCEL",store:cancelFriendRequest("one",canceled.request.id),
 store:cancelFriendRequest("one",canceled.request.id),#store:requestsFor("three"))
out("FRIEND_REMOVE",store:removeFriend("one","two"),
 store:removeFriend("one","two"),#store:friendsOf("one"))
out("FRIEND_MISSING",store:createFriendRequest("one","missing").status)

local socialResult=store:setSocials(a,{youtube="Hi.Name",discord=" dev-id ",tiktok=""})
local num=0
for _ in pairs(socialResult.body.socials) do num=num+1 end
out("SOCIAL_SET",socialResult.status,socialResult.body.socials.youtube,
 socialResult.body.socials.discord,num)
socialResult=store:setSocials(a,{youtube="bad?handle"})
out("SOCIAL_FORMAT",socialResult.status,socialResult.body.field,socialResult.body.why)
socialResult=store:setSocials(a,{twitch="badword"})
out("SOCIAL_RUDE",socialResult.status,socialResult.body.field,socialResult.body.why)
out("SOCIAL_UNCHANGED",a.socials.youtube,a.socials.discord)

local legacy,otherLegacy="1234567890abcdef","oldkey"
local oldAccount={id=legacy,createdAt=1792864800000,name="Legacy"}
local otherAccount={id=otherLegacy,createdAt=1792864800000,name="Other"}
local oldClan={name="LEG",members={{id=legacy}},past={{id=otherLegacy}},
 invites={{id=legacy,by=otherLegacy}},requests={otherLegacy}}
local legacyStore=Store.open("server-lua/tests/.does-not-exist.json",{
 nowMs=function()return 1792864800000 end,
 randomBytes=function(n)assert(n==8);return "abcdefgh" end})
legacyStore.save=function()end
legacyStore.data={
 accounts={[legacy]=oldAccount,[otherLegacy]=otherAccount},
 names={legacy=legacy,other=otherLegacy},
 emails={["legacy@example.com"]=legacy},clans={LEG=oldClan},
 legacyIds={},social={
 friends={[legacy]={{id=otherLegacy}},[otherLegacy]={{id=legacy}}},
 requests={{senderId=legacy,recipientId=otherLegacy}}}}
local remapped=legacyStore:migrateIds()
local aId,bId=remapped[legacy],remapped[otherLegacy]
local count=0
for _ in pairs(legacyStore.data.accounts) do count=count+1 end
out("MIGRATE",#aId==24 and aId:match("^[a-f0-9]+$")~=nil,
 aId:sub(-#legacy)==legacy,
 #bId==24 and bId:match("^[a-f0-9]+$")~=nil,count)
out("MIGRATE_RELATIONS",
 legacyStore.data.names.legacy==aId,
 legacyStore.data.emails["legacy@example.com"]==aId,
 oldClan.members[1].id==aId,oldClan.past[1].id==bId,
 oldClan.invites[1].by==bId,oldClan.requests[1]==bId)
out("MIGRATE_SOCIAL",
 legacyStore.data.social.friends[aId][1].id==bId,
 legacyStore.data.social.requests[1].recipientId==bId,
 legacyStore:accountById(otherLegacy)==otherAccount)

local ticketNow=1792864800000
local ticketStore=Store.open("server-lua/tests/.does-not-exist.json",{
 nowMs=function()return ticketNow end,
 randomBytes=function(n)return string.rep("a",n) end})
ticketStore.data={accounts={[id]=a}}
local trustedDid=string.rep("f",16)
local t1=ticketStore:issueTicket({account=a,did=trustedDid,server="LC"})
out("TICKET_ISSUE",#t1.ticket==36 and t1.ticket:match("^[a-f0-9]+$")~=nil,
 t1.did==trustedDid,ticketStore:recentDevice(t1.did))
local admission=ticketStore:consumeTicket(t1.ticket,60000)
out("TICKET_CONSUME",admission.account==a,admission.did==trustedDid,
 admission.server=="LC",ticketStore:consumeTicket(t1.ticket,60000)==Json.null)
local t2=ticketStore:issueTicket({account=Json.null,did="invalid",server=Json.null})
ticketStore.tickets[t2.ticket].at=ticketStore.tickets[t2.ticket].at-900001
out("TICKET_EXPIRED",#t2.did==24 and t2.did:match("^[a-f0-9]+$")~=nil,
 ticketStore:consumeTicket(t2.ticket,60000)==Json.null)
ticketStore.devices[trustedDid]=ticketNow-900001
out("TICKET_DEVICE_EXPIRED",ticketStore:recentDevice(trustedDid))

local function rankedStats(total,weekly)
 local stats=base()
 stats.kills=total
 stats.periods={
  week={key="2026-10-19",kills=weekly,bestScore=30},
  day={key="2026-10-24",kills=math.floor(weekly/2),bestScore=30},
  month={key="2026-10",kills=weekly,bestScore=30}
 }
 return stats
end
local rankedAccounts={
 ["id-a"]={id="id-a",name="A",stats=rankedStats(25,12),clan="ABC"},
 ["id-b"]={id="id-b",name="B",stats=rankedStats(20,7),verdict="shadow"},
 ["id-c"]={id="id-c",name="C",stats=rankedStats(15,4)},
 ["id-d"]={id="id-d",name="D",stats=rankedStats(10,2)}
}
local rankedClans={
 ABC={name="ABC",stats=rankedStats(10,9),members={{id="id-a"}}},
 DEF={name="DEF",stats=rankedStats(8,5),members={{id="id-b"}},shadowed=true}
}
local leaderboard=Store.open("server-lua/tests/.does-not-exist.json",{
 nowMs=function()return 1792864800000 end})
leaderboard.data={accounts=rankedAccounts,clans=rankedClans}
for _,span in ipairs({"all","day","week","month"}) do
 local result=leaderboard:top(span)
 local function summary(rows)
  local names={}
  for _,p in ipairs(rows) do
   names[#names+1]=p.name..":"..p.kills..":"..(p.shadowed and "1" or "0")
  end
  return table.concat(names,",")
 end
 out("TOP_"..span:upper(),summary(result.players),summary(result.clans))
end
local crowns=leaderboard:weeklyCrowns()
out("WEEKLY_CROWNS",crowns["id-a"],crowns["id-b"],crowns["id-c"],crowns["id-d"])

local authStore=Store.open("server-lua/tests/.does-not-exist.json",{
 nowMs=function()return 1792864800000 end,
 randomBytes=function(n)return string.rep("a",n) end})
authStore.data={accounts={},emails={},names={},clans={},
 social={friends={},requests={}},legacyIds={}}
local authSaves=0
authStore.save=function()authSaves=authSaves+1 end
out("ACCOUNT_EMPTY",authStore:accountForEmail("")==Json.null,
 authStore:accountForEmail(string.rep("x",121))==Json.null)
local created=authStore:accountForEmail(" A@EXAMPLE.COM ")
out("ACCOUNT_CREATE",#created.id==24 and created.id:match("^[a-f0-9]+$")~=nil,
 created.email,created.name==Json.null,created.stats.lives,authSaves)
out("ACCOUNT_REUSE",authStore:accountForEmail("a@example.com")==created,authSaves)
local loginFlow=authStore:startLogin("a@example.com")
out("LOGIN_START",#loginFlow==24 and loginFlow:match("^[a-f0-9]+$")~=nil,
 authStore.loginFlows[loginFlow]~=nil)
out("LOGIN_FINISH",authStore:finishLogin(loginFlow)==created,
 authStore:finishLogin(loginFlow)==Json.null)
local discord=authStore:createDiscordCode(string.rep("D",40))
out("DISCORD_CODE",#discord==24 and discord:match("^[a-f0-9]+$")~=nil,
 #authStore:discordCode(discord).discord)
out("DISCORD_LINK",authStore:linkDiscord(created,discord).body.error)
created.name="Permanent"
local discordResult=authStore:linkDiscord(created,discord)
out("DISCORD_LINK_OK",discordResult.status,#discordResult.body.discord,
 authStore:discordCode(discord)==Json.null,#created.discord.name)
local expired=authStore:createDiscordCode("expired")
authStore.discordCodes[expired].at=authStore.discordCodes[expired].at-600001
out("DISCORD_EXPIRE",authStore:discordCode(expired)==Json.null)

local claim=authStore:accountForEmail("claim@example.com")
local nameResult=authStore:claimName(claim,"ab")
out("CLAIM_SHORT",nameResult.status,nameResult.body.error)
nameResult=authStore:claimName(claim,"Bad+Name")
out("CLAIM_CENSORED",nameResult.status,nameResult.body.error,nameResult.body.shown)
nameResult=authStore:claimName(claim,"qweir")
out("CLAIM_UNCLEAN",nameResult.status,nameResult.body.error)
nameResult=authStore:claimName(claim,"PlayerOne")
out("CLAIM_VALID",nameResult.status,nameResult.body.name,
 authStore:nameOwner("playerone")==claim)
local another=authStore:accountForEmail("another@example.com")
nameResult=authStore:claimName(another,"playerone")
out("CLAIM_TAKEN",nameResult.status,nameResult.body.error)
nameResult=authStore:claimName(claim,"OtherName")
out("CLAIM_IMMUTABLE",nameResult.status,nameResult.body.name)
