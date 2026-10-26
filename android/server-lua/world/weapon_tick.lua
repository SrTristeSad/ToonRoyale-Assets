-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of Node Player.update "USE WEAPON OR TOOL" + "Turret Gear" sections.
-- Real weapon/projectile config is injected from the original item tables.
-- No invented combat outcomes: gather/hasRes/useRes/projectiles/turret
-- must be supplied by authoritative Player and ProjectileManager.
local Tick={}
local function truthy(v) return v~=nil and v~=false and v~=0 end
local function jsOr(v,alt) return truthy(v) and v or alt end
function Tick.step(player,delta,options)
  assert(type(delta)=="number" and delta==delta and delta>=0,"invalid delta")
  assert(player and type(player.weaponIndex)=="number","Player.weaponIndex required")
  options=options or {}
  local weapon=assert(options.weapon,"original weapon definition required")
  local projectiles=options.projectiles
  if player.buildIndex<0 then
    if player.hits>0 then player.gathering=1 end
    local reload=player.reloads[player.weaponIndex]
    if reload and reload>0 then
      player.reloads[player.weaponIndex]=reload-delta
      player.gathering=player.mouseState
    elseif truthy(player.gathering) or truthy(player.autoGather) then
      local worked=true
      if weapon.gather~=nil then
        assert(type(player.gather)=="function","authoritative Player.gather required")
        player:gather(options.players)
      elseif weapon.projectile~=nil
        and type(player.hasRes)=="function"
        and player:hasRes(weapon,player.skin and player.skin.projCost or 0) then
        assert(type(player.useRes)=="function","authoritative Player.useRes required")
        assert(type(options.addProjectile)=="function","ProjectileManager.addProjectile required")
        player:useRes(weapon,player.skin and player.skin.projCost or 0)
        player.noMovTimer=0
        local projectileIndex=weapon.projectile
        local projectile=assert(projectiles and projectiles[projectileIndex],"original projectile definition required")
        local offset=player.scale*2
        local multiplier=player.skin and jsOr(player.skin.aMlt,1) or 1
        if truthy(weapon.rec) then
          player.xVel=player.xVel-weapon.rec*math.cos(player.dir)
          player.yVel=player.yVel-weapon.rec*math.sin(player.dir)
        end
        options.addProjectile(player.x+offset*math.cos(player.dir),
          player.y+offset*math.sin(player.dir),player.dir,
          projectile.range*multiplier,projectile.speed*multiplier,
          projectileIndex,player,nil,player.zIndex)
      else
        worked=false
      end
      player.gathering=player.mouseState
      if worked then
        player.reloads[player.weaponIndex]=weapon.speed*
          (player.skin and jsOr(player.skin.atkSpd,1) or 1)
      end
    end
  end
  player.hits=0
  if player.skin and truthy(player.skin.turret) then
    player.shootCount=player.shootCount-delta
    if player.shootCount<=0 then
      assert(type(player.shootTurret)=="function","Player.shootTurret required")
      player:shootTurret()
    end
  end
  return player
end
return Tick
