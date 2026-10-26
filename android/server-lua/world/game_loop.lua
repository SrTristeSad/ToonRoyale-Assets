-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.tick scheduling port from server/src/moomoo/server.js.
-- Real subsystems (Player.update, Projectile.update, AI, clan, stats) MUST be
-- provided by the authoritative game. No "stand-in" gameplay is performed.
local GameLoop={}

local function requireMethod(value,method,owner)
  assert(value and type(value[method])=="function",
    (owner or "game").."."..method.." callback required")
  return value[method]
end

function GameLoop.tick(game,nowMs)
  assert(game and type(game.lastTick)=="number","Game.lastTick required")
  assert(type(nowMs)=="number" and nowMs==nowMs and nowMs>=game.lastTick,
    "monotonic authoritative Date.now timestamp required")
  assert(type(game.players)=="table" and type(game.projectiles)=="table"
    and type(game.ais)=="table","original Game actor arrays required")
  local cfg=assert(game.config,"original shared config required")
  assert(cfg.server and type(cfg.server.leaderboardRate)=="number"
     and type(cfg.server.statsRate)=="number"
     and type(cfg.minimapRate)=="number",
     "original leaderboard, minimap and stats timer constants required")
  local delta=nowMs-game.lastTick
  game.lastTick=nowMs

  -- Preserve the order of Game.tick, even when an effect kills an actor.
  if game.bots then requireMethod(game.bots,"tick","bots")(game.bots,delta) end
  for _,player in ipairs(game.players) do
    player.chatCooldown=player.chatCooldown-delta
    player.tribeCooldown=player.tribeCooldown-delta
    player.pingCooldown=player.pingCooldown-delta
    if player.alive then requireMethod(player,"update","player")(player,delta) end
    if player.anticheat then
      requireMethod(player.anticheat,"tick","anticheat")(player.anticheat,nowMs)
    end
  end
  for _,projectile in ipairs(game.projectiles) do
    requireMethod(projectile,"update","projectile")(projectile,delta)
  end
  requireMethod(game,"updateStructures","Game")(game,delta)
  for _,ai in ipairs(game.ais) do
    if ai.active then requireMethod(ai,"update","ai")(ai,delta) end
  end
  game.spawnTimer=game.spawnTimer-delta
  if game.spawnTimer<=0 then
    game.spawnTimer=1000
    requireMethod(game,"ensureAnimals","Game")(game)
  end
  requireMethod(game,"updateLeaders","Game")(game)
  game.leaderboardTimer=game.leaderboardTimer-delta
  if game.leaderboardTimer<=0 then
    game.leaderboardTimer=cfg.server.leaderboardRate
    requireMethod(game,"sendLeaderboard","Game")(game)
  end
  game.minimapTimer=game.minimapTimer-delta
  local sendMinimap=game.minimapTimer<=0
  if sendMinimap then game.minimapTimer=cfg.minimapRate end
  game.statsTimer=game.statsTimer-delta
  local sendStats=game.statsTimer<=0
  if sendStats then game.statsTimer=cfg.server.statsRate end
  for _,viewer in ipairs(game.players) do
    requireMethod(game,"syncPlayers","Game")(game,viewer)
    requireMethod(game,"syncObjects","Game")(game,viewer)
    requireMethod(game,"syncAnimals","Game")(game,viewer)
    if sendMinimap then
      requireMethod(game,"sendMinimap","Game")(game,viewer)
    end
    if sendStats and viewer.watchStats>=0 then
      requireMethod(game,"sendStats","Game")(game,viewer,viewer.watchStats)
    end
  end
  return delta
end

return GameLoop
