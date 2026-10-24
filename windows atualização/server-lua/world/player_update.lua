-- SPDX-License-Identifier: AGPL-3.0-only
-- Assembles the *same three consecutive portions* of Node Player.update:
-- periodic effects -> physics -> weapons/tool/turret.
-- Does not invent the Player constructor or item definitions: callbacks,
-- server clock, actor roster and original items are mandatory inputs.
local Vitals=require("server-lua.world.vitals")
local Movement=require("server-lua.world.movement")
local WeaponTick=require("server-lua.world.weapon_tick")
local DefaultConfig=require("src.game.config")
local PlayerUpdate={}

function PlayerUpdate.step(player,delta,ctx)
  ctx=ctx or {}
  assert(type(delta)=="number" and delta>=0 and delta==delta,
    "nonnegative tick delta required")
  if not player.alive then return false end
  local cfg=ctx.config or DefaultConfig
  local items=assert(ctx.items and ctx.items.weapons and ctx.items.projectiles,
    "original shared items.weapons/projectiles required")
  local weapon=assert(items.weapons[player.weaponIndex],"invalid original weapon index")
  local world=assert(ctx.world,"authoritative ObjectManager required")
  local players=assert(ctx.players,"original player list required")
  assert(type(ctx.nowMs)=="number","authoritative Date.now required")

  -- Effect timer runs *before* movement, and damage during effect ticks
  -- does not abort the remainder of the current Player.update in Node.
  Vitals.step(player,delta)
  Movement.step(player,delta,world,players,{
    config=cfg,nowMs=ctx.nowMs,weapon=weapon,
    disable=ctx.disable,hit=ctx.hit,
    allowDeathMidTick=true
  })
  WeaponTick.step(player,delta,{
    weapon=weapon,projectiles=items.projectiles,players=players,
    addProjectile=ctx.addProjectile
  })
  return true
end

return PlayerUpdate
