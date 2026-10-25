-- Integration: bot survival, XP, resource priorities, gold and honest shop.
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local Goals=require("server-lua.world.bot_goals")
local Catalogue=require("server-lua.world.catalogue")
local room=Room.new({nowMs=10000,services={ensureAnimals=function()end},
 broadcast=function()end})
local registry=Registry.new(room,{
 randomString=function()return "abcdefghijklmnoq"end,
 anticheatFactory=function()error("no fake socket for bot")end,botCount=1
})
local a=room.bots.agents[1]
local p=a.p
local plan=assert(Goals.gearPlan(p,1,Catalogue))
assert(plan.tail and plan.id==3 and plan.price==1500)
p.food=6;p.health=58
assert(Goals.resourceType(p,1,Catalogue)==1,
 "bot must seek food when it cannot heal")
p.food=85;p.health=100;p.wood=100;p.stone=100;p.points=0
assert(Goals.resourceType(p,1,Catalogue)==3,
 "bot must look for gold to buy ordinary store equipment")
local px,py=p.x,p.y
local wood={active=true,type=0,x=px+40,y=py,scale=35}
local gold={active=true,type=3,x=px+240,y=py,scale=35}
local food={active=true,type=1,x=px+390,y=py,scale=35}
local found,purpose=Goals.selectResource(p,{wood,gold,food},1,Catalogue)
assert(found==gold and purpose=="gold",
 "long term shop goal must outweigh nearby unneeded wood")
room.game_objects={wood,gold,food}
a.lastTarget=nil;a.holdUntil=0
room.bots:decide(a,270)
assert(a.lastMode=="gather" and a.lastPurpose=="gold"
 and p.mouseState==0 and p.moveDir~=nil,
 "gold-seeking bot must travel toward the gold vein")
local beforeXP=p.XP
p:addResource(3,1600,true) -- authoritative gold grant and XP, not AI mutation
assert(p.points==1600 and (p.XP~=beforeXP or p.age>1),
 "earning real gold must also generate legal progression")
assert(Goals.purchase(p,1,Catalogue),"bot failed legal shop purchase")
assert(p.points==100 and p.tails[3]==1 and p.tailIndex==3,
 "store must deduct money and equip real owned accessory")
assert(not Goals.purchase(p,1,Catalogue),
 "bot must not buy gear without sufficient money")
p.food=10;p.health=42
found,purpose=Goals.selectResource(p,{wood,gold,food},1,Catalogue)
assert(found==food and purpose=="food",
 "injured bot must abandon gold farming to replenish food")
local prior=a.at
room.bots:decide(a,900)
assert(a.at>prior,"healing must not reset elapsed AI clock")
local enemy={x=p.x+140,y=p.y,health=100,maxHealth=100,isPlayer=true}
assert(not Goals.shouldFight(p,enemy,140),
 "badly wounded bots should avoid duels")
p.health=100
assert(Goals.shouldFight(p,enemy,140),
 "healthy bots can defend themselves")
print("PASS survival-first bots: food -> gold -> real shop, XP and retreat")
