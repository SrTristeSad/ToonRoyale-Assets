-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.recordLife from the copied Node server. AccountStore remains authoritative.
local Life={}
local function jsOr(v,fallback)
 if v==nil or v==false or v==0 or v=="" then return fallback end
 return v
end
function Life.record(game,player,died)
 if not player.lifeStats or not player.account or not game.accounts then
  player.lifeStats=nil
  return
 end
 local store=game.accounts
 local life=player.lifeStats
 assert(type(game.wallTimeMs)=="function","wall clock required for life playtime")
 local now=game.wallTimeMs()
 assert(type(now)=="number" and type(player.spawnedAt)=="number","spawn time required")
 assert(type(player.variant)=="function","original Player.variant required")
 life.died=died
 life.playtime=now-player.spawnedAt
 life.look={hat=jsOr(player.skinIndex,0),acc=jsOr(player.tailIndex,0),
   weapon=jsOr(player.weaponIndex,0),variant=player:variant().id,
   color=jsOr(player.skinColor,0)}
 player.lifeStats=nil
 if not (store.data and store.data.accounts and store.data.accounts[player.account.id]) then return end
 assert(type(game.recordUnlocks)=="function","original unlock recording required")
 game:recordUnlocks(player)
 if player.account.verdict=="shadow" then return end
 assert(type(store.weeklyTopClan)=="function" and type(store.recordLife)=="function",
  "persistent AccountStore weeklyTopClan and recordLife required")
 local before=store.weeklyTopClan()
 store.recordLife(player.account,life)
 local after=store.weeklyTopClan()
 if after and after~=before and game.hooks and game.hooks.event then
  game.hooks.event({kind="clan_top",server=game.key,clan=after})
 end
end
return Life
