// Run the REAL Game.updateStructures, turretTarget and GameObject.update.
import fs from "node:fs";
import assert from "node:assert/strict";
import { config } from "../../server/src/moomoo/config.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
assert.equal(items.projectiles[1].layer,1);
assert.equal(items.projectiles[1].speed,undefined);
const src=fs.readFileSync(new URL("../../server/src/moomoo/server.js",import.meta.url),"utf8");
const start=src.indexOf("    updateStructures(delta) {");
const end=src.indexOf("    // Graceful shutdown",start);
if(start<0||end<0)throw Error("Original Game structure methods changed");
const methods=src.slice(start,end).replace(/\n    }\n\n    turretTarget\(/,"\n    },\n\n    turretTarget(");
const reference=new Function("UTILS","items","return ({"+methods+"});")(UTILS,items);
const trials=[
 {name:"idle"},
 {name:"windmill",windmill:true},
 {name:"owner-only",turret:true,shootCount:20},
 {name:"enemy",turret:true,shootCount:20,target:{x:250}},
 {name:"ally",turret:true,shootCount:20,team:"RED",target:{x:250,team:"RED"}},
 {name:"enemy-team",turret:true,shootCount:20,team:"RED",target:{x:250,team:"BLUE"}},
 {name:"invisible",turret:true,shootCount:20,target:{x:250,powers:{invisible:1}}},
 {name:"hidden-hat",turret:true,shootCount:20,target:{x:250,skin:{invisTimer:10},noMovTimer:20}},
 {name:"anti-turret",turret:true,shootCount:20,target:{x:250,skin:{antiTurret:true}}},
 {name:"npc",turret:true,shootCount:20,target:{x:250,isAI:true}},
 {name:"npc-submerged",turret:true,shootCount:20,target:{x:250,isAI:true,submerged:true}},
 {name:"npc-spawning",turret:true,shootCount:20,target:{x:250,isAI:true,spawnCounter:150}},
 {name:"nearer",turret:true,shootCount:20,target:{x:260},secondTarget:{x:190}},
 {name:"cooldown",turret:true,shootCount:400,target:{x:200}},
 {name:"range",turret:true,shootCount:20,target:{x:785,scale:35}},
 {name:"out-range",turret:true,shootCount:20,target:{x:800,scale:35}},
 {name:"no-visibility",turret:true,shootCount:20,target:{x:200},see:false},
 {name:"damaged",turret:true,shootCount:20,target:{x:250},disabled:true},
 {name:"two-turrets",turret:true,shootCount:20,target:{x:250},secondTurret:true},
 {name:"wiggle",windmill:true,xWiggle:8,yWiggle:-6}
];
const f=x=>Number(x||0).toFixed(6);
function fmtArg(v){
 if(v==null)return "-";
 return typeof v==="number"?f(v):String(v);
}
for(const sc of trials){
 const events=[];
 const makePlayer=(id,sid,opts={})=>({
   id,sid,x:100,y:100,scale:35,alive:true,active:true,
   powers:{invisible:0},skin:null,team:null,
   noMovTimer:0,...opts,
   canSee(){return sc.see!==false},
   send(name,...args){events.push("SEND:"+id+":"+name+":"+args.map(fmtArg).join(","))}
 });
 const owner=makePlayer("owner",1,{team:sc.team||null});
 const players=[owner],ais=[];
 const makeTarget=(s,id,sid)=>{
   const result=makePlayer(id,sid,{x:s.x??250,y:s.y??100,scale:s.scale??35,
     skin:s.skin||null,powers:s.powers||{invisible:0},
     team:s.team||null,noMovTimer:s.noMovTimer||0,
     submerged:s.submerged||false,spawnCounter:s.spawnCounter||0});
   if(s.isAI){result.isAI=true;ais.push(result);}else players.push(result);
   return result;
 };
 if(sc.target)makeTarget(sc.target,"enemy",2);
 if(sc.secondTarget)makeTarget(sc.secondTarget,"enemy2",3);
 const objects=[];
 const manager=new ObjectManager(GameObject,objects,UTILS,config,players,{broadcast(){}});
 function makeStructure(sid,x){
   const turret=sc.turret;
   const data=turret?{id:17,doUpdate:true,projectile:1,shootRate:2200,shootRange:700,
     health:800,group:{id:7,layer:1}}:{id:10,doUpdate:true,turnSpeed:0.0016,
     pps:1,health:400,group:{id:3,layer:1}};
   manager.add(sid,x,100,0,turret?43:45,undefined,data,false,owner);
   const obj=objects.find(o=>o.sid===sid);
   if(sc.shootCount!=null&&turret)obj.shootCount=sc.shootCount;
   if(sc.xWiggle)obj.xWiggle=sc.xWiggle;
   if(sc.yWiggle)obj.yWiggle=sc.yWiggle;
   for(const p of players)obj.sentTo[p.id]=1;
   return obj;
 }
 const structure=makeStructure(0,100);
 const second=sc.secondTurret?makeStructure(1,220):null;
 if(sc.disabled)manager.disableObj(structure);
 const game={
   object_manager:manager,players,ais,
   projectile_manager:{
     addProjectile(...args){events.push("SHOT:"+args.map(v=>v===owner?"owner":fmtArg(v)).join(","))}
   },turretTarget:reference.turretTarget,updateStructures:reference.updateStructures
 };
 for(let tick=1;tick<=3;tick++){
   game.updateStructures(100);
   console.log(["STRUCT",sc.name,tick,manager.updateObjects.length,
     f(structure.dir),f(structure.shootCount),f(structure.xWiggle),f(structure.yWiggle),
     structure.active?1:0,second?f(second.dir):"-",
     second?f(second.shootCount):"-",events.join(";")].join("|"));
 }
}
