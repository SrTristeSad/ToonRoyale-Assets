// SPDX-License-Identifier: AGPL-3.0-only
// Execute the *entire* original Player.update from Node, including all
// phase transitions, against the assembled Lua PlayerUpdate implementation.
import fs from "node:fs";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { config } from "../../server/src/moomoo/config.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { snowFactor,secretDistance,inSecretPool,hasTail,TAIL,EFFECT } from "../../server/src/moomoo/modules/effects.js";
const src=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
function portion(name){
 const at=src.indexOf("this."+name+" = function (");
 const end=src.indexOf("\n        };",at);
 if(at<0||end<0)throw Error("Original Player."+name+" changed");
 return src.slice(at,end+11).replace("this."+name+" = ","").replace(/;\s*$/,"");
}
const keep=new Function("config","secretDistance","return ("+portion("keepInWorld")+");")(config,secretDistance);
function original(player,world,players,projectileManager){
 return new Function("items","config","UTILS","players","objectManager",
   "projectileManager","snowFactor","inSecretPool","hasTail","TAIL","EFFECT",
   "mathCOS","mathSIN","mathSQRT","mathPOW","Date",
   "let timerCount=0;return ("+portion("update")+");")(
     items,config,UTILS,players,world,projectileManager,snowFactor,inSecretPool,
     hasTail,TAIL,EFFECT,Math.cos,Math.sin,Math.sqrt,Math.pow,{now:()=>10000}
   );
}
const scenarios=[
 {name:"idle",delta:33},
 {name:"walk",delta:100,moveDir:0.75},
 {name:"coast",delta:95,moveDir:null,xVel:0.24,yVel:-0.12},
 {name:"slow",delta:111,slowMult:0.3,moveDir:2.35},
 {name:"river",delta:111,x:7200,y:7200},
 {name:"snow",delta:111,y:200},
 {name:"regen",delta:310,skin:{healthRegen:3,spdMult:0.85}},
 {name:"poison",delta:200,dmgOverTime:{dmg:3,time:2,doer:"enemy"}},
 {name:"hammer-hit",delta:100,hits:1,mouseState:0},
 {name:"hammer-auto",delta:100,autoGather:1},
 {name:"build-walk",delta:111,buildIndex:0,gathering:1},
 {name:"bow",delta:100,weaponIndex:9,gathering:1},
 {name:"bow-nothing",delta:100,weaponIndex:9,gathering:1,resources:false},
 {name:"musket",delta:100,weaponIndex:15,gathering:1,dir:0.75},
 {name:"turret-hat",delta:100,skin:{turret:true},shootCount:25},
 {name:"locked",delta:100,lockMove:true,xVel:0.3,yVel:0.2},
 {name:"stone-collision",delta:100,obstacle:true},
 {name:"death-mid-tick",delta:100,dmgOverTime:{dmg:150,time:1,doer:"enemy"}}
];
const fmt=x=>Number(x||0).toFixed(6);
function g(v){
 if(v===undefined||v===null)return "~";
 if(v===true)return "true";
 if(v===false)return "false";
 return typeof v==="number"?fmt(v):String(v);
}
for(const s of scenarios){
 const events=[];
 const p={
  id:"p",sid:1,alive:true,isPlayer:true,
  x:s.x??500,y:s.y??500,scale:config.playerScale,
  speed:config.playerSpeed,xVel:s.xVel??0,yVel:s.yVel??0,
  dir:s.dir??0.25,moveDir:s.moveDir===undefined?0.4:s.moveDir,
  buildIndex:s.buildIndex??-1,weaponIndex:s.weaponIndex??0,
  hits:s.hits??0,gathering:s.gathering??0,mouseState:s.mouseState??0,
  autoGather:s.autoGather??0,lockMove:s.lockMove??false,
  noMovTimer:0,slowMult:s.slowMult??1,zIndex:0,healCol:0,
  reloads:[],shootCount:s.shootCount??250,
  skin:s.skin??null,tail:null,powers:{speed:1,power:1,god:0},
  health:100,maxHealth:100,
  shameTimer:0,shameCount:0,pps:0,dmgOverTime:s.dmgOverTime??{},
  superUntil:0,dragonUntil:0
 };
 p.changeHealth=function(amount,who){
   events.push("HP:"+fmt(amount)+":"+(who===this?"self":g(who)));
   this.health=Math.min(100,this.health+amount);
   if(this.health<=0)this.alive=false;
 };
 p.addResource=function(type,amount,auto){
   events.push("RES:"+type+":"+fmt(amount)+":"+(auto?1:0));
 };
 p.gather=function(){events.push("GATHER");this.noMovTimer=0;this.slowMult=Math.max(0,this.slowMult-0.3)};
 p.hasRes=function(weapon,cost){events.push("HAS:"+weapon.id+":"+g(cost));return s.resources!==false};
 p.useRes=function(weapon,cost){events.push("USE:"+weapon.id+":"+g(cost))};
 p.shootTurret=function(){events.push("TURRET");this.shootCount=250};
 p.keepInWorld=keep;
 const players=[p];
 const objects=[];
 const mgr=new ObjectManager(GameObject,objects,UTILS,config,players,{broadcast(){}});
 if(s.obstacle)mgr.add(0,555,500,0,30,2,{},false,null);
 const proj={addProjectile(...args){
   events.push("SHOT:"+args.map(x=>x===p?"self":g(x)).join(","));
 }};
 p.update=original(p,mgr,players,proj);
 for(let tick=1;tick<=3;tick++){
   p.update(s.delta);
   console.log(["FULL",s.name,tick,p.alive?1:0,fmt(p.x),fmt(p.y),
    fmt(p.xVel),fmt(p.yVel),fmt(p.health),fmt(p.slowMult),
    fmt(p.noMovTimer),p.hits,p.gathering,
    p.reloads[p.weaponIndex]===undefined?"~":fmt(p.reloads[p.weaponIndex]),
    fmt(p.shootCount),fmt(p.shameTimer),fmt(p.zIndex),events.join(";")].join("|"));
 }
}
