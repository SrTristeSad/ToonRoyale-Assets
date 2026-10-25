-- Regression: Node sends zero-indexed weapons inventory as map keys.
local World=require("src.game.world_state")
local Hud=require("src.game.reference_hud")
local Upgrades=require("src.game.reference_upgrades")
local world=World.new()
world:apply("V",{{[0]=3},1})
assert(#world.inventory.weapons==1 and world.inventory.weapons[1]==3,
  "short sword must remain visible in Lua action bar")
assert(Hud.slotForKey(world,"1")==3,"weapon slot must select upgraded sword")
world:apply("V",{{[0]=4,[1]=9},1})
assert(#world.inventory.weapons==2
  and world.inventory.weapons[1]==4 and world.inventory.weapons[2]==9,
  "both upgraded primary and secondary must survive packet V")
local key,weapon=Hud.slotForKey(world,"2")
assert(key==9 and weapon==true,"secondary slot must preserve weapon identity")
world:apply("V",{{4,9},1})
assert(#world.inventory.weapons==2 and world.inventory.weapons[1]==4,
  "ordinary MessagePack arrays must remain supported")
world:apply("V",{{[0]=3,[1]=9},1})
world.upgradePoints=1;world.upgradeAge=8
local offers=Upgrades.offers(world)
local found=false
for _,offer in ipairs(offers) do
  if offer.id==4 and offer.kind=="weapon" then found=true end
end
assert(found,"katana upgrade must recognize original sword prerequisite")
print("PASS zero-indexed inventory / primary and secondary weapon upgrades")
