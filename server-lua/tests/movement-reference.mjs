// SPDX-License-Identifier: AGPL-3.0-only
// Differential movement test: execute the ORIGINAL Player.update movement lines
// directly from the Node source, not an independently rewritten JS simulation.
import fs from "node:fs";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config } from "../../server/src/moomoo/config.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { TAIL, EFFECT, hasTail, snowFactor, secretDistance, inSecretPool } from "../../server/src/moomoo/modules/effects.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";

const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const start=source.indexOf("            // SLOWER:");
const end=source.indexOf("            // USE WEAPON OR TOOL:",start);
if(start<0||end<0)throw Error("Player.update movement marker changed");
const portion=source.slice(start,end);
const move=new Function("delta","objectManager","players","items","config","UTILS","hasTail","TAIL","EFFECT","snowFactor","inSecretPool","nowMs",
  "const mathCOS=Math.cos,mathSIN=Math.sin,mathSQRT=Math.sqrt,mathPOW=Math.pow; const Date={now:()=>nowMs};\n"+portion);
const bs=source.indexOf("this.keepInWorld = function (prevX, prevY) {");
const be=source.indexOf("\n        };",bs);
if(bs<0||be<0)throw Error("Original keepInWorld marker changed");
const keep=new Function("config","secretDistance","return "+
  source.slice(bs,be+11).replace(/^this.keepInWorld = /,""))(config,secretDistance);
const scenarios=[
 ["walk",33,{}],["coast",95,{moveDir:null,xVel:0.29,yVel:-0.14}],
 ["diagonal",111.111,{moveDir:2.35}],["slow",110,{slowMult:0.33}],
 ["snow",100,{y:1000}],["snow-skin",120,{y:1000,skin:{coldM:true,spdMult:1.2}}],
 ["snowball",111,{y:1000,tail:{id:12}}],["winter",111,{y:1000,tail:{id:6}}],
 ["river",111,{x:7200,y:7200}],["river-imm",111,{x:7200,y:7200,skin:{watrImm:true}}],
 ["secret-pool",111,{x:-2350,y:7200}],["secret-imm",111,{x:-2350,y:7200,skin:{watrImm:true}}],
 ["build",80,{buildIndex:0}],["dash",120,{tail:{id:5}}],
 ["super",110,{superUntil:50000}],["power",110,{powers:{speed:2.1}}],
 ["locked",111,{lockMove:true,xVel:0.2,yVel:0.1}],["northwall",111,{x:600,y:35,moveDir:-Math.PI/2}],
 ["eastwall",111,{x:14350,y:7300,moveDir:0}],["westwall",111,{x:36,y:9200,moveDir:Math.PI}],
 ["rock",80,{x:500,y:500,objects:[{x:550,y:500,scale:22,type:2}]}],
 ["trap",80,{x:500,y:500,objects:[{x:545,y:500,scale:25,type:2,ignoreCollision:true,trap:true,zIndex:2}]}],
 ["boost",80,{x:500,y:500,objects:[{x:545,y:500,scale:25,type:2,ignoreCollision:true,boostSpeed:0.012,dir:1}]}],
 ["heal",80,{x:500,y:500,objects:[{x:545,y:500,scale:25,type:2,ignoreCollision:true,healCol:8}]}],
 ["enemy",100,{x:500,y:500,second:{x:555,y:500}}],
 ["fast",950,{x:750,y:750,xVel:0.8,moveDir:0.3}],
 ["zero",0,{x:500,y:500}]
];
const fmt=n=>Number(n||0).toFixed(7);
function report(name,tick,p,other,obj) {
 console.log(["MOVE",name,tick,fmt(p.x),fmt(p.y),fmt(p.xVel),fmt(p.yVel),
 fmt(p.slowMult),fmt(p.noMovTimer),p.lockMove?1:0,p.zIndex,p.healCol||0,
 p.health,p.alive?1:0,other?fmt(other.x):"-",other?fmt(other.y):"-",
 obj?(obj.hideFromEnemy===false?1:0):"-"].join("|"));
}
for (const [name,dt,override] of scenarios) {
 const p={
   sid:1,id:"player1",x:500,y:500,xVel:0,yVel:0,scale:config.playerScale,
   speed:config.playerSpeed,dir:0,moveDir:0.35,skin:null,tail:null,
   powers:{speed:1},slowMult:1,noMovTimer:0,
   buildIndex:-1,weaponIndex:0,lockMove:false,zIndex:0,
   alive:true,health:100,healCol:0,team:null,dmgOverTime:{},superUntil:0,
   changeHealth(amount){this.health+=amount;this.alive=this.health>0;return !this.alive},
   ...Object.fromEntries(Object.entries(override).filter(([k])=>k!=="objects"&&k!=="second"))
 };
 p.keepInWorld=keep;
 const others=[p];
 let second=null;
 if (override.second) {
   second={sid:2,x:override.second.x,y:override.second.y,scale:35,
     alive:true,isPlayer:true,team:null,xVel:0,yVel:0};
   others.push(second);
 }
 const list=[];
 const mgr=new ObjectManager(GameObject,list,UTILS,config,others,{broadcast(){},send(){}});
 let obj=null;
 for(const [i,o] of (override.objects||[]).entries()){
   const data={};
   for(const key of ["ignoreCollision","trap","boostSpeed","healCol","zIndex","dmg","pDmg"])
     if(o[key]!==undefined)data[key]=o[key];
   mgr.add(i,o.x,o.y,o.dir||0,o.scale,o.type,data,false,null);
   obj=list[i];
 }
 const saved=Math.random;
 Math.random=mulberry32(2323);
 try {
   for(let step=1;step<=3;step++){
     move.call(p,dt,mgr,others,items,config,UTILS,hasTail,TAIL,EFFECT,snowFactor,inSecretPool,10000);
     report(name,step,p,second,obj);
   }
 } finally {Math.random=saved;}
}
