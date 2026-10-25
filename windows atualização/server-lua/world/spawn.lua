-- SPDX-License-Identifier: AGPL-3.0-only
-- Spawn/reset port from server/src/moomoo/modules/player.js lines SPAWN,
-- RESET MOVE DIR, RESET RESOURCES and applyPowers.
-- All world positions use World:randomInt and World:canPlace, not invented tuning.
local DefaultConfig=require("src.game.config")
local Spawn={}

function Spawn.applyPowers(player,config)
  if not player.alive then return end
  local ratio=player.maxHealth~=0 and player.health/player.maxHealth or 1
  player.scale=config.playerScale*player.powers.size
  player.maxHealth=100*player.powers.health
  player.health=math.max(1,math.floor(player.maxHealth*ratio+0.5))
end

function Spawn.resetResources(player,moofoll,config)
  for _,name in ipairs(config.resourceTypes) do
    player[name]=config.unlimitedResources and config.unlimitedAmount
      or (moofoll and 100 or 0)
  end
  if config.unlimitedResources then player.points=config.unlimitedAmount end
end

function Spawn.spawn(player,moofoll,world,options)
  options=options or {}
  local config=options.config or DefaultConfig
  assert(world and type(world.randomInt)=="function" and type(world.canPlace)=="function",
    "spawn requires the original world manager with real placement rules")
  assert(type(options.nowMs)=="number","spawn needs a deterministic server clock")
  assert(player and type(player.sid)=="number" and type(player.powers)=="table",
    "player SID and original admin powers required")
  player.active=true
  player.alive=true
  player.lockMove=false
  player.lockDir=false
  player.minimapCounter=0
  player.chatCountdown=0
  player.shameCount=0
  player.shameTimer=0
  player.sentTo={}
  player.gathering=0
  player.autoGather=0
  player.animTime=0
  player.animSpeed=0
  player.mouseState=0
  player.buildIndex=-1
  player.weaponIndex=0
  player.dmgOverTime={}
  player.noMovTimer=0
  player.maxXP=300
  player.XP=0
  player.age=1
  player.kills=0
  player.upgrAge=2
  player.upgradePoints=0
  player.x=0
  player.y=0
  player.zIndex=0
  player.xVel=0
  player.yVel=0
  player.slowMult=1
  player.dir=0
  player.dirPlus=0
  player.targetDir=0
  player.targetAngle=0
  player.maxHealth=100
  player.health=player.maxHealth
  player.scale=config.playerScale
  player.speed=config.playerSpeed
  player.moveDir=nil
  Spawn.resetResources(player,moofoll,config)
  player.items={0,3,6,10}
  player.weapons={[0]=0} -- Node: this.weapons = [0], keyed by weapon type
  player.shootCount=0
  player.weaponXP={}
  player.reloads={}
  -- SERVER additions (distinct from original client state)
  player.spawned=true
  player.hits=0
  player.dragonUntil=0
  player.superUntil=0
  player.spawnedAt=options.nowMs
  player.lifeStats={
    kills=0,wood=0,food=0,stone=0,gold=0,damage=0,animalDamage=0,
    healing=0,animals=0,bosses=0,score=player.points,
    animalKills={},bossKills=0
  }
  Spawn.applyPowers(player,config)
  local spawnPoint=nil
  if type(world.fetchSpawnObj)=="function" then
    spawnPoint=world:fetchSpawnObj(player.sid,options)
  end
  if spawnPoint then
    player.x=spawnPoint[1]
    player.y=spawnPoint[2]
  elseif world.mapSpawn then
    -- Only custom map packs have a hub spawn. Original Node random spawns
    -- and player-owned respawn points still take precedence unchanged.
    local hub=world.mapSpawn
    for _=1,20 do
      player.x=math.max(player.scale,math.min(config.mapScale-player.scale,
        hub.x+world:randomInt(-65,65)))
      player.y=math.max(player.scale,math.min(config.mapScale-player.scale,
        hub.y+world:randomInt(-65,65)))
      if world:canPlace(player.x,player.y,player.scale,0.6,nil,true) then break end
    end
  else
    -- Matches the JS do-at-most-20 placement attempts, including the last
    -- candidate being retained even if every candidate is obstructed.
    for _=1,20 do
      player.x=world:randomInt(player.scale,config.mapScale-player.scale)
      player.y=world:randomInt(player.scale,config.mapScale-player.scale)
      if world:canPlace(player.x,player.y,player.scale,0.6,nil,true) then break end
    end
  end
  return player
end
return Spawn
