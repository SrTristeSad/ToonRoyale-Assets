-- SPDX-License-Identifier: AGPL-3.0-only
-- Authoritative MOVEMENT portion of Player.update (Node player.js, SLOWER -> MAP BOUNDARIES).
-- Does not fake weapon attacks, XP, regeneration or any other part of Player.update.
-- Called with the authoritative world and original weapon/equipment data.
local Environment=require("server-lua.world.environment")
local Collision=require("server-lua.world.collision")
local Config=require("src.game.config")
local Movement={}

local function jsOr(x,fallback)
  -- JavaScript "x || 1": Lua treats 0 as truthy; JS does not.
  if x==nil or x==false or x==0 then return fallback end
  return x
end
local function finite(n)
  return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end

function Movement.step(player,delta,world,players,opts)
  opts=opts or {}
  local cfg=opts.config or Config
  local weapon=assert(opts.weapon,"original weapon data required")
  assert(finite(delta) and delta>=0,"invalid tick delta")
  assert(world and type(world.getGridArrays)=="function","authoritative world required")
  assert(type(players)=="table","players array required")
  assert(opts.nowMs~=nil and finite(opts.nowMs),"authoritative clock required")
  assert(player.alive and player.powers and finite(player.powers.speed),
    "alive player with powers.speed required")
  assert(finite(player.x) and finite(player.y) and finite(player.xVel) and finite(player.yVel),
    "player coordinates/velocity required")
  -- Node player.js: after shame/regeneration section, before weapon/tool section.
  if player.slowMult<1 then
    player.slowMult=player.slowMult+0.0008*delta
    if player.slowMult>1 then player.slowMult=1 end
  end
  player.noMovTimer=player.noMovTimer+delta
  if player.xVel~=0 or player.yVel~=0 then player.noMovTimer=0 end
  if player.lockMove then
    player.xVel=0
    player.yVel=0
  else
    local skin,tail=player.skin,player.tail
    local speedMultiplier=(player.buildIndex>=0 and 0.5 or 1)
      *jsOr(weapon.spdMult,1)
      *(skin and jsOr(skin.spdMult,1) or 1)
      *(tail and jsOr(tail.spdMult,1) or 1)
      *(player.y<=cfg.snowBiomeTop and Environment.snowFactor(player,cfg) or 1)
      *player.slowMult
    if tail and tail.id==5 then speedMultiplier=speedMultiplier*1.05 end -- Dash Cape
    if (player.superUntil or 0)>opts.nowMs then speedMultiplier=speedMultiplier*1.15 end -- Super Cape
    speedMultiplier=speedMultiplier*player.powers.speed
    local riverTop=cfg.mapScale/2-cfg.riverWidth/2
    local riverBottom=cfg.mapScale/2+cfg.riverWidth/2
    if player.zIndex==0 and player.y>=riverTop and player.y<=riverBottom and player.x>=0 then
      if skin and skin.watrImm then
        speedMultiplier=speedMultiplier*0.75
        player.xVel=player.xVel+cfg.waterCurrent*0.4*delta
      else
        speedMultiplier=speedMultiplier*0.33
        player.xVel=player.xVel+cfg.waterCurrent*delta
      end
    elseif player.zIndex==0 and player.x<0 and Environment.inSecretPool(cfg,player.x,player.y) then
      speedMultiplier=speedMultiplier*(skin and skin.watrImm and 0.75 or 0.33)
    end
    local inputX,inputY=0,0
    if player.moveDir~=nil then
      inputX=math.cos(player.moveDir)
      inputY=math.sin(player.moveDir)
    end
    local len=math.sqrt(inputX*inputX+inputY*inputY)
    if len~=0 then
      inputX=inputX/len
      inputY=inputY/len
    end
    if inputX~=0 then player.xVel=player.xVel+inputX*player.speed*speedMultiplier*delta end
    if inputY~=0 then player.yVel=player.yVel+inputY*player.speed*speedMultiplier*delta end
  end
  player.zIndex=0
  player.lockMove=false
  player.healCol=0
  local tmpSpeed=math.sqrt((player.xVel*delta)^2+(player.yVel*delta)^2)
  local depth=math.min(4,math.max(1,math.floor(tmpSpeed/40+0.5)))
  local tMlt=1/depth
  local checked={}
  local collisionOptions={
    config=cfg,randomInt=function(lo,hi) return world:randomInt(lo,hi) end,
    disable=opts.disable,hit=opts.hit
  }
  for _=1,depth do
    local prevX,prevY=player.x,player.y
    if player.xVel~=0 then player.x=player.x+player.xVel*delta*tMlt end
    if player.yVel~=0 then player.y=player.y+player.yVel*delta*tMlt end
    Environment.keepInWorld(player,prevX,prevY,cfg)
    local groups=world:getGridArrays(player.x,player.y,player.scale)
    for _,group in ipairs(groups) do
      for _,obj in ipairs(group) do
        if obj.active and not checked[obj.sid] then
          if Collision.checkCollision(player,obj,tMlt,collisionOptions) then
            checked[obj.sid]=true
            if not player.alive then break end
          end
        end
      end
      if not player.alive then break end
    end
    if not player.alive then break end
  end
  local selfIndex=nil
  for i,v in ipairs(players) do if v==player then selfIndex=i;break end end
  -- JS loops later players only (indexOf + 1); no arbitrary player ordering.
  if selfIndex then
    for i=selfIndex+1,#players do
      local other=players[i]
      if other~=player and other.alive and (other.spaceId or "surface")=="surface" then
        Collision.checkCollision(player,other,nil,collisionOptions)
      end
    end
  end
  if player.xVel~=0 then
    player.xVel=player.xVel*cfg.playerDecel^delta
    if player.xVel<=0.01 and player.xVel>=-0.01 then player.xVel=0 end
  end
  if player.yVel~=0 then
    player.yVel=player.yVel*cfg.playerDecel^delta
    if player.yVel<=0.01 and player.yVel>=-0.01 then player.yVel=0 end
  end
  Environment.keepInWorld(player,player.x,player.y,cfg)
  return player
end

return Movement
