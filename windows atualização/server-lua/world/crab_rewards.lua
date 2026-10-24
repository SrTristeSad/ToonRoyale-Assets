-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact Crab King victory branch in Game.onAnimalKilled (server.js).
-- Keep kill eligibility, Crab Shell item 61, server message and event hook.
local Rewards={}
local CRAB_SHELL=61
function Rewards.onKill(ai,doer,ctx)
  assert(ai and ai.index==11 and doer and doer.isPlayer,
    "original Crab King defeat must have a player killer")
  assert(ctx and type(ctx.crabKillers)=="table" and
    type(ctx.broadcast)=="function",
    "real Game.crabKillers and broadcast required")
  assert(type(doer.shownName)=="function","original Player.shownName required")
  local winners={[doer]=true}
  for player,damage in pairs(ai.damageBy) do
    if player.alive and damage>=ai.maxHealth*0.05 then
      winners[player]=true
    end
  end
  for player in pairs(winners) do
    assert(type(player.skins)=="table" and type(player.send)=="function",
      "original Player.skins and Player.send required")
    ctx.crabKillers[player.sid]=true
    if player.lifeStats then
      player.lifeStats.bossKills=player.lifeStats.bossKills+1
    end
    if not player.skins[CRAB_SHELL] then
      player.skins[CRAB_SHELL]=1
      player:send("5",0,CRAB_SHELL,0)
    end
  end
  local name=doer:shownName(nil)
  ctx.broadcast("6",-1,name.." defeated the Crab King!")
  if ctx.event then
    ctx.event({kind="boss",server=ctx.key,by=name})
  end
end
return Rewards
