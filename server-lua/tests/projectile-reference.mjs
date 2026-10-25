// Original Node Projectile + ProjectileManager + ObjectManager + GameObject
// are run directly.  This is not a JS reimplementation of projectile physics.
import assert from "node:assert/strict";
import { Projectile } from "../../server/src/moomoo/modules/projectile.js";
import { ProjectileManager } from "../../server/src/moomoo/modules/projectileManager.js";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { config } from "../../server/src/moomoo/config.js";
assert.equal(items.projectiles[0].dmg,25);
assert.equal(items.projectiles[0].speed,1.6);
assert.equal(items.projectiles[0].scale,103);
assert.equal(items.projectiles[0].range,1000);
assert.equal(items.weapons[11].shield,0.2);
const cases=[
 {name:"fly"},{name:"moving-expiry",range:70},{name:"near-expiry",range:1},
 {name:"player",target:{x:145}},{name:"shield",target:{x:145,weaponIndex:11,dir:Math.PI}},
 {name:"team",team:"BLUE",target:{x:145,team:"BLUE"}},
 {name:"enemy-team",team:"BLUE",target:{x:145,team:"RED"}},
 {name:"npc",target:{x:145,isAI:true}},
 {name:"far-enemy",target:{x:400}},
 {name:"wall",structure:{x:145,health:50,projDmg:true}},
 {name:"break-wall",structure:{x:145,health:10,projDmg:true,owner:true}},
 {name:"solid",structure:{x:145,health:10,projDmg:false}},
 {name:"ignore-wall",structure:{x:145,health:10,projDmg:true},ignoreObj:0},
 {name:"invisible-wall",structure:{x:145,health:10,projDmg:true,ignoreCollision:true}},
 {name:"hidden-layer",structure:{x:145,layer:-1,health:10,projDmg:true}},
 {name:"two-structures",structure:{x:155,health:10,projDmg:true},secondStructure:{x:135,health:10,projDmg:true}},
 {name:"closer-player",target:{x:150},secondTarget:{x:130}},
 {name:"offscreen",see:false,target:{x:145}},
 {name:"observer",target:{x:145},observer:true},
 {name:"reuse-projectile",range:1,reuse:true}
];
function num(v){
 if(v==null)return "-";
 return typeof v==="number"?(Number.isInteger(v)?String(v):v.toFixed(6)):String(v);
}
const fmt=n=>Number(n||0).toFixed(6);
for(const sc of cases){
 const events=[];
 const makePlayer=(id,sid,opts={})=>({
   id,sid,active:true,alive:true,isPlayer:true,
   x:100,y:100,dir:0,scale:35,
   team:null,weaponIndex:0,xVel:0,yVel:0,health:100,
   sentTo:{},...opts,
   canSee(o){return sc.see!==false},
   send(name,...args){events.push("SEND:"+id+":"+name+":"+args.map(num).join(","))},
   changeHealth(damage){events.push("HP:"+id+":"+fmt(damage));this.health+=damage;return this.health<=0},
   changeItemCount(group,amount){events.push("COUNT:"+id+":"+group+":"+amount)}
 });
 const owner=makePlayer("owner",1,{team:sc.team||null});
 const players=[owner],ais=[];
 function createTarget(def,id,sid){
   const result=makePlayer(id,sid,{x:def.x??145,y:def.y??100,team:def.team||null,
      weaponIndex:def.weaponIndex??0,dir:def.dir??0,scale:def.scale??35});
   if(def.isAI){result.isPlayer=false;result.isAI=true;ais.push(result)}
   else players.push(result);
   return result;
 }
 const target=sc.target?createTarget(sc.target,"enemy",2):null;
 const secondTarget=sc.secondTarget?createTarget(sc.secondTarget,"enemy2",3):null;
 if(sc.observer)players.push(makePlayer("observer",4,{x:600,y:600}));
 const objects=[];
 const om=new ObjectManager(GameObject,objects,UTILS,config,players,{broadcast(){}});
 const makeObject=(def)=>{
   const sid=objects.length;
   const ownerObj=def.owner?owner:null;
   const data={health:def.health,projDmg:def.projDmg,ignoreCollision:def.ignoreCollision,
     id:5,group:{id:1,layer:def.layer??0},req:["wood",10]};
   om.add(sid,def.x??145,def.y??100,0,def.scale??40,2,data,false,ownerObj);
   const obj=objects[objects.length-1];
   for(const player of players)obj.sentTo[player.id]=1;
   return obj;
 };
 const object=sc.structure?makeObject(sc.structure):null;
 const secondObject=sc.secondStructure?makeObject(sc.secondStructure):null;
 const projectiles=[];
 const manager=new ProjectileManager(Projectile,projectiles,players,ais,om,items,config,UTILS,{send(){}});
 if(sc.reuse){
   const unused=manager.addProjectile(5000,5000,0,10,1.6,0,owner,null,0);
   unused.active=false;
 }
 const projectile=manager.addProjectile(100,100,0,sc.range??1000,1.6,0,owner,
   sc.ignoreObj??null,0);
 for(let tick=1;tick<=3;tick++){
   for(const p of projectiles)p.update(40);
   console.log([
     "PROJ",sc.name,tick,projectiles.length,projectile.sid,
     projectile.active?1:0,projectile.skipMov?1:0,
     fmt(projectile.x),fmt(projectile.y),fmt(projectile.range),
     target?fmt(target.health):"-",target?fmt(target.xVel):"-",
     secondTarget?fmt(secondTarget.health):"-",
     object?fmt(object.health):"-",object?(object.active?1:0):"-",
     secondObject?fmt(secondObject.health):"-",
     events.join(";")
   ].join("|"));
 }
}
