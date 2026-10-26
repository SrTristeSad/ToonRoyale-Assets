-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of Game.updateStructures / Game.turretTarget from Node server.js
-- plus GameObject.update for automatically animated building objects.
local Structures={}
local function jsTruth(v) return v~=nil and v~=false and v~=0 end
local function jsOr(v,alt) return jsTruth(v) and v or alt end
local function fix(n,places)
  local m=10^places
  if n<0 then return -math.floor(-n*m+0.5)/m end
  return math.floor(n*m+0.5)/m
end
function Structures.target(structure,players,ais)
  local owner=structure.owner
  local closest=nil
  local closestDist=math.huge
  local function consider(obj)
    local dx=obj.x-structure.x
    local dy=obj.y-structure.y
    local dist=math.sqrt(dx*dx+dy*dy)
    if dist<=structure.shootRange+jsOr(obj.scale,0) and dist<closestDist then
      closest=obj;closestDist=dist
    end
  end
  for _,player in ipairs(players) do
    if player.alive and (player.spaceId or "surface")=="surface" and player~=owner
      and not (player.skin and jsTruth(player.skin.antiTurret))
      and not (owner and jsTruth(owner.team) and player.team==owner.team)
      and not (player.skin and jsTruth(player.skin.invisTimer)
        and player.noMovTimer>=player.skin.invisTimer)
      and not jsTruth(player.powers.invisible) then
      consider(player)
    end
  end
  for _,ai in ipairs(ais) do
    if ai.active and ai.alive and not jsTruth(ai.spawnCounter)
      and not jsTruth(ai.submerged) then consider(ai) end
  end
  return closest
end

function Structures.update(world,players,ais,items,delta,opts)
  opts=opts or {}
  assert(world and type(world.updateObjects)=="table",
    "original ObjectManager.updateObjects list required")
  assert(type(players)=="table" and type(ais)=="table","actor lists required")
  assert(items and items.projectiles,"real projectile config required")
  assert(type(delta)=="number" and delta>=0,"nonnegative delta required")
  assert(type(opts.addProjectile)=="function",
    "authoritative ProjectileManager.addProjectile callback required")
  for _,obj in ipairs(world.updateObjects) do
    if obj and obj.active then
      -- The GameObject.update part runs even if this isn't a turret.
      if jsTruth(obj.xWiggle) then obj.xWiggle=obj.xWiggle*0.99^delta end
      if jsTruth(obj.yWiggle) then obj.yWiggle=obj.yWiggle*0.99^delta end
      if jsTruth(obj.turnSpeed) then obj.dir=obj.dir+obj.turnSpeed*delta end
      if obj.projectile~=nil and jsTruth(obj.shootRate)
        and jsTruth(obj.shootRange) then
        if type(obj.shootCount)~="number" then obj.shootCount=obj.shootRate end
        obj.shootCount=obj.shootCount-delta
        if obj.shootCount<=0 then
          local target=Structures.target(obj,players,ais)
          if not target then
            obj.shootCount=math.min(obj.shootRate,250)
          else
            local dir=math.atan(target.y-obj.y,target.x-obj.x)
            obj.dir=dir
            local proj=assert(items.projectiles[obj.projectile],
              "original turret projectile config missing")
            opts.addProjectile(obj.x+math.cos(dir)*(obj.scale+45),
              obj.y+math.sin(dir)*(obj.scale+45),
              dir,obj.shootRange,jsOr(proj.speed,1.6),
              obj.projectile,obj.owner,obj.sid,proj.layer)
            obj.shootCount=obj.shootRate
            for _,viewer in ipairs(players) do
              if obj.sentTo[viewer.id] and viewer:canSee(obj) then
                viewer:send("M",obj.sid,fix(dir,2))
              end
            end
          end
        end
      end
    end
  end
end
return Structures
