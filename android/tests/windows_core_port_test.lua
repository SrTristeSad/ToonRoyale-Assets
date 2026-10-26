-- Port contract: Windows gameplay core is present while Android's original
-- touch controller remains the sole owner of gesture routing.
package.path="./?.lua;./?/init.lua;"..package.path
local function source(path)
  local f=assert(io.open(path,"rb"),path.." not packaged")
  local value=f:read("*a");f:close()
  return value
end
local checks={
  {"src/mobile/controls.lua","function M:attackJoystick"},
  {"src/mobile/controls.lua","function M:pressed"},
  {"src/mobile/controls.lua","function M:released"},
  {"src/mobile/controls.lua","function M:draw"},
  {"src/mobile/lua_host_thread.lua",'require("server-lua.local_server")'},
  {"src/net/mooio_host.lua",'love.thread.newThread'},
  {"src/game/mooio_home.lua","function Home:checkMapMods"},
  {"src/game/mooio_home.lua","function Home:refreshInstalled"},
  {"src/game/mooio_home.lua",'self.screen="maps"'},
  {"src/game/mooio_home.lua",'self.screen="mods"'},
  {"src/game/mooio_pause.lua",'function Pause:draw'},
  {"server-lua/local_server.lua",'require("server-lua.world.room_mods")'},
  {"server-lua/world/room_mods.lua","function Mods.build"},
  {"server-lua/world/map_profiles.lua","function Maps.load"},
  {"server-lua/world/mod_creatures.lua","newSpecies"},
  {"server-lua/world/wolf_pack.lua","return"},
  {"server-lua/world/ai.lua","return"},
  {"main.lua","function love.touchpressed"},
  {"main.lua","function love.touchmoved"},
  {"main.lua","function love.touchreleased"},
  {"main.lua",'home.screen~="create"'},
  {"main.lua",'phase=="death_choice"'},
}
for _,item in ipairs(checks) do
  local data=source(item[1])
  assert(data:find(item[2],1,true),
    "Windows/Android port contract missing "..item[1].."::"..item[2])
end
-- Independent creation screens really exist and retain map/mod options.
local Mobile=require("src.mobile.controls")
local mobile=Mobile.new()
local w,h=1280,720
local layout=mobile:layout(w,h)
assert(layout==mobile:layout(w,h))
assert(layout.move and layout.fire and #layout.skills==4)
local move,attack=layout.move,layout.fire
assert(mobile:pressed(1,move.x,move.y,w,h,14400,5)=="move")
assert(mobile:pressed(2,attack.x,attack.y,w,h,14400,5)=="attack")
assert(mobile.moveId==1 and mobile.fireId==2)
assert(mobile:released(2)=="attack")
assert(mobile:released(1)=="move")
local unpack=unpack or table.unpack
local function listings(path)
  if path=="server-lua/mods" then
    return {"lobos-em-matilha.json","novas-especies.json","mais-lobos.json"}
  elseif path=="server-lua/maps" then
    return {"bunker-e-cavernas.json","cabana-e-mina.json"}
  elseif path=="server-lua/mods/maps" then
    return {"refugio-personalizado.json","reserva-criaturas.json"}
  end
  return {}
end
love={graphics={getDimensions=function()return w,h end},
  filesystem={
    getDirectoryItems=listings,
    read=function(path)
      local file=io.open(path,"rb")
      if not file then return nil end
      local str=file:read("*a");file:close();return str
    end
  }}
local Home=require("src.game.mooio_home")
local screen=Home.new()
assert(type(screen.refreshInstalled)=="function")
assert(type(screen.checkMapMods)=="function")
assert(#screen.modCatalog>=2,"Multiple independent Windows mods unavailable")
assert(#screen.mapCatalog>=2,"Windows random/custom maps unavailable")
screen.modIds="lobos-em-matilha,mais-lobos"
screen.mapId=""
assert(screen:checkMapMods(false))
local count=0
for _ in screen.modIds:gmatch("[^,]+") do count=count+1 end
assert(count==2,"Multiple selected mods collapsed")
print("ANDROID WINDOWS CORE PORT PASS: mobile controls retained; Lua core, mods and maps present")
