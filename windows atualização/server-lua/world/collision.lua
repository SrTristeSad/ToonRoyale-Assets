-- SPDX-License-Identifier: AGPL-3.0-only
-- Literal gameplay-geometry port of ObjectManager.checkCollision from Node.
-- Damage, trap, teleport, boost, healing and z-order effects are authoritative.
local World=require("server-lua.world.objects")
local Config=require("src.game.config")
local Geometry={}
local function direction(x1,y1,x2,y2)
  local dy,dx=y1-y2,x1-x2
  if math.atan2 then return math.atan2(dy,dx) end
  return math.atan(dy,dx) -- Lua 5.2+/5.4
end
local function sameTeam(player,owner)
  return owner and owner.team and owner.team==player.team
end
function Geometry.checkCollision(player,other,delta,options)
  options=options or {}
  delta=delta or 1
  local dx,dy=player.x-other.x,player.y-other.y
  local tmpLen=player.scale+other.scale
  if math.abs(dx)>tmpLen and math.abs(dy)>tmpLen then return false end
  local otherScale=other.isPlayer and other.scale
    or (other.getScale and other:getScale() or World.objectScale(other))
  tmpLen=player.scale+otherScale
  local penetration=math.sqrt(dx*dx+dy*dy)-tmpLen
  if penetration>0 then return false end
  local angle=direction(player.x,player.y,other.x,other.y)
  if not other.ignoreCollision then
    if other.isPlayer then
      local separation=-penetration/2
      player.x=player.x+separation*math.cos(angle)
      player.y=player.y+separation*math.sin(angle)
      other.x=other.x-separation*math.cos(angle)
      other.y=other.y-separation*math.sin(angle)
    else
      player.x=other.x+tmpLen*math.cos(angle)
      player.y=other.y+tmpLen*math.sin(angle)
      player.xVel=player.xVel*0.75
      player.yVel=player.yVel*0.75
    end
    if other.dmg and other.owner~=player and not sameTeam(player,other.owner) then
      assert(type(player.changeHealth)=="function","player.changeHealth required for damaging collisions")
      player:changeHealth(-other.dmg,other.owner,other)
      local force=1.5*(other.weightM or 1)
      player.xVel=player.xVel+force*math.cos(angle)
      player.yVel=player.yVel+force*math.sin(angle)
      if other.pDmg and not (player.skin and player.skin.poisonRes) then
        player.dmgOverTime=player.dmgOverTime or {}
        player.dmgOverTime.dmg=other.pDmg
        player.dmgOverTime.time=5
        player.dmgOverTime.doer=other.owner
      end
      if player.colDmg and other.health then
        assert(type(other.changeHealth)=="function","other.changeHealth required for contact damage")
        if other:changeHealth(-player.colDmg) then
          assert(type(options.disable)=="function","disable callback required")
          options.disable(other)
        end
        assert(type(options.hit)=="function","hit callback required")
        options.hit(other,direction(player.x,player.y,other.x,other.y))
      end
    end
  else
    if other.trap and not player.noTrap and other.owner~=player
      and not sameTeam(player,other.owner) then
      player.lockMove=true
      other.hideFromEnemy=false
    elseif other.boostSpeed then
      local speed=delta*other.boostSpeed*(other.weightM or 1)
      player.xVel=player.xVel+speed*math.cos(other.dir)
      player.yVel=player.yVel+speed*math.sin(other.dir)
    elseif other.healCol then
      player.healCol=other.healCol
    elseif other.teleport then
      assert(type(options.randomInt)=="function","randomInt required for teleport")
      local config=options.config or Config
      player.x=options.randomInt(0,config.mapScale)
      player.y=options.randomInt(0,config.mapScale)
    end
  end
  if other.zIndex and other.zIndex>(player.zIndex or 0) then
    player.zIndex=other.zIndex
  end
  return true
end
return Geometry
