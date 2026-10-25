// SPDX-License-Identifier: MIT
// The 4.0.0 + 2.0.1-4 upstream snapshots and ORIGINAL extra list are checked
// against Lua word-for-word, then actual Player.setUserData is extracted.
import fs from "node:fs";
import { config } from "../../server/src/moomoo/config.js";
import upstream from "./name-words-upstream.json" with { type:"json" };
const nameFilter=fs.readFileSync(new URL("../../server/src/moomoo/libs/nameFilter.js",import.meta.url),"utf8");
const extra=nameFilter.match(/const CLIENT_EXTRA_WORDS = (\[[^\n]+\]);/);
if(!extra)throw Error("original CLIENT_EXTRA_WORDS source changed");
const words=[...upstream.local,...upstream.base,"qweir",...JSON.parse(extra[1])];
function hex(text){return Buffer.from(text,"utf8").toString("hex")}
words.forEach((word,i)=>console.log("WORD|"+i+"|"+hex(word)));
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const start=source.indexOf("this.setUserData = function (data)");
const end=source.indexOf("\n        };",start);
if(start<0||end<0)throw Error("original Player.setUserData changed");
const body=source.slice(start,end+11).replace("this.setUserData = ","").replace(/;\s*$/,"");
const setUserData=new Function("config","NAME_WORDS","return ("+body+")")(config,words);
const cases=[
 {id:"ordinary",name:"Explorer"},{id:"spaces",name:"   Player  One   "},
 {id:"short",name:"Hi"},{id:"long",name:"LongPlayerCharacterName1234"},
 {id:"whitespace",name:"   "},{id:"empty",name:""},
 {id:"qweir",name:"qweir"},{id:"discord",name:"discord"},
 {id:"digits",name:"d1sc0rd"},{id:"decorated",name:"-Long-Player-"},
 {id:"unicode",name:"Ação bonita"},{id:"emoji",name:"Rock🔥Star"},
 {id:"punctuation",name:"User@34#&+!"},{id:"skin",name:"Player",skin:2},
 {id:"bad-skin",name:"Player",skin:999},
 {id:"anon-guest",name:"Explorer",anon:true},
 {id:"anon-account",name:"Explorer",anon:true,account:"Member"},
 {id:"anon-account-disabled",name:"Explorer",anon:false,account:"Member"},
 {id:"account-override",name:"Explorer",account:"Permanent"},
 {id:"empty-account",name:"Explorer",account:""},
 {id:"lower",name:"hello123"},
 {id:"numeric",name:1234},{id:"null",name:null},
 {id:"truth",name:true}
];
for(const tc of cases){
 const player={
  name:"old",skinColor:4,anon:true,
  account:tc.account===undefined?null:{name:tc.account}
 };
 setUserData.call(player,{name:tc.name,skin:tc.skin,anon:tc.anon});
 console.log(["NAME",tc.id,hex(player.name),player.skinColor,player.anon?1:0].join("|"));
}
