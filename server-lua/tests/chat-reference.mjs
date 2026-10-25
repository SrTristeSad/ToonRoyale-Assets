// SPDX-License-Identifier: AGPL-3.0-only
// Execute original filterchat.js and packets.js case "6" without replacing
// their business logic; inject only the pinned bad-words@4.0.0 source list.
import fs from "node:fs";
import upstream from "./name-words-upstream.json" with {type:"json"};
import items from "../../shared/config/items.js";
import {config} from "../../server/src/moomoo/config.js";
import {UTILS} from "../../server/src/moomoo/libs/utils.js";
const words=[...upstream.local,...upstream.base];
const source=fs.readFileSync(new URL("../../server/src/moomoo/libs/filterchat.js",import.meta.url),"utf8");
const code=source.replace(/^import .*\n/gm,"")
 .replace("const chatFilter = new Filter();","const chatFilter = {list: words};")
 .replace("export const filter_chat","const filter_chat");
if(!code.includes("const chatFilter = {list: words};"))throw Error("source chatFilter changed");
const filter_chat=new Function("words",code+"\nreturn filter_chat;")(words);
const handlerSource=fs.readFileSync(new URL("../../server/src/network/packets.js",import.meta.url),"utf8");
const a=handlerSource.indexOf("export function handlePacket("),b=handlerSource.indexOf("function handleAdmin(",a);
if(a<0||b<0)throw Error("source packets handler changed");
const handler=handlerSource.slice(a,b).trim().replace(/^export /,"");
const run=new Function("items","config","UTILS","filter_chat",
 "const isNum=UTILS.isNumber;const isInt=Number.isInteger;return ("+handler+")")(
  items,config,UTILS,filter_chat);
const cases=[
 {id:"ascii",text:"Hello world"},
 {id:"censor-lower",text:"Shit happens"},
 {id:"censor-upper",text:"SHIT HAPPENS"},
 {id:"censor-inside",text:"bullshit talk"},
 {id:"censor-double",text:"shit shit"},
 {id:"censor-two",text:"fUcK and shit"},
 {id:"extended",text:"Água é bom 2026!"},
 {id:"emoji",text:"🐸 Frogs 👑 jump"},
 {id:"long-ascii",text:"123456789012345678901234567890xxxxxxxx"},
 {id:"utf16-boundary",text:"a".repeat(29)+"😀"+"Z"},
 {id:"no-ascii",text:"🔥🐷❤️"},
 {id:"punctuation",text:"{hello} ++ [wow]"},
 {id:"newline",text:"one\ntwo\rthree"},
 {id:"empty",text:""},
 {id:"nonascii-between",text:"fuçk"},
 {id:"control",text:"abc\tdef\u0001!"}
];
const hex=text=>Buffer.from(text,"utf8").toString("hex");
for(const c of cases)console.log(["FILTER",c.id,hex(filter_chat(c.text))].join("|"));
const gameCases=[
 ...cases.map(c=>({...c})),
 {id:"cooldown",text:"Hello",cooldown:100},
 {id:"shadow",text:"hello buddy",shadow:true},
 {id:"dead",text:"hello buddy",alive:false},
 {id:"bad-input",text:12},
 {id:"bad-null",text:null},
 {id:"staff-absent",text:"hello buddy",noChat:true},
 {id:"shadow-staff-absent",text:"hello buddy",noChat:true,shadow:true}
];
for(const c of gameCases){
 const events=[];
 const player={
   id:"tester",sid:7,alive:c.alive!==false,
   chatCooldown:c.cooldown??0,shadowed:!!c.shadow,
   anticheat:{invalid(packet,why){events.push("INVALID:"+packet+":"+why)}},
   send(packet,sid,text){events.push("SELF:"+packet+":"+sid+":"+hex(text))}
 };
 const game={key:"LC",players:[player],server:{
    broadcast(packet,sid,text){events.push("ALL:"+packet+":"+sid+":"+hex(text))}
 }};
 const context={game,chat:c.noChat?null:{
   gameChat(p,text,room){events.push("LOG:"+p.sid+":"+hex(text)+":"+room)}
 }};
 run(context,player,"6",[c.text]);
 console.log(["CHAT",c.id,player.chatCooldown,events.join(";")].join("|"));
}
