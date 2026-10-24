// Compare REAL server/src/api/store.js AccountStore class against Lua output.
import fs from "node:fs";
const source=fs.readFileSync(new URL("../../server/src/api/store.js",import.meta.url),"utf8");
const marker="export class AccountStore";
const pos=source.indexOf(marker);
if(pos<0)throw Error("original AccountStore class not found");
const periods={day:()=>"2026-10-24",week:()=>"2026-10-19",month:()=>"2026-10"};
const defaults={friendNotifs:true,friendRequests:true,clanInvites:true,clanChat:true,whispers:true};
const Store=new Function("PERIOD_SPANS","DEFAULT_PREFS",
 "return ("+source.slice(pos).replace(/^export /,"").trim()+")")(periods,defaults);
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
