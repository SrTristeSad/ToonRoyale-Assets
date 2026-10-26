-- SPDX-License-Identifier: AGPL-3.0-only
-- Compatibility wrapper for pre-spawn Player parity tests.
-- All original state and pure methods live in player_identity.lua, which
-- is also used by the authoritative world/player.lua (no duplicate state).
-- The spawn and item operations here bind the original Room dependencies.
local Identity=require("server-lua.world.player_identity")
local Spawn=require("server-lua.world.spawn")
local Config=require("src.game.config")
local Constructor={}
function Constructor.new(id,sid,opts)
  opts=opts or {}
  local p=Identity.new(id,sid,{
    hats=assert(opts.hats,"original hats catalogue required"),
    accessories=assert(opts.accessories,"original accessories required"),
    config=opts.config or Config,
    nameWords=opts.nameWords
  })
  p.addItem=function(self,itemId)
    return Identity.addItem(self,itemId,{
      list=assert(opts.items and opts.items.list,
        "original item list required for Player.addItem")
    })
  end
  p.spawn=function(self,moofoll)
    local world=assert(opts.world,"authoritative world required for Player.spawn")
    assert(type(opts.nowMs)=="function",
      "server clock callback required for Player.spawn")
    return Spawn.spawn(self,moofoll,world,{
      config=opts.config or Config,nowMs=opts.nowMs()
    })
  end
  return p
end
return Constructor
