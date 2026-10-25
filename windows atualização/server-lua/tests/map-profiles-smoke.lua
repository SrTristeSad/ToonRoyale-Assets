-- No new protocol or fake client: validate actual server-side generation API.
local Maps=require("server-lua.world.map_profiles")
local Spaces=require("server-lua.world.map_spaces")
local Config=require("src.game.config")
local Mods=require("server-lua.world.room_mods")
local World=require("server-lua.world.objects")
local Local=require("server-lua.local_server")
local Json=require("server-lua.vendor.dkjson")

local bunker=Maps.load("server-lua/maps","bunker-e-cavernas")
assert(#bunker.spaces==4 and bunker.portals[1].style=="bunker")
assert(bunker.portals[2].style=="cave")
local bunkerSpaces=Spaces.new(bunker,Config.mapScale)
local hatch=assert(bunkerSpaces:destination("surface","entrada-bunker",35))
assert(hatch.spaceId=="bunker-01")
local basement=assert(bunkerSpaces:destination("bunker-01","descer-bunker",35))
assert(basement.spaceId=="bunker-02")
local cave=assert(bunkerSpaces:destination("bunker-02","tunel-da-gruta",35))
assert(cave.spaceId=="caverna-01")
local deep=assert(bunkerSpaces:destination("caverna-01","descer-caverna",35))
assert(deep.spaceId=="caverna-02")
assert(#bunkerSpaces:get("caverna-02").mobs==3)
local spec=Maps.load("server-lua/maps","cabana-e-mina")
assert(spec.mode=="generated" and #spec.spaces==2)
local profile=Mods.build("normal",{},"server-lua/mods")
Maps.apply(profile.config,spec)
assert(profile.config.treesPerArea==11 and Config.treesPerArea==9)
local function signature()
 local world=World.new({config=profile.config,random=Maps.random(spec.generation.seed)})
 world:loadMap(spec)
 assert(#world.objects>0)
 local first={}
 for i=1,math.min(15,#world.objects) do
  local o=world.objects[i]
  first[#first+1]=o.x..":"..o.y..":"..o.type
 end
 return table.concat(first,",")
end
assert(signature()==signature(),"local seeded generator must be reproducible")

local spaces=Spaces.new(spec,Config.mapScale)
assert(spaces:get("cabana").type=="interior")
assert(spaces:get("mina").type=="underground")
assert(not spaces:canOccupy("cabana",350,135,15),"wall did not block collision")
assert(spaces:canOccupy("cabana",600,900,20))
local entry=assert(spaces:destination("surface","entrar-cabana",20))
assert(entry.spaceId=="cabana" and entry.x==600)
local down=assert(spaces:destination("cabana","escada-mina",20))
assert(down.spaceId=="mina" and down.y==500)
local up=assert(spaces:destination("mina","subir-escada",20))
assert(up.spaceId=="cabana")
assert(spaces:destination("surface","wrong")==nil)

local authored=World.new({config=Config,random=function()return 0.5 end})
authored:loadMap(Maps.load("server-lua/maps","mapa-de-exemplo"))
assert(#authored.objects==3 and authored.objects[1].x==1200)
local invalid=Json.encode({schemaVersion=1,id="mapa-ruim",name="Mapa ruim",
 mode="authored",generation={},surface={{x=12,y=12,kind=7,scale=100}},
 portals={},spaces={}})
assert(not pcall(Maps.validate,invalid,"mapa-ruim"),"unknown resource allowed")
assert(not pcall(Maps.load,"server-lua/maps","../private"),"path traversal accepted")
local fs={
 getDirectoryItems=function() return {"cabana-e-mina.json","mapa-de-exemplo.json","unsafe.lua"} end,
 read=function(path)local f=assert(io.open(path,"rb"));local body=f:read("*a");f:close();return body end
}
assert(#Maps.available(fs,"server-lua/maps")==2)

-- Actual Local.new() uses chosen pack for LC, retaining untouched MB.
local dataDir=assert(os.getenv("MOO_IO_TEST_MOD_DATA_DIR"),"temporary CI directory required")
local options={nowMs=function()return 10000 end,bind="127.0.0.1",
 port=18963,roomCode="maptest123456789",mode="lan",
 dataDir=dataDir,guiHost=true,botCount=0,mapId="cabana-e-mina"}
local server=Local.new(options)
local lc=server.rooms.LC.room
local mb=server.rooms.MB.room
assert(lc.mapId=="cabana-e-mina" and mb.mapId=="classico")
assert(lc.mapSpaces:get("mina").type=="underground")
assert(mb.mapSpaces:get("mina")==nil)
assert(lc.config.treesPerArea==11 and mb.config.treesPerArea==Config.treesPerArea)
assert(lc.object_manager.config==lc.config)
server:close()
options.mapId="missing-map"
options.dataDir=dataDir.."/not-created"
assert(not pcall(Local.new,options),"missing map must abort before account or world creation")
print("PASS custom map core: seed, authored world, house, underground, portal, isolation")
