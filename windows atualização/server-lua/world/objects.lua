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
  return setmetatable({config=config,random=random,objects={},grids={}},World)
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

return World
