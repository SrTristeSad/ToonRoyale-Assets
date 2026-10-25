import fs from "node:fs";
import { config } from "../../server/src/moomoo/config.js";
const src=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
function original(name){
 const at=src.indexOf("this."+name+" = function (");
 const end=src.indexOf("\n        };",at);
 if(at<0||end<0)throw Error("Original Player."+name+" changed");
 const body=src.slice(at,end+11).replace("this."+name+" = ","").replace(/;\s*$/,"");
 return new Function("config","HAT","mathABS","return ("+body+")")(config,{SHAME:45},Math.abs);
}
const methods=Object.fromEntries(["shownName","canSee","applyPowers","displaySkin","resetMoveDir"].map(n=>[n,original(n)]));
const scenes=[
 {id:"ordinary"},{id:"anonymous",anon:true},{id:"role",role:"mod",invisible:true},
 {id:"invisible",invisible:true},{id:"invis-hat",invisHat:true},
 {id:"far",far:true},{id:"large",size:1.6,healthMult:1.8},
 {id:"small",size:0.7,healthMult:0.5},{id:"shame",shameTimer:1000},
 {id:"dead",dead:true}
];
for(const t of scenes){
 const p={sid:14,name:"Hero",anon:t.anon||false,role:t.role||null,
  alive:!t.dead,skinIndex:28,shameTimer:t.shameTimer||0,
  moveDir:1.2,maxHealth:100,health:70,
  scale:config.playerScale,powers:{size:t.size||1,health:t.healthMult||1}};
 const other={isPlayer:true,x:t.far?30000:100,y:100,scale:35,
  noMovTimer:t.invisHat?1000:0,
  skin:t.invisHat?{invisTimer:500}:null,
  powers:{invisible:t.invisible?1:0}};
 p.x=100;p.y=100;
 const values={
  own:methods.shownName.call(p,p),other:methods.shownName.call(p,null),
  see:methods.canSee.call(p,other),missing:methods.canSee.call(p,null),
  skin:methods.displaySkin.call(p)
 };
 methods.applyPowers.call(p);methods.resetMoveDir.call(p);
 console.log(["PMETHOD",t.id,values.own,values.other,values.see?1:0,
 values.missing?1:0,values.skin,p.scale,p.maxHealth,p.health,
 p.moveDir===undefined?1:0].join("|"));
}
