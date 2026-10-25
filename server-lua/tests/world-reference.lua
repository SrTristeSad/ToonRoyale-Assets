-- SPDX-License-Identifier: AGPL-3.0-only
-- Print byte-comparable fixtures of native Lua generation.
local seed=tonumber(arg[1] or "1")
assert(seed and seed>=0 and seed%1==0,"seed integer required")
local Crypto=require("src.protocol.original_crypto")
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local world=World.new({config=Config,random=Crypto.mulberry32(seed)})
world:generate()
print(table.concat({"CFG",Config.mapScale,Config.areaCount,Config.treesPerArea,
  Config.bushesPerArea,Config.totalRocks,Config.goldOres,
  Config.riverWidth,Config.snowBiomeTop,Config.colGrid,Config.server.cactusDamage},"|"))
for _,o in ipairs(world.objects) do
  print(table.concat({"OBJ",o.sid,string.format('%.6f',o.x),string.format('%.6f',o.y),o.scale,o.type,o.name or "-",
    o.dmg or 0,o.layer,#o.gridLocations},"|"))
end
local points={
  {100,100,35,0.6,nil,false},
  {7200,7200,35,0.6,nil,false},
  {7200,7200,35,0.6,nil,true},
  {100,12000,95,0.6,18,false},
  {100,12000,95,0.6,nil,false},
  {7200,6810,80,0.6,nil,false},
  {8000,8000,150,0.6,nil,false}
}
for _,p in ipairs(points) do
  local x,y,s,m,i,w=p[1],p[2],p[3],p[4],p[5],p[6]
  local yes=world:canPlace(x,y,s,m,i,w)
  print(table.concat({"PLACE",x,y,s,m,i or "-",w and 1 or 0,yes and 1 or 0},"|"))
end

for _,p in ipairs({
  {0,0,35},{14300,14300,80},{1000,1425,80},{1440,1440,150},
  {7200,7200,200},{-2500,7200,50},{15000,15000,50},
  {1440,7200,200},{35,35,500},{1439,1439,200}
}) do
  local groups={}
  for _,grid in ipairs(world:getGridArrays(p[1],p[2],p[3])) do
    local ids={}
    for _,o in ipairs(grid) do ids[#ids+1]=o.sid end
    groups[#groups+1]=table.concat(ids,",")
  end
  print(table.concat({"GRID",p[1],p[2],p[3],table.concat(groups,";")},"|"))
end
