// SPDX-License-Identifier: AGPL-3.0-only
// The test executes the exact original Node Player.update weapon subsection.
import fs from "node:fs";
import assert from "node:assert/strict";
import { items } from "../../server/src/moomoo/modules/items.js";
const original=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const begin=original.indexOf("            // USE WEAPON OR TOOL:");
const end=original.indexOf("\n        };",begin);
if(begin<0||end<0)throw Error("Player.update weapon subsection changed");
const actual=new Function("delta","items","projectileManager","players","mathCOS","mathSIN",
  original.slice(begin,end));
for(const [index,values] of [
  [0,{gather:1,speed:300}],
  [9,{projectile:0,speed:600}],
  [11,{shield:0.2}],
  [15,{projectile:5,speed:1500,rec:0.35}]
]) for(const [key,value] of Object.entries(values))
  assert.equal(items.weapons[index][key],value,"source config changed: weapons["+index+"]."+key);
assert.equal(items.projectiles[0].range,1000);
assert.equal(items.projectiles[0].speed,1.6);
assert.equal(items.projectiles[5].range,1400);
assert.equal(items.projectiles[5].speed,3.6);
const situations=[
  {name:"idle"}, {name:"gather-click",hits:1,mouseState:0},
  {name:"gather-held",gathering:1,mouseState:1},
  {name:"auto-hammer",autoGather:1},
  {name:"reload",reload:120,gathering:1,mouseState:0},
  {name:"building",buildIndex:2,hits:1,autoGather:1},
  {name:"bow",weaponIndex:9,gathering:1,mouseState:0},
  {name:"bow-empty",weaponIndex:9,gathering:1,hasResources:false},
  {name:"bow-auto",weaponIndex:9,autoGather:1,skin:{aMlt:1.25,atkSpd:0.8,projCost:0.5}},
  {name:"bow-reload",weaponIndex:9,autoGather:1,reload:100},
  {name:"musket",weaponIndex:15,gathering:1,dir:0.75,xVel:0.5,yVel:-0.15},
  {name:"musket-no-res",weaponIndex:15,gathering:1,hasResources:false},
  {name:"shield",weaponIndex:11,gathering:1},
  {name:"turret",skin:{turret:{range:500}},shootCount:50},
  {name:"turret-gather",skin:{turret:{range:500}},shootCount:25,autoGather:1}
];
const f=n=>Number(n).toFixed(6);
const fmtP=(...values)=>values.map((v)=>typeof v==="number"?f(v):v==null?"-":v).join(",");
for(const sc of situations){
  const events=[];
  const p={
    weaponIndex:0,buildIndex:-1,autoGather:0,gathering:0,mouseState:0,
    reloads:{},hits:0,skin:null,scale:35,
    x:123,y:456,dir:0.25,xVel:0,yVel:0,noMovTimer:200,
    zIndex:0,shootCount:200,hasResources:true,...Object.fromEntries(Object.entries(sc).filter(([key])=>key!=="name"&&key!=="reload"))
  };
  if(sc.reload!==undefined)p.reloads[p.weaponIndex]=sc.reload;
  p.gather=(_players)=>events.push("GATHER");
  p.hasRes=(weapon,mult)=>{events.push("HAS:"+fmtP(weapon.id,mult));return p.hasResources;};
  p.useRes=(weapon,mult)=>events.push("USE:"+fmtP(weapon.id,mult));
  p.shootTurret=()=>{events.push("TURRET");p.shootCount=250};
  const manager={addProjectile:(x,y,dir,range,speed,index,owner,ignore,layer)=>{
    events.push("SHOT:"+fmtP(x,y,dir,range,speed,index,layer));
  }};
  for(let tick=1;tick<=3;tick++){
    actual.call(p,100,items,manager,[p],Math.cos,Math.sin);
    console.log(["WEAPON",sc.name,tick,p.weaponIndex,
      p.gathering,p.hits,p.noMovTimer,
      p.reloads[p.weaponIndex]===undefined?"-":f(p.reloads[p.weaponIndex]),
      f(p.xVel),f(p.yVel),f(p.shootCount),events.join(";")].join("|"));
  }
}
