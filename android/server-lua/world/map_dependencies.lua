-- Explicit, data-only dependencies between installed maps and creature mods.
-- Maps cannot invent creatures or silently spawn unknown IDs.
local BaseTypes=require("server-lua.world.animal_types")
local Deps={}
local function contains(xs,id)
 for _,x in ipairs(xs or {}) do if x==id then return true end end
 return false
end
function Deps.required(map)
 local result,seen={},{}
 if type(map)~="table" then return result end
 if type(map.species)=="table" then
  for _,id in ipairs(map.species) do
   if type(id)=="number" and not seen[id] then result[#result+1]=id;seen[id]=true end
  end
 else
  for _,zone in ipairs(map.spaces or {}) do
   for _,mob in ipairs(zone.mobs or {}) do
    if type(mob.kind)=="number" and not seen[mob.kind] then
     result[#result+1]=mob.kind;seen[mob.kind]=true
    end
   end
  end
 end
 table.sort(result)
 return result
end
function Deps.missing(map,selected,available,base)
 local provided={}
 for id in pairs(base or BaseTypes) do provided[id]=true end
 for _,mod in ipairs(available or {}) do
  if contains(selected,mod.id) then
   for _,kind in ipairs(mod.species or {}) do provided[kind]=true end
  end
 end
 local missing={}
 for _,kind in ipairs(Deps.required(map)) do
  if not provided[kind] then missing[#missing+1]=kind end
 end
 return missing
end
function Deps.resolve(map,selected,available,maxMods,base)
 local chosen={}
 for _,id in ipairs(selected or {}) do chosen[#chosen+1]=id end
 local added={}
 for _,kind in ipairs(Deps.missing(map,chosen,available,base)) do
  local providers={}
  for _,mod in ipairs(available or {}) do
   if contains(mod.species,kind) then providers[#providers+1]=mod end
  end
  -- Never guess when different installed mods define the same creature.
  if #providers~=1 then
   local reason=#providers==0 and "mod da especie "..kind..
      " nao instalado" or "especie "..kind.." fornecida por varios mods"
   return nil,reason
  end
  local provider=providers[1]
  if not contains(chosen,provider.id) then
   if #chosen>=(maxMods or 8) then
    return nil,"limite de mods: mapa precisa de "..provider.name
   end
   chosen[#chosen+1]=provider.id
   added[#added+1]=provider.name
  end
 end
 return chosen,nil,added
end
function Deps.validateTypes(map,types)
 for _,kind in ipairs(Deps.required(map)) do
  if not (types or BaseTypes)[kind] then
   return false,"Mapa "..tostring(map and map.name or map and map.id or "")..
      " exige a especie "..kind..
      ". Ative o mod que a adiciona antes de criar a sala."
  end
 end
 return true
end
return Deps
