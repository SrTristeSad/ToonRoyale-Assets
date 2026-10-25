// Extract unchanged Player constructor preamble and relevant methods, avoiding
// importing unrelated npm dependencies. No reimplementation of Node logic.
import fs from "node:fs";
import { config } from "../../server/src/moomoo/config.js";
import { HAT } from "../../server/src/moomoo/modules/effects.js";
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const start=source.indexOf("constructor(id, sid, config,");
const end=source.indexOf("// SPAWN:",start);
if(start<0||end<0)throw Error("Original constructor marker changed");
const preamble=source.slice(source.indexOf("{",start)+1,end);
const constructorFn=new Function("id","sid","hats","accessories",
  "const player={};(function(){"+preamble+"}).call(player);return player");
function get(name){
 const marker="this."+name+" = function (";
 const a=source.indexOf(marker),b=source.indexOf("\n        };",a);
 if(a<0||b<0)throw Error("Player."+name+" changed");
 const e=source.slice(a,b+11).replace("this."+name+" = ","").replace(/;\s*$/,"");
 return new Function("config","NAME_WORDS","items","UTILS","HAT","return ("+e+");")(
  config,["qweir","discord","badword"],items,{fixTo:(v,dp)=>Number(v.toFixed(dp))},HAT
 );
}
const groups=[{id:0},{id:1},{id:2},{id:3}];
const items={list:{0:{id:0,group:groups[0]},3:{id:3,group:groups[1]},
  4:{id:4,group:groups[1]},6:{id:6,group:groups[2]},10:{id:10,group:groups[3]},
  11:{id:11,group:groups[3]}}};
const hats=[{id:0,price:0},{id:5,price:0},{id:9,price:20},
 {id:40,price:0,dontSell:true},{id:61,price:0,dontSell:true}];
const accessories=[{id:0,price:0},{id:1,price:200},{id:6,price:0},
 {id:16,price:0,dontSell:true}];
const methods=["resetMoveDir","addItem","setUserData","shownName","getData","applyPowers","displaySkin"];
const refs=Object.fromEntries(methods.map(n=>[n,get(n)]));
const cases=[
 {name:"initial",applyData:false},
 {name:"basic",data:{name:" Guest ",skin:2}},
 {name:"punctuation",data:{name:"T(hi):/ ?-User",skin:9}},
 {name:"truncation",data:{name:"LongPlayerName123456789",skin:0}},
 {name:"nonascii",data:{name:"Café ✨ Rai",skin:50}},
 {name:"profanity",data:{name:"hello qweir friend",skin:1}},
 {name:"leetspeak",data:{name:"D1SC0RD",skin:3}},
 {name:"empty",data:{name:"   ",skin:1}},
 {name:"missing-name",data:{skin:1}},
 {name:"account",data:{name:"Moo",skin:4},account:{name:"AccountID",role:"mod"}},
 {name:"account-anon",data:{name:"Guest",skin:4,anon:true},account:{name:"Permanent",role:"admin"}},
 {name:"anon-guest",data:{name:"Guest",skin:3,anon:true}},
 {name:"no-data",data:null,account:{name:"Existing"}},
 {name:"replace",data:{name:"Name",skin:8},item:4,buildIndex:3},
 {name:"new-item",data:{name:"Name",skin:8},item:11},
 {name:"missing-item",data:{name:"Name",skin:8},item:99},
 {name:"powers",data:{name:"Hero",skin:1},health:42,powers:{size:1.5,health:2}},
 {name:"shame",data:{name:"Hero",skin:1},shameTimer:1000}
];
function owned(object){return Object.keys(object).map(Number).sort((a,b)=>a-b).join(",")}
function field(x){return x==null?"~":typeof x==="boolean"?(x?"true":"false"):String(x)}
function formattedData(values){return values.map(field).join(",")}
for(const tc of cases){
 const p=constructorFn("session",17,hats,accessories);
 for(const [key,v] of Object.entries(refs))p[key]=v;
 if(tc.account){p.account=tc.account;p.role=tc.account.role||null;}
 p.items=[0,3,6,10];p.buildIndex=tc.buildIndex??-1;
 p.x=125.5549;p.y=502.4561;p.dir=1.23456;
 p.health=tc.health??80;p.maxHealth=100;p.scale=35;
 if(tc.powers)Object.assign(p.powers,tc.powers);
 p.clanTag="CLAN";
 p.shameTimer=tc.shameTimer??0;
 p.skinIndex=4;p.tailIndex=2;p.zIndex=0;
 p.moveDir=1;p.resetMoveDir();
 if(tc.applyData!==false)p.setUserData(tc.data);
 const changed=tc.item!==undefined?p.addItem(tc.item):null;
 if(tc.powers){p.alive=true;p.applyPowers();}
 const outsider={id:"other"};
 const data=p.getData(outsider);
 console.log(["IDENTITY",tc.name,p.id,p.sid,p.name,
  p.shownName(outsider),p.shownName(p),p.skinColor,p.anon?1:0,
  p.isMember?1:0,p.alive?1:0,p.active?1:0,
  p.moveDir===undefined?"~":String(p.moveDir),owned(p.skins),
  owned(p.tails),p.items.join(","),p.buildIndex,changed===null?"~":changed?1:0,
  p.displaySkin(),p.scale,p.maxHealth,p.health,
  formattedData(data)].join("|"));
}
