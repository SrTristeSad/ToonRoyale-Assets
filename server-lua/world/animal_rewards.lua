-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.onAnimalKilled and AiManager hooks from server/src/moomoo/server.js.
-- Normal animal statistics and original Cow Cape multipliers. Crab King
-- victory, rewards, broadcast and special crown still require the original
-- fully integrated raid/scoreboard handler.
local Rewards={}
local KEYS={
 [0]="cow",[1]="pig",[2]="bull",[3]="bully",[4]="wolf",
 [5]="duck",[6]="moostafa",[7]="treasure",[8]="moofie",
 [9]="boar",[10]="yeti",[11]="crab_king",[12]="sheep",
 [13]="crab",[14]="crab"
}
local BOSSES={crab_king=true,moostafa=true,moofie=true}
local function cowCape(ai,doer)
 return ai.index==0 and doer and doer.tail and doer.tail.id==8
end
function Rewards.killScore(ai,doer)
 if cowCape(ai,doer) then return math.floor(ai.killScore*1.5+0.5) end
 return ai.killScore
end
function Rewards.dropAmount(ai,doer,amount)
 if cowCape(ai,doer) then return math.floor(amount*1.5+0.5) end
 return amount
end
function Rewards.onKill(ai,doer,opts)
 if not doer or not doer.isPlayer then return end
 local key=KEYS[ai.index]
 local stats=doer.lifeStats
 if stats then
   if BOSSES[key] then stats.bosses=stats.bosses+1
   else stats.animals=stats.animals+1 end
   if key then
     assert(type(stats.animalKills)=="table","real Player.lifeStats.animalKills required")
     stats.animalKills[key]=(stats.animalKills[key] or 0)+1
   end
 end
 if ai.index==11 then
   assert(opts and type(opts.onCrabKingKilled)=="function",
     "Crab King victory handler needed for rewards, crowns and broadcast")
   return opts.onCrabKingKilled(ai,doer)
 end
end
return Rewards
