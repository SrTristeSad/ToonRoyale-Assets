-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of server/src/moomoo/modules/projectile.js + projectileManager.js.
-- Matches projectile initialization, first-tick skip, travel, expiry, original
-- UTILS.lineInRect collision, shield checks, object damage and packets X/L/Q/Y.
local DefaultConfig=require("src.game.config")
local World=require("server-lua.world.objects")
local Projectiles={}
Projectiles.__index=Projectiles
local PI=math.pi
local function truthy(v)return v~=nil and v~=false and v~=0 end
local function jsOr(v,other)return truthy(v) and v or other end
local function fix(v,places)
  -- Node parseFloat(v.toFixed(n)), validated by differential fixture.
  local mul=10^places
  if v<0 then return -math.floor(-v*mul+0.5)/mul end
  return math.floor(v*mul+0.5)/mul
end
local function getDist(x1,y1,x2,y2)
  local x,y=x1-x2,y1-y2
  return math.sqrt(x*x+y*y)
end
local function angleDist(a,b)
  local diff=math.abs(b-a)%(2*PI)
  return diff>PI and 2*PI-diff or diff
end
-- This intentionally follows UTILS.lineInRect, including its epsilon
-- and segment clipping behavior (not a replacement general intersection).
local function lineInRect(rx,ry,rx2,ry2,x1,y1,x2,y2)
  local minX,maxX=x1,x2
  if x1>x2 then minX=x2;maxX=x1 end
  if maxX>rx2 then maxX=rx2 end
  if minX<rx then minX=rx end
  if minX>maxX then return false end
  local minY,maxY=y1,y2
  local dx=x2-x1
  if math.abs(dx)>0.0000001 then
    local a=(y2-y1)/dx
    local b=y1-a*x1
    minY=a*minX+b
    maxY=a*maxX+b
  end
  if minY>maxY then minY,maxY=maxY,minY end
  if maxY>ry2 then maxY=ry2 end
  if minY<ry then minY=ry end
  if minY>maxY then return false end
  return true
end
Projectiles.lineInRect=lineInRect

function Projectiles.new(options)
  options=options or {}
  assert(options.world and type(options.world.getGridArrays)=="function"
     and type(options.world.disableObject)=="function",
    "original ObjectManager interface required")
  assert(type(options.players)=="table" and type(options.ais)=="table",
    "player and AI lists required")
  assert(options.items and options.items.projectiles and options.items.weapons,
    "real items.projectiles and items.weapons tables required")
  local self=setmetatable({world=options.world,players=options.players,
    ais=options.ais,items=options.items,
    config=options.config or DefaultConfig,projectiles={}},Projectiles)
  return self
end

function Projectiles:addProjectile(x,y,dir,range,speed,index,owner,ignoreObj,layer)
  local data=assert(self.items.projectiles[index],"source projectile index invalid")
  local proj=nil
  for _,candidate in ipairs(self.projectiles) do
    if not candidate.active then proj=candidate;break end
  end
  if not proj then
    proj={sid=#self.projectiles}
    self.projectiles[#self.projectiles+1]=proj
  end
  proj.active=true
  proj.indx=index;proj.x=x;proj.y=y;proj.dir=dir;proj.skipMov=true
  proj.speed=speed;proj.dmg=data.dmg
  proj.scale=data.scale;proj.range=range;proj.owner=owner
  proj.sentTo={}
  proj.ignoreObj=ignoreObj
  proj.layer=jsOr(layer,data.layer)
  proj.src=data.src
  return proj
end

function Projectiles:updateOne(proj,delta)
  assert(type(delta)=="number" and delta>=0,"valid tick delta required")
  if not proj.active then return end
  local speed=proj.speed*delta
  if not proj.skipMov then
    proj.x=proj.x+speed*math.cos(proj.dir)
    proj.y=proj.y+speed*math.sin(proj.dir)
    proj.range=proj.range-speed
    if proj.range<=0 then
      proj.x=proj.x+proj.range*math.cos(proj.dir)
      proj.y=proj.y+proj.range*math.sin(proj.dir)
      speed=1
      proj.range=0
      proj.active=false
    end
  else
    proj.skipMov=false
  end
  -- Projectile.update on the original server sends X and processes collision
  -- even on the update that expires its range.
  for _,viewer in ipairs(self.players) do
    if not proj.sentTo[viewer.id] and viewer:canSee(proj) then
      proj.sentTo[viewer.id]=1
      viewer:send("X",fix(proj.x,1),fix(proj.y,1),fix(proj.dir,2),
        fix(proj.range,1),proj.speed,proj.indx,proj.layer,proj.sid)
    end
  end
  local targets={}
  local function candidate(target)
    if target.alive and target~=proj.owner
      and not (truthy(proj.owner.team) and target.team==proj.owner.team) then
      if lineInRect(target.x-target.scale,target.y-target.scale,
        target.x+target.scale,target.y+target.scale,
        proj.x,proj.y,proj.x+speed*math.cos(proj.dir),
        proj.y+speed*math.sin(proj.dir)) then
        targets[#targets+1]=target
      end
    end
  end
  for _,player in ipairs(self.players) do candidate(player) end
  for _,ai in ipairs(self.ais) do candidate(ai) end
  for _,grid in ipairs(self.world:getGridArrays(proj.x,proj.y,proj.scale)) do
    for _,obj in ipairs(grid) do
      local scale=(type(obj.getScale)=="function") and obj:getScale()
        or World.objectScale(obj)
      local already=false
      for _,hit in ipairs(targets) do if hit==obj then already=true;break end end
      if obj.active and proj.ignoreObj~=obj.sid
        and proj.layer<=obj.layer and not already
        and not truthy(obj.ignoreCollision)
        and lineInRect(obj.x-scale,obj.y-scale,obj.x+scale,obj.y+scale,
          proj.x,proj.y,proj.x+speed*math.cos(proj.dir),
          proj.y+speed*math.sin(proj.dir)) then
        targets[#targets+1]=obj
      end
    end
  end
  if #targets==0 then return end
  local hit=nil
  local closest=nil
  for _,obj in ipairs(targets) do
    local d=getDist(proj.x,proj.y,obj.x,obj.y)
    if closest==nil or d<closest then
      closest=d;hit=obj
    end
  end
  if hit.isPlayer or hit.isAI then
    local knock=0.3*jsOr(hit.weightM,1)
    hit.xVel=hit.xVel+knock*math.cos(proj.dir)
    hit.yVel=hit.yVel+knock*math.sin(proj.dir)
    local blocked=false
    if hit.weaponIndex~=nil then
      local weapon=assert(self.items.weapons[hit.weaponIndex],"missing shield weapon")
      blocked=truthy(weapon.shield)
        and angleDist(proj.dir+PI,hit.dir)<=self.config.shieldAngle
    end
    if not blocked then
      assert(type(hit.changeHealth)=="function","real victim changeHealth required")
      hit:changeHealth(-proj.dmg,proj.owner,proj.owner,proj)
    end
  else
    if truthy(hit.projDmg) and truthy(hit.health) then
      assert(type(hit.changeHealth)=="function","real structure changeHealth required")
      if hit:changeHealth(-proj.dmg) then self.world:disableObject(hit) end
    end
    for _,viewer in ipairs(self.players) do
      if viewer.active then
        if hit.sentTo and hit.sentTo[viewer.id] then
          if hit.active then
            if viewer:canSee(hit) then viewer:send("L",fix(proj.dir,2),hit.sid) end
          else
            viewer:send("Q",hit.sid)
          end
        end
        if not hit.active and hit.owner==viewer then
          assert(hit.group and hit.group.id~=nil,"destroyed item group required")
          assert(type(viewer.changeItemCount)=="function",
            "owner item counter required")
          viewer:changeItemCount(hit.group.id,-1)
        end
      end
    end
  end
  proj.active=false
  for _,viewer in ipairs(self.players) do
    if proj.sentTo[viewer.id] then
      viewer:send("Y",proj.sid,fix(closest,1))
    end
  end
end

function Projectiles:update(delta)
  for _,projectile in ipairs(self.projectiles) do
    self:updateOne(projectile,delta)
  end
end
return Projectiles
