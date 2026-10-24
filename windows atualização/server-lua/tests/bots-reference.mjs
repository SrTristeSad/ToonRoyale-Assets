// Exact LOCAL server/src/mooio/bots.js RoomBots class against the Lua port.
import fs from "node:fs";
const src=fs.readFileSync(new URL("../../server/src/mooio/bots.js",import.meta.url),"utf8");
const parsed=src.indexOf("export function parseBotCount(");
const classAt=src.indexOf("export class RoomBots");
const end=src.indexOf("export const BOT_LIMIT");
if(parsed<0||classAt<0||end<0)throw Error("LOCAL bots.js layout changed");
const parseBotCount=new Function("return ("+src.slice(parsed,classAt).trim().replace(/^export /,"")+")")();
const items={list:{0:{id:0}},weapons:{0:{range:70}}};
// Evaluate the class with the REAL constants/helpers declared above it.
const constantsAt=src.indexOf("const MAX_BOTS");
if(constantsAt<0||constantsAt>=parsed)throw Error("original bot helpers changed");
const helpers=src.slice(constantsAt,parsed);
const RoomBots=new Function("items","parseBotCount",helpers+"return ("+
 src.slice(classAt,end).trim().replace(/^export /,"")+")")(items,parseBotCount);
const originalRandom=Math.random;Math.random=()=>0.5;
const number=x=>x===undefined||x===null?"nil":Number(x).toFixed(6);
function makeGame(modifier=()=>{}){
 const player={x:1000,y:1000,scale:35,maxHealth:100,health:100,food:50,
  moveDir:undefined,dir:0,mouseState:0,buildIndex:-1,weaponIndex:0,
  alive:true,spawnCalls:0,buildCalls:0,
  setUserData(data){this.name=data.name;this.skin=data.skin},
  spawn(x){this.spawnCalls++;this.alive=true},
  buildItem(item){if(item.id!==0)throw Error("wrong original item");this.buildCalls++}};
 const game={players:[player],ais:[],game_objects:[],config:{mapScale:14400},
  addPlayer(){return player}};
 modifier(player,game);
 const bots=new RoomBots(game,1);
 return {p:player,g:game,b:bots,a:bots.agents[0]};
}
function dump(name,x){
 const {p,a}=x;
 console.log([name,p.name,String(p.isBot),String(p.spawnCalls),
  String(p.buildCalls),String(p.mouseState),number(p.dir),number(p.moveDir),
  String(p.gathering||0),number(a.at),number(a.stuck)].join("|"));
}
try {
 for(const [name,prepare,elapsed] of [
  ["WANDER",()=>{},270],
  ["GATHER",(_,g)=>g.game_objects.push({active:true,type:1,isItem:false,
    dontGather:false,x:1040,y:1000,scale:30}),270],
  ["FIGHT",(_,g)=>g.players.push({alive:true,x:1060,y:1000,scale:35}),270],
  ["FLEE",(p,g)=>{p.health=30;g.players.push({alive:true,x:1060,y:1000,scale:35})},270],
  ["HEAL",(p)=>{p.health=70;p.food=15},900],
  ["HUNT",(p,g)=>{p.food=20;g.ais.push({index:0,alive:true,active:true,
    x:1070,y:1000,scale:20})},270],
  ["STUCK",(p)=>{p.moveDir=1},1100]
 ]){const x=makeGame(prepare);x.b.decide(x.a,elapsed);dump(name,x)}
 const dead=makeGame(p=>p.alive=false);
 dead.b.decide(dead.a,2200);dead.b.decide(dead.a,2200);
 dump("RESPAWN",dead);
 const tick=makeGame();
 tick.b.tick(100);tick.b.tick(170);
 dump("TICK_270",tick);
 for(const n of [null,"","0",0,8,9,-1,1.5,"03",true]){
  let result;try{result=String(parseBotCount(n))}catch{result="error"}
  console.log("COUNT|"+String(n)+"|"+result);
 }
}finally{Math.random=originalRandom}
