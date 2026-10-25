// SPDX-License-Identifier: AGPL-3.0-only
// Runs the unchanged original AI.changeHealth using real AI.init and AI_TYPES.
import { AI } from "../../server/src/moomoo/modules/ai.js";
import { AI_TYPES } from "../../server/src/moomoo/modules/aiManager.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config } from "../../server/src/moomoo/config.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";
const cases=[
 {id:"cow-hit",index:0,amount:-25},
 {id:"cow-heal",index:0,amount:45},
 {id:"cow-kill",index:0,amount:-600},
 {id:"cow-kill-no-doer",index:0,amount:-600,noDoer:true},
 {id:"pig-reward",index:1,amount:-900,overrideReward:850,overrideDrop:3},
 {id:"bull-chase",index:2,amount:-50,runFrom:true},
 {id:"wolf-run",index:4,amount:-25,runFrom:true},
 {id:"wolf-no-run",index:4,amount:-25,runFrom:true,dontRun:true},
 {id:"yeti-scare",index:10,amount:-40,runFrom:true,hitScare:1},
 {id:"moostafa-hit",index:6,amount:-90,runFrom:true},
 {id:"fixed-respawn",index:6,amount:-20000},
 {id:"delayed-respawn",index:8,amount:-9000},
 {id:"boss-dive",index:11,amount:-600000,submerged:true},
 {id:"boss-kill",index:11,amount:-600000},
 {id:"admin-despawn",index:0,amount:-900,despawnOnDeath:true},
 {id:"custom-range",index:0,amount:-1000,minSpawnRange:0.2,maxSpawnRange:0.3},
 {id:"no-damage",index:0,amount:10,active:false},
 {id:"silent-hit",index:0,amount:-30,notVisible:true},
 {id:"heal-run",index:0,amount:10,runFrom:true}
];
const fmt=v=>Number(v??0).toFixed(6);
for(const sc of cases){
 const events=[];
 let randomCalls=0;
 const saved=Math.random;
 const random=mulberry32(20260+sc.index);
 Math.random=()=>{randomCalls++;return random()};
 try{
   const doer={
     id:"killer",isPlayer:true,alive:true,
     points:0,wood:0,food:0,stone:0,
     lifeStats:{animalDamage:0},
     canSee(){return !sc.notVisible},
     addResource(type,amount){
       events.push("RESOURCE:"+type+":"+fmt(amount));
       this[config.resourceTypes[type]]+=amount;
     }
   };
   const hooks={
     onKill(ai,who){events.push("KILL:"+(who?"doer":"none")+":"+ai.index)},
     killScore(ai){events.push("REWARD:"+ai.killScore);
       return sc.overrideReward??ai.killScore},
     dropAmount(ai,killer,n){
       events.push("DROP:"+fmt(n));
       return n*(sc.overrideDrop??1)
     },
     respawnAt(ai){
       events.push("RESPAWN:"+ai.index);
       return {x:-2500,y:7200}
     }
   };
   const server={send(id,name,...args){
     events.push("SEND:"+id+":"+name+":"+args.map(fmt).join(","))
   }};
   const a=new AI(3,{getGridArrays(){return []}},[doer],null,UTILS,config,
     (who,score)=>events.push("SCORE:"+fmt(score)),
     server,hooks);
   a.init(500,520,0.25,sc.index,AI_TYPES[sc.index]);
   for(const k of ["submerged","despawnOnDeath","dontRun","hitScare",
     "minSpawnRange","maxSpawnRange","active"]){
     if(sc[k]!==undefined)a[k]=sc[k]
   }
   if(sc.index===6){a.startX=500;a.startY=520;}
   const source= sc.noDoer?null:doer;
   const result=a.changeHealth(sc.amount,source,sc.runFrom?doer:null);
   const damage=a.damageBy.get(doer)||0;
   console.log(["ANIMALHEALTH",sc.id,result?"1":"0",randomCalls,
     a.active?"1":"0",a.alive?"1":"0",fmt(a.x),fmt(a.y),
     fmt(a.health),fmt(a.spawnCounter),fmt(a.waitCount),fmt(a.moveCount),
     fmt(a.hitWait),a.runFrom?"1":"0",a.chargeTarget?"1":"0",
     a.state,a.submerged?"1":"0",fmt(damage),
     fmt(doer.lifeStats.animalDamage),fmt(doer.food),fmt(doer.points),
     events.join(";")].join("|"));
 } finally{Math.random=saved}
}
