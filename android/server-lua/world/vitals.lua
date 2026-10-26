-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact periodic-health and shame-timer section of Player.update from the
-- original Node server (before SLOWER).  Call once per authoritative tick.
-- Health mutation, death and economy are delegated to the real Player methods:
-- there are NO fake combat/score implementations in this module.
local Vitals={}
local function truthy(v)
  -- JS 0, false, null and undefined are all falsy, unlike Lua 0.
  return v~=nil and v~=false and v~=0
end
function Vitals.step(player,delta,config)
  assert(type(delta)=="number" and delta==delta and delta>=0,
    "finite nonnegative millisecond tick required")
  if not player.alive then return false end
  if player.shameTimer>0 then
    player.shameTimer=player.shameTimer-delta
    if player.shameTimer<=0 then
      player.shameTimer=0
      player.shameCount=0
    end
  end
  -- The original timerCount is a closure of Player's constructor. It starts
  -- at zero and is NOT reset by spawn(), so do not reset it here either.
  if player.regenTimer==nil then player.regenTimer=0 end
  player.regenTimer=player.regenTimer-delta
  if player.regenTimer<=0 then
    local skin=player.skin
    local tail=player.tail
    local regen=(skin and truthy(skin.healthRegen) and skin.healthRegen or 0)
      +(tail and truthy(tail.healthRegen) and tail.healthRegen or 0)
    local room=config and config.server
    if room and room.roomRules then
      regen=regen+(room.roomRules.healthRegenPerSecond or 0)
    elseif room and room.roomDifficulty=="pacifico" then
      regen=regen+6 -- Legacy peaceful fixtures preserve their behavior.
    end
    if truthy(regen) then player:changeHealth(regen,player) end
    local effect=player.dmgOverTime
    if truthy(effect.dmg) then
      player:changeHealth(-effect.dmg,effect.doer)
      effect.time=effect.time-1
      if effect.time<=0 then effect.dmg=0 end
    end
    if truthy(player.healCol) then player:changeHealth(player.healCol,player) end
    local pps=player.pps+(skin and truthy(skin.pps) and skin.pps or 0)
    if truthy(pps) and player.alive then player:addResource(3,pps,true) end
    player.regenTimer=1000
  end
  return player.alive
end
return Vitals
