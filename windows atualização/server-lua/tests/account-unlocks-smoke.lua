-- SPDX-License-Identifier: AGPL-3.0-only
local Unlocks=require("server-lua.world.account_unlocks")
local events={}
local account={id="test"}
local function save(a,data)
 assert(a==account)
 if data.hat then events[#events+1]="hat:"..data.hat end
 if data.acc then events[#events+1]="acc:"..data.acc end
 if data.weapon then events[#events+1]="weapon:"..data.weapon..":"..data.variant end
end
local game={accounts={recordUnlocks=save},
 items={
  hats={{id=0,price=0},{id=5,price=200}},
  accessories={{id=0,price=0},{id=7,price=1500}},weapons={}
 },
 config={weaponVariants={
  {id=0,xp=0},{id=1,xp=3000},{id=2,xp=7000},
  {id=3,xp=12000},{id=4,xp=30000,membersOnly=true}
 }}}
local player={account=account,skins={[0]=1,[5]=1},
 tails={[0]=1,[7]=1},weapons={[0]=2,[1]=9},
 weaponXP={[2]=35000,[9]=0},isMember=false}
Unlocks.record(game,player)
assert(table.concat(events,",")=="hat:5,acc:7,weapon:2:3,weapon:9:0",
 table.concat(events,","))
events={}
player.isMember=true
Unlocks.record(game,player)
assert(events[3]=="weapon:2:4")
events={}
player.account=nil
Unlocks.record(game,player)
assert(#events==0)
player.account=account
game.accounts=nil
-- The original Node Game.recordUnlocks returns early when accounts is absent.
assert(pcall(function()Unlocks.record(game,player)end))
assert(#events==0,"missing account store must not emit unlocks")
print("PASS Game.recordUnlocks: catalogo pago, armas zero-based e variante membro")
