// Exact Node LOCAL objectManager.fetchSpawnObj, not a hand-written proxy.
import fs from "node:fs";
const source=fs.readFileSync(
 new URL("../../server/src/moomoo/modules/objectManager.js",import.meta.url),"utf8");
const start=source.indexOf("this.fetchSpawnObj = function(sid) {");
const end=source.indexOf("\n        };",start);
if(start<0||end<0)throw Error("original Node fetchSpawnObj changed");
const events=[];
const owner={sid:7,changeItemCount(group,delta){
 events.push("count:"+group+":"+delta);
}};
const points=[
 {sid:91,x:513,y:726,active:true,owner,spawnPoint:true,group:{id:42}},
 {sid:92,x:600,y:800,active:true,owner,spawnPoint:true,group:{id:42}},
 {sid:93,x:700,y:900,active:true,owner:{sid:8},spawnPoint:true,group:{id:42}}
];
const server={broadcast(name,sid){events.push(name+":"+sid)}};
const fetch=new Function("gameObjects","server","return ("+
 source.slice(start+"this.fetchSpawnObj = ".length,end).trim()+"})")(points,server);
const manager={disableObj(point){point.active=false;events.push("disable:"+point.sid)}};
for(let i=0;i<4;i++){
 const pos=fetch.call(manager,7);
 console.log("SPAWN_"+i+"|"+(pos?pos.join(","):"null")+"|"+
  events.join(",")+"|"+points.map(p=>String(p.active)).join(","));
}
