// SPDX-License-Identifier: AGPL-3.0-only
// Extract and execute the unchanged original Game methods from server.js.
import fs from "node:fs";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
const source=fs.readFileSync(new URL("../../server/src/moomoo/server.js",import.meta.url),"utf8");
function method(name){
  const start=source.indexOf("    "+name+"(");
  const end=source.indexOf("\n    }",start);
  if(start<0||end<0)throw Error("Game."+name+" changed");
  return source.slice(start,end+6).trim();
}
const roleDef=source.match(/const ROLE_NUMBER = \{[^;]+;/)?.[0];
const iconDef=source.match(/const iconFor = [^;]+;/)?.[0];
if(!roleDef||!iconDef)throw Error("Source role and icon definitions changed");
const real=new Function("UTILS",roleDef+"\n"+iconDef+
  "\nreturn ({"+["syncAnimals","sendMinimap","updateLeaders","sendLeaderboard","sendStats"]
  .map(method).join(",\n")+"});")(UTILS);
const profiles=[
 {name:"normal",staff:false,anon:false,accounts:true},
 {name:"staff",staff:true,anon:false,accounts:true},
 {name:"anonymous",staff:false,anon:true,accounts:true},
 {name:"guest",staff:false,anon:false,accounts:false}
];
const fmt=(v)=>v==null?"~":typeof v==="number"?(
  Number.isInteger(v)?String(v):v.toFixed(6)):String(v);
const fmtPacket=(v)=>Array.isArray(v)?"["+v.map(fmt).join(",")+"]":fmt(v);
for(const profile of profiles){
 const events=[];
 const create=(sid,x,y,extra={})=>{
   const p={
     sid,id:"p"+sid,name:"Person"+sid,x,y,dir:0,scale:35,
     health:100,points:50,age:1,kills:0,alive:true,spawned:true,
     team:null,role:null,account:null,clanTag:null,anon:false,shadowed:false,
     visibleAis:new Set(),skin:null,
     shownName(viewer){return this.anon&&viewer!==this?"Anon#"+this.sid:this.name},
     canSee(other){return Math.abs(other.x-this.x)<1000&&Math.abs(other.y-this.y)<1000},
     send(name,...args){events.push("P"+sid+":"+name+":"+args.map(fmtPacket).join("|"))},
     ...extra
   };
   return p;
 };
 const viewer=create(0,100,100,{team:profile.name==="guest"?null:"RED",
   role:profile.staff?"mod":null,points:50,kills:0});
 const ally=create(1,180,120,{team:"RED",points:215,kills:2,
   anon:profile.anon,role:"admin",account:profile.accounts?{id:"A1"}:null,
   clanTag:"Tag",lifeStats:{kills:2,wood:13,food:12,stone:3,gold:100,
     damage:83.5,animalDamage:51.75,healing:15.1,animals:3,bosses:1,score:215}});
 const other=create(2,400,110,{team:"BLUE",points:149.5,kills:1,clanTag:"Other",
   shadowed:true,account:profile.accounts?{id:"A2"}:null});
 const offline=create(3,5000,5000,{points:250,kills:8,alive:false});
 const equal=create(4,280,150,{team:"RED",points:215,kills:2});
 const players=[viewer,ally,other,offline,equal];
 const ais=[
   {sid:20,index:3,active:true,spawnCounter:0,x:155,y:170,dir:0.354,
     health:88.8,nameIndex:2,state:0,scale:65},
   {sid:21,index:4,active:true,spawnCounter:100,x:250,y:190,dir:2.115,
     health:65,nameIndex:0,state:1,scale:70},
   {sid:22,index:6,active:true,spawnCounter:0,x:8000,y:8000,dir:1,
     health:200,nameIndex:1,state:2,scale:100}
 ];
 const game={
   players,ais,crabKillers:new Set([1,3]),
   accounts:profile.accounts?{}:null,
   crownOf(player){return player.account?(player.sid===1?3:2):0},
   ...real
 };
 for(let stage=1;stage<=3;stage++){
   if(stage===2){
     ais[0].x=1600;ais[1].spawnCounter=0;ais[2].active=false;
     viewer.x=230;
     ally.points=219;
   }else if(stage===3){
     ais[0].x=180;ais[1].x=2600;ais[2].active=true;ais[2].x=250;
     other.alive=false;ally.anon=false;
     viewer.role=profile.staff?"admin":null;
   }
   game.updateLeaders();
   game.syncAnimals(viewer);
   game.sendMinimap(viewer);
   game.sendLeaderboard();
   game.sendStats(viewer,1);
   console.log("SOCIAL|"+profile.name+"|"+stage+"|"+
     players.map(p=>[p.sid,p.isLeader?1:0,p.iconIndex].join(",")).join(";")+"|"+
     [...viewer.visibleAis].join(",")+"|"+events.join(";"));
   events.length=0;
 }
}
