// SPDX-License-Identifier: AGPL-3.0-only
// Execute ORIGINAL Player.changeHealth & Player.kill for deterministic differential checks.
import fs from "node:fs";
import { TAIL, EFFECT, hasTail } from "../../server/src/moomoo/modules/effects.js";
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
function original(name,env){
  const marker="this."+name+" = function (";
  const start=source.indexOf(marker),end=source.indexOf("\n        };",start);
  if(start<0||end<0)throw Error("Original Player."+name+" has changed");
  const expression=source.slice(start,end+11).replace("this."+name+" = ","").replace(/;\s*$/,"");
  return new Function("players","server","scoreCallback","iconCallback","TAIL","EFFECT","hasTail","Date",
    "return ("+expression+");")(env.players,env.server,env.score,env.icon,TAIL,EFFECT,hasTail,{now:()=>876500});
}
const scenarios=[
  {name:"heal",health:70,amount:15,self:true},
  {name:"heal-cap",health:95,amount:20,self:true},
  {name:"heal-full",health:100,amount:10,self:true},
  {name:"base-damage",health:100,amount:-15},
  {name:"armor",health:100,amount:-20,skin:{dmgMult:0.75},tail:{dmgMult:0.9}},
  {name:"god",health:100,amount:-40,god:1},
  {name:"blockades",health:100,amount:-40,tail:{id:15},projectile:true},
  {name:"kill",health:10,amount:-15,age:2},
  {name:"gold-steal",health:10,amount:-20,points:303,attackerSkin:{goldSteal:true}},
  {name:"skull-cape",health:10,amount:-15,age:2,iconIndex:1,attackerTail:{id:4}},
  {name:"troll-cape",health:10,amount:-15,age:2,attackerTail:{id:7},spikes:true},
  {name:"super-cape",health:10,amount:-15,attackerTail:{id:1}},
  {name:"self-damage",health:40,amount:-10,self:true},
  {name:"no-doer",health:8,amount:-9,noDoer:true},
  {name:"inert-attacker",health:8,amount:-9,attackerAlive:false},
  {name:"projectile-armor",health:100,amount:-35,tail:{id:15,dmgMult:0.8},projectile:true}
];
const fmt=n=>Number(n||0).toFixed(3);
const repr=v=>v===undefined||v===null?"~":String(v);
for(const tc of scenarios){
  const events=[];
  const p={id:"victim",sid:7,isPlayer:true,alive:true,
    x:125.5,y:250.5,health:tc.health,maxHealth:100,
    iconIndex:tc.iconIndex||0,age:tc.age||1,points:tc.points||120,
    skin:tc.skin||null,tail:tc.tail||null,powers:{god:tc.god||0},
    lifeStats:{healing:0,damage:0,kills:0},sentTo:{victim:true,attacker:true},
    hitTime:0,kills:0,canSee(){return true}};
  const attacker={id:"attacker",sid:8,isPlayer:true,alive:tc.attackerAlive!==false,
    kills:1,skin:tc.attackerSkin||null,tail:tc.attackerTail||null,
    superUntil:0,lifeStats:{healing:0,damage:0,kills:0},canSee(){return true}};
  const peers=[p,attacker];
  const server={send(id,name,...args){
    events.push("SEND:"+id+":"+name+":"+args.map(repr).join(","));
  }};
  const score=(player,amount)=>events.push("SCORE:"+player.id+":"+repr(amount));
  const icon=(player)=>events.push("ICON:"+player.id);
  const env={players:peers,server,score,icon};
  p.kill=original("kill",env);
  p.changeHealth=original("changeHealth",env);
  const who=tc.noDoer?null:tc.self?p:attacker;
  const src=tc.spikes?{group:{name:"spikes"}}:null;
  const ok=p.changeHealth(tc.amount,who,src,tc.projectile?{}:null);
  console.log(["HP",tc.name,ok?1:0,fmt(p.health),p.alive?1:0,
    fmt(p.hitTime),fmt(p.lifeStats.healing),fmt(attacker.lifeStats.damage),
    attacker.kills,attacker.lifeStats.kills,fmt(attacker.superUntil),
    events.join(";")].join("|"));
}
