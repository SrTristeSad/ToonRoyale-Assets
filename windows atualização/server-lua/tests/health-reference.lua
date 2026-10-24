-- SPDX-License-Identifier: AGPL-3.0-only
local Health=require("server-lua.world.health")
local scenarios={
  {name="heal",health=70,amount=15,self=true},
  {name="heal-cap",health=95,amount=20,self=true},
  {name="heal-full",health=100,amount=10,self=true},
  {name="base-damage",health=100,amount=-15},
  {name="armor",health=100,amount=-20,skin={dmgMult=0.75},tail={dmgMult=0.9}},
  {name="god",health=100,amount=-40,god=1},
  {name="blockades",health=100,amount=-40,tail={id=15},projectile=true},
  {name="kill",health=10,amount=-15,age=2},
  {name="gold-steal",health=10,amount=-20,points=303,attackerSkin={goldSteal=true}},
  {name="skull-cape",health=10,amount=-15,age=2,iconIndex=1,attackerTail={id=4}},
  {name="troll-cape",health=10,amount=-15,age=2,attackerTail={id=7},spikes=true},
  {name="super-cape",health=10,amount=-15,attackerTail={id=1}},
  {name="self-damage",health=40,amount=-10,self=true},
  {name="no-doer",health=8,amount=-9,noDoer=true},
  {name="inert-attacker",health=8,amount=-9,attackerAlive=false},
  {name="projectile-armor",health=100,amount=-35,tail={id=15,dmgMult=0.8},projectile=true}
}
local function fmt(n) return string.format("%.3f",n or 0) end
local function repr(v)
  if v==nil then return "~" end
  if type(v)=="number" and v==math.floor(v) then return string.format("%.0f",v) end
  return tostring(v)
end
for _,tc in ipairs(scenarios) do
  local events={}
  local p={
    id="victim",sid=7,isPlayer=true,alive=true,
    x=125.5,y=250.5,health=tc.health,maxHealth=100,
    iconIndex=tc.iconIndex or 0,age=tc.age or 1,points=tc.points or 120,
    skin=tc.skin,tail=tc.tail,powers={god=tc.god or 0},
    lifeStats={healing=0,damage=0,kills=0},
    sentTo={victim=true,attacker=true},hitTime=0,kills=0,
    canSee=function()return true end
  }
  local attacker={
    id="attacker",sid=8,isPlayer=true,alive=tc.attackerAlive~=false,
    kills=1,skin=tc.attackerSkin,tail=tc.attackerTail,
    superUntil=0,lifeStats={healing=0,damage=0,kills=0},
    canSee=function()return true end
  }
  local function send(id,name,...)
    local elements={}
    for i=1,select("#",...) do elements[i]=repr(select(i,...)) end
    events[#events+1]="SEND:"..id..":"..name..":"..table.concat(elements,",")
  end
  local opts={
    nowMs=876500,players={p,attacker},send=send,
    score=function(who,amount)events[#events+1]="SCORE:"..who.id..":"..repr(amount)end,
    icon=function(who)events[#events+1]="ICON:"..who.id end
  }
  local doer
  if tc.noDoer then doer=nil elseif tc.self then doer=p else doer=attacker end
  local src=tc.spikes and {group={name="spikes"}} or nil
  local projectile=tc.projectile and {} or nil
  local ok=Health.change(p,tc.amount,doer,src,projectile,opts)
  print(table.concat({"HP",tc.name,ok and 1 or 0,fmt(p.health),p.alive and 1 or 0,
    fmt(p.hitTime),fmt(p.lifeStats.healing),fmt(attacker.lifeStats.damage),
    attacker.kills,attacker.lifeStats.kills,fmt(attacker.superUntil),
    table.concat(events,";")},"|"))
end
