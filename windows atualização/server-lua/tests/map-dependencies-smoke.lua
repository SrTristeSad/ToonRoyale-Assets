-- Regression for Windows crash: selecting a map that requires mob 15
-- must choose its species mod (or fail cleanly BEFORE starting a room).
local Maps=require("server-lua.world.map_profiles")
local Mods=require("server-lua.world.room_mods")
local Deps=require("server-lua.world.map_dependencies")
local Local=require("server-lua.local_server")
local fs={
 getDirectoryItems=function(root)
  local items={}
  local process=assert(io.popen('find "'..root..'" -maxdepth 1 -type f -name "*.json" -printf "%f\\n" 2>/dev/null'))
  for name in process:lines() do items[#items+1]=name end
  process:close()
  return items
 end,
 read=function(path)
  local f=assert(io.open(path,"rb"))
  local content=f:read("*a")
  f:close()
  return content
 end
}
local maps=Maps.available(fs,"server-lua/maps")
local mods=Mods.available(fs,"server-lua/mods")
local reservation,provider
for _,map in ipairs(maps) do
 if map.id=="reserva-criaturas" then reservation=map end
end
for _,mod in ipairs(mods) do
 if mod.id=="novas-especies" then provider=mod end
end
assert(reservation and provider)
assert(#reservation.species==2 and reservation.species[1]==15
 and reservation.species[2]==16)
assert(#provider.species==2 and provider.species[1]==15
 and provider.species[2]==16)
local chosen,err,added=Deps.resolve(reservation,{},mods)
assert(chosen and #chosen==1 and chosen[1]=="novas-especies"
 and added[1]==provider.name,"missing species mod not resolved")
assert(#Deps.missing(reservation,chosen,mods)==0)
assert(#Deps.missing(reservation,{},mods)==2)
local loaded=Maps.load("server-lua/maps","reserva-criaturas")
assert(not Deps.validateTypes(loaded,Mods.build("normal",{},"server-lua/mods").types))
local p=Mods.build("normal",{"novas-especies"},"server-lua/mods")
assert(Deps.validateTypes(loaded,p.types))
local bunker=Maps.load("server-lua/maps","bunker-e-cavernas")
local plain,why=Deps.resolve(bunker,{},mods)
assert(plain and #plain==0 and not why,"built-in caverns must remain standalone")
local bad={id="bad",species={63},name="Invalido"}
assert(Deps.resolve(bad,{},mods)==nil,"unavailable species must not create a server")
-- Preserve the current game behavior: custom species are never fabricated.
local dir=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"))
local ok,reason=pcall(Local.new,{bind="127.0.0.1",roomCode="missing-creature",
 port=19123,dataDir=dir.."/invalid-species",guiHost=true,botCount=0,
 mapId="reserva-criaturas",modIds="",nowMs=function()return 100000 end})
assert(not ok and tostring(reason):find("especie 15",1,true),
 "invalid room must be rejected with a useful reason before starting")
-- Protocol token persistence expects an existing data directory in this
-- standalone fixture; the production launcher creates it before starting.
assert(os.execute('mkdir -p "'..dir..'/valid-species"'))
local valid=Local.new({bind="127.0.0.1",roomCode="valid-creature",
 port=19124,dataDir=dir.."/valid-species",guiHost=true,botCount=0,
 mapId="reserva-criaturas",modIds="novas-especies",
 nowMs=function()return 100000 end})
assert(valid.rooms.LC.room.mapId=="reserva-criaturas")
valid:close()
print("PASS map dependencies: no unsafe default, automatic species selection, early validation")
