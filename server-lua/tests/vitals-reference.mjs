// SPDX-License-Identifier: AGPL-3.0-only
// Execute the actual pre-movement portion of Node Player.update, including its
// constructor-scoped timerCount, and compare events with native Lua.
import fs from "node:fs";
const src=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const start=src.indexOf("this.update = function (delta) {");
const end=src.indexOf("            // SLOWER:",start);
if(start<0||end<0)throw Error("Missing original Player.update section");
const body=src.slice(start,end).replace(/^this\.update = /,"")+"\n}";
const build=new Function("let timerCount=0; const update=("+body+"); return {update, timer:()=>timerCount};");
const cases=[
 {name:"idle",steps:[0,400,400,400]},
 {name:"regen",steps:[200,500,500,1000],skin:{healthRegen:3}},
 {name:"double-regen",steps:[0,1050,1050],skin:{healthRegen:3},tail:{healthRegen:2}},
 {name:"poison",steps:[0,300,300,300,300],dmgOverTime:{dmg:7,time:2,doer:"enemy"}},
 {name:"healer",steps:[0,1000,1000],healCol:5},
 {name:"mill",steps:[0,500,500,1100],pps:3},
 {name:"hat-pps",steps:[0,1000,1000],skin:{pps:4}},
 {name:"mixed",steps:[100,1100,1100],skin:{healthRegen:2,pps:4},dmgOverTime:{dmg:3,time:2,doer:"enemy"},healCol:1,pps:5},
 {name:"death",steps:[0,200,1200],health:4,dmgOverTime:{dmg:6,time:2,doer:"enemy"},pps:6},
 {name:"already-dead",steps:[300,400],alive:false},
 {name:"shame",steps:[100,100,100,200],shameTimer:300,shameCount:8},
 {name:"zero-values",steps:[0,999,1,0],skin:{healthRegen:0,pps:0},tail:{healthRegen:0},healCol:0,pps:0}
];
function fm(v){return Number(v).toFixed(3)}
for(const tc of cases){
 const events=[];
 const p={
   id:"p7",alive:true,health:70,maxHealth:100,
   shameTimer:0,shameCount:0,
   dmgOverTime:{},healCol:0,pps:0,points:50,
   skin:null,tail:null,...Object.fromEntries(Object.entries(tc).filter(([k])=>!["name","steps"].includes(k))),
   changeHealth(value,source){
     events.push("H:"+fm(value)+":"+((source===this)?"self":String(source??"-")));
     this.health=Math.min(this.maxHealth,this.health+value);
     if(this.health<=0)this.alive=false;
   },
   addResource(type,value,auto){
     events.push("R:"+type+":"+fm(value)+":"+(auto?1:0));
     this.points+=value;
   }
 };
 const u=build();
 for(let step=0;step<tc.steps.length;step++){
   u.update.call(p,tc.steps[step]);
   console.log(["VITAL",tc.name,step+1,p.alive?1:0,fm(p.health),fm(p.points),
     fm(p.shameTimer),p.shameCount,fm(p.dmgOverTime.dmg||0),
     fm(p.dmgOverTime.time||0),fm(u.timer()),events.join(",")].join("|"));
 }
}
