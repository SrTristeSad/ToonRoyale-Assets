// SPDX-License-Identifier: AGPL-3.0-only
// Executes source packets.js case I and original resendData function unchanged.
import fs from "node:fs";
import items from "../../shared/config/items.js";
import {UTILS} from "../../server/src/moomoo/libs/utils.js";
import {ANTICHEAT_CONFIG} from "../../server/src/anticheat/config.js";
const text=fs.readFileSync(new URL("../../server/src/network/packets.js",import.meta.url),"utf8");
const a=text.indexOf("function resendData(");
const b=text.indexOf("export function handlePacket(");
const c=text.indexOf("function handleAdmin(",b);
if(a<0||b<0||c<0)throw Error("original packets source markers changed");
const original=text.slice(a,b)+"\n"+text.slice(b,c).replace("export function handlePacket","function handlePacket");
const handler=new Function("UTILS","ANTICHEAT_CONFIG","items",
 "const isNum=UTILS.isNumber;const isInt=Number.isInteger;"+original+
 "\nreturn handlePacket;")(UTILS,ANTICHEAT_CONFIG,items);
const specs=[
 {id:"enable",data:[1],account:"Hero",now:100000,anon:false},
 {id:"disable",data:[0],account:"Hero",now:100000,anon:true},
 {id:"repeat-enable",data:[1],account:"Hero",now:100000,anon:true},
 {id:"repeat-disable",data:[0],account:"Hero",now:100000,anon:false},
 {id:"too-soon",data:[1],account:"Hero",now:100000,changed:95000},
 {id:"border-before",data:[1],account:"Hero",now:100000,changed:90001},
 {id:"border-exact",data:[1],account:"Hero",now:100000,changed:90000},
 {id:"invalid",data:[2],account:"Hero",now:100000},
 {id:"invalid-boolean",data:[true],account:"Hero",now:100000},
 {id:"invalid-string",data:["1"],account:"Hero",now:100000},
 {id:"invalid-null",data:[null],account:"Hero",now:100000},
 {id:"invalid-empty",data:[],account:"Hero",now:100000},
 {id:"guest",data:[1],now:100000},
 {id:"empty-account",data:[1],account:"",now:100000},
 {id:"zero-time",data:[1],account:"Hero",now:9000},
 {id:"early-exact",data:[1],account:"Hero",now:10000},
 {id:"prior-change-noact",data:[1],account:"Hero",now:120000,changed:115000},
 {id:"old-change",data:[1],account:"Hero",now:120000,changed:100000}
];
const saved=Date.now;
try{
 for(const tc of specs){
  const events=[];
  Date.now=()=>tc.now;
  const p={
   id:"self",sid:7,anon:tc.anon??false,
   account:tc.account===undefined?null:{name:tc.account},
   anonChangedAt:tc.changed??0,
   sentTo:{self:1,other:2,third:3},
   anticheat:{invalid(n,reason){events.push("INVALID:"+n+":"+reason)}}
  };
  const game={players:[p,{id:"other"},{id:"third"}],leaderboardTimer:1520};
  handler({game},p,"I",tc.data);
  const keys=Object.keys(p.sentTo).sort().join(",");
  console.log(["ANON",tc.id,p.anon?1:0,p.anonChangedAt,
     game.leaderboardTimer,keys,events.join(";")].join("|"));
 }
}finally{Date.now=saved}
