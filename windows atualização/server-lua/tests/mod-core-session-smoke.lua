-- A genuine Local.new() composes the chosen game profile before world generation.
local Local=require("server-lua.local_server")
local Config=require("src.game.config")
local dir=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"),
  "dedicated temporary test directory required")
local clock=function()return 10000 end
local function server(extra)
 local opts={
  nowMs=clock,bind="127.0.0.1",port=18963,
  roomCode="modcore12345678",mode="lan",dataDir=dir,
  botCount=0,guiHost=true
 }
 for key,value in pairs(extra or {}) do opts[key]=value end
 return Local.new(opts)
end
local modified=server({
 difficulty="normal",modIds="floresta-densa,lobos-em-matilha"
})
local room=modified.rooms.LC.room
assert(room.config.treesPerArea==17 and room.config.bushesPerArea==7,
  "map mod must be active before world generation")
assert(room.config.totalRocks==54 and room.config.goldOres==12)
assert(room.config.server.roomDifficulty=="normal",
  "mods cannot overwrite selected difficulty")
assert(room.config.server.roomRules.cooperativeWolves==true,
  "cooperation mod must reach the real room's AI configuration")
assert(room.animal_manager.config==room.config,
  "animal manager must share authoritative modded room config")
assert(room.animal_manager.types==modified.rooms.LC.room.animal_manager.types)
assert(modified.rooms.MB.room.config.treesPerArea==Config.treesPerArea,
  "modified LC room must not contaminate separate MB gameplay")
assert(modified.rooms.MB.room.config.server.roomDifficulty==nil,
  "original MB room keeps reference behavior")
modified:close()
local failed=pcall(function()
  server({modIds="missing-mod-name",
    dataDir=dir.."/must-not-be-created"})
end)
assert(not failed,"unavailable mods must abort before opening world and accounts")
local original=server()
assert(original.rooms.LC.room.config.treesPerArea==Config.treesPerArea)
assert(original.rooms.LC.room.config.server.roomRules.cooperativeWolves==false)
original:close()
print("PASS Lua mod core: real generated room, no global contamination, preflight failure")
