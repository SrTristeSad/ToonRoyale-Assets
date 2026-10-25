// SPDX-License-Identifier: AGPL-3.0-only
// Executes ORIGINAL packets.js handlePacket for H/c, plus original Player.addItem.
import fs from "node:fs";
import items from "../../shared/config/items.js";
import store from "../../shared/config/store.js";
import {config} from "../../server/src/moomoo/config.js";
import {UTILS} from "../../server/src/moomoo/libs/utils.js";
const src=fs.readFileSync(new URL("../../server/src/network/packets.js",import.meta.url),"utf8");
const start=src.indexOf("export function handlePacket(");
const end=src.indexOf("function handleAdmin(",start);
if(start<0||end<0)throw Error("original packets.js markers changed");
const body=src.slice(start,end).trim().replace(/^export /,"");
const handle=new Function("items","hats","accessories","config","UTILS",
 "const isNum=UTILS.isNumber;const isInt=Number.isInteger;return ("+body+")")(
 items,store.hats,store.accessories,config,UTILS);
const playerSrc=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const a=playerSrc.indexOf("this.addItem = function (");
const b=playerSrc.indexOf("\n        };",a);
if(a<0||b<0)throw Error("original addItem markers changed");
const playerAddItem=new Function("items","return ("+
 playerSrc.slice(a,b+11).replace("this.addItem = ","").replace(/;\s*$/,"")+
 ")")(items);
const accessory=store.accessories.find(x=>x.price>0&&!x.dontSell);
if(!accessory||items.weapons.length!==16||items.list.length!==23)throw Error("source catalogue drift");
const cases=[
 {id:"upgrade-axe",n:"H",args:[1],upgrAge:2},
 {id:"upgrade-sword",n:"H",args:[3],upgrAge:2,weaponIndex:1},
 {id:"upgrade-bow",n:"H",args:[9],upgrAge:6},
 {id:"upgrade-pre-fail",n:"H",args:[2],upgrAge:8},
 {id:"upgrade-pre-pass",n:"H",args:[2],upgrAge:8,weapons:[1]},
 {id:"upgrade-wall",n:"H",args:[20],upgrAge:3,buildIndex:3},
 {id:"upgrade-mill",n:"H",args:[27],upgrAge:5,buildIndex:10},
 {id:"upgrade-pre-item-fail",n:"H",args:[21],upgrAge:7},
 {id:"upgrade-pre-item-pass",n:"H",args:[21],upgrAge:7,items:[0,4,6,10]},
 {id:"upgrade-no-age",n:"H",args:[1],upgrAge:5},
 {id:"upgrade-negative",n:"H",args:[-1]},
 {id:"upgrade-invalid",n:"H",args:["1"]},
 {id:"upgrade-empty",n:"H",args:[]},
 {id:"upgrade-no-points",n:"H",args:[1],upgradePoints:0},
 {id:"upgrade-dead",n:"H",args:[1],alive:false},
 {id:"purchase-hat",n:"c",args:[1,57,0],points:800},
 {id:"purchase-hat-account",n:"c",args:[1,57,0],points:800,account:true},
 {id:"purchase-free-owned",n:"c",args:[1,51,0],points:800},
 {id:"purchase-shame",n:"c",args:[1,45,0],points:800},
 {id:"purchase-no-money",n:"c",args:[1,2,0],points:0},
 {id:"purchase-accessory",n:"c",args:[1,accessory.id,1],points:2000},
 {id:"purchase-accessory-account",n:"c",args:[1,accessory.id,1],points:2000,account:true},
 {id:"equip-hat",n:"c",args:[0,51,0]},
 {id:"equip-tail",n:"c",args:[0,accessory.id,1],ownedTail:true},
 {id:"equip-not-owned",n:"c",args:[0,57,0]},
 {id:"equip-tail-not-owned",n:"c",args:[0,accessory.id,1]},
 {id:"unequip-hat",n:"c",args:[0,0,0]},
 {id:"unequip-tail",n:"c",args:[0,0,1]},
 {id:"invalid-action",n:"c",args:[2,57,0]},
 {id:"invalid-id",n:"c",args:[1,1.5,0]},
 {id:"invalid-id-null",n:"c",args:[1,null,0]},
 {id:"store-dead",n:"c",args:[1,57,0],alive:false},
 {id:"store-buy-unknown",n:"c",args:[1,999,0],points:2000}
];
const value=x=>x===undefined?"~":x===null?"null":String(x);
for(const tc of cases){
 const events=[];
 const p={
  id:"test",sid:7,alive:tc.alive!==false,upgradePoints:tc.upgradePoints??1,
  upgrAge:tc.upgrAge??2,weaponIndex:tc.weaponIndex??0,
  buildIndex:tc.buildIndex??-1,
  weapons:tc.weapons??[0],weaponXP:[15,30],
  items:tc.items??[0,3,6,10],
  points:tc.points??1000,
  skins:Object.fromEntries(store.hats.filter(x=>x.price<=0&&!x.dontSell).map(x=>[x.id,1])),
  tails:Object.fromEntries(store.accessories.filter(x=>x.price<=0&&!x.dontSell).map(x=>[x.id,1])),
  skin:{id:51},tail:{id:accessory.id},skinIndex:51,tailIndex:accessory.id,
  account:tc.account?{id:"account"}:null,
  anticheat:{invalid(packet,why){events.push("INVALID:"+packet+":"+why)}},
  send(packet,...values){
   events.push("SEND:"+packet+":"+values.map(x=>Array.isArray(x)?x.map(value).join(","):value(x)).join(":"))
  },
  addItem:playerAddItem,
  addResource(id,count,doSend){events.push("RESOURCE:"+id+":"+count+":"+doSend);this.points+=count}
 };
 if(tc.ownedTail)p.tails[accessory.id]=1;
 const ctx={
   game:{players:[p],key:"LC"},
   accounts:{recordUnlocks(account,obj){
     events.push("UNLOCK:"+account.id+":"+JSON.stringify(obj))
   }}
 };
 handle(ctx,p,tc.n,tc.args);
 console.log(["EQUIP",tc.id,p.upgrAge,p.upgradePoints,p.weaponIndex,p.buildIndex,
  p.weapons.map(value).join(","),p.weaponXP.map(value).join(","),p.items.join(","),
  p.points,p.skinIndex,p.tailIndex,p.skin?p.skin.id:"~",p.tail?p.tail.id:"~",
  p.skins[57]||0,p.tails[accessory.id]||0,events.join(";")].join("|"));
}
