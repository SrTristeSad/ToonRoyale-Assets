// SPDX-License-Identifier: AGPL-3.0-only
// Execute the ACTUAL unmodified Game.generateWorld method and ObjectManager
// from Node, with the same deterministic random stream as the Lua port.
// This is a test-only PRNG; production world generation still uses Math.random.
import fs from "node:fs";
import { ObjectManager } from "../../server/src/moomoo/modules/objectManager.js";
import { GameObject } from "../../server/src/moomoo/modules/gameObject.js";
import { UTILS } from "../../server/src/moomoo/libs/utils.js";
import { config } from "../../server/src/moomoo/config.js";
import { mulberry32 } from "../../server/src/protocol/crypto.js";

const filename=new URL("../../server/src/moomoo/server.js",import.meta.url);
const source=fs.readFileSync(filename,"utf8");
const start=source.indexOf("    generateWorld() {");
const end=source.indexOf("\n    randomSecretPoint(",start);
if (start<0 || end<0) throw new Error("Original world function changed: update reference extractor");
const method=source.slice(start,end).trim();
// Construct the method from the original source; NO reimplementation in this runner.
const generate=new Function("config","UTILS",`return ({ ${method} }).generateWorld;`)(config,UTILS);
const seed=Number(process.argv[2]||1)>>>0;
const origRandom=Math.random;
Math.random=mulberry32(seed);
try {
  const objects=[];
  const server={broadcast() {},send() {}};
  const manager=new ObjectManager(GameObject,objects,UTILS,config,[],server);
  const target={game_objects:objects,object_manager:manager};
  generate.call(target);
  console.log(["CFG",config.mapScale,config.areaCount,config.treesPerArea,
    config.bushesPerArea,config.totalRocks,config.goldOres,
    config.riverWidth,config.snowBiomeTop,config.colGrid,
    config.server.cactusDamage].join("|"));
  for (const o of objects) {
    console.log(["OBJ",o.sid,o.x,o.y,o.scale,o.type,o.name||"-",
      o.dmg||0,o.layer,o.gridLocations.length].join("|"));
  }
  for (const [x,y,s,m,i,w] of [
    [100,100,35,0.6,null,false],
    [7200,7200,35,0.6,null,false],
    [7200,7200,35,0.6,null,true],
    [100,12000,95,0.6,18,false],
    [100,12000,95,0.6,null,false],
    [7200,6810,80,0.6,null,false],
    [8000,8000,150,0.6,null,false]
  ]) {
    const allowed=manager.checkItemLocation(x,y,s,m,i,w);
    console.log(["PLACE",x,y,s,m,i??"-",w?1:0,allowed?1:0].join("|"));
  }
} finally {
  Math.random=origRandom;
}
