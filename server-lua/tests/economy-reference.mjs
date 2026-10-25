// SPDX-License-Identifier: AGPL-3.0-only
// Execute the ACTUAL original Player resource/XP/inventory methods.
import fs from "node:fs";
import { config as shared } from "../../server/src/moomoo/config.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
function extract(method,cfg,server,score){
  const marker="this."+method+" = function (";
  const pos=source.indexOf(marker),last=source.indexOf("\n        };",pos);
  if(pos<0||last<0)throw Error("Original method changed: "+method);
  const code=source.slice(pos,last+11).replace("this."+method+" = ","").replace(/;\s*$/,"");
  return new Function("config","server","scoreCallback","UTILS","return ("+code+");")(cfg,server,score,UTILS);
}
const actions=[
  ["wood",p=>p.addResource(0,12,false)],
  ["food-auto",p=>p.addResource(1,7,true)],
  ["stone-spend",p=>p.addResource(2,-5,false)],
  ["gold",p=>p.addResource(3,25,false)],
  ["gold-auto",p=>p.addResource(3,12,true)],
  ["weapon-xp",p=>p.addWeaponXP(33)],
  ["age-xp",p=>p.earnXP(25)],
  ["age-up",p=>p.earnXP(350)],
  ["item-count",p=>p.changeItemCount(1,-2)],
  ["has-cost",p=>p.hasRes(p.item)],
  ["not-enough",p=>{p.wood=1;return p.hasRes(p.item)}],
  ["consume",p=>p.useRes(p.item)],
  ["build",p=>p.canBuild(p.item)],
  ["build-limit",p=>{p.itemCounts[1]=30;return p.canBuild(p.item)}],
  ["sandbox",p=>p.useRes(p.item)],
  ["sandbox-build",p=>{p.wood=0;return p.canBuild(p.item)}],
  ["sandbox-no-limit",p=>{delete p.item.group.limit;return p.canBuild(p.item)}],
  ["unlimited-spend",p=>p.addResource(0,-25,false)],
  ["round-cost",p=>p.useRes(p.item,1.25)]
];
const fmt=x=>Number(x||0).toFixed(3);
for(const [name,action] of actions){
  const cfg={...shared,inSandbox:name.startsWith("sandbox"),
    unlimitedResources:name==="unlimited-spend"};
  const events=[];
  const server={send(id,packet,...args){
    events.push("SEND:"+id+":"+packet+":"+args.map(v=>String(v)).join(","));
  }};
  const score=(player,value,auto)=>{
    events.push("SCORE:"+fmt(value)+":"+(auto?1:0));
    player.points+=value;
  };
  const p={
    id:"p0",sid:0,weaponIndex:0,weaponXP:[],
    wood:50,food:25,stone:25,points:80,
    age:1,XP:0,maxXP:300,upgradePoints:0,upgrAge:2,
    itemCounts:{1:10},lifeStats:{wood:0,food:0,stone:0}
  };
  p.item={req:["wood",10,"stone",5],group:{id:1,limit:30,sandboxLimit:99}};
  for(const method of ["addWeaponXP","earnXP","addResource","changeItemCount","hasRes","useRes","canBuild"]){
    p[method]=extract(method,cfg,server,score);
  }
  const result=action(p);
  console.log(["ECON",name,typeof result==="boolean"?(result?1:0):"-",
    fmt(p.wood),fmt(p.food),fmt(p.stone),fmt(p.points),fmt(p.weaponXP[0]),
    p.age,fmt(p.XP),fmt(p.maxXP),p.upgradePoints,p.itemCounts[1],
    p.lifeStats.wood,p.lifeStats.food,p.lifeStats.stone,events.join(";")].join("|"));
}
