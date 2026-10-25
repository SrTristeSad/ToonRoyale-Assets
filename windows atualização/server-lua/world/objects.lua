-- SPDX-License-Identifier: AGPL-3.0-only
-- World object generation port of server/src/moomoo/server.js::generateWorld
-- and objectManager.js::checkItemLocation.  All constants come from the
-- already transcribed src.game.config; never invent independent tuning.
local DefaultConfig = require("src.game.config")
local World = {}
World.__index = World

local function distance(x1,y1,x2,y2)
  local dx,dy=x2-x1,y2-y1
  return math.sqrt(dx*dx+dy*dy)
end

function World.new(opts)
  opts=opts or {}
  local config=opts.config or DefaultConfig
  local random=opts.random or math.random
  assert(type(random)=="function","random() required")
  assert(config.mapScale and config.areaCount and config.colGrid
    and config.treeScales and config.bushScales and config.rockScales
    and config.snowBiomeTop and config.riverWidth,
    "world generation requires actual shared config values")
  return setmetatable({config=config,random=random,objects={},grids={},updateObjects={}},World)
end

function World:randomInt(min,max)
  -- Node UTILS.randInt: Math.floor(Math.random()*(max-min+1))+min.
  return math.floor(self.random()*(max-min+1))+min
end

function World:pick(list)
  -- Node picks one element even if the attempted placement is rejected.
  return list[math.floor(self.random()*#list)+1]
end

local function objectScale(obj, multiplier, ignoreCollisionDivision)
  multiplier=multiplier or 1
  local factor=(obj.isItem or obj.type==2 or obj.type==3 or obj.type==4)
    and 1 or (0.6*multiplier)
  return obj.scale*factor*(ignoreCollisionDivision and 1 or (obj.colDiv or 1))
end
World.objectScale=objectScale

function World:canPlace(x,y,scale,scaleMultiplier,index,ignoreWater)
  -- ObjectManager.checkItemLocation: iterate in original insertion order.
  for _,obj in ipairs(self.objects) do
    local blockScale=obj.blocker or objectScale(obj,scaleMultiplier,obj.isItem)
    if obj.active and distance(x,y,obj.x,obj.y)<scale+blockScale then
      return false
    end
  end
  local config=self.config
  if not ignoreWater and index~=18
    and y>=config.mapScale/2-config.riverWidth/2
    and y<=config.mapScale/2+config.riverWidth/2 then
    return false
  end
  return true
end

function World:addObject(x,y,scale,kind)
  local config=self.config
  -- Node ObjectManager.add: desert bushes turn into damaging cacti.
  local cactus=(kind==1 and y>=config.mapScale-config.snowBiomeTop)
  local obj={
    sid=#self.objects, x=x,y=y,dir=0,scale=scale,type=kind,
    active=true,isItem=false,colDiv=1,
    layer=(kind==0 and 3 or kind==2 and 0 or kind==4 and -1 or 2),
    name=cactus and "cactus" or nil,
    dmg=cactus and (config.server.cactusDamage or 20) or nil,
    gridLocations={}
  }
  self.objects[#self.objects+1]=obj
  -- Same colGrid intersection checks as ObjectManager.setObjectGrids.
  local cellSize=config.mapScale/config.colGrid
  local cx=math.min(config.mapScale,math.max(0,x))
  local cy=math.min(config.mapScale,math.max(0,y))
  for a=0,config.colGrid-1 do
    local cellX=a*cellSize
    for b=0,config.colGrid-1 do
      local cellY=b*cellSize
      if cx+scale>=cellX and cx-scale<=cellX+cellSize
        and cy+scale>=cellY and cy-scale<=cellY+cellSize then
        local key=a.."_"..b
        if not self.grids[key] then self.grids[key]={} end
        self.grids[key][#self.grids[key]+1]=obj
        obj.gridLocations[#obj.gridLocations+1]=key
      end
    end
  end
  return obj
end

function World:generate()
  local cfg=self.config
  local areaSize=cfg.mapScale/cfg.areaCount
  local riverTop=cfg.mapScale/2-cfg.riverWidth/2
  local riverBottom=cfg.mapScale/2+cfg.riverWidth/2
  local function place(x,y,scale,kind,ignoreWater)
    if not self:canPlace(x,y,scale,0.6,nil,ignoreWater) then return false end
    self:addObject(x,y,scale,kind)
    return true
  end
  -- JS nested for-loops are zero based; Lua's loops preserve that order.
  for ax=0,cfg.areaCount-1 do
    for ay=0,cfg.areaCount-1 do
      local left,top=ax*areaSize,ay*areaSize
      local placed,tries=0,0
      while placed<cfg.treesPerArea and tries<200 do
        tries=tries+1
        local x=self:randomInt(left,left+areaSize)
        local y=self:randomInt(top,top+areaSize)
        if not (y>=riverTop-100 and y<=riverBottom+100)
          and y<cfg.mapScale-cfg.snowBiomeTop
          and place(x,y,self:pick(cfg.treeScales),0,false) then
          placed=placed+1
        end
      end
      placed,tries=0,0
      while placed<cfg.bushesPerArea and tries<200 do
        tries=tries+1
        local x=self:randomInt(left,left+areaSize)
        local y=self:randomInt(top,top+areaSize)
        if not (y>=riverTop-50 and y<=riverBottom+50)
          and place(x,y,self:pick(cfg.bushScales),1,false) then
          placed=placed+1
        end
      end
    end
  end
  local placed,tries=0,0
  while placed<cfg.totalRocks and tries<5000 do
    tries=tries+1
    local x=self:randomInt(0,cfg.mapScale)
    local y=self:randomInt(0,cfg.mapScale)
    if place(x,y,self:pick(cfg.rockScales),2,true) then placed=placed+1 end
  end
  placed,tries=0,0
  while placed<cfg.goldOres and tries<5000 do
    tries=tries+1
    local x=self:randomInt(0,cfg.mapScale)
    local y=self:randomInt(0,cfg.mapScale)
    if place(x,y,self:pick(cfg.rockScales),3,true) then placed=placed+1 end
  end
  return self.objects
end

-- Custom maps still use the ORIGINAL MooMoo grid/world generator.
-- Positions on the surface can be declarative and scattered per session.
-- Interiors retain hand-authored local geometry and matching door endpoints.
local function squared(x,y,a,b)
 local dx,dy=x-a,y-b
 return dx*dx+dy*dy
end
function World:scatterMapPoints(profile)
 local cfg=self.config
 local extent=cfg.mapScale
 local reserved={}
 local function reserve(x,y,spacing)
  reserved[#reserved+1]={x=x,y=y,spacing=spacing}
 end
 -- Explicitly placed points remain valid for authored maps and old mods.
 for _,portal in ipairs(profile.portals or {}) do
  if type(portal.x)=="number" then reserve(portal.x,portal.y,350) end
 end
 for _,obj in ipairs(profile.interactables or {}) do
  if type(obj.x)=="number" then reserve(obj.x,obj.y,250) end
 end
 for _,item in ipairs(profile.surface or {}) do
  if type(item.x)=="number" then reserve(item.x,item.y,200) end
 end
 if profile.spawn then reserve(profile.spawn.x,profile.spawn.y,300) end
 -- Spread entrances across the world rather than clustering them
 -- around the old fixed spawn. The server picks once; each client receives
 -- the exact same authoritative coordinates via map/zone packets.
 local totalPortals=#(profile.portals or {})
 local function choose(radius,spacing,ignoreWater)
  local border=math.max(250,radius+80)
  local candidate
  for attempt=1,3200 do
   local x=self:randomInt(border,extent-border)
   local y=self:randomInt(border,extent-border)
   local enough=true
   local required=spacing*(attempt>2200 and 0.55 or 1)
   for _,site in ipairs(reserved) do
    local clearance=math.max(site.spacing or 0,required)
    if squared(x,y,site.x,site.y)<clearance*clearance then
     enough=false;break
    end
   end
   if enough and self:canPlace(x,y,radius,0.6,nil,ignoreWater) then
    candidate={x=x,y=y};break
   end
  end
  assert(candidate,"could not scatter map feature without collision")
  reserve(candidate.x,candidate.y,spacing)
  return candidate.x,candidate.y
 end
 for _,portal in ipairs(profile.portals or {}) do
  if portal.placement=="random" then
   local spacing=totalPortals>1 and extent*0.23 or 900
   portal.x,portal.y=choose(170,spacing,false)
   -- Keep 'placement' as metadata. It remains declarative and need not
   -- be revalidated or regenerated after the room is running.
  end
 end
 -- Connect every return portal to the ACTUAL randomized surface entrance.
 -- Indoor coordinates are stable, while the exit location can vary by room.
 for _,zone in ipairs(profile.spaces or {}) do
  for _,exit in ipairs(zone.portals or {}) do
   if exit.to=="surface" then
    local nearest,d2
    for _,entry in ipairs(profile.portals or {}) do
     if entry.to==zone.id then
      local d=squared(exit.x,exit.y,entry.targetX,entry.targetY)
      if not d2 or d<d2 then nearest,d2=entry,d end
     end
    end
    if nearest then exit.targetX,exit.targetY=nearest.x,nearest.y end
   end
  end
 end
 for _,obj in ipairs(profile.interactables or {}) do
  if obj.placement=="random" then
   obj.x,obj.y=choose(120,420,false)
  end
 end
end

-- Classic generate() itself stays unchanged: identical type counts,
-- shared/config.js grid subdivision, placement and collision rules.
function World:loadMap(profile)
 if not profile then return self:generate() end
 self.mapSpawn=profile.spawn
 if profile.mode=="generated" then self:generate() end
 self:scatterMapPoints(profile)
 for _,o in ipairs(profile.surface or {}) do
  if o.placement=="random" then
   for _=1,(o.count or 1) do
    local placed=false
    for attempt=1,3200 do
     local margin=math.max(240,o.scale+20)
     local x=self:randomInt(margin,self.config.mapScale-margin)
     local y=self:randomInt(margin,self.config.mapScale-margin)
     if self:canPlace(x,y,o.scale,0.6,nil,false) then
      local away=true
      for _,portal in ipairs(profile.portals or {}) do
       if squared(x,y,portal.x,portal.y)<(o.scale+300)^2 then
        away=false;break
       end
      end
      if away then
       self:addObject(x,y,o.scale,o.kind)
       placed=true;break
      end
     end
    end
    assert(placed,"could not distribute custom surface items")
   end
  else
   assert(self:canPlace(o.x,o.y,o.scale,0.6,nil,true),
     "overlapping authored map object")
   self:addObject(o.x,o.y,o.scale,o.kind)
  end
 end
 -- Keep actual passage pads clear of originally generated objects.
 local entrances={}
 for _,portal in ipairs(profile.portals or {}) do entrances[#entrances+1]=portal end
 if profile.spawn then entrances[#entrances+1]=profile.spawn end
 for _,portal in ipairs(entrances) do
  for _,obj in ipairs(self.objects) do
   if obj.active then
    local dx,dy=obj.x-portal.x,obj.y-portal.y
    local clearance=(obj.scale or 0)+105
    if dx*dx+dy*dy<clearance*clearance then self:disableObject(obj) end
   end
  end
 end
 return self.objects
end

-- ObjectManager.getGridArrays: same nine-cell order and edge checks.
-- This is called once per player's collision-substep during game updates.
function World:getGridArrays(xPos,yPos,scale)
  local cfg=self.config
  local cellSize=cfg.mapScale/cfg.colGrid
  local col=math.floor(xPos/cellSize)
  local row=math.floor(yPos/cellSize)
  local result={}
  local function push(x,y)
    local group=self.grids[x.."_"..y]
    if group then result[#result+1]=group end
  end
  push(col,row)
  if xPos+scale>=(col+1)*cellSize then
    push(col+1,row)
    if row~=0 and yPos-scale<=row*cellSize then
      push(col+1,row-1)
    elseif yPos+scale>=(row+1)*cellSize then
      push(col+1,row+1)
    end
  end
  if col~=0 and xPos-scale<=col*cellSize then
    push(col-1,row)
    if row~=0 and yPos-scale<=row*cellSize then
      push(col-1,row-1)
    elseif yPos+scale>=(row+1)*cellSize then
      push(col-1,row+1)
    end
  end
  if yPos+scale>=(row+1)*cellSize then push(col,row+1) end
  if row~=0 and yPos-scale<=row*cellSize then push(col,row-1) end
  return result
end

-- Port of ObjectManager.disableObj/removeObjGrid/fetchSpawnObj.
function World:disableObject(obj)
  if not obj or not obj.active then return false end
  obj.active=false
  if obj.owner and obj.pps then obj.owner.pps=obj.owner.pps-obj.pps end
  for _,key in ipairs(obj.gridLocations or {}) do
    local arr=self.grids[key]
    if arr then
      for i=#arr,1,-1 do if arr[i]==obj then table.remove(arr,i) end end
    end
  end
  -- ObjectManager.disableObj removes dynamic structures from updateObjects.
  if self.updateObjects then
    for i=#self.updateObjects,1,-1 do
      if self.updateObjects[i]==obj then table.remove(self.updateObjects,i);break end
    end
  end
  return true
end

-- ObjectManager.removeAllItems(sid, server) from the original LOCAL Node.
function World:removeAllItems(sid,opts)
 opts=opts or {}
 for _,obj in ipairs(self.objects) do
  if obj.active and obj.owner and obj.owner.sid==sid then
   self:disableObject(obj)
  end
 end
 if opts.broadcast then
  opts.broadcast("R",sid)
 end
end

function World:fetchSpawnObj(sid,opts)
  opts=opts or {}
  for _,obj in ipairs(self.objects) do
    if obj.active and obj.owner and obj.owner.sid==sid and obj.spawnPoint then
      local pos={obj.x,obj.y}
      self:disableObject(obj)
      assert(type(opts.broadcast)=="function","real spawn-point requires Q broadcast")
      opts.broadcast("Q",obj.sid)
      if obj.owner then
        assert(type(obj.owner.changeItemCount)=="function","spawn-point requires item counter")
        assert(obj.group and obj.group.id~=nil,"spawn-point group missing")
        obj.owner:changeItemCount(obj.group.id,-1)
      end
      return pos
    end
  end
  return nil
end

-- ObjectManager.add for constructed items: same SID reuse order and GameObject.init
-- fields.  Natural map generation keeps the existing addObject() path.
function World:addDynamic(x,y,dir,scale,kind,data,owner)
  local sid=#self.objects
  local obj=nil
  -- ObjectManager.add(gameObjects.length, ..., setSID=false)
  for _,candidate in ipairs(self.objects) do
    if candidate.sid==sid then obj=candidate;break end
  end
  if not obj then
    for _,candidate in ipairs(self.objects) do
      if not candidate.active then obj=candidate;break end
    end
  end
  if not obj then
    obj={sid=sid}
    self.objects[#self.objects+1]=obj
  end
  data=data or {}
  if not data.name and kind==1 and y>=self.config.mapScale-self.config.snowBiomeTop then
    data={name="cactus",dmg=self.config.server.cactusDamage or 20}
  end
  local oldSid=obj.sid
  -- Original GameObject.init clears all per-life fields before reusing an object.
  for k in pairs(obj) do obj[k]=nil end
  obj.sid=oldSid
  obj.sentTo={}
  obj.gridLocations={}
  obj.active=true
  obj.doUpdate=data.doUpdate
  obj.x=x;obj.y=y;obj.dir=dir
  obj.xWiggle=0;obj.yWiggle=0
  obj.scale=scale;obj.type=kind;obj.id=data.id
  obj.owner=owner;obj.name=data.name
  obj.isItem=(data.id~=nil)
  obj.group=data.group;obj.health=data.health
  obj.layer=obj.group and obj.group.layer
    or (kind==0 and 3 or kind==2 and 0 or kind==4 and -1 or 2)
  obj.colDiv=data.colDiv or 1
  for _,k in ipairs({"blocker","ignoreCollision","dontGather","hideFromEnemy",
    "friction","projDmg","dmg","pDmg","pps","turnSpeed","req","trap",
    "healCol","teleport","boostSpeed","projectile","shootRange",
    "shootRate","spawnPoint"}) do
    obj[k]=data[k]
  end
  obj.zIndex=data.zIndex or 0
  obj.shootCount=obj.shootRate
  obj.changeHealth=function(self,amount)
    self.health=self.health+amount
    return self.health<=0
  end
  local cfg=self.config
  local cell=cfg.mapScale/cfg.colGrid
  local ox=math.min(cfg.mapScale,math.max(0,obj.x))
  local oy=math.min(cfg.mapScale,math.max(0,obj.y))
  for col=0,cfg.colGrid-1 do
    local gx=col*cell
    for row=0,cfg.colGrid-1 do
      local gy=row*cell
      if ox+scale>=gx and ox-scale<=gx+cell
        and oy+scale>=gy and oy-scale<=gy+cell then
        local key=col.."_"..row
        self.grids[key]=self.grids[key] or {}
        self.grids[key][#self.grids[key]+1]=obj
        obj.gridLocations[#obj.gridLocations+1]=key
      end
    end
  end
  if obj.doUpdate then
    self.updateObjects=self.updateObjects or {}
    self.updateObjects[#self.updateObjects+1]=obj
  end
  return obj
end


return World
