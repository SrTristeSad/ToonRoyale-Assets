-- Versioned data-only custom maps. The classic room does not load a pack.
local Json=require("server-lua.vendor.dkjson")
local Config=require("src.game.config")
local Maps={}
local function integer(v,lo,hi)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
  and v%1==0 and v>=lo and v<=hi
end
local function id(v)
 return type(v)=="string" and #v>=2 and #v<=48
   and v:match("^[a-z][a-z0-9%-]+$")~=nil
end
local function validText(v,max)
 return type(v)=="string" and #v>0 and #v<=max and not v:find("[%c]")
end
Maps.validId=id
local function only(t,fields)
 assert(type(t)=="table","map object must be a table")
 for k in pairs(t) do assert(fields[k],"unknown map field: "..tostring(k)) end
end
-- Presentational options are deliberately data-only. No Lua code, external
-- asset paths, or renderer names may be supplied by a community map.
local visualThemes={wood=true,rock=true,metal=true,stone=true,
  sand=true,earth=true,grass=true,ice=true,brick=true}
local entranceStyles={house=true,bunker=true,cave=true,door=true,
  hatch=true,stairs=true,tunnel=true,arch=true}
local function validateVisual(zone)
 local visual=zone.visual
 if visual==nil then
  zone.visual={floor=zone.type=="underground" and "rock" or "wood",
    wall=zone.type=="underground" and "rock" or "wood",tileSize=128}
  return
 end
 only(visual,{floor=true,wall=true,tileSize=true,name=true})
 assert(visual.floor==nil or visualThemes[visual.floor],
  "unknown map floor material")
 assert(visual.wall==nil or visualThemes[visual.wall],
  "unknown map wall material")
 assert(visual.tileSize==nil or integer(visual.tileSize,32,256),
  "invalid map tile size")
 assert(visual.name==nil or validText(visual.name,60),
  "invalid region display name")
 visual.floor=visual.floor or (zone.type=="underground" and "rock" or "wood")
 visual.wall=visual.wall or visual.floor
 visual.tileSize=visual.tileSize or 128
end
local bounds={treesPerArea={0,50},bushesPerArea={0,50},
 totalRocks={0,400},goldOres={0,160},riverWidth={0,2000},seed={1,2147483646}}
local function checkSurface(object)
 only(object,{x=true,y=true,kind=true,scale=true})
 assert(integer(object.x,0,Config.mapScale)
   and integer(object.y,0,Config.mapScale),"surface coordinates out of bounds")
 assert(integer(object.kind,0,3) and integer(object.scale,30,200),
   "surface object type or scale invalid")
end
local function checkObstacles(obstacles,w,h)
 assert(type(obstacles)=="table" and #obstacles<=256,"too many obstacles")
 for _,o in ipairs(obstacles) do
  only(o,{x=true,y=true,width=true,height=true,material=true})
  assert(o.material==nil or visualThemes[o.material],"unknown wall material")
  assert(integer(o.x,0,w) and integer(o.y,0,h)
   and integer(o.width,1,1024) and integer(o.height,1,1024)
   and o.x+o.width<=w and o.y+o.height<=h,"obstacle outside space")
 end
end
local function dims(space)
 if not space then return Config.mapScale,Config.mapScale end
 return space.width,space.height
end
local function blocked(zone,x,y)
 for _,o in ipairs(zone and zone.obstacles or {}) do
  if x>=o.x and x<=o.x+o.width and y>=o.y and y<=o.y+o.height then
   return true
  end
 end
 for _,obj in ipairs(zone and zone.interactables or {}) do
  if obj.kind=="gate" and x>=obj.x-obj.width/2
    and x<=obj.x+obj.width/2 and y>=obj.y-obj.height/2
    and y<=obj.y+obj.height/2 then return true end
 end
 return false
end
local function checkPortals(portals,source,lookup,max)
 assert(type(portals)=="table" and #portals<=max,"too many portals")
 local fromW,fromH=dims(source)
 local seen={}
 for _,p in ipairs(portals) do
  only(p,{id=true,x=true,y=true,to=true,targetX=true,targetY=true,
    style=true,label=true})
  assert(p.style==nil or entranceStyles[p.style],
    "unsupported entrance style")
  assert(p.label==nil or validText(p.label,40),"invalid entrance label")
  assert(id(p.id) and not seen[p.id],"duplicate/invalid portal")
  seen[p.id]=true
  local dest=p.to=="surface" and nil or lookup[p.to]
  assert(p.to=="surface" or dest,"portal destination unknown")
  local toW,toH=dims(dest)
  assert(integer(p.x,0,fromW) and integer(p.y,0,fromH)
   and integer(p.targetX,0,toW) and integer(p.targetY,0,toH),
    "portal entry or exit outside boundaries")
  assert(not blocked(source,p.x,p.y) and not blocked(dest,p.targetX,p.targetY),
    "portal blocked by solid geometry")
 end
end
-- Stateless interaction manifests. Runtime state belongs only to the
-- LOCAL Room; JSON files cannot specify callbacks, Lua or asset paths.
local resources={wood=true,stone=true,food=true}
local interactiveKinds={cache=true,lever=true,gate=true,node=true,switch=true}
local function checkInteractables(list,w,h,zone)
 assert(type(list)=="table" and #list<=32,"too many map interactables")
 local lookup={}
 for _,obj in ipairs(list) do
  only(obj,{id=true,kind=true,x=true,y=true,width=true,height=true,
    label=true,material=true,resource=true,amount=true,target=true,
    charges=true,cooldownMs=true})
  assert(id(obj.id) and not lookup[obj.id],"invalid or duplicate interaction ID")
  assert(interactiveKinds[obj.kind],"unsupported interaction kind")
  assert(zone or obj.kind=="cache" or obj.kind=="node",
    "surface gates and switches require collision-aware indoor physics")
  assert(integer(obj.x,120,w-120) and integer(obj.y,120,h-120),
    "interaction out of map bounds")
  assert(obj.label==nil or validText(obj.label,40),"invalid interaction label")
  assert(obj.material==nil or visualThemes[obj.material],
    "invalid interaction material")
  if obj.kind=="cache" then
   assert(resources[obj.resource] and integer(obj.amount,1,500),
     "invalid cache reward")
   assert(obj.target==nil and obj.width==nil and obj.height==nil
     and obj.charges==nil and obj.cooldownMs==nil,
     "cache cannot control gates")
  elseif obj.kind=="node" then
   assert(resources[obj.resource] and integer(obj.amount,1,500)
     and integer(obj.charges,1,20)
     and integer(obj.cooldownMs,0,120000),
     "invalid harvest node resource, charges or cooldown")
   assert(obj.target==nil and obj.width==nil and obj.height==nil,
     "harvest node cannot control a gate")
  elseif obj.kind=="lever" or obj.kind=="switch" then
   assert(id(obj.target) and obj.resource==nil and obj.amount==nil
     and obj.width==nil and obj.height==nil and obj.charges==nil,
     "invalid mechanism target")
   if obj.kind=="switch" then
    assert(integer(obj.cooldownMs,0,120000),"invalid switch cooldown")
   else
    assert(obj.cooldownMs==nil,"one-way lever cannot set cooldown")
   end
  else
   assert(integer(obj.width,24,240) and integer(obj.height,24,240)
     and obj.x+obj.width/2<w-30 and obj.y+obj.height/2<h-30
     and obj.x-obj.width/2>30 and obj.y-obj.height/2>30,
     "invalid gate size or placement")
   assert(obj.target==nil and obj.amount==nil and obj.resource==nil
     and obj.charges==nil and obj.cooldownMs==nil,
     "gate cannot hold reward")
  end
  if obj.kind~="gate" then
   assert(not blocked(zone,obj.x,obj.y),"interaction inside wall")
  else
   local rect={x=obj.x-obj.width/2,y=obj.y-obj.height/2,
     width=obj.width,height=obj.height}
   for _,wall in ipairs(zone and zone.obstacles or {}) do
    assert(not (rect.x<wall.x+wall.width and rect.x+rect.width>wall.x
      and rect.y<wall.y+wall.height and rect.y+rect.height>wall.y),
      "gate overlaps static wall")
   end
  end
  lookup[obj.id]=obj
 end
 for _,obj in ipairs(list) do
  if obj.kind=="lever" or obj.kind=="switch" then
   assert(lookup[obj.target] and lookup[obj.target].kind=="gate",
     "lever must target a gate in the same zone")
  end
 end
end

-- Optional sprite-sheet metadata for original animal IDs (0..14).
-- Maps never execute scripts or accept filesystem paths in animation packs.
local animationStates={idle=true,walk=true,attack=true,hurt=true,death=true}
local function checkAnimalAnimations(definitions)
 assert(type(definitions)=="table","animalAnimations must be an object")
 local count=0
 for key,set in pairs(definitions) do
  count=count+1
  assert(count<=15 and type(key)=="string" and key:match("^%d+$")
    and tonumber(key)>=0 and tonumber(key)<=14
    and tostring(tonumber(key))==key,"invalid animated animal ID")
  only(set,{sheet=true,frameWidth=true,frameHeight=true,
    idle=true,walk=true,attack=true,hurt=true,death=true})
  assert(type(set.sheet)=="string" and #set.sheet<=64
    and set.sheet:match("^[a-zA-Z0-9][a-zA-Z0-9_%-]*%.png$"),
    "animation sheet must be a safe PNG basename")
  assert(integer(set.frameWidth,8,512) and integer(set.frameHeight,8,512),
    "invalid animation frame dimensions")
  local clips=0
  for name in pairs(animationStates) do
   local clip=set[name]
   if clip~=nil then
    clips=clips+1
    only(clip,{row=true,frames=true,fps=true,loop=true})
    assert(integer(clip.row,0,31) and integer(clip.frames,1,24)
      and integer(clip.fps,1,30),
      "invalid animation clip: "..name)
    assert(clip.loop==nil or type(clip.loop)=="boolean",
      "animation loop must be a boolean")
   end
  end
  assert(clips>0,"animation requires at least one state")
 end
end

function Maps.validate(content,wanted)
 assert(type(content)=="string" and #content<=131072,"map pack exceeds 128 KiB")
 local map,_,why=Json.decode(content,1,Json.null)
 assert(not why and type(map)=="table","invalid map JSON")
 only(map,{schemaVersion=true,id=true,name=true,description=true,mode=true,
  generation=true,surface=true,spaces=true,portals=true,spawn=true,
  interactables=true,animalAnimations=true})
 assert(map.schemaVersion==1 and id(map.id)
   and (not wanted or wanted==map.id),"wrong map schema or ID")
 assert(validText(map.name,70) and
    (map.description==nil or validText(map.description,240)),"invalid map name/description")
 assert(map.mode=="generated" or map.mode=="authored","invalid map mode")
 assert(type(map.generation)=="table","generation must be an object")
 only(map.generation,{treesPerArea=true,bushesPerArea=true,
  totalRocks=true,goldOres=true,riverWidth=true,seed=true})
 for field,v in pairs(map.generation) do
  local r=bounds[field]
  assert(r and integer(v,r[1],r[2]),"generation out of range: "..field)
 end
 if map.mode=="authored" then
  assert(next(map.generation)==nil,"authored maps cannot also generate nature")
 end
 if map.spawn~=nil then
  only(map.spawn,{x=true,y=true})
  assert(integer(map.spawn.x,100,Config.mapScale-100)
    and integer(map.spawn.y,100,Config.mapScale-100),
    "custom spawn must be inside surface bounds")
 end
 map.surface=map.surface or {}
 assert(type(map.surface)=="table" and #map.surface<=400,"too many surface resources")
 for _,o in ipairs(map.surface) do checkSurface(o) end
 if map.mode=="authored" then assert(#map.surface>0,"empty authored map") end
 map.animalAnimations=map.animalAnimations or {}
 checkAnimalAnimations(map.animalAnimations)
 map.spaces=map.spaces or {}
 assert(type(map.spaces)=="table" and #map.spaces<=24,"too many map spaces")
 local lookup={}
 for _,zone in ipairs(map.spaces) do
  only(zone,{id=true,type=true,width=true,height=true,obstacles=true,
    portals=true,mobs=true,visual=true,interactables=true})
  assert(id(zone.id) and zone.id~="surface" and not lookup[zone.id],
    "invalid or duplicate space ID")
  assert(zone.type=="interior" or zone.type=="underground","invalid space type")
  assert(integer(zone.width,256,4096) and integer(zone.height,256,4096),
    "invalid space dimensions")
  validateVisual(zone)
  zone.obstacles=zone.obstacles or {}
  zone.portals=zone.portals or {}
  zone.interactables=zone.interactables or {}
  checkObstacles(zone.obstacles,zone.width,zone.height)
  checkInteractables(zone.interactables,zone.width,zone.height,zone)
  zone.mobs=zone.mobs or {}
  assert(type(zone.mobs)=="table" and #zone.mobs<=24,"too many indoor mobs")
  for _,mob in ipairs(zone.mobs) do
   only(mob,{kind=true,x=true,y=true})
   assert(integer(mob.kind,0,63) and mob.kind~=11,"invalid mob index")
   assert(integer(mob.x,100,zone.width-100) and integer(mob.y,100,zone.height-100),
    "mob spawn out of zone")
   assert(not blocked(zone,mob.x,mob.y),"mob spawn inside wall")
  end
  lookup[zone.id]=zone
 end
 map.portals=map.portals or {}
 map.interactables=map.interactables or {}
 checkInteractables(map.interactables,Config.mapScale,Config.mapScale,nil)
 checkPortals(map.portals,nil,lookup,64)
 for _,zone in ipairs(map.spaces) do
  checkPortals(zone.portals,zone,lookup,32)
  -- Gates must never isolate a transition or cover the arrival/exit pad.
  -- A reversible mechanism must always be able to close safely after
  -- its destination passage has been used.
  for _,obj in ipairs(zone.interactables or {}) do
   if obj.kind=="gate" then
    for _,portal in ipairs(zone.portals or {}) do
     local px=math.max(obj.x-obj.width/2,
       math.min(obj.x+obj.width/2,portal.x))
     local py=math.max(obj.y-obj.height/2,
       math.min(obj.y+obj.height/2,portal.y))
     local dx,dy=portal.x-px,portal.y-py
     assert(dx*dx+dy*dy>80*80,
       "map gate too close to passage: "..obj.id)
    end
   end
  end
 end
 return map
end
-- Map mods are ordinary JSON manifests in a second data-only folder.
-- Never load Lua files or silently override a bundled map with the same ID.
local function directories(dir)
 dir=dir or "server-lua/maps"
 if dir=="server-lua/maps" then
  return {dir,"server-lua/mods/maps"}
 end
 return {dir}
end
function Maps.load(dir,mapId)
 assert(id(mapId),"invalid map ID")
 local content
 for _,root in ipairs(directories(dir)) do
  local path=root.."/"..mapId..".json"
  if love and love.filesystem and type(love.filesystem.read)=="function" then
   local ok,data=pcall(love.filesystem.read,path)
   if ok and type(data)=="string" then content=data end
  end
  if not content then
   local handle=io.open(path,"rb")
   if handle then
    content=handle:read(131073)
    handle:close()
   end
  end
  if content then break end
 end
 assert(content,"map not installed: "..mapId)
 return Maps.validate(content,mapId)
end
function Maps.available(fs,dir)
 if type(fs)~="table" or type(fs.getDirectoryItems)~="function"
  or type(fs.read)~="function" then return {} end
 local found,seen={},{}
 for _,root in ipairs(directories(dir)) do
  local ok,list=pcall(fs.getDirectoryItems,root)
  if ok and type(list)=="table" then
   table.sort(list)
   for _,filename in ipairs(list) do
    local mapId=type(filename)=="string"
      and filename:match("^([a-z][a-z0-9%-]+)%.json$")
    if id(mapId) and not seen[mapId] then
     local readOK,body=pcall(fs.read,root.."/"..filename)
     if readOK and type(body)=="string" then
      local good,map=pcall(Maps.validate,body,mapId)
      if good then
       seen[mapId]=true
       found[#found+1]={id=map.id,name=map.name,
        description=map.description or "",mode=map.mode,
        spaces=#map.spaces,source=root=="server-lua/mods/maps"
          and "mod" or "base"}
      end
     end
    end
   end
  end
 end
 return found
end
function Maps.apply(cfg,map)
 if map then for field,value in pairs(map.generation) do
  if field~="seed" then cfg[field]=value end
 end end
 return cfg
end
function Maps.random(seed)
 assert(integer(seed,1,2147483646),"invalid map seed")
 local state=seed
 return function()
  state=(state*16807)%2147483647
  return (state-1)/2147483646
 end
end
return Maps
