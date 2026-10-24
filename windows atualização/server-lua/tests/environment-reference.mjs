// Reference: actual effects.js and unmodified Player.keepInWorld source.
import fs from "node:fs";
import { config } from "../../server/src/moomoo/config.js";
import { secretDistance, inSecretPool, snowFactor } from "../../server/src/moomoo/modules/effects.js";
const text=fs.readFileSync(new URL("../../server/src/moomoo/modules/player.js",import.meta.url),"utf8");
const start=text.indexOf("this.keepInWorld = function (prevX, prevY) {");
const finish=text.indexOf("\n        };",start);
if (start<0 || finish<0) throw Error("Source keepInWorld changed");
const original=text.slice(start,finish+11).replace(/^this.keepInWorld = /,"");
const keep=new Function("config","secretDistance","return "+original)(config,secretDistance);
const fmt=n=>Number(n).toFixed(6);
const positions=[
  [10,10,50,50],[14399,14399,14300,14300],[-300,7200,-320,7190],
  [-300,9000,35,9000],[-2500,7200,-2550,7200],[-3800,7250,-3790,7260],
  [-1600,5200,-1550,7000],[-400,6050,-400,7200],[50,7500,50,7490],
  [14430,7000,14400,7000],[10,14400,10,14370]
];
for(const [x,y,px,py] of positions){
  const player={x,y,xVel:0.65,yVel:-0.13,scale:35};
  keep.call(player,px,py);
  console.log(["BOUND",x,y,px,py,fmt(player.x),fmt(player.y),fmt(player.xVel),fmt(player.yVel)].join("|"));
}
const samples=[[-100,7200],[-1500,6500],[-3500,6800],[-4700,7250],[-400,9000],[100,7200],[-2200,7800]];
for(const [x,y] of samples)
  console.log(["SECRET",x,y,fmt(secretDistance(config,x,y)),inSecretPool(config,x,y)?1:0].join("|"));
for(const [skin,tail] of [[null,null],[{coldM:true},null],[null,{id:6}],[null,{id:12}]]) {
  const player={skin,tail};
  console.log(["SNOW",skin?1:0,tail?tail.id:0,fmt(snowFactor(player,config))].join("|"));
}
