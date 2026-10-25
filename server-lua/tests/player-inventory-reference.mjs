// Test real Player.addItem/resetResources/getData/setData from Node.js.
import fs from "node:fs";
import { items } from "../../server/src/moomoo/modules/items.js";
import { config } from "../../server/src/moomoo/config.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
function method(name){
 const start=source.indexOf("this."+name+" = function (");
 const end=source.indexOf("\n        };",start);
 if(start<0||end<0)throw Error("Original Player."+name+" changed");
 const expression=source.slice(start,end+11).replace("this."+name+" = ","").replace(/;\s*$/,"");
 return new Function("items","config","UTILS","return ("+expression+");")(
   items,config,UTILS);
}
const methods=Object.fromEntries(["addItem","resetResources","getData","setData","shownName"].map(n=>[n,method(n)]));
const cases=[
 {name:"starter",items:[0,3,6,10],buildIndex:3,seq:[4,5,7,8,11,12,1,2,14,15,16,19,22,0,23,-1]},
 {name:"empty",items:[],buildIndex:-1,seq:[0,3,6,10,5,8,11,20,21]},
 {name:"selected-food",items:[0,3,6,10],buildIndex:0,seq:[1,2,2,6,5,4]},
 {name:"selected-mill",items:[0,3,6,10],buildIndex:10,seq:[11,12,11,10]}
];
for(const c of cases){
 const p={items:[...c.items],buildIndex:c.buildIndex};
 for(const id of c.seq){
   const result=methods.addItem.call(p,id);
   console.log(["ITEM",c.name,id,result?1:0,p.buildIndex,p.items.join(",")].join("|"));
 }
}
const fmt=v=>v===null||v===undefined?"~":typeof v==="number"?v.toFixed(5):String(v);
const resources=[
 {name:"no-moofoll",moofoll:false},
 {name:"moofoll",moofoll:true},
 {name:"none",moofoll:null}
];
for(const tc of resources){
 const p={points:11,wood:31,food:39,stone:43,gold:50};
 methods.resetResources.call(p,tc.moofoll);
 console.log(["RESET",tc.name,...config.resourceTypes.map(n=>p[n]),p.points].join("|"));
}
const scenes=[
 {name:"normal",x:125.135,y:-50.476,dir:0.67891},
 {name:"anon",x:-315.456,y:7260.824,dir:-2.1276,anon:true,clanTag:"ABC"},
 {name:"clan",x:100.569,y:101.675,dir:3.141592,clanTag:"TEST",morph:2,dive:1},
 {name:"invisible",x:-650,y:7300,dir:-3.14159,invisible:1,disguised:true},
 {name:"powers",x:920.115,y:42.675,dir:1.23456,aura:1,boss:1,disguised:true},
 {name:"anon-morph",x:230.445,y:60.995,dir:-0.005,anon:true,morph:3,dive:2,disguised:true},
 {name:"zeros",x:0,y:0,dir:0,clanTag:""},
 {name:"negative",x:-0.12,y:-0.09,dir:-0.12999}
];
for(const scene of scenes){
 const p={
 id:"client",sid:9,name:"Hero",x:scene.x,y:scene.y,dir:scene.dir,
 health:76,maxHealth:150,scale:37,skinColor:2,
 powers:{aura:scene.aura||0,boss:scene.boss||0,invisible:scene.invisible||0},
 clanTag:scene.clanTag||null,morph:scene.morph??-1,dive:scene.dive||0,
 disguised:scene.disguised||false,anon:scene.anon||false
 };
 p.shownName=methods.shownName;
 const data=methods.getData.call(p,scene.anon?{}:p);
 const wire=data.map(fmt).join(",");
 const newPlayer={};
 methods.setData.call(newPlayer,data);
 console.log(["WIRE",scene.name,wire,...["id","sid","name","x","y","dir",
   "health","maxHealth","scale","skinColor","aura","bossMode","clan"].map(k=>fmt(newPlayer[k]))].join("|"));
}
