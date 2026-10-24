-- SPDX-License-Identifier: AGPL-3.0-only
-- Same economy/XP scenarios as economy-reference.mjs
local Base=require("src.game.config")
local Econ=require("server-lua.world.economy")
local names={
  "wood","food-auto","stone-spend","gold","gold-auto","weapon-xp",
  "age-xp","age-up","item-count","has-cost","not-enough",
  "consume","build","build-limit","sandbox","sandbox-build","sandbox-no-limit",
  "unlimited-spend","round-cost"
}
local function fmt(x) return string.format("%.3f",x or 0) end
local function repr(v)
  if type(v)=="number" and v==math.floor(v) then return string.format("%.0f",v) end
  return tostring(v)
end
for _,name in ipairs(names) do
  local sandbox=name:sub(1,7)=="sandbox"
  local cfg=setmetatable({
    inSandbox=sandbox,unlimitedResources=name=="unlimited-spend"
  },{__index=Base})
  local events={}
  local p={
    id="p0",sid=0,weaponIndex=0,weaponXP={},
    wood=50,food=25,stone=25,points=80,
    age=1,XP=0,maxXP=300,upgradePoints=0,upgrAge=2,
    itemCounts={[1]=10},lifeStats={wood=0,food=0,stone=0}
  }
  p.item={req={"wood",10,"stone",5},group={id=1,limit=30,sandboxLimit=99}}
  local opts={
    config=cfg,
    send=function(id,packet,...)
      local args={}
      for i=1,select("#",...) do args[i]=repr(select(i,...)) end
      events[#events+1]="SEND:"..id..":"..packet..":"..table.concat(args,",")
    end,
    score=function(player,value,auto)
      events[#events+1]="SCORE:"..fmt(value)..":"..(auto and 1 or 0)
      player.points=player.points+value
    end
  }
  local result=nil
  if name=="wood" then Econ.addResource(p,0,12,false,opts)
  elseif name=="food-auto" then Econ.addResource(p,1,7,true,opts)
  elseif name=="stone-spend" then Econ.addResource(p,2,-5,false,opts)
  elseif name=="gold" then Econ.addResource(p,3,25,false,opts)
  elseif name=="gold-auto" then Econ.addResource(p,3,12,true,opts)
  elseif name=="weapon-xp" then Econ.addWeaponXP(p,33)
  elseif name=="age-xp" then Econ.earnXP(p,25,opts)
  elseif name=="age-up" then Econ.earnXP(p,350,opts)
  elseif name=="item-count" then Econ.changeItemCount(p,1,-2,opts)
  elseif name=="has-cost" then result=Econ.hasRes(p,p.item)
  elseif name=="not-enough" then p.wood=1;result=Econ.hasRes(p,p.item)
  elseif name=="consume" then Econ.useRes(p,p.item,nil,opts)
  elseif name=="build" then result=Econ.canBuild(p,p.item,opts)
  elseif name=="build-limit" then p.itemCounts[1]=30;result=Econ.canBuild(p,p.item,opts)
  elseif name=="sandbox" then Econ.useRes(p,p.item,nil,opts)
  elseif name=="sandbox-build" then p.wood=0;result=Econ.canBuild(p,p.item,opts)
  elseif name=="sandbox-no-limit" then p.item.group.limit=nil;result=Econ.canBuild(p,p.item,opts)
  elseif name=="unlimited-spend" then Econ.addResource(p,0,-25,false,opts)
  elseif name=="round-cost" then Econ.useRes(p,p.item,1.25,opts)
  end
  print(table.concat({"ECON",name,type(result)=="boolean" and (result and 1 or 0) or "-",
    fmt(p.wood),fmt(p.food),fmt(p.stone),fmt(p.points),fmt(p.weaponXP[0]),
    p.age,fmt(p.XP),fmt(p.maxXP),p.upgradePoints,p.itemCounts[1],
    p.lifeStats.wood,p.lifeStats.food,p.lifeStats.stone,
    table.concat(events,";")},"|"))
end
