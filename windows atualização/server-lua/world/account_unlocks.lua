-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.recordUnlocks from the copied Node Game server.js.
local Unlocks={}
local function owned(v) return v~=nil and v~=false and v~=0 end
local function findById(entries,id)
  for _,entry in ipairs(entries) do
    if entry.id==id then return entry end
  end
end
function Unlocks.record(game,player)
  if not player.account or not game.accounts then return end
  assert(type(game.accounts.recordUnlocks)=="function",
    "persistent AccountStore.recordUnlocks required")
  local catalogue=assert(game.items,"original catalogue required")
  assert(catalogue.hats and catalogue.accessories and catalogue.weapons,
    "hats accessories and weapons from original catalogue required")
  for key,isOwned in pairs(assert(player.skins,"Player.skins required")) do
    local id=tonumber(key)
    local hat=id and findById(catalogue.hats,id)
    if owned(isOwned) and hat and (hat.price or 0)>0 then
      game.accounts.recordUnlocks(player.account,{hat=hat.id})
    end
  end
  for key,isOwned in pairs(assert(player.tails,"Player.tails required")) do
    local id=tonumber(key)
    local acc=id and findById(catalogue.accessories,id)
    if owned(isOwned) and acc and (acc.price or 0)>0 then
      game.accounts.recordUnlocks(player.account,{acc=acc.id})
    end
  end
  local weaponTypes={}
  for kind in pairs(assert(player.weapons,"Player.weapons required")) do
    if type(kind)=="number" and kind%1==0 then
      weaponTypes[#weaponTypes+1]=kind
    end
  end
  table.sort(weaponTypes)
  local variants=assert(game.config.weaponVariants,
    "original weaponVariants required")
  for _,kind in ipairs(weaponTypes) do
    local weapon=player.weapons[kind]
    if weapon~=nil then
      local xp=(player.weaponXP and player.weaponXP[weapon]) or 0
      local best=0
      for _,variant in ipairs(variants) do
        if xp>=variant.xp and (not variant.membersOnly or owned(player.isMember)) then
          best=variant.id
        end
      end
      game.accounts.recordUnlocks(player.account,{weapon=weapon,variant=best})
    end
  end
end
return Unlocks
