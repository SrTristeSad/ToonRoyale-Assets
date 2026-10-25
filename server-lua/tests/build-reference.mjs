// Extract actual Player.buildItem and run with real Node ObjectManager.
import fs from "node:fs";
import assert from "node:assert/strict";
import { config } from "../../server/src/moomoo/config.js";
import { items } from "../../server/src/moomoo/modules/items.js";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
assert.equal(items.list[3].name,"wood wall");
assert.equal(items.list[3].scale,50);
assert.equal(items.list[3].placeOffset,-5);
assert.equal(items.list[10].name,"windmill");
assert.equal(items.list[10].pps,1);
assert.equal(items.list[0].name,"apple");
assert.equal(items.list[2].name,"cheese");
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const a=source.indexOf("this.buildItem = function (item) {");
const b=source.indexOf("\n        };",a);
if(a<0||b<0)throw Error("Player.buildItem original changed");
const code=source.slice(a,b+11).replace(/^this.buildItem = /,"").replace(/;\s*$/,"");
const fmt=n=>Number(n).toFixed(5);
const trials=[
 {name:"wall",item:3},{name:"windmill",item:10},
 {name:"wall-angle",item:3,dir:1.2},
 {name:"water",item:3,y:7200},{name:"overlap",item:3,obstacle:true},
 {name:"denied",item:3,canBuild:false},{name:"noEat",item:0,skin:{noEat:true}},
 {name:"apple",item:0},{name:"apple-full",item:0,health:100},
 {name:"cheese",item:2},{name:"cheese-full",item:2,health:100},
 {name:"shame-trigger",item:0,hitTime:9950,shameCount:7},
 {name:"shame-fading",item:0,hitTime:9700,shameCount:5},
 {name:"shame-existing",item:0,shameTimer:1000},
 {name:"reused-object",item:3,reuse:true},
 {name:"short-respawn",item:3,buildIndex:3}
];
for(const sc of trials){
 const events=[];
 const objects=[];
 const mgr=new ObjectManager(GameObject,objects,UTILS,config,[],{broadcast(){}});
 const objData=items.list[sc.item];
 const p={
   id:"p",sid:7,x:500,y:sc.y??500,dir:sc.dir??0,
   scale:35,skin:sc.skin??null,
   health:sc.health??60,maxHealth:100,
   hitTime:sc.hitTime??0,shameCount:sc.shameCount??0,
   shameTimer:sc.shameTimer??0,buildIndex:sc.buildIndex??sc.item,
   pps:0,wood:100,food:100,stone:100,points:0,
   dmgOverTime:{},itemCounts:{},
   canBuild(item){events.push("CAN:"+item.id);return sc.canBuild!==false},
   changeItemCount(index,count){this.itemCounts[index]=(this.itemCounts[index]||0)+count;
     events.push("COUNT:"+index+":"+count)},
   changeHealth(amount){events.push("HEALTH:"+amount);if(this.health>=this.maxHealth&&amount>0)return false;
     this.health=Math.min(this.maxHealth,this.health+amount);return true},
   useRes(item){events.push("USE:"+item.id)}
 };
 if(sc.obstacle)mgr.add(0,580,500,0,50,2,{},false,null);
 if(sc.reuse){mgr.add(0,4000,4000,0,50,2,{},false,null);mgr.disableObj(objects[0]);}
 const build=new Function("objectManager","Date","mathCOS","mathSIN",
  "return ("+code+");")(mgr,{now:()=>10000},Math.cos,Math.sin);
 build.call(p,objData);
 const descriptions=objects.map(obj=>[
   obj.sid,obj.active?1:0,fmt(obj.x),fmt(obj.y),fmt(obj.dir),obj.scale,
   obj.id??"-",obj.type??"-",obj.group?.id??"-",obj.owner?.sid??"-",
   obj.health??"-",obj.gridLocations.length,obj.sentTo&&Object.keys(obj.sentTo).length
 ].join(","));
 console.log(["BUILD",sc.name,p.buildIndex,p.health,p.shameCount,p.shameTimer,p.hitTime,p.pps,
  p.itemCounts[objData.group.id]||0,objects.length,descriptions.join(";"),events.join(";")].join("|"));
}
