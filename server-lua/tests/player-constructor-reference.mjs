// Extract the unchanged constructor pre-spawn state from original Player.js.
import fs from "node:fs";
import store from "../../shared/config/store.js";
const source=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const start=source.indexOf("        this.id = id;");
const end=source.indexOf("        // SPAWN:",start);
if(start<0||end<0)throw Error("Node Player constructor changed");
const original=source.slice(start,end);
const cases=[{id:"abc",sid:0},{id:"another-client",sid:47},{id:"last",sid:2}];
for(const t of cases){
 const p={};
 const make=new Function("id","sid","hats","accessories",original);
 make.call(p,t.id,t.sid,store.hats,store.accessories);
 const listed=(x)=>Object.entries(x).filter(([,v])=>v===1).map(([k])=>Number(k)).sort((a,b)=>a-b).join(",");
 console.log(["CONSTRUCTOR",p.id,p.sid,p.name,p.active?1:0,p.alive?1:0,
  p.spawned?1:0,p.watchStats,p.morph,p.dive,p.team==null?1:0,
  p.points,p.pps,p.skinIndex,p.tailIndex,p.tribeCooldown,p.chatCooldown,
  p.pingCooldown,p.powers.god,p.powers.aura,p.powers.godlike,
  p.powers.boss,p.powers.invisible,p.powers.size,p.powers.power,
  p.powers.speed,p.powers.health,listed(p.skins),listed(p.tails),
  p.itemCounts&&Object.keys(p.itemCounts).length,p.joinRequests.size
 ].join("|"));
}
