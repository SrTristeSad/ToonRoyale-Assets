-- Bot progression uses real Player age XP and the same H upgrade logic as humans.
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local Catalogue=require("server-lua.world.catalogue")
local Loadout=require("server-lua.world.bot_loadout")
local room=Room.new({
 nowMs=10000,services={ensureAnimals=function()end},
 broadcast=function()end
})
local registry=Registry.new(room,{
 randomString=function()return "abcdefghijklmnop"end,
 anticheatFactory=function()error("bot must not open authenticated connection")end,
 botCount=2
})
local agent=room.bots.agents[1]
local p=agent.p
assert(p.age==1 and p.upgrAge==2 and p.upgradePoints==0
 and p.weapons[0]==0 and p.weaponIndex==0)
-- No XP, no age upgrade. A bot cannot invent unlocked weapons.
room.bots:decide(agent,270)
assert(p.weaponIndex==0 and p.weapons[0]==0)
local function level()
 p:earnXP(p.maxXP+1)
 assert(p.upgradePoints==1)
 room.bots:decide(agent,270)
 assert(p.upgradePoints==0,"bot failed to spend legitimate age point")
end
level() -- age 2: class 1 prefers the gathering axe
assert(p.age==2 and p.upgrAge==3 and p.weapons[0]==1
 and p.weaponIndex==1,
 "bot must upgrade real primary weapon at age 2")
level() -- age 3: bot may choose a valid item with the same rules
assert(p.upgrAge==4 and #p.items>=4)
level() -- age 4
level() -- age 5
assert(p.age==5 and p.weapons[1]==nil)
level() -- age 6: ranged weapon unlocked
assert(p.age==6 and p.weapons[1]==9,
 "ranged bot must choose a legal bow using real age points")
local bow=Catalogue.weapons[9]
assert(Loadout.chooseWeapon(p,Catalogue,"fight",450,1)==1,
 "bow must not be usable before resource cost is affordable")
p.wood=bow.req[2]+10
assert(Loadout.chooseWeapon(p,Catalogue,"fight",450,1)==9,
 "combat should equip bow against distant target")
assert(Loadout.chooseWeapon(p,Catalogue,"gather",450,1)==1,
 "resource collection should use primary gathering weapon")
assert(Loadout.attackRange(bow,Catalogue)>=450)
local opponent={id="opponent",sid=99,alive=true,active=true,isPlayer=true,
 x=p.x+450,y=p.y,scale=35,health=100,maxHealth=100,spaceId="surface"}
room.players[#room.players+1]=opponent
p.health=p.maxHealth
room.bots:decide(agent,270)
assert(p.weaponIndex==9 and p.mouseState==1,
 "authoritative combat must actually fire unlocked bow at range")
opponent.x=p.x+55
room.bots:decide(agent,270)
assert(p.weaponIndex==1 and p.mouseState==1,
 "bot must switch to melee when enemy closes distance")
for _,other in ipairs(room.players) do
 if other==opponent then
  for i,v in ipairs(room.players) do
   if v==opponent then table.remove(room.players,i);break end
  end
  break
 end
end
level() -- age 7 item
level() -- age 8: axe upgrades only if owns its prerequisite
assert(p.age==8 and p.weapons[0]==2,
 "upgraded axe must require original hand axe")
-- An archer archetype makes a different legitimate age-8 choice.
local archer={upgradePoints=1,upgrAge=8,
 weapons={[0]=3,[1]=9},items={0,3,6,10}}
assert(Loadout.choose(archer,Catalogue,6)==12,
 "ranged bot should prefer crossbow when prerequisites allow it")
archer.weapons[1]=12;archer.upgrAge=9
assert(Loadout.choose(archer,Catalogue,6)==13,
 "ranged bot should later consider repeater crossbow progression")
-- Dead bots cannot spend points until respawn.
p.alive=false;p.upgradePoints=1
assert(not Loadout.upgrade(p,Catalogue,1))
assert(p.upgradePoints==1)
print("PASS bot age XP, legal primary/secondary upgrades, resources and weapon switching")
