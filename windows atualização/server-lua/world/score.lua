-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.scoreCallback from original server/src/moomoo/server.js.
-- Only real Player.earnXP is accepted, no duplicate ranking or economic model.
local Score={}
function Score.add(player,amount,config)
  assert(type(amount)=="number","original score delta required")
  config=assert(config,"authoritative shared config required")
  if not player or not player.isPlayer then return end
  if config.unlimitedResources and amount<0 then return end
  assert(type(player.send)=="function","real Player.send required")
  player.points=player.points+amount
  player:send("N","points",player.points,1)
  if amount>0 then
    assert(type(player.earnXP)=="function","real Player.earnXP required")
    player:earnXP(amount)
    if player.lifeStats then
      player.lifeStats.gold=player.lifeStats.gold+amount
      player.lifeStats.score=math.max(player.lifeStats.score,player.points)
    end
  end
end
return Score
