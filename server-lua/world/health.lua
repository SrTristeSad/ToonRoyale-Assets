-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of Player.changeHealth and Player.kill in the original Node server.
-- Explicit callbacks are the real game transport / scoring / icon managers;
-- no stand-in awards or client messages are invented.
local Health={}
local function jsOr(value,alternative)
  if value==nil or value==false or value==0 then return alternative end
  return value
end
local function round(value)
  return math.floor(value+0.5)
end
local function hasTail(player,index)
  return player.tail~=nil and player.tail.id==index
end
local function notify(options,id,name,...)
  assert(type(options.send)=="function","server.send callback required")
  return options.send(id,name,...)
end

function Health.kill(player,doer,source,projectile,options)
  options=options or {}
  assert(type(options.nowMs)=="number","authoritative timestamp required")
  if doer and doer.alive and doer.isPlayer then
    doer.kills=doer.kills+1
    local reward
    if doer.skin and doer.skin.goldSteal then
      reward=round(player.points/2)
    else
      reward=round(player.age*100*(doer.skin and jsOr(doer.skin.kScrM,1) or 1))
    end
    if player.iconIndex==1 and hasTail(doer,4) then reward=reward*3 end
    if source and source.group and source.group.name=="spikes"
      and not projectile and hasTail(doer,7) then reward=reward*2 end
    if hasTail(doer,1) then doer.superUntil=options.nowMs+10000 end
    assert(type(options.score)=="function","score callback required")
    options.score(doer,round(reward))
    notify(options,doer.id,"N","kills",doer.kills,1)
    if doer.lifeStats then
      doer.lifeStats.kills=doer.lifeStats.kills+1
    end
  end
  player.alive=false
  notify(options,player.id,"P")
  assert(type(options.icon)=="function","death icon callback required")
  options.icon(player)
end

function Health.change(player,amount,doer,source,projectile,options)
  options=options or {}
  assert(type(options.nowMs)=="number","authoritative timestamp required")
  assert(type(options.players)=="table","authoritative player list required")
  if amount>0 and player.health>=player.maxHealth then return false end
  if amount<0 and player.powers.god~=nil and player.powers.god~=false and player.powers.god~=0 then return false end
  if amount<0 and player.skin then amount=amount*jsOr(player.skin.dmgMult,1) end
  if amount<0 and player.tail then amount=amount*jsOr(player.tail.dmgMult,1) end
  if amount<0 and projectile and hasTail(player,15) then amount=amount*0.75 end
  if amount<0 then player.hitTime=options.nowMs end
  player.health=player.health+amount
  if player.health>player.maxHealth then
    amount=amount-(player.health-player.maxHealth)
    player.health=player.maxHealth
  end
  if amount>0 and player.lifeStats then
    player.lifeStats.healing=player.lifeStats.healing+amount
  end
  if amount<0 and doer and doer~=player and doer.lifeStats then
    doer.lifeStats.damage=doer.lifeStats.damage-amount
  end
  if player.health<=0 then Health.kill(player,doer,source,projectile,options) end
  for _,peer in ipairs(options.players) do
    if player.sentTo[peer.id] then
      notify(options,peer.id,"O",player.sid,round(player.health))
    end
  end
  if doer and type(doer.canSee)=="function" and doer:canSee(player)
    and not (doer==player and amount<0) then
    notify(options,doer.id,"8",round(player.x),round(player.y),round(-amount),1)
  end
  return true
end
return Health
