-- SPDX-License-Identifier: AGPL-3.0-only
-- Geometry and biome modifiers from server/src/moomoo/modules/effects.js
-- and Player.keepInWorld from server/src/moomoo/modules/player.js.
local Config=require("src.game.config")
local M={}
local function hypot(x,y) return math.sqrt(x*x+y*y) end
function M.secretDistance(config,x,y)
  config=config or Config
  local z=config.secretPool
  local mid=config.mapScale/2
  local n=-x
  local band=math.abs(y-mid)-z.gorgeHalf
  if x>=z.gorgeX0 then n=math.min(n,math.max(band,0)) end
  for _,p in ipairs(z.pool) do
    n=math.min(n,hypot(x-p[1],y-p[2])-p[3])
  end
  if math.abs(y-z.waterfall.y)<z.waterfall.half+60 and x<z.waterfall.x then
    n=math.min(n,math.abs(y-z.waterfall.y)-z.waterfall.half)
  end
  return n
end
function M.inSecretPool(config,x,y)
  config=config or Config
  for _,p in ipairs(config.secretPool.pool) do
    if hypot(x-p[1],y-p[2])<=p[3]*0.9 then return true end
  end
  return false
end
function M.snowFactor(player,config)
  config=config or Config
  if player.skin and player.skin.coldM then return 1 end
  if player.tail and player.tail.id==6 then return 1 end -- TAIL.WINTER_CAPE from effects.js
  if player.tail and player.tail.id==12 then
    return 1-(1-config.snowSpeed)*0.5 -- EFFECT.snowballSnowFactor
  end
  return config.snowSpeed
end
function M.keepInWorld(player,prevX,prevY,config)
  config=config or Config
  if player.y-player.scale<0 then
    player.y=player.scale
  elseif player.y+player.scale>config.mapScale then
    player.y=config.mapScale-player.scale
  end
  if player.x+player.scale>config.mapScale then
    player.x=config.mapScale-player.scale
  end
  if player.x-player.scale<0 and M.secretDistance(config,math.min(player.x,-1),player.y)>0 then
    if player.x>=player.scale-1 or prevX>=player.scale then
      player.x=math.max(player.x,player.scale)
      return
    end
    if M.secretDistance(config,prevX,player.y)<=0 then
      player.x=prevX;player.xVel=0
    elseif M.secretDistance(config,player.x,prevY)<=0 then
      player.y=prevY;player.yVel=0
    else
      player.x=prevX;player.y=prevY
      player.xVel=0;player.yVel=0
    end
  end
end
return M
