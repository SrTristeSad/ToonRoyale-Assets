// SPDX-License-Identifier: AGPL-3.0-only
// Full original AI.update (Crab King, index 11), including dive, target,
// secret boundary, telegraphs and player damage. Never rewrite Node mechanics.
import { AI } from "../../server/src/moomoo/modules/ai.js";
import { AI_TYPES } from "../../server/src/moomoo/modules/aiManager.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config } from "../../server/src/moomoo/config.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";
const cases=[
 {name:"idle",steps:[100,200,300]},
 {name:"walk",steps:[100,200,300],raider:true,raiderPos:[-2100,7200]},
 {name:"no-target",steps:[800,800,800],raider:true,raiderPos:[300,7200]},
 {name:"invisible",steps:[800,800,800],raider:true,invisible:true},
 {name:"force-slam",steps:[100,600,800],raider:true,forced:"slam"},
 {name:"force-claw",steps:[100,400,800],raider:true,forced:"claw"},
 {name:"force-geysers",steps:[100,600,1100],raider:true,forced:"geysers"},
 {name:"force-dive",steps:[100,600,2000],raider:true,forced:"dive"},
 {name:"dive-cycle",steps:[700,3600,1650],state:1,stateTimer:700,raider:true},
 {name:"submerged",steps:[100,400,1100],state:2,stateTimer:2400,raider:true},
 {name:"emerging",steps:[100,1650,100],state:3,stateTimer:1200,raider:true},
 {name:"slam-near",steps:[100,1300,100],raider:true,forced:"slam",raiderPos:[-2430,7200]},
 {name:"claw-multi",steps:[100,1200,100],raider:true,forced:"claw",extraRaider:true},
 {name:"geysers-multi",steps:[100,1700,100],raider:true,forced:"geysers",extraRaider:true},
 {name:"forced-wait",steps:[100,300,300],forced:"claw"},
 {name:"boundary",steps:[100,100,100],x:-1435,y:7200,xVel:1.5,yVel:0.4,raider:true}
];
const fmt=x=>Number(x??0).toFixed(6);
const val=v=>v==null?"~":typeof v==="number"?fmt(v):String(v);
const argumentsText=args=>args.map(val).join(",");
for(const tc of cases){
 const events=[];
 let count=0;
 const saved=Math.random;
 const rng=mulberry32(18000+cases.indexOf(tc));
 Math.random=()=>{count++;return rng()};
 try{
  const makeRaider=(id,x,y,invisible)=>({
    id,sid:id==="raider"?7:8,isPlayer:true,alive:true,
    x,y,scale:35,xVel:0,yVel:0,health:100,
    powers:{invisible:invisible?1:0},
    canSee(){return true},
    changeHealth(amount){this.health+=amount;events.push("HP:"+this.id+":"+fmt(amount));return false}
  });
  const players=[];
  if(tc.raider)players.push(makeRaider("raider",...(tc.raiderPos||[-2350,7200]),tc.invisible));
  if(tc.extraRaider)players.push(makeRaider("raider2",-2700,7480,false));
  const server={send(id,name,...args){events.push("SEND:"+id+":"+name+":"+argumentsText(args))}};
  const ai=new AI(5,{getGridArrays(){return []}},players,null,UTILS,config,
    ()=>{},server,{});
  ai.init(tc.x??-2500,tc.y??7200,0.2,11,AI_TYPES[11]);
  if(tc.state!==undefined){ai.state=tc.state;ai.stateTimer=tc.stateTimer;ai.submerged=(tc.state==1||tc.state==2)}
  if(tc.forced)ai.nextAttack=tc.forced;
  if(tc.xVel)ai.xVel=tc.xVel;
  if(tc.yVel)ai.yVel=tc.yVel;
  for(let tick=0;tick<3;tick++){
   ai.update(tc.steps[tick]);
   const a=ai.bossAttack;
   console.log([
     "CRAB",tc.name,tick+1,count,ai.state,ai.submerged?1:0,
     fmt(ai.stateTimer),fmt(ai.x),fmt(ai.y),fmt(ai.dir),
     fmt(ai.xVel),fmt(ai.yVel),fmt(ai.targetDir),
     fmt(ai.bossCooldown),a?fmt(a.time):"~",a?a.strikes.length:0,
     val(ai.nextAttack),players.length?fmt(players[0].health):"~",
     players.length?fmt(players[0].xVel):"~",
     players.length?fmt(players[0].yVel):"~",events.join(";")
   ].join("|"));
  }
 }finally{Math.random=saved}
}
