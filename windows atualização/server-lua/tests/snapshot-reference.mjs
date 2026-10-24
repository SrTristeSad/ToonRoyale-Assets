// SPDX-License-Identifier: AGPL-3.0-only
// Extract and run ACTUAL original Game.syncPlayers / Game.syncObjects and
// Player.canSee / Player.getData for differential S2C packet testing.
import fs from "node:fs";
import { config } from "../../server/src/moomoo/config.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";

const gameSrc=fs.readFileSync(new URL("../../server/src/moomoo/server.js",import.meta.url),"utf8");
const a=gameSrc.indexOf("    syncPlayers(viewer) {");
const b=gameSrc.indexOf("    syncAnimals(viewer) {",a);
if (a<0||b<0) throw Error("Game.syncPlayers or syncObjects missing");
const methodText=gameSrc.slice(a,b).replace(/}\n\s*(?=\/\/ "H")/, "},\n    ");\nconst methods=new Function("config","UTILS","return ({"+methodText+"});")(config,UTILS);
const playerSrc=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
function playerFn(method) {
 const mark="this."+method+" = function (";
 const a=playerSrc.indexOf(mark);
 const b=playerSrc.indexOf("\n        };",a);
 if(a<0||b<0)throw Error("Player."+method+" changed");
 const chunk=playerSrc.slice(a,b+11).replace(new RegExp("^this\\."+method+" = "),"");
 return new Function("config","UTILS","mathABS","return "+chunk)(config,UTILS,Math.abs);
}
const canSee=playerFn("canSee");
const getData=playerFn("getData");
const repr=v=>v==null?"~":typeof v==="boolean"?(v?"true":"false"):String(v);
const printPacket=(name,args)=>console.log("PACK|"+name+"|"+args.map(v=>Array.isArray(v)?v.map(repr).join(","):repr(v)).join("|"));
function player(id,sid,x,y,options={}) {
 const p={id,sid,name:"Player"+sid,x,y,dir:0.21,
  health:100,maxHealth:100,scale:35,skinColor:0,
  team:null,clanTag:null,morph:0,dive:0,powers:{speed:1},
  anon:false,isLeader:false,skinIndex:0,tailIndex:0,iconIndex:0,zIndex:0,
  buildIndex:-1,weaponIndex:0,shameTimer:0,noMovTimer:0,
  alive:true,isPlayer:true,visiblePlayers:new Set(),attrCache:new Map(),
  sentTo:{},skin:null,role:null,disguised:false,
  canSee,getData,shownName(viewer){return this.anon&&viewer!==this?"Anon#"+this.sid:this.name},
  displaySkin(){return this.shameTimer>0?45:this.skinIndex},
  variant(){return {id:this.weaponIndex===1?1:0}},
  send(name,...args){printPacket(name,args)},
  ...options};
 return p;
}
const me=player("me",0,100,100,{team:"RED",clanTag:"Red"});
const ally=player("ally",1,180,120,{anon:true,team:"RED",clanTag:"Red",name:"Ally"});
const far=player("far",2,5000,5000,{team:"BLUE",clanTag:"Blue"});
const stealth=player("stealth",3,210,110,{skin:{invisTimer:10},noMovTimer:30});
const all=[me,ally,far,stealth];
const tree=new GameObject(0);
tree.init(110.25,150.5,0,150,0,{},null);
const friendly=new GameObject(1);
friendly.init(140,180,0,50,2,{hideFromEnemy:true,id:4},me);
const hostile=new GameObject(2);
hostile.init(180,190,0,35,2,{hideFromEnemy:true,id:3},far);
const remote=new GameObject(3);
remote.init(5000,5000,0,55,2,{},null);
const game={players:all,game_objects:[tree,friendly,hostile,remote]};
console.log("TICK|1");
methods.syncPlayers.call(game,me);
methods.syncObjects.call(game,me);
ally.x=310;
ally.weaponIndex=1;
ally.shameTimer=40;
ally.team=null;
far.x=400; far.y=200;
remote.x=350;remote.y=250;
console.log("TICK|2");
methods.syncPlayers.call(game,me);
methods.syncObjects.call(game,me);
ally.alive=false;
far.x=5000;far.y=5000;
stealth.noMovTimer=0;
me.dir=0.7;
console.log("TICK|3");
methods.syncPlayers.call(game,me);
methods.syncObjects.call(game,me);
