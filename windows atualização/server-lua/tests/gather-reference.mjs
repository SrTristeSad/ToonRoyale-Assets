// SPDX-License-Identifier: AGPL-3.0-only
// Differential test: extracts and executes the ORIGINAL Player.gather function,
// original ObjectManager and original GameObject. No rewritten JS combat physics.
import fs from "node:fs";
import assert from "node:assert/strict";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config } from "../../server/src/moomoo/config.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { gatherBonus,hasTail,TAIL,EFFECT } from "../../server/src/moomoo/modules/effects.js";
const src=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const at=src.indexOf("this.gather = function () {");
const end=src.indexOf("\n        };",at);
if(at<0||end<0)throw Error("Original Player.gather source changed");
const code=src.slice(at,end+11).replace(/^this.gather = /,"").replace(/;\s*$/,"");
function makeGather(manager,players,ais){
  return new Function("items","objectManager","UTILS","config","gatherBonus",
    "hasTail","TAIL","EFFECT","players","ais","mathCOS","mathSIN","Date",
    "return ("+code+");")(items,manager,UTILS,config,gatherBonus,hasTail,
      TAIL,EFFECT,players,ais,Math.cos,Math.sin,{now:()=>10000});
}
const f=n=>Number(n||0).toFixed(6);
const j=v=>v==null?"-":String(v);
for(const [index,properties] of [
  [0,{dmg:25,range:65,gather:1}],
  [7,{dmg:20,range:65,gather:1,hitSlow:0.1,knock:0.1}],
  [14,{dmg:0,range:125,gather:0,steal:250,knock:0.2}],
  [11,{shield:0.2}]
])for(const [key,value] of Object.entries(properties))
  assert.equal(items.weapons[index][key],value,"source item config drift "+index+"."+key);
const fixtures=[
  {name:"empty"},
  {name:"tree",obj:{type:0}},
  {name:"stone",obj:{type:2}},
  {name:"bush",obj:{type:1}},
  {name:"gold",obj:{type:3}},
  {name:"tree-cape",obj:{type:0},tail:{id:9}},
  {name:"stone-cape",obj:{type:2},tail:{id:10}},
  {name:"cookie-cape",obj:{type:1},tail:{id:3}},
  {name:"gold-hat",obj:{type:0},skin:{extraGold:true}},
  {name:"hidden",obj:{type:0,hideFromEnemy:true,hostileOwner:true}},
  {name:"blocked",obj:{type:0,dontGather:true}},
  {name:"behind",obj:{type:0,x:415}},
  {name:"far",obj:{type:0,x:900}},
  {name:"two-resources",obj:{type:0},secondObj:{type:2,x:575,y:545}},
  {name:"double-grid",x:1420,obj:{type:0,x:1450,scale:70}},
  {name:"wall-hit",obj:{type:2,health:40,req:["wood",10],owner:true}},
  {name:"wall-break",obj:{type:2,health:10,req:["wood",10],owner:true}},
  {name:"wall-high-damage",obj:{type:2,health:40,req:["stone",15],owner:true},skin:{bDmg:2}},
  {name:"melee",target:{}},
  {name:"defended",target:{weaponIndex:11,dir:Math.PI}},
  {name:"ally",team:"RED",target:{team:"RED"}},
  {name:"submerged",target:{submerged:true}},
  {name:"melee-behind",target:{x:410}},
  {name:"npc",target:{isAI:true,isPlayer:false}},
  {name:"steal",weaponIndex:14,target:{points:120}},
  {name:"dagger",weaponIndex:7,target:{}},
  {name:"poison",target:{},variant:{val:1.18,poison:true}},
  {name:"poison-resist",skin:{poisonDmg:3,poisonTime:2},target:{skin:{poisonRes:true}}},
  {name:"poison-gear",skin:{poisonDmg:4,poisonTime:2},target:{}},
  {name:"devils-tail",tail:{id:20},target:{}},
  {name:"thorns",tail:{id:14},target:{}},
  {name:"dragon-cape",tail:{id:2},target:{}},
  {name:"emerald",variant:{val:1.18,lifesteal:0.15},target:{}},
  {name:"lifesteal-skin",skin:{healD:0.2},target:{}},
  {name:"reflection",target:{skin:{dmg:0.2,dmgK:0.4}}},
  {name:"knockback",weaponIndex:7,target:{weightM:1.5}}
];
for(const v of fixtures){
  const events=[],player={
    id:"self",sid:7,isPlayer:true,team:v.team||null,active:true,alive:true,
    x:v.x||500,y:500,dir:0,scale:35,weaponIndex:v.weaponIndex||0,
    xVel:0,yVel:0,noMovTimer:220,slowMult:1,health:60,maxHealth:100,
    wood:0,food:0,stone:0,points:0,XP:0,skin:v.skin||null,tail:v.tail||null,
    powers:{power:1},dragonUntil:0,superUntil:0,sentTo:{self:true},
    canSee:()=>true
  };
  player.variant=()=>v.variant||{val:1};
  player.addResource=(type,amount)=>{
    events.push("RES:"+type+":"+f(amount));
    if(type===3)player.points+=amount;
    else player[config.resourceTypes[type]]+=amount;
  };
  player.earnXP=amount=>{events.push("XP:"+f(amount));player.XP+=amount};
  player.changeHealth=(amount,doer)=>{events.push("SELFHP:"+f(amount));player.health+=amount;return player.health<=0};
  player.sendAnimation=hit=>events.push("ANIM:"+hit);
  player.changeItemCount=(index,n)=>events.push("ITEM:"+index+":"+n);
  player.send=(name,...args)=>events.push("SEND:"+name+":"+args.map(x=>typeof x==="number"?f(x):j(x)).join(","));
  const players=[player],ais=[];
  const target=v.target?{
    id:"target",sid:8,team:v.target.team||null,isPlayer:v.target.isPlayer!==false,
    isAI:v.target.isAI||false,alive:true,submerged:v.target.submerged||false,
    x:v.target.x??570,y:v.target.y??500,scale:35,dir:v.target.dir??1.5,
    xVel:0,yVel:0,health:100,points:v.target.points??120,
    weightM:v.target.weightM??1,weaponIndex:v.target.weaponIndex,
    skin:v.target.skin||null,tail:v.target.tail||null,dmgOverTime:{},
    changeHealth(amount){events.push("ENEMYHP:"+f(amount));this.health+=amount;return this.health<=0},
    addResource(type,n){events.push("ENEMYRES:"+type+":"+f(n));if(type===3)this.points+=n}
  }:null;
  if(target)(target.isAI?ais:players).push(target);
  const objects=[];
  const manager=new ObjectManager(GameObject,objects,UTILS,config,players,{broadcast(){}});
  function makeObj(spec){
    const owner=spec.hostileOwner?{sid:13,team:"BLUE"}:spec.owner?player:null;
    const data={
      hideFromEnemy:spec.hideFromEnemy||undefined,
      dontGather:spec.dontGather||undefined,
      health:spec.health,
      req:spec.req,
      group:spec.owner?{id:1,layer:0}:undefined
    };
    const sid=objects.length;
    manager.add(sid,spec.x??570,spec.y??500,0,spec.scale??30,spec.type,data,false,owner);
    const obj=objects[objects.length-1];
    obj.sentTo[player.id]=1;
    return obj;
  }
  const obj=v.obj?makeObj(v.obj):null;
  const second=v.secondObj?makeObj(v.secondObj):null;
  const gather=makeGather(manager,players,ais);
  gather.call(player);
  console.log([
    "GATHER",v.name,f(player.noMovTimer),f(player.slowMult),
    f(player.wood),f(player.food),f(player.stone),f(player.points),f(player.XP),
    f(player.health),f(player.xVel),f(player.yVel),f(player.dragonUntil),
    obj?(obj.active?1:0):"-",obj?f(obj.health):"-",
    second?(second.active?1:0):"-",target?f(target.health):"-",
    target?f(target.xVel):"-",target?f(target.yVel):"-",
    target?f(target.points):"-",target?f(target.dmgOverTime.dmg):"-",
    target?f(target.dmgOverTime.time):"-",events.join(";")
  ].join("|"));
}
