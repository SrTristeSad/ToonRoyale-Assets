// SPDX-License-Identifier: AGPL-3.0-only
// Guard the source-of-truth Node reference AND the current Lua-only Windows path.
import fs from "node:fs";
import assert from "node:assert/strict";
const root=new URL("../../",import.meta.url);
const read=path=>fs.readFileSync(new URL(path,root),"utf8");
const client=read("src/net/mooio_host.lua");
const paths=read("src/net/mooio_paths.lua");
const luaLauncher=read("scripts/start-server-lua.ps1");
const luaRun=read("server-lua/local_server.lua");
const nodeReference=read("server/src/index.js");
const nodeLauncher=read("scripts/start-server.ps1");
const packageJson=JSON.parse(read("package.json"));

assert.match(client,/local\s+Paths=require\("src\.net\.mooio_paths"\)/);
assert.match(client,/local\s+script=Paths\.script\(root\)/);
assert.match(client,/Host:start\(mode,requestedIP,requestedBots\)/);
assert.match(paths,/scripts\/start-server-lua\.ps1/);
assert.doesNotMatch(paths,/return join\(root,"scripts\/start-server\.ps1"\)/);
assert.doesNotMatch(paths,/server\/src\/index\.js/);
assert.match(luaLauncher,/MOO_IO_LUA_SERVER/);
assert.match(luaLauncher,/love\.exe/);
assert.match(luaRun,/server-lua\.world\.room/);
assert.match(nodeLauncher,/server\\src\\index\.js/);
assert.equal(packageJson.scripts["start:server"],"node server/src/index.js");
assert.match(nodeReference,/MOO_IO_V2_PRIVATE_ROOM/);
assert.doesNotMatch(client,/setenv\("MOO_IO_V2_PRIVATE_ROOM","1"\)/);
assert.doesNotMatch(luaLauncher,/\$env:MOO_IO_V2_PRIVATE_ROOM\s*=\s*['"]1['"]/);
console.log("PASS: Windows starts LOCAL Lua; historical Node source remains only as differential reference.");
