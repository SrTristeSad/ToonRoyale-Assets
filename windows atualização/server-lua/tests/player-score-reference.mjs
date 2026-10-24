// Execute exact original Player.variant and Game.scoreCallback from source.
import fs from "node:fs";
import {config} from "../../server/src/moomoo/config.js";
const playerSrc=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const gameSrc=fs.readFileSync(new URL("../../server/src/moomoo/server.js",import.meta.url),"utf8");
const method=(src,marker,endMarker)=>{
 const start=src.indexOf(marker),end=src.indexOf(endMarker,start);
 if(start<0||end<0)throw Error("original source changed: "+marker);
 return src.slice(start+marker.length,end+endMarker.length).replace(/;\s*$/,"");
};
const variant=new Function("config","return ("+method(playerSrc,
 "this.variant = ","\n        };")+");")(config);
const score=new Function("config","return ("+method(gameSrc,
 "this.scoreCallback = ","\n        };")+");")(config);
const vars=[0,2999,3000,6999,7000,11999,12000,29999,30000,40000];
for(const xp of vars){
 for(const member of [false,true]){
  const p={weaponIndex:0,weaponXP:{0:xp},isMember:member};
  const v=variant.call(p);
  console.log(["VAR",xp,member?1:0,v.id,v.src,v.val,
    v.poison?1:0,v.lifesteal??0,v.membersOnly?1:0].join("|"));
 }
}
const scenarios=[
 {name:"positive",amount:120},
 {name:"negative",amount:-70},
 {name:"zero",amount:0},
 {name:"recover",amount:3000,points:400},
 {name:"negative-limit",amount:-300,points:110},
 {name:"statless",amount:20,noStats:true},
 {name:"no-player",amount:150,isPlayer:false},
 {name:"no-player-god",amount:-80,isPlayer:false}
];
function fmt(x){return Number(x).toFixed(3)}
for(const s of scenarios){
 const events=[];
 const p={
   isPlayer:s.isPlayer!==false,points:s.points??100,
   lifeStats:s.noStats?null:{gold:12,score:105},
   send(name,...args){events.push("SEND:"+name+":"+args.join(","))},
   earnXP(amount){events.push("XP:"+amount)}
 };
 score(p,s.amount);
 console.log(["SCORE",s.name,fmt(p.points),
  p.lifeStats?fmt(p.lifeStats.gold):"-",
  p.lifeStats?fmt(p.lifeStats.score):"-",events.join(";")].join("|"));
}
