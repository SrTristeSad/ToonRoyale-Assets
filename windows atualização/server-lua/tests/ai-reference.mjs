// SPDX-License-Identifier: AGPL-3.0-only
// Executes original AI.update, AI.init and AiManager's unmodified type table.
// Deterministic PRNG and obstacle-free world's real getGridArrays interface.
import { AI } from "../../server/src/moomoo/modules/ai.js";
import { AiManager } from "../../server/src/moomoo/modules/aiManager.js";
import { config } from "../../server/src/moomoo/config.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";
const scenarios=[
 {name:"cow-idle",index:0,delta:100},
 {name:"pig-roam",index:1,delta:350,waitCount:0,moveCount:1500,targetDir:1.3},
 {name:"cow-wait",index:0,delta:800,waitCount:450},
 {name:"cow-new-heading",index:0,delta:1200,waitCount:200},
 {name:"cow-run",index:0,delta:120,waitCount:0,moveCount:500,runFrom:true},
 {name:"bull-target",index:2,delta:300,waitCount:50,player:{x:590,y:500}},
 {name:"bull-charge",index:2,delta:180,waitCount:0,moveCount:800,chargeTarget:true,player:{x:700,y:610}},
 {name:"bull-no-target",index:2,delta:160,waitCount:50,player:{x:2500,y:2500}},
 {name:"bull-repel",index:2,delta:150,waitCount:50,player:{x:600,y:500,skin:{bullRepel:true}}},
 {name:"wolf-shore",index:4,delta:350,y:7000,waitCount:0,moveCount:1500,targetDir:1.1},
 {name:"wolf-locked",index:4,delta:150,lockMove:true,xVel:0.7,yVel:0.25},
 {name:"wolf-bounds",index:4,delta:140,x:30,y:30,waitCount:0,moveCount:1400,targetDir:3.14},
 {name:"wolf-contact",index:4,delta:100,waitCount:0,moveCount:1200,chargeTarget:true,player:{x:565,y:500}},
 {name:"wolf-hit",index:4,delta:400,hitWait:200,player:{x:550,y:500}},
 {name:"boar-poison",index:9,delta:500,dmgOverTime:{dmg:4,time:2,doer:"poison"}},
 {name:"cow-spawn-delay",index:0,delta:1000,spawnCounter:2500},
 {name:"cow-spawn-end",index:0,delta:1000,spawnCounter:400},
 {name:"fixed-spawn",index:6,delta:1500,spawnCounter:400,x:950,y:850},
 {name:"treasure-stand",index:7,delta:700,waitCount:0,moveCount:200},
 {name:"boar-inactive",index:9,delta:600,active:false}
];
const fmt=n=>Number(n||0).toFixed(6);
const text=v=>v==null?"~":String(v);
const signatures=[{id:0,scale:72,speed:0.00095},{id:2,scale:78,speed:0.00094},{id:4,scale:84,speed:0.001},{id:6,scale:80,speed:0.0007},{id:7,scale:70,speed:0}];
const roster=[];
const sim={getGridArrays:()=>[],checkCollision(){throw Error("unexpected structure collision")}};
const server={send(id,name,sid){throw Error("unexpected event "+name+":"+sid)}};
const aiManager=new AiManager(roster,[],items,sim,config,UTILS,()=>{},server,{});
for(const p of signatures){
 const real=aiManager.aiTypes[p.id];
 for(const [key,value] of Object.entries(p))if(key!=="id"&&real[key]!==value)throw Error("source animal config drift "+p.id+"."+key);
}
for(const tc of scenarios){
 const events=[];
 const oldRandom=Math.random;
 let calls=0;
 const rng=mulberry32(400+tc.index);
 Math.random=()=>{calls++;return rng()};
 try{
   const actor=tc.player?{
     id:"enemy",sid:8,active:true,alive:true,isPlayer:true,
     x:tc.player.x,y:tc.player.y,scale:35,xVel:0,yVel:0,
     skin:tc.player.skin||null,powers:{invisible:0},
     changeHealth(amount){events.push("HP:"+fmt(amount));return true},
     canSee(){return true}
   }:null;
   const players=actor?[actor]:[];
   const objectManager={getGridArrays(){return []},
     checkCollision(){throw Error("unexpected collision")} };
   const server={send(id,name,...args){events.push("SEND:"+id+":"+name+":"+args.map(text).join(","))}};
   const ai=new AI(4,objectManager,players,items,UTILS,config,()=>{},server,{});
   const type=aiManager.aiTypes[tc.index];
   ai.init(tc.x??500,tc.y??500,tc.dir??0.2,tc.index,type);
   for(const [key,v] of Object.entries(tc)){
     if(!["name","index","delta","player"].includes(key)&&key!=="runFrom"&&key!=="chargeTarget")ai[key]=v;
   }
   if(tc.runFrom)ai.runFrom={x:600,y:510,active:true,alive:true,isPlayer:true};
   if(tc.chargeTarget)ai.chargeTarget=actor;
   if(tc.dmgOverTime){
     ai.changeHealth=(n,doer)=>{events.push("DOT:"+fmt(n)+":"+text(doer));ai.health+=n;return true}
   }
   for(let tick=1;tick<=3;tick++){
     ai.update(tc.delta);
     console.log([
      "AI",tc.name,tick,calls,ai.sid,ai.nameIndex,ai.active?1:0,
      fmt(ai.x),fmt(ai.y),fmt(ai.xVel),fmt(ai.yVel),fmt(ai.dir),
      fmt(ai.health),fmt(ai.waitCount),fmt(ai.moveCount),fmt(ai.hitWait),
      fmt(ai.targetDir),fmt(ai.spawnCounter),fmt(ai.dmgOverTime.dmg),
      fmt(ai.dmgOverTime.time),ai.chargeTarget?1:0,ai.runFrom?1:0,
      actor?fmt(actor.xVel):"-",actor?fmt(actor.yVel):"-",events.join(";")
     ].join("|"));
   }
 }finally{Math.random=oldRandom}
}
