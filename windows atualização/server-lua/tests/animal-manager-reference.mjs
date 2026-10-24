// SPDX-License-Identifier: AGPL-3.0-only
// Executes the original exported AI_TYPES, AiManager.spawn, Game.animalPosition
// and Game.ensureAnimals. The Lua fixture is compared line for line.
import fs from "node:fs";
import { AI_TYPES,AiManager } from "../../server/src/moomoo/modules/aiManager.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config as cfg } from "../../server/src/moomoo/config.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";
function normalized(value){
 if(Array.isArray(value))return "["+value.map(normalized).join(",")+"]";
 return String(value);
}
for(let i=0;i<AI_TYPES.length;i++){
 const obj=AI_TYPES[i];
 const fields=Object.keys(obj).sort().map(k=>k+"="+normalized(obj[k]));
 console.log("TYPE|"+i+"|"+fields.join("|"));
}
const src=fs.readFileSync(new URL("../../server/src/moomoo/server.js",import.meta.url),"utf8");
function method(name){
 const at=src.indexOf("    "+name+"("),end=src.indexOf("\n    }",at);
 if(at<0||end<0)throw Error("Game."+name+" changed");
 return src.slice(at,end+6).trim();
}
const functions=new Function("config","UTILS","CRAB_KING",
 "return ({"+["animalPosition","ensureAnimals"].map(method).join(",\n")+"})")(
  {...cfg,server:{...cfg.server,animalSpawnPlan:[
   {index:0,desired:2},{index:2,desired:1},
   {index:4,desired:1,area:"snow"},{index:5,desired:1,area:"river"},
   {index:6,desired:1,positions:[{xRatio:0.5,yRatio:0.93}]},
   {index:11,desired:1,area:"secret",positions:[{x:-2500,y:7200}]}
  ]}},UTILS,11);
const testCfg={...cfg,server:{...cfg.server,animalSpawnPlan:[
   {index:0,desired:2},{index:2,desired:1},
   {index:4,desired:1,area:"snow"},{index:5,desired:1,area:"river"},
   {index:6,desired:1,positions:[{xRatio:0.5,yRatio:0.93}]},
   {index:11,desired:1,area:"secret",positions:[{x:-2500,y:7200}]}
 ]}};
const at=src.indexOf("    animalPosition(");
const objCode=["animalPosition","ensureAnimals"].map(method).join(",\n");
const gameFns=new Function("config","UTILS","CRAB_KING","return ({"+objCode+"})")(testCfg,UTILS,11);
const oldRandom=Math.random;
const rand=mulberry32(2026);
Math.random=()=>rand();
try{
 const list=[];
 const world={checkItemLocation(){return true},getGridArrays(){return []},
   checkCollision(){}};
 const mgr=new AiManager(list,[],items,world,testCfg,UTILS,()=>{}, {send(){}},{});
 const game={ai_manager:mgr,ais:list,object_manager:world,
   randomSecretPoint(scale){return {x:-2500,y:7200}},
   ...gameFns};
 const checks=[
   {index:0},{index:4,area:"snow"},{index:5,area:"river"},
   {index:6,positions:[{xRatio:0.5,yRatio:0.93}]},
   {index:11,positions:[{x:-2500,y:7200}]}
 ];
 for(const plan of checks){
   const pos=game.animalPosition(plan);
   console.log("POS|"+plan.index+"|"+String(plan.area||"normal")+"|"+pos.x+"|"+pos.y);
 }
 game.ensureAnimals();
 for(let i=0;i<list.length;i++){
   const a=list[i];
   console.log("SPAWN|"+i+"|"+a.sid+"|"+a.index+"|"+a.x+"|"+a.y+"|"+
    a.dir.toFixed(6)+"|"+a.nameIndex+"|"+a.health+"|"+
    (a.spawnDelay||0)+"|"+(a.boss?1:0));
 }
 game.ensureAnimals();
 console.log("NO_DUP|"+list.length);
 const first=list[0];
 first.active=false;
 const reused=mgr.spawn(850,920,0.4,9,{spawnDelay:2500});
 console.log("REUSE|"+reused.sid+"|"+reused.index+"|"+reused.x+"|"+reused.y+
   "|"+reused.nameIndex+"|"+reused.spawnDelay+"|"+list.length);
 const missing=mgr.spawn(700,750,0.5,99);
 console.log("MISSING|"+missing.sid+"|"+missing.index+"|"+missing.x+"|"+list.length);
}finally{Math.random=oldRandom}
