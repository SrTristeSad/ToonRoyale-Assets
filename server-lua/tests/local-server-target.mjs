// SPDX-License-Identifier: AGPL-3.0-only
// Guard the EXACT Node server launched by "Criar minha sala" in the Windows game.
// This prevents confusing it with the optional V2/private-worker mode.
import fs from "node:fs";
import assert from "node:assert/strict";
const root=new URL("../../",import.meta.url);
const read=(path)=>fs.readFileSync(new URL(path,root),"utf8");
const client=read("src/net/mooio_host.lua");
const paths=read("src/net/mooio_paths.lua");
const launcher=read("scripts/start-server.ps1");
const bundle=read("tools/build-offline-server.mjs");
const packageJson=JSON.parse(read("package.json"));
const server=read("server/src/index.js");

assert.match(client,/local\s+Paths=require\("src\.net\.mooio_paths"\)/);
assert.match(client,/local\s+script=Paths\.script\(root\)/);
assert.match(client,/Host:start\(mode,requestedIP,requestedBots\)/);
assert.match(paths,/scripts\/start-server\.ps1/);
assert.match(launcher,/server\\src\\offline\.mjs/);
assert.match(launcher,/server\\src\\index\.js/);
assert.match(launcher,/Start-Process\s+-FilePath\s+\$nodeExe/);
assert.match(bundle,/server","src","index\.js"/);
assert.match(bundle,/server","src","offline\.mjs"/);
assert.equal(packageJson.scripts["start:server"],"node server/src/index.js");
assert.match(server,/const V2_ROOM = process\.env\.MOO_IO_V2_PRIVATE_ROOM === "1"/);
assert.match(server,/new AccountStore\(DATA_DIR, \{ passwordMode: V2_ROOM \}\)/);
assert.doesNotMatch(client,/setenv\("MOO_IO_V2_PRIVATE_ROOM","1"\)/);
assert.doesNotMatch(launcher,/\$env:MOO_IO_V2_PRIVATE_ROOM\s*=\s*['"]1['"]/);
console.log("PASS: o alvo da migracao Lua e o Node LOCAL iniciado por Criar minha sala, nao o modo V2.");
