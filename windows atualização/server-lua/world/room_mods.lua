-- Data-only server configuration. Unmodified 'normal' has byte-for-byte
-- equivalent gameplay values to the original Node baseline.
-- No loadfile, dofile, load, eval or executable Lua from community mods.
local Json=require("server-lua.vendor.dkjson")
local Config=require("src.game.config")
local Types=require("server-lua.world.animal_types")
local Creatures=require("server-lua.world.mod_creatures")
local Mods={}
local multipliers={
  pacifico={spawn=0.65,damage=0.5,speed=0.85,range=0.5},
  normal={spawn=1,damage=1,speed=1,range=1},
  dificil={spawn=1.5,damage=1.2,speed=1.1,range=1.2},
  extremo={spawn=2,damage=1.5,speed=1.2,range=1.4}
}
Mods.levels={"pacifico","normal","dificil","extremo"}
local limits={
  spawns={desired={0,200}},
  world={treesPerArea={0,50},bushesPerArea={0,50},totalRocks={0,400},goldOres={0,160}},
  rules={healthRegenPerSecond={0,30},cooperativeWolves="boolean",predictiveHostiles="boolean"},
  animals={health={1,1000000},dmg={0,10000},speed={0,0.02},
    viewRange={1,6000},turnSpeed={0,0.1}}
}
local function copy(object)
 if type(object)~="table" then return object end
 local out={}
 for k,v in pairs(object) do out[k]=copy(v) end
 return out
end
local function finite(value,range)
 return type(value)=="number" and value==value and value~=math.huge
   and value~=-math.huge and value>=range[1] and value<=range[2]
   and (range~=limits.spawns.desired or value%1==0)
end
local function validateManifest(content,id)
 assert(type(id)=="string" and #id>=2 and #id<=48
   and id:match("^[a-z][a-z0-9%-]+$"),"mod ID invalido")
 assert(type(content)=="string" and #content<=65536,"arquivo de mod muito grande")
 local data,_,why=Json.decode(content,1,Json.null)
 assert(not why and type(data)=="table" and data.id==id
    and data.schemaVersion==1 and data.requiresClient=="base",
   "manifesto de mod invalido: "..id)
 for field in pairs(data) do
  assert(field=="id" or field=="schemaVersion" or field=="requiresClient"
   or field=="name" or field=="description" or field=="changes"
   or field=="animalAnimations" or field=="newAnimals",
   "campo desconhecido no mod: "..field)
 end
 assert(type(data.name)=="string" and #data.name>0 and #data.name<=70,
   "nome de mod invalido")
 assert(data.description==nil or
   (type(data.description)=="string" and #data.description<=240),
   "descricao de mod invalida")
 assert(data.changes==nil or type(data.changes)=="table",
   "invalid optional rule changes")
 assert(type(data.changes)=="table" and next(data.changes)
   or type(data.animalAnimations)=="table" and next(data.animalAnimations)
   or type(data.newAnimals)=="table" and next(data.newAnimals),
   "mod sem mudancas")
 data.changes=data.changes or {}
 Creatures.animations(data.animalAnimations or {},63)
 Creatures.newSpecies(data.newAnimals or {})
 return data
end
-- Metadata API for the client mod picker and server diagnostics.
-- It invokes the same manifest validator as the runtime.
local function modFile(dir,id)
 assert(type(dir)=="string" and #dir>0,"diretorio de mods invalido")
 assert(type(id)=="string" and #id>=2 and #id<=48
    and id:match("^[a-z][a-z0-9%-]+$"),"mod ID invalido")
 local path=dir.."/"..id..".json"
 -- LÖVE resolves UTF-8 source paths correctly even on Windows. The standalone
 -- Lua test server uses the regular filesystem as a compatible fallback.
 local content
 if love and love.filesystem and type(love.filesystem.read)=="function" then
  local ok,data=pcall(love.filesystem.read,path)
  if ok and type(data)=="string" then content=data end
 end
 if not content then
  local f,err=io.open(path,"rb")
  assert(f,"mod nao encontrado: "..id..": "..tostring(err))
  content=f:read(65537);f:close()
 end
 return validateManifest(content,id)
end
function Mods.describe(dir,id)
 local data=modFile(dir,id)
 return {id=data.id,name=data.name,description=data.description or ""}
end
-- The menu can inspect installed mods without executing external Lua or opening
-- remote pages. Uses LÖVE's read-only filesystem API; injectable for tests.
function Mods.available(fs,dir)
 dir=dir or "server-lua/mods"
 if type(fs)~="table" or type(fs.getDirectoryItems)~="function"
   or type(fs.read)~="function" then return {} end
 local ok,files=pcall(fs.getDirectoryItems,dir)
 if not ok or type(files)~="table" then return {} end
 table.sort(files)
 local result={}
 for _,filename in ipairs(files) do
  local id=type(filename)=="string" and filename:match("^([a-z][a-z0-9%-]+)%.json$")
  if id and #id<=48 then
   local success,content=pcall(fs.read,dir.."/"..filename)
   if success and type(content)=="string" then
    local valid,manifest=pcall(validateManifest,content,id)
    if valid then
     -- Invalid gameplay patches must not appear as installable mods.
     local compatible=pcall(Mods.build,"normal",{id},dir)
     if compatible then
      local species={}
      for key in pairs(manifest.newAnimals or {}) do
       local kind=tonumber(key)
       if kind then species[#species+1]=kind end
      end
      table.sort(species)
      result[#result+1]={id=manifest.id,name=manifest.name,
        description=manifest.description or "",species=species}
     end
    end
   end
  end
 end
 return result
end
function Mods.ids(raw)
 if raw==nil or raw=="" then return {} end
 assert(type(raw)=="string" and #raw<=400,"lista de mods invalida")
 local result,seen={},{}
 for id in (raw..","):gmatch("([^,]*),") do
  id=id:match("^%s*(.-)%s*$")
  assert(#id>0 and #id<=48 and id:match("^[a-z][a-z0-9%-]+$"),
    "ID de mod invalido: "..id)
  assert(not seen[id],"mod duplicado: "..id)
  seen[id]=true;result[#result+1]=id
  assert(#result<=8,"limite de oito mods por sala")
 end
 return result
end
function Mods.build(level,ids,dir,map)
 assert(multipliers[level],"dificuldade desconhecida: "..tostring(level))
 assert(type(ids)=="table" and #ids<=8,"lista de mods invalida")
 local cfg=copy(Config)
 -- Map defaults precede mods, so an explicitly enabled world mod wins.
 -- Previously Local.new() applied the map after this function, silently
 -- undoing world trees/rocks/gold parameters on every custom map.
 if map then
  assert(type(map)=="table" and type(map.generation)=="table",
    "validated custom map required")
  for field,value in pairs(map.generation) do
   if field~="seed" then
    assert(limits.world[field],"unsupported map generation option")
    cfg[field]=value
   end
  end
 end
 local types=copy(Types)
 local spawns=cfg.server.animalSpawnPlan
 cfg.server.roomDifficulty=level
 -- All mutable gameplay options belong to this isolated room config.
 -- NORMAL deliberately stays equivalent to the original server values.
 cfg.server.roomRules={
  healthRegenPerSecond=level=="pacifico" and 6 or 0,
  cooperativeWolves=level=="dificil" or level=="extremo",
  predictiveHostiles=level=="dificil" or level=="extremo"
 }
 local factor=multipliers[level]
 if level~="normal" then
  for _,entry in ipairs(spawns) do
   if not types[entry.index].boss and not types[entry.index].fixedSpawn then
    if level=="pacifico" and types[entry.index].hostile then
     entry.desired=math.max(0,math.floor(entry.desired*factor.spawn))
    elseif level~="pacifico" then
     entry.desired=math.min(200,math.ceil(entry.desired*factor.spawn))
    end
   end
  end
  for _,ai in pairs(types) do
   if ai.hostile and not ai.boss then
    if level=="pacifico" then
     ai.hostile=false;ai.chargePlayer=false
    end
    if ai.dmg then ai.dmg=math.min(10000,ai.dmg*factor.damage) end
    if ai.speed then ai.speed=math.min(0.02,ai.speed*factor.speed) end
    if ai.viewRange then ai.viewRange=math.min(6000,ai.viewRange*factor.range) end
   end
  end
 end
 local animations=copy(map and map.animalAnimations or {})
 local used,patches={},{}
 local manifests={}
 -- Resolve species across ALL selected mods before animations and gameplay
 -- patches. A standalone animation mod may safely target a mob registered
 -- by another mod regardless of selection order.
 for _,modId in ipairs(ids) do
  assert(not manifests[modId],"duplicate mod")
  local manifest=modFile(assert(dir,"mod directory required"),modId)
  manifests[modId]=manifest
  for index,data in pairs(Creatures.newSpecies(manifest.newAnimals or {})) do
   assert(types[index]==nil and not used["creature."..index],
     "duplicate custom species: "..index)
   local entry=copy(data)
   local desired=entry.desired or 0
   entry.id=index
   entry.desired=nil
   entry.hostile=not not entry.hostile
   entry.chargePlayer=not not entry.chargePlayer
   entry.killScore=entry.killScore or 0
   entry.dmg=entry.dmg or 0
   entry.viewRange=entry.viewRange or 800
   types[index]=entry
   spawns[#spawns+1]={index=index,desired=desired,area="all"}
   used["creature."..index]=true
  end
 end
 for _,id in ipairs(ids) do
  assert(not used["mod:"..id],"mod duplicado");used["mod:"..id]=true
  local manifest=manifests[id]
  for raw,set in pairs(manifest.animalAnimations or {}) do
   local index=tonumber(raw)
   assert(types[index] and not used["animation."..index],
     "animation species missing or conflict: "..raw)
   used["animation."..index]=true
   animations[raw]=copy(set) -- rule mods override map default art
  end
  for group,entries in pairs(manifest.changes) do
   assert(limits[group] and type(entries)=="table" and next(entries),
     "grupo de mod invalido: "..tostring(group))
   if group=="world" or group=="rules" then
    local target=group=="world" and cfg or cfg.server.roomRules
    for field,value in pairs(entries) do
     local limit=limits[group][field]
     assert(limit and target[field]~=nil
       and (limit=="boolean" and type(value)=="boolean"
         or type(limit)=="table" and finite(value,limit)
           and (group~="world" or value%1==0)),
       "valor ou campo nao permitido: "..group.."."..tostring(field))
     local key=group.."."..field
     assert(not used[key],"conflito entre mods: "..key)
     used[key]=true;patches[#patches+1]={target=target,field=field,value=value}
    end
   else
   for rawIndex,fields in pairs(entries) do
    assert(type(rawIndex)=="string" and rawIndex:match("^%d+$")
      and type(fields)=="table" and next(fields),
      "indice de mod invalido")
    local index=tonumber(rawIndex)
    local target
    if group=="animals" then target=types[index] else
     for _,row in ipairs(spawns) do if row.index==index then target=row;break end end
    end
    assert(target,"indice de mod inexistente: "..group.."."..rawIndex)
    for field,value in pairs(fields) do
     local range=limits[group][field]
     assert(range and type(target[field])=="number" and finite(value,range),
       "valor ou campo nao permitido: "..group.."."..rawIndex.."."..field)
     local key=group.."."..rawIndex.."."..field
     assert(not used[key],"conflito entre mods: "..key)
     used[key]=true;patches[#patches+1]={target=target,field=field,value=value}
    end
   end
   end
  end
 end
 -- Never partially install a mod: all manifests validated before applying patches.
 for _,change in ipairs(patches) do change.target[change.field]=change.value end
 local total=0
 for _,row in ipairs(spawns) do total=total+row.desired end
 assert(total<=600,"limite de 600 animais por sala")
 return {config=cfg,types=types,difficulty=level,mods=ids,
   animations=animations}
end
return Mods
