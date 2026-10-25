-- SPDX-License-Identifier: AGPL-3.0-only
-- Resource, weapon XP, age XP, item counts and item costs from Node Player.js.
-- Uses real server callbacks and shared/config values; no fake inventory rules.
local Config=require("src.game.config")
local Economy={}
local function jsOr(value,fallback)
  if value==nil or value==false or value==0 then return fallback end
  return value
end
local function round(v) return math.floor(v+0.5) end
local function fix(v,dp)
  local x=10^dp
  return math.floor(v*x+0.5)/x
end
local function sender(options,player,name,...)
  assert(options and type(options.send)=="function","server.send required")
  options.send(player.id,name,...)
end

function Economy.addWeaponXP(player,amount)
  local index=player.weaponIndex
  if not player.weaponXP[index] or player.weaponXP[index]==0 then
    player.weaponXP[index]=0
  end
  player.weaponXP[index]=player.weaponXP[index]+amount
end

function Economy.earnXP(player,amount,options)
  options=options or {}
  local config=options.config or Config
  assert(type(config.maxAge)=="number","original config.maxAge required")
  if player.age<config.maxAge then
    player.XP=player.XP+amount
    if player.XP>=player.maxXP then
      if player.age<config.maxAge then
        player.age=player.age+1
        player.XP=0
        player.maxXP=player.maxXP*1.2
      else
        player.XP=player.maxXP
      end
      player.upgradePoints=player.upgradePoints+1
      sender(options,player,"U",player.upgradePoints,player.upgrAge)
      sender(options,player,"T",player.XP,fix(player.maxXP,1),player.age)
    else
      sender(options,player,"T",player.XP)
    end
  end
end

function Economy.addResource(player,rtype,amount,auto,options)
  options=options or {}
  local config=options.config or Config
  if config.unlimitedResources and amount<0 then return end
  if not auto and amount>0 then Economy.addWeaponXP(player,amount) end
  if rtype==3 then
    assert(type(options.score)=="function","authoritative score callback required")
    options.score(player,amount,true)
  else
    local name=assert(config.resourceTypes[rtype+1],"unknown original resource type")
    player[name]=player[name]+amount
    sender(options,player,"N",name,player[name],1)
    if amount>0 and player.lifeStats then
      player.lifeStats[name]=player.lifeStats[name]+amount
    end
  end
end

function Economy.changeItemCount(player,index,value,options)
  player.itemCounts[index]=jsOr(player.itemCounts[index],0)+value
  sender(options,player,"S",index,player.itemCounts[index])
end

function Economy.hasRes(player,item,multiplier)
  local req=assert(item.req,"item must contain original resource costs")
  for i=1,#req,2 do
    if player[req[i]]<round(req[i+1]*jsOr(multiplier,1)) then return false end
  end
  return true
end

function Economy.useRes(player,item,multiplier,options)
  options=options or {}
  local cfg=options.config or Config
  if cfg.inSandbox then return end
  local req=assert(item.req,"item must contain original resource costs")
  for i=1,#req,2 do
    local code=nil
    for j,name in ipairs(cfg.resourceTypes) do if name==req[i] then code=j-1;break end end
    assert(code~=nil,"unknown resource "..tostring(req[i]))
    Economy.addResource(player,code,-round(req[i+1]*jsOr(multiplier,1)),false,options)
  end
end

function Economy.canBuild(player,item,options)
  options=options or {}
  local cfg=options.config or Config
  local group=assert(item.group,"original item group required")
  local limit
  if cfg.inSandbox then
    if group.sandboxLimit~=nil and group.sandboxLimit~=false and group.sandboxLimit~=0 then
      limit=group.sandboxLimit
    else
      -- Preserve JS short-circuit: only read group.limit if there is
      -- no sandboxLimit. Some item groups omit a normal-mode limit.
      assert(type(group.limit)=="number","original group limit required")
      limit=math.max(group.limit*3,99)
    end
  else
    limit=group.limit
  end
  if limit and limit~=0 and (player.itemCounts[group.id] or 0)>=limit then return false end
  return cfg.inSandbox and true or Economy.hasRes(player,item)
end
return Economy
