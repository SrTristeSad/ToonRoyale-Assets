// Use the original ObjectManager.checkCollision with real GameObjects.
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config } from "../../server/src/moomoo/config.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";
const fmt=n=>Number(n||0).toFixed(9);
for (const type of ["solid","apart","player","trap","boost","heal","damage","teleport"]) {
  const owner={team:"Blue",sid:22};
  const p={sid:1,x:50,y:70,xVel:0.24,yVel:-0.10,scale:35,zIndex:0,team:"Red",
    health:100,skin:null,lockMove:false,healCol:0,dmgOverTime:{},colDmg:0,
    changeHealth(v) { this.health+=v;return this.health<=0; }};
  const o=new GameObject(10);
  o.init(75,75,0,20,2,{},owner);
  if (type==="apart") {o.x=500;o.y=700;}
  if (type==="player") {o.x=75;o.y=75;o.isPlayer=true;o.scale=35;}
  if (type==="trap") {o.ignoreCollision=true;o.trap=true;o.zIndex=2;}
  if (type==="boost") {o.ignoreCollision=true;o.boostSpeed=0.003;o.dir=1.1;}
  if (type==="heal") {o.ignoreCollision=true;o.healCol=8;}
  if (type==="damage") {o.dmg=20;o.pDmg=3;o.weightM=1.2;}
  if (type==="teleport") {o.ignoreCollision=true;o.teleport=true;}
  const objects=[o],manager=new ObjectManager(GameObject,objects,UTILS,config,[],{broadcast(){}});
  const prior=Math.random;
  Math.random=mulberry32(24680);
  let hit;
  try {hit=manager.checkCollision(p,o,0.5);} finally {Math.random=prior;}
  console.log(["COL",type,hit?1:0,fmt(p.x),fmt(p.y),fmt(p.xVel),fmt(p.yVel),
    fmt(o.x),fmt(o.y),p.health,p.lockMove?1:0,p.healCol||0,p.zIndex,
    p.dmgOverTime.dmg||0,p.dmgOverTime.time||0,o.hideFromEnemy===false?1:0].join("|"));
}
