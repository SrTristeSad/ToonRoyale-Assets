// Compare REAL server/src/api/store.js AccountStore class against Lua output.
import fs from "node:fs";
const source=fs.readFileSync(new URL("../../server/src/api/store.js",import.meta.url),"utf8");
const marker="export class AccountStore";
const pos=source.indexOf(marker);
if(pos<0)throw Error("original AccountStore class not found");
const periods={day:()=>"2026-10-24",week:()=>"2026-10-19",month:()=>"2026-10"};
const defaults={friendNotifs:true,friendRequests:true,clanInvites:true,clanChat:true,whispers:true};
const objectIdStart=source.indexOf("function objectId(");
const objectIdEnd=source.indexOf("\n}",objectIdStart)+2;
if(objectIdStart<0||objectIdEnd<2)throw Error("original ObjectId source changed");
const {randomBytes}=await import("node:crypto");
const objectId=new Function("randomBytes","return ("+source.slice(objectIdStart,objectIdEnd)+")")(randomBytes);
const Store=new Function("PERIOD_SPANS","DEFAULT_PREFS","isRude","objectId",
 "SOCIAL_FIELDS","HANDLE_RE","fs","randomBytes","DEVICE_REJOIN_MS","CLAN_RE","CLAN_MAX_MEMBERS","emptyStats","DISCORD_CODE_MS",
 "return ("+source.slice(pos).replace(/^export /,"").trim()+")")(
 periods,defaults,value=>value==="badword",objectId,
 ["youtube","twitch","tiktok","x","discord"],/^[A-Za-z0-9._-]{1,32}$/,
 {writeFileSync(){ /* isolated differential fixture, no production writes */ }},randomBytes,900000,/^[A-Za-z0-9]{3,4}$/,80,()=>({kills:0,deaths:0,damage:0,healing:0,wood:0,food:0,stone:0,gold:0,animalDamage:0,animalKills:{},bestScore:0,maxKills:0,lives:0,playtime:0,periods:{}}),600000);
const id="abc123";
const base=()=>({kills:0,deaths:0,damage:0,healing:0,wood:0,food:0,stone:0,
 gold:0,animalDamage:0,animalKills:{},bestScore:0,maxKills:0,lives:0,playtime:0,periods:{}});
const a={id,name:"Tester",role:null,verdict:null,clan:"ABC",stats:base(),
 unlocks:{hats:[5],accs:[7],weapons:{"2":3}},prefs:{friendRequests:false}};
const clan={name:"ABC",members:[{id,role:"officer",kills:1,periods:{}}],
 requests:["someone"],invites:[],stats:{kills:0,raidKills:0,periods:{}}};
const store=Object.create(Store.prototype);
store.data={accounts:{[id]:a},names:{tester:id},emails:{"a@example.com":id},
 clans:{ABC:clan},social:{friends:{[id]:[{id:"friend"}]},requests:[
 {id:"r1",senderId:"friend",recipientId:id}]},legacyIds:{legacy:id}};
let saves=0;store.save=()=>{saves++};
const n=x=>x==null?"~":String(x);
const out=(label,...xs)=>console.log([label,...xs.map(n)].join("|"));
let p=store.prefsOf(a);
out("PREFS",p.friendNotifs,p.friendRequests,p.clanChat);
p=store.setPrefs(a,{friendRequests:true,clanInvites:false,role:true});
out("PREFS_EDIT",p.friendRequests,p.clanInvites,p.friendNotifs);
let opts=store.lookOptions(a);
out("LOOK_OPTIONS",opts.hats.join(","),opts.accs.join(","),opts.weapons[0],opts.weapons[2]);
let z=store.setLook(a,{hat:5,acc:7,weapon:2,variant:2,color:4});
out("LOOK_OK",z.status,z.body.look.hat,z.body.look.variant);
z=store.setLook(a,{hat:99,acc:7,weapon:2,variant:0,color:1});
out("LOOK_BAD",z.status,z.body.error);
let info=store.accountInfo(a);
out("ACCOUNT_INFO",info.name,info.clan.name,info.clan.role,info.clanNotes);
out("SELECTORS",store.accountByEmail(" A@example.com ")===a,
 store.accountById("legacy")===a,store.nameOwner(" TESTER ")===a);
out("SOCIAL",store.areFriends(id,"friend"),store.requestsFor(id).length,store.requestsFrom(id).length);
out("NAMES",store.namesFor([id,"legacy","nonexistent"])[id],store.namesFor(["legacy"]).legacy,store.namesFor(["nonexistent"]).nonexistent);
store.setRole("Tester","mod");
out("ROLE_VALID",a.role);
store.setRole("Tester","invalid");
out("ROLE_CLEAR",a.role);
store.setVerdict("Tester","shadow");
out("VERDICT_SHADOW",a.verdict);
store.setVerdict("Tester","clear");
out("VERDICT_CLEAR",a.verdict);
store.setClanShadow("ABC",true);out("CLAN_SHADOW",clan.shadowed);
store.setClanShadow("ABC",false);
store.recordUnlocks(a,{hat:5});
store.recordUnlocks(a,{weapon:2,variant:4});
out("UNLOCK",a.unlocks.hats.length,a.unlocks.weapons[2]);
const life={died:true,kills:4,damage:10,healing:2,wood:50,food:30,stone:20,
 gold:11,animalDamage:8,playtime:15000,score:60,
 animalKills:{wolf:2},bossKills:1,look:{hat:5,weapon:2}};
store.recordLife(a,life);
out("LIFE",a.stats.lives,a.stats.deaths,a.stats.kills,a.stats.gold,
 a.stats.animalKills.wolf,a.stats.bestScore,a.stats.playtime);
out("MEMBER_PERIODS",clan.members[0].kills,clan.members[0].periods.week.key,
 clan.members[0].periods.week.kills,clan.members[0].periods.month.kills);
out("CLAN_PERIODS",clan.stats.kills,clan.stats.raidKills,clan.stats.periods.week.kills);
out("WEEKLY_TOP",store.weeklyTopClan());
out("PROFILE",store.profile(a).name,store.profile(a).clan.name,
 store.profile(a).periods.week.kills);
out("SAVES",saves);

const creator={id:"creator",name:"Creator",clan:null,stats:base(),role:null};
const joiner={id:"joiner",name:"Joiner",clan:null,stats:base(),role:null};
store.data.accounts.creator=creator;
store.data.accounts.joiner=joiner;
store.data.names.creator="creator";
store.data.names.joiner="joiner";
const log=[];store.onClanEvent=(name,msg)=>log.push(name+":"+msg);
let cr=store.clanAction(creator,"create",{name:"DEF"});
out("CLAN_CREATE",cr.status,creator.clan,store.data.clans.DEF.members[0].role);
let req=store.clanAction(joiner,"request",{clan:"def"});
out("CLAN_REQUEST",req.status,store.data.clans.DEF.requests.length);
let cv=store.myClan(creator);
out("CLAN_MINE",cv.role,cv.requests.join(","),cv.clan.members[0].role);
let decide=store.clanAction(creator,"decide",{name:"Joiner",accept:true});
out("CLAN_DECIDE",decide.status,joiner.clan,store.data.clans.DEF.members.length);
let rank=store.clanAction(creator,"role",{name:"Joiner",role:"owner"});
out("CLAN_TRANSFER",rank.status,store.data.clans.DEF.members.map(x=>x.role).join(","));
let leave=store.clanAction(creator,"leave",{});
out("CLAN_LEAVE",leave.status,n(creator.clan),store.data.clans.DEF.members.length);
let disband=store.clanAction(joiner,"disband",{});
out("CLAN_DISBAND",disband.status,!!store.data.clans.DEF,n(joiner.clan));
out("CLAN_EVENTS",log.length,log[0],log[1]);

for(const who of ["one","two","three"]){
 store.data.accounts[who]={id:who,name:who,clan:null,stats:base()};
 store.data.names[who]=who;
}
let r1=store.createFriendRequest("one","two");
out("FRIEND_CREATE",r1.status,/^[a-f0-9]{24}$/.test(r1.request?.id),
 r1.request?.createdAt?.length===24 && r1.request.createdAt.endsWith("Z"));
out("FRIEND_PENDING",store.requestsFor("two").length,store.requestsFrom("one").length);
out("FRIEND_DUPLICATE",store.createFriendRequest("one","two").status);
out("FRIEND_ANSWER",!!store.answerFriendRequest("two",r1.request.id,true),
 store.friendsOf("one").length,store.friendsOf("two").length);
out("FRIEND_ALREADY",store.createFriendRequest("one","two").status);
let reverse=store.createFriendRequest("three","two");
out("FRIEND_REVERSE_PENDING",reverse.status);
let merged=store.createFriendRequest("two","three");
out("FRIEND_REVERSE_MERGE",merged.status,merged.friends,store.areFriends("two","three"));
let canceled=store.createFriendRequest("one","three");
out("FRIEND_CANCEL",store.cancelFriendRequest("one",canceled.request.id),
 store.cancelFriendRequest("one",canceled.request.id),store.requestsFor("three").length);
out("FRIEND_REMOVE",store.removeFriend("one","two"),
 store.removeFriend("one","two"),store.friendsOf("one").length);
out("FRIEND_MISSING",store.createFriendRequest("one","missing").status);

let socialResult=store.setSocials(a,{youtube:"Hi.Name",discord:" dev-id ",tiktok:""});
out("SOCIAL_SET",socialResult.status,socialResult.body.socials.youtube,
 socialResult.body.socials.discord,Object.keys(socialResult.body.socials).length);
socialResult=store.setSocials(a,{youtube:"bad?handle"});
out("SOCIAL_FORMAT",socialResult.status,socialResult.body.field,socialResult.body.why);
socialResult=store.setSocials(a,{twitch:"badword"});
out("SOCIAL_RUDE",socialResult.status,socialResult.body.field,socialResult.body.why);
out("SOCIAL_UNCHANGED",a.socials.youtube,a.socials.discord);

const legacy="1234567890abcdef",otherLegacy="oldkey";
const oldAccount={id:legacy,createdAt:1792864800000,name:"Legacy"};
const otherAccount={id:otherLegacy,createdAt:1792864800000,name:"Other"};
const oldClan={name:"LEG",members:[{id:legacy}],past:[{id:otherLegacy}],
 invites:[{id:legacy,by:otherLegacy}],requests:[otherLegacy]};
const legacyStore=Object.create(Store.prototype);
legacyStore.file="never-written.json";
legacyStore.data={accounts:{[legacy]:oldAccount,[otherLegacy]:otherAccount},
 names:{legacy,other:otherLegacy},emails:{"legacy@example.com":legacy},
 clans:{LEG:oldClan},legacyIds:{},social:{
 friends:{[legacy]:[{id:otherLegacy}],[otherLegacy]:[{id:legacy}]},
 requests:[{senderId:legacy,recipientId:otherLegacy}]}};
const remapped=legacyStore.migrateIds();
const aId=remapped[legacy],bId=remapped[otherLegacy];
out("MIGRATE",/^[a-f0-9]{24}$/.test(aId),aId.endsWith(legacy),
 /^[a-f0-9]{24}$/.test(bId),Object.keys(legacyStore.data.accounts).length);
out("MIGRATE_RELATIONS",
 legacyStore.data.names.legacy===aId,legacyStore.data.emails["legacy@example.com"]===aId,
 oldClan.members[0].id===aId,oldClan.past[0].id===bId,
 oldClan.invites[0].by===bId,oldClan.requests[0]===bId);
out("MIGRATE_SOCIAL",
 legacyStore.data.social.friends[aId][0].id===bId,
 legacyStore.data.social.requests[0].recipientId===bId,
 legacyStore.accountById(otherLegacy)===otherAccount);

const ticketStore=Object.create(Store.prototype);
ticketStore.data={accounts:{[id]:a}};
ticketStore.tickets=new Map();
ticketStore.devices=new Map();
const trustedDid="f".repeat(16);
const t1=ticketStore.issueTicket({account:a,did:trustedDid,server:"LC"});
out("TICKET_ISSUE",/^[a-f0-9]{36}$/.test(t1.ticket),
 t1.did===trustedDid,ticketStore.recentDevice(t1.did));
const admission=ticketStore.consumeTicket(t1.ticket,60000);
out("TICKET_CONSUME",admission.account===a,admission.did===trustedDid,
 admission.server==="LC",ticketStore.consumeTicket(t1.ticket,60000)===null);
const t2=ticketStore.issueTicket({account:null,did:"invalid",server:null});
ticketStore.tickets.get(t2.ticket).at-=900001;
out("TICKET_EXPIRED",/^[a-f0-9]{24}$/.test(t2.did),
 ticketStore.consumeTicket(t2.ticket,60000)===null);
ticketStore.devices.set(trustedDid,Date.now()-900001);
out("TICKET_DEVICE_EXPIRED",ticketStore.recentDevice(trustedDid));

const rankedStats=(total,weekly)=>({...base(),kills:total,
 periods:{week:{key:"2026-10-19",kills:weekly,bestScore:30},
 day:{key:"2026-10-24",kills:Math.floor(weekly/2),bestScore:30},
 month:{key:"2026-10",kills:weekly,bestScore:30}}});
const rankedAccounts={
 "id-a":{id:"id-a",name:"A",stats:rankedStats(25,12),clan:"ABC"},
 "id-b":{id:"id-b",name:"B",stats:rankedStats(20,7),verdict:"shadow"},
 "id-c":{id:"id-c",name:"C",stats:rankedStats(15,4)},
 "id-d":{id:"id-d",name:"D",stats:rankedStats(10,2)}
};
const rankedClans={
 ABC:{name:"ABC",stats:rankedStats(10,9),members:[{id:"id-a"}]},
 DEF:{name:"DEF",stats:rankedStats(8,5),members:[{id:"id-b"}],shadowed:true}
};
const leaderboard=Object.create(Store.prototype);
leaderboard.data={accounts:rankedAccounts,clans:rankedClans};
for(const span of ["all","day","week","month"]){
 const result=leaderboard.top(span);
 out("TOP_"+span.toUpperCase(),
 result.players.map(p=>p.name+":"+p.kills+":"+(p.shadowed?1:0)).join(","),
 result.clans.map(p=>p.name+":"+p.kills+":"+(p.shadowed?1:0)).join(","));
}
const crowns=leaderboard.weeklyCrowns();
out("WEEKLY_CROWNS",crowns["id-a"],crowns["id-b"],crowns["id-c"],crowns["id-d"]);

const authStore=Object.create(Store.prototype);
authStore.data={accounts:{},emails:{},names:{},clans:{},social:{friends:{},requests:[]},legacyIds:{}};
authStore.loginFlows=new Map();
authStore.discordCodes=new Map();
let authSaves=0;authStore.save=()=>{authSaves++};
out("ACCOUNT_EMPTY",authStore.accountForEmail("")===null,
 authStore.accountForEmail("x".repeat(121))===null);
const created=authStore.accountForEmail(" A@EXAMPLE.COM ");
out("ACCOUNT_CREATE",/^[a-f0-9]{24}$/.test(created.id),created.email,
 created.name===null,created.stats.lives,authSaves);
out("ACCOUNT_REUSE",authStore.accountForEmail("a@example.com")===created,authSaves);
const loginFlow=authStore.startLogin("a@example.com");
out("LOGIN_START",/^[a-f0-9]{24}$/.test(loginFlow),authStore.loginFlows.has(loginFlow));
out("LOGIN_FINISH",authStore.finishLogin(loginFlow)===created,
 authStore.finishLogin(loginFlow)===null);
const discord=authStore.createDiscordCode("D".repeat(40));
out("DISCORD_CODE",/^[a-f0-9]{24}$/.test(discord),
 authStore.discordCode(discord).discord.length);
out("DISCORD_LINK",authStore.linkDiscord(created,discord).body.error);
created.name="Permanent";
const discordResult=authStore.linkDiscord(created,discord);
out("DISCORD_LINK_OK",discordResult.status,discordResult.body.discord.length,
 authStore.discordCode(discord)===null,created.discord.name.length);
const expired=authStore.createDiscordCode("expired");
authStore.discordCodes.get(expired).at-=600001;
out("DISCORD_EXPIRE",authStore.discordCode(expired)===null);
