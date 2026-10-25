-- SPDX-License-Identifier: AGPL-3.0-only
-- Full port of Node Player.gather: terrain collection, structure damage,
-- melee against players and animals, steals, shields, poison and hit effects.
-- Works only with real Player callbacks, world grids, weapon data and variants.
local Config=require("src.game.config")
local Sync=require("server-lua.world.snapshot")
local Gather={}
local PI=math.pi
local function truthy(x) return x~=nil and x~=false and x~=0 end
local function jsOr(x,fallback) return truthy(x) and x or fallback end
local function atan2(y,x)
  if math.atan2 then return math.atan2(y,x) end
  return math.atan(y,x)
end
local function distance(x1,y1,x2,y2)
  local x,y=x1-x2,y1-y2
  return math.sqrt(x*x+y*y)
end
local function angleDist(a,b)
  local diff=math.abs(b-a)%(PI*2)
  return diff>PI and PI*2-diff or diff
end
local function hasTail(player,id) return player.tail~=nil and player.tail.id==id end
local function gatherBonus(player,typeId)
  if typeId==0 and hasTail(player,9) then return 1 end
  if typeId==2 and hasTail(player,10) then return 1 end
  if typeId==1 and hasTail(player,3) then return 1 end
  return 0
end

function Gather.step(player,opts)
  opts=opts or {}
  local cfg=opts.config or Config
  local weapon=assert(opts.weapon,"weapon data from original items.weapons required")
  local world=assert(opts.world,"world with original grid required")
  local players=assert(opts.players,"players required")
  local ais=assert(opts.ais,"AI array required")
  local weapons=assert(opts.weapons,"indexed weapon definitions required")
  assert(type(opts.nowMs)=="number","server timestamp required")
  assert(type(opts.hitObject)=="function","ObjectManager.hitObj callback required")
  assert(type(player.sendAnimation)=="function","Player.sendAnimation callback required")
  assert(type(player.earnXP)=="function" and type(player.addResource)=="function"
    and type(player.changeHealth)=="function" and type(player.variant)=="function",
    "authoritative player methods required")
  player.noMovTimer=0
  player.slowMult=math.max(0,player.slowMult-jsOr(weapon.hitSlow,0.3))
  local variant=assert(player:variant(),"weapon variant required")
  local poison=variant.poison
  local variantDamage=variant.val
  local checked={}
  local hitSomething=false
  local gridArrays=world:getGridArrays(player.x,player.y,weapon.range)
  for _,arr in ipairs(gridArrays) do
    for _,obj in ipairs(arr) do
      if obj.active and not truthy(obj.dontGather) and not checked[obj.sid]
         and Sync.objectVisible(obj,player) then
        local dist=distance(player.x,player.y,obj.x,obj.y)-obj.scale
        if dist<=weapon.range then
          local dir=atan2(obj.y-player.y,obj.x-player.x)
          if angleDist(dir,player.dir)<=cfg.gatherAngle then
            checked[obj.sid]=true
            if truthy(obj.health) then
              assert(type(obj.changeHealth)=="function","GameObject.changeHealth callback missing")
              local amount=-weapon.dmg*variantDamage*jsOr(weapon.sDmg,1)
                *(player.skin and jsOr(player.skin.bDmg,1) or 1)*player.powers.power
              if obj:changeHealth(amount,player) then
                assert(type(obj.req)=="table","building resource costs required")
                for i=1,#obj.req,2 do
                  local typeId=nil
                  for j,resource in ipairs(cfg.resourceTypes) do
                    if resource==obj.req[i] then typeId=j-1;break end
                  end
                  assert(typeId~=nil,"invalid building resource in source")
                  player:addResource(typeId,obj.req[i+1])
                end
                assert(type(opts.disableObject)=="function","ObjectManager.disableObj required")
                opts.disableObject(obj)
              end
            else
              player:earnXP(4*weapon.gather)
              local count=weapon.gather+(obj.type==3 and 4 or 0)+gatherBonus(player,obj.type)
              player:addResource(obj.type,count)
              if player.skin and truthy(player.skin.extraGold) then
                player:addResource(3,1)
              end
            end
            hitSomething=true
            opts.hitObject(obj,dir)
          end
        end
      end
    end
  end

  for _,target in ipairs(players) do
    if target~=player and target.alive
       and (target.spaceId or "surface")== (player.spaceId or "surface")
       and not truthy(target.submerged)
       and not (truthy(target.team) and target.team==player.team) then
      Gather.hitActor(player,target,weapon,variant,poison,weapons,cfg,opts)
    end
  end
  for _,target in ipairs(ais) do
    if target~=player and target.alive
       and (target.spaceId or "surface")== (player.spaceId or "surface")
       and not truthy(target.submerged)
       and not (truthy(target.team) and target.team==player.team) then
      Gather.hitActor(player,target,weapon,variant,poison,weapons,cfg,opts)
    end
  end
  player:sendAnimation(hitSomething and 1 or 0)
end

function Gather.hitActor(player,target,weapon,variant,applyPoison,weapons,cfg,opts)
  local dist=distance(player.x,player.y,target.x,target.y)-target.scale*1.8
  if dist>weapon.range then return false end
  local dir=atan2(target.y-player.y,target.x-player.x)
  if angleDist(dir,player.dir)>cfg.gatherAngle then return false end
  local steal=weapon.steal
  if truthy(steal) and type(target.addResource)=="function" then
    steal=math.min(jsOr(target.points,0),steal)
    player:addResource(3,steal)
    target:addResource(3,-steal)
  end
  local multiplier=variant.val
  if target.weaponIndex~=nil then
    local shieldWeapon=assert(weapons[target.weaponIndex],"shield target weapon missing")
    if truthy(shieldWeapon.shield) and angleDist(dir+PI,target.dir)<=cfg.shieldAngle then
      multiplier=shieldWeapon.shield
    end
  end
  local baseDmg=weapon.dmg
  local dmg=baseDmg
    *(player.skin and jsOr(player.skin.dmgMultO,1) or 1)
    *(player.tail and jsOr(player.tail.dmgMultO,1) or 1)
  if player.dragonUntil>opts.nowMs then dmg=dmg*1.05 end
  if player.superUntil>opts.nowMs then dmg=dmg*1.05 end
  dmg=dmg*player.powers.power
  local speed=0.3*jsOr(target.weightM,1)+jsOr(weapon.knock,0)
  target.xVel=target.xVel+speed*math.cos(dir)
  target.yVel=target.yVel+speed*math.sin(dir)
  if player.skin and truthy(player.skin.healD) then
    player:changeHealth(dmg*multiplier*player.skin.healD,player)
  end
  if player.tail and truthy(player.tail.healD) then
    player:changeHealth(dmg*multiplier*player.tail.healD,player)
  end
  if target.skin and truthy(target.skin.dmg) then
    player:changeHealth(-baseDmg*target.skin.dmg,target)
  end
  if target.tail and truthy(target.tail.dmg) then
    player:changeHealth(-baseDmg*target.tail.dmg,target)
  end
  if target.dmgOverTime and player.skin and truthy(player.skin.poisonDmg)
     and not (target.skin and truthy(target.skin.poisonRes)) then
    target.dmgOverTime.dmg=player.skin.poisonDmg
    target.dmgOverTime.time=jsOr(player.skin.poisonTime,1)
    target.dmgOverTime.doer=player
  end
  if target.dmgOverTime and truthy(applyPoison)
     and not (target.skin and truthy(target.skin.poisonRes)) then
    target.dmgOverTime.dmg=5
    target.dmgOverTime.time=5
    target.dmgOverTime.doer=player
  end
  if target.isPlayer and target.dmgOverTime and hasTail(player,20)
     and not truthy(target.dmgOverTime.dmg) then
    target.dmgOverTime.dmg=4
    target.dmgOverTime.time=2
    target.dmgOverTime.doer=player
  end
  if target.isPlayer and hasTail(player,14) then
    player:changeHealth(dmg*multiplier*0.05,player)
  end
  if truthy(variant.lifesteal) then
    player:changeHealth(dmg*multiplier*variant.lifesteal,player)
  end
  if target.isPlayer and hasTail(player,2) then
    player.dragonUntil=opts.nowMs+5000
  end
  if target.skin and truthy(target.skin.dmgK) then
    player.xVel=player.xVel-target.skin.dmgK*math.cos(dir)
    player.yVel=player.yVel-target.skin.dmgK*math.sin(dir)
  end
  assert(type(target.changeHealth)=="function","target.changeHealth required")
  target:changeHealth(-dmg*multiplier,player,player)
  return true
end

return Gather
