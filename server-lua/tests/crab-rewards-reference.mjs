// SPDX-License-Identifier: AGPL-3.0-only
// Execute *actual* Game.onAnimalKilled from original server.js with
// original store ANIMAL_KEYS/BOSS_KEYS and original HAT.CRAB_SHELL.
import fs from "node:fs";
const src=fs.readFileSync(new URL("../../server/src/moomoo/server.js",import.meta.url),"utf8");
const store=fs.readFileSync(new URL("../../server/src/api/store.js",import.meta.url),"utf8");
const effects=fs.readFileSync(new URL("../../server/src/moomoo/modules/effects.js",import.meta.url),"utf8");
const parseArray=name=>{
 const match=store.match(new RegExp("export const "+name+" = (\\[[^;]+\\]);"));
 if(!match)throw Error("Original "+name+" changed");
 return JSON.parse(match[1]);
};
if(!effects.includes("CRAB_SHELL: 61"))throw Error("Original Crab Shell ID changed");
const start=src.indexOf("    onAnimalKilled(ai, doer) {");
const end=src.indexOf("\n    }",start);
if(start<0||end<0)throw Error("Original Game.onAnimalKilled changed");
const fn=new Function("ANIMAL_KEYS","BOSS_KEYS","CRAB_KING","HAT",
 "return ({"+src.slice(start,end+6)+"}).onAnimalKilled")(
 parseArray("ANIMAL_KEYS"),parseArray("BOSS_KEYS"),11,{CRAB_SHELL:61});
const cases=[
 {name:"solo",contributors:[]},
 {name:"helpers",contributors:[{sid:2,damage:25000},{sid:3,damage:35000}]},
 {name:"threshold",contributors:[{sid:2,damage:23999},{sid:3,damage:24000}]},
 {name:"dead",contributors:[{sid:2,damage:50000,alive:false}]},
 {name:"same-killer",contributors:[{sid:1,damage:25000},{sid:3,damage:25000}]},
 {name:"previous-shell",contributors:[{sid:2,damage:25000}],preowned:[1,2]},
 {name:"no-stat",contributors:[{sid:2,damage:25000}],noStats:[1,2]},
 {name:"no-account",contributors:[{sid:2,damage:25000}],noStats:[3]},
 {name:"other-animal",index:6,contributors:[{sid:2,damage:50000}]},
 {name:"cow",index:0,contributors:[{sid:2,damage:50000}]},
 {name:"not-player",notPlayer:true,contributors:[]},
 {name:"no-killer",noKiller:true,contributors:[]}
];
for(const tc of cases){
 const events=[],crabKillers=new Set();
 const makePlayer=(sid)=>{
   const name=sid===1?"Hero":"Helper"+sid;
   return {
     sid,id:"p"+sid,isPlayer:true,alive:true,
     skins:tc.preowned?.includes(sid)?{61:1}:{},
     lifeStats:tc.noStats?.includes(sid)?null:{
       animals:0,bosses:0,bossKills:0,animalKills:{}
     },
     shownName(){return name},
     send(type,...args){events.push("HAT:"+sid+":"+type+":"+args.join(","))}
   };
 };
 const killer=makePlayer(1);
 if(tc.notPlayer)killer.isPlayer=false;
 const order=new Map([[1,killer]]);
 const damageBy=new Map();
 for(const item of tc.contributors){
   let p=order.get(item.sid);
   if(!p){p=makePlayer(item.sid);order.set(item.sid,p);}
   if(item.alive===false)p.alive=false;
   damageBy.set(p,item.damage);
 }
 const ai={
   index:tc.index??11,damageBy,maxHealth:480000
 };
 const game={
  crabKillers, key:"LC",
  server:{broadcast(name,...args){events.push("BROADCAST:"+name+":"+args.join(","))}},
  hooks:{event(data){events.push("EVENT:"+data.kind+":"+data.server+":"+data.by)}}
 };
 fn.call(game,ai,tc.noKiller?null:killer);
 const people=[...order.values()].map(p=>{
  const s=p.lifeStats;
  return [p.sid,s?s.animals:"-",s?s.bosses:"-",s?s.bossKills:"-",
    s?JSON.stringify(s.animalKills):"-",p.skins[61]||0,
    crabKillers.has(p.sid)?1:0].join(",");
 }).join(";");
 console.log("CRABREWARD|"+tc.name+"|"+people+"|"+events.join(";"));
}
