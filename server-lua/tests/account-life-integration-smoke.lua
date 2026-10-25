-- SPDX-License-Identifier: AGPL-3.0-only
-- Full service chain: Lua Game.recordLife -> Game.recordUnlocks -> accounts.json.
local Json=require("server-lua.vendor.dkjson")
local Store=require("server-lua.world.account_store")
local Unlocks=require("server-lua.world.account_unlocks")
local Life=require("server-lua.world.life_persistence")
local path="server-lua/tests/.account-life-integration.json"
local id="1234567890abcdef12345678"
local stats={kills=0,deaths=0,damage=0,healing=0,wood=0,food=0,stone=0,gold=0,
 animalDamage=0,animalKills={},bestScore=0,maxKills=0,lives=0,playtime=0,periods={}}
local account={id=id,name="Tester",stats=stats,clan=Json.null}
local initial={accounts={[id]=account},names={tester=id},emails={},clans={},
 social={friends={},requests={}},legacyIds={}}
local writer=assert(io.open(path,"wb"))
assert(writer:write(Json.encode(initial)))
assert(writer:close())
local function clean()
 os.remove(path);os.remove(path..".lua-backup");os.remove(path..".lua-new")
end
local ok,err=pcall(function()
 local now=function()return 1792864800000 end
 local store=Store.open(path,{nowMs=now})
 local game={accounts=store:callbacks(),key="LC",wallTimeMs=now,
   items={hats={{id=5,price=200}},accessories={{id=7,price=500}},weapons={}},
   config={weaponVariants={{id=0,xp=0},{id=1,xp=3000}}}}
 game.recordUnlocks=function(self,p) return Unlocks.record(self,p) end
 local player={account=store.data.accounts[id],spawnedAt=1792864740000,
   skinIndex=5,tailIndex=7,weaponIndex=2,skinColor=0,skins={[5]=1},
   tails={[7]=1},weapons={[0]=2},weaponXP={[2]=3500},
   isMember=false,
   variant=function()return {id=1}end,
   lifeStats={kills=3,damage=20,healing=2,wood=3,food=4,stone=5,gold=6,
    animalDamage=7,animalKills={wolf=1},score=90,bossKills=0}}
 Life.record(game,player,false)
 assert(player.lifeStats==nil)
 local restored=Store.open(path,{nowMs=now})
 local a=restored.data.accounts[id]
 assert(a.stats.lives==1 and a.stats.deaths==0 and a.stats.kills==3)
 assert(a.stats.playtime==60000 and a.stats.bestScore==90)
 assert(a.unlocks.hats[1]==5 and a.unlocks.accs[1]==7)
 assert(a.unlocks.weapons["2"]==1 and a.bestLook.weapon==2)
end)
clean()
assert(ok,err)
print("PASS vida finalizada -> equipamentos -> stats -> accounts.json -> reload")
