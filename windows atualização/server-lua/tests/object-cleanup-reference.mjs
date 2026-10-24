// Execute the ORIGINAL ObjectManager.removeAllItems method from the local Node.
import fs from "node:fs";
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/objectManager.js",import.meta.url),"utf8");
const marker="this.removeAllItems = function(sid, server) {";
const at=source.indexOf(marker);
const end=source.indexOf("\n        };",at);
if(at<0||end<0)throw Error("ObjectManager.removeAllItems source changed");
const records=[
 {sid:10,active:true,owner:{sid:4}},
 {sid:11,active:true,owner:{sid:4}},
 {sid:12,active:false,owner:{sid:4}},
 {sid:13,active:true,owner:{sid:5}},
 {sid:14,active:true,owner:null}
];
const emitter=[];
const fn=new Function("gameObjects","return ("+
 source.slice(at+"this.removeAllItems = ".length,end).trim()+")")(records);
const world={disableObj(obj){obj.active=false;emitter.push("off:"+obj.sid)}};
const server={broadcast(name,sid){emitter.push(name+":"+sid)}};
fn.call(world,4,server);
fn.call(world,4,server);
console.log("CLEANUP|"+emitter.join(","));
console.log("REMAIN|"+records.filter(x=>x.active).map(x=>x.sid).join(","));
