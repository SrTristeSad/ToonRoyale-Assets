// SPDX-License-Identifier: AGPL-3.0-only
// Executes the original Player.spawn/reset/applyPowers methods, with original
// ObjectManager and GameObject.  All random draws are seeded in BOTH runtimes.
import fs from "node:fs";
import { config as shared } from "../../server/src/moomoo/config.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";
const src=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
function method(name,env) {
  const token="this."+name+" = function (";
  const at=src.indexOf(token),to=src.indexOf("\n        };",at);
  if(at<0||to<0)throw Error("Original Player."+name+" missing");
  const fn=src.slice(at,to+11).replace("this."+name+" = ","");
  return new Function("config","UTILS","objectManager","Date","return ("+fn+");")(
    env.cfg,UTILS,env.manager,{now:()=>543210}
  );
}
const cases=[
  {name:"normal",seed:1},
  {name:"moofoll",seed:42,moofoll:true},
  {name:"powers",seed:12345,powers:{size:1.5,health:2}},
  {name:"unlimited",seed:345,unlimited:true},
  {name:"respawn",seed:987,spawnPoint:true},
  {name:"obstructed",seed:72,blocked:true},
  {name:"obstacles",seed:123,obstacles:true},
  {name:"last-attempt",seed:555,rejectAll:true}
];
const fmt=v=>Number(v).toFixed(6);
for(const tc of cases){
  const cfg={...shared,unlimitedResources:!!tc.unlimited};
  const events=[];
  const p={
    sid:7,id:"user7",name:"ExistingUser",points:333,alive:false,active:false,
    scale:8,health:12,maxHealth:40,pps:0.2,moveDir:2,spawned:false,
    skins:{123:1},tails:{456:1},skinIndex:1,tailIndex:2,
    powers:{size:tc.powers?.size||1,health:tc.powers?.health||1,speed:1},
    changeItemCount(group,amount){events.push("S:"+group+":"+amount)}
  };
  const objects=[];
  const server={broadcast(name,sid){events.push(name+":"+sid)}};
  const manager=new ObjectManager(GameObject,objects,UTILS,cfg,[],server);
  if(tc.obstacles){
    manager.add(0,180,200,0,145,2,{},false,null);
    manager.add(1,4000,4000,0,200,0,{},false,null);
  }
  let spawnObj=null;
  if(tc.spawnPoint){
    manager.add(44,511,633,0,80,4,{id:9,group:{id:4},spawnPoint:true},false,p);
    spawnObj=objects[0];
  }
  let calls=0;
  const rand=mulberry32(tc.seed);
  const oldRand=Math.random;
  Math.random=()=>{calls++;return rand()};
  const actualCheck=manager.checkItemLocation;
  if(tc.rejectAll) manager.checkItemLocation=()=>false;
  try{
    const env={cfg,manager};
    p.resetMoveDir=method("resetMoveDir",env);
    p.resetResources=method("resetResources",env);
    p.applyPowers=method("applyPowers",env);
    p.spawn=method("spawn",env);
    p.spawn(!!tc.moofoll);
  }finally{Math.random=oldRand;manager.checkItemLocation=actualCheck}
  console.log(["SPAWN",tc.name,calls,fmt(p.x),fmt(p.y),fmt(p.scale),
    fmt(p.speed),p.health,p.maxHealth,p.age,p.maxXP,p.XP,
    p.wood,p.food,p.stone,p.points,p.buildIndex,p.weaponIndex,
    p.items.join(","),p.weapons.join(","),p.spawned?1:0,p.alive?1:0,
    p.moveDir==null?1:0,p.slowMult,p.lifeStats.score,
    spawnObj?(spawnObj.active?1:0):"-",events.join(",")].join("|"));
}
