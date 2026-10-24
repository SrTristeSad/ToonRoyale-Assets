// SPDX-License-Identifier: AGPL-3.0-only
// Execute the exact Game.tick source, not a reimplementation of the loop.
import fs from "node:fs";
import { config } from "../../server/src/moomoo/config.js";
const text=fs.readFileSync(new URL("../../server/src/moomoo/server.js",import.meta.url),"utf8");
const start=text.indexOf("    tick() {");
const end=text.indexOf("\n    updateLeaders() {",start);
if(start<0||end<0)throw Error("Game.tick original changed");
const realTick=new Function("Date","config",
  "return ({"+text.slice(start,end)+"}).tick;")({now:()=>globalThis.testGameClock},config);
const profiles=[
 {id:"full",bots:true,players:3,projectiles:2,ais:2},
 {id:"simple",bots:false,players:1,projectiles:0,ais:0},
 {id:"empty",bots:false,players:0,projectiles:0,ais:0},
 {id:"inactive",bots:true,players:2,projectiles:1,ais:3,noStats:true}
];
for(const profile of profiles){
 const events=[];
 const mk=(name,methods)=>Object.fromEntries(
   methods.map(method=>[method,function(...args){
     events.push(name+"."+method+":"+args.map(a=>typeof a==="object"&&a&&a.label?a.label:String(a)).join(","));
   }])
 );
 const players=Array.from({length:profile.players},(_,i)=>({
   label:"p"+i,alive:i!==1,watchStats:profile.noStats?-1:i===2?-1:i,
   chatCooldown:250,tribeCooldown:350,pingCooldown:450,
   update(delta){events.push(this.label+".update:"+delta)},
   anticheat:i===0?{tick(now){events.push("anti.tick:"+now)}}:null
 }));
 const projectiles=Array.from({length:profile.projectiles},(_,i)=>({
   update(delta){events.push("shot"+i+".update:"+delta)}
 }));
 const ais=Array.from({length:profile.ais},(_,i)=>({
   active:i!==1,update(delta){events.push("ai"+i+".update:"+delta)}
 }));
 const game={
   config,lastTick:10000,leaderboardTimer:0,minimapTimer:0,
   statsTimer:0,spawnTimer:0,
   players,projectiles,ais,
   bots:profile.bots?{tick(d){events.push("bots.tick:"+d)}}:null,
   ...mk("game",["updateStructures","ensureAnimals","updateLeaders",
     "sendLeaderboard","syncPlayers","syncObjects","syncAnimals",
     "sendMinimap","sendStats"])
 };
 game.tick=realTick;
 for(const clock of [10000,10100,10500,11150,11500,13250]){
   globalThis.testGameClock=clock;
   game.tick();
   console.log(["LOOP",profile.id,clock,
     game.lastTick,game.spawnTimer,game.leaderboardTimer,
     game.minimapTimer,game.statsTimer,
     players.map(p=>[p.chatCooldown,p.tribeCooldown,p.pingCooldown].join(",")).join(";"),
     events.join("|")].join("#"));
 }
}
