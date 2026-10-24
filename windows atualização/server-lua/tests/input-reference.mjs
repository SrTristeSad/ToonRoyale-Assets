// SPDX-License-Identifier: AGPL-3.0-only
// Call the original server/src/network/packets.js handlePacket unchanged.
import fs from "node:fs";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config } from "../../server/src/moomoo/config.js";
import { items } from "../../server/src/moomoo/modules/items.js";
// Importing the handler's whole module would also import the production chat
// dependency. Execute its actual unchanged function from the source instead;
// none of these packet cases calls the filtered-chat or account handlers.
const source=fs.readFileSync(new URL("../../server/src/network/packets.js",import.meta.url),"utf8");
const start=source.indexOf("export function handlePacket(");
const end=source.indexOf("function handleAdmin(",start);
if(start<0||end<0)throw Error("Original packet handler marker changed");
const original=source.slice(start,end).trim().replace(/^export /,"");
const handlePacket=new Function("UTILS","items","config",
 "const isNum=UTILS.isNumber;const isInt=Number.isInteger;return ("+original+");")(
 UTILS,items,config);

const cases=[
 {id:"spawn",packet:"M",args:[{name:"Test",skin:0,moofoll:false}],alive:false},
 {id:"spawn-invalid",packet:"M",args:["bad"],alive:false},
 {id:"spawn-alive",packet:"M",args:[{name:"Test"}]},
 {id:"dir",packet:"D",args:[0.9]},
 {id:"dir-invalid",packet:"D",args:["bad"]},
 {id:"move",packet:"9",args:[2.4]},
 {id:"stop",packet:"9",args:[null]},
 {id:"move-invalid",packet:"9",args:[false]},
 {id:"reset",packet:"e",args:[]},
 {id:"attack",packet:"F",args:[true,1.2]},
 {id:"attack-empty",packet:"F",args:[false,null]},
 {id:"build",packet:"F",args:[1,1.5],buildIndex:3},
 {id:"build-invalid",packet:"F",args:[1,"bad"]},
 {id:"weapon-select",packet:"z",args:[0,true],buildIndex:3},
 {id:"item-select",packet:"z",args:[3,false]},
 {id:"item-toggle",packet:"z",args:[3,false],buildIndex:3},
 {id:"item-invalid",packet:"z",args:["bad",false]},
 {id:"item-unowned",packet:"z",args:[5,false]},
 {id:"toggle-gather",packet:"K",args:[1]},
 {id:"toggle-lock",packet:"K",args:[0]},
 {id:"toggle-invalid",packet:"K",args:[5]},
 {id:"ping",packet:"0",args:[]},
 {id:"map-self",packet:"S",args:[]},
 {id:"map-ally",packet:"S",args:[],team:"RED",allyTeam:"RED"},
 {id:"map-cooldown",packet:"S",args:[],pingCooldown:500},
 {id:"map-tap",packet:"U",args:[200.5,100.25]},
 {id:"map-tap-ally",packet:"U",args:[210.25,120.25],team:"RED",allyTeam:"RED"},
 {id:"map-negative",packet:"U",args:[-5,120]},
 {id:"map-nonnumeric",packet:"U",args:["bad",120]},
 {id:"map-extra",packet:"U",args:[15,25,35]},
 {id:"map-dead",packet:"S",args:[],alive:false},
 {id:"dead-dir",packet:"D",args:[2.2],alive:false},
 {id:"dead-attack",packet:"F",args:[true,0.5],alive:false}
];
const g=v=>v==null?"~":typeof v==="number"?(Number.isInteger(v)?String(v):v.toFixed(5)):String(v);
for(const spec of cases){
 const events=[];
 const p={
   id:"guest",sid:7,alive:spec.alive===undefined?true:spec.alive,
   name:"Old",dir:0.25,moveDir:0.8,mouseState:0,hits:0,
   x:125.5,y:200.5,team:spec.team??null,pingCooldown:spec.pingCooldown??0,
   buildIndex:spec.buildIndex??-1,weaponIndex:0,
   autoGather:0,lockDir:false,
   itemCounts:{},items:[0,3,6,10],weapons:[0],
   attrCache:new Map([["old",1]]),
   anticheat:{
     invalid(name,why){events.push("INVALID:"+name+":"+why)},
     onGameStart(){events.push("ACSTART")}
   },
   setUserData(data){this.name=data.name;events.push("SET:"+this.name)},
   spawn(v){this.alive=true;events.push("SPAWN:"+g(v))},
   resetMoveDir(){this.moveDir=undefined;events.push("RESET")},
   buildItem(item){events.push("BUILD:"+item.id)},
   send(name,...args){events.push("SEND:"+name+":"+args.map(g).join(","))}
 };
 const ally={
   id:"ally",team:spec.allyTeam??null,alive:true,
   send(name,...args){events.push("ALLY:"+name+":"+args.map(g).join(","))}
 };
 const ctx={game:{key:"LC",players:[p,ally]},log:s=>events.push("LOG:"+s)};
 handlePacket(ctx,p,spec.packet,spec.args);
 console.log(["INPUT",spec.id,p.alive?1:0,g(p.dir),g(p.moveDir),
   g(p.mouseState),p.hits,p.buildIndex,p.weaponIndex,g(p.autoGather),
   g(p.lockDir),p.attrCache.size,g(p.pingCooldown),events.join(";")].join("|"));
}
