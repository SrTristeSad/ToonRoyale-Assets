-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of the original Player.buildItem closure, not a new building design.
-- The authoritative Player/economy and ObjectManager are injected; this
-- preserves item.consume, shame and spawn-point behavior without mocks.
local Build={}
local function jsTruthy(v) return v~=nil and v~=false and v~=0 end
local function jsOr(v,default) return jsTruthy(v) and v or default end

function Build.use(player,item,world,opts)
  opts=opts or {}
  assert(player and item and type(player.canBuild)=="function"
    and type(player.useRes)=="function" and type(player.changeItemCount)=="function",
    "original Player economy methods required")
  assert(world and type(world.canPlace)=="function" and type(world.addDynamic)=="function",
    "authoritative ObjectManager placement/addition required")
  assert(type(opts.nowMs)=="number","server Date.now required")
  local placeDistance=player.scale+item.scale+jsOr(item.placeOffset,0)
  local x=player.x+placeDistance*math.cos(player.dir)
  local y=player.y+placeDistance*math.sin(player.dir)
  -- Preserve JS && short-circuit order: canBuild -> noEat -> placement.
  if player:canBuild(item)
     and not (type(item.consume)=="function" and player.skin and jsTruthy(player.skin.noEat))
     and (type(item.consume)=="function" or world:canPlace(x,y,item.scale,0.6,item.id,false,player)) then
    local worked=false
    if type(item.consume)=="function" then
      if jsTruthy(player.hitTime) then
        local since=opts.nowMs-player.hitTime
        player.hitTime=0
        if since<=120 then
          player.shameCount=player.shameCount+1
          if player.shameCount>=8 then
            player.shameTimer=30000
            player.shameCount=0
          end
        else
          player.shameCount=player.shameCount-2
          if player.shameCount<=0 then player.shameCount=0 end
        end
      end
      if player.shameTimer<=0 then worked=not not item.consume(player) end
    else
      worked=true
      if item.group and jsTruthy(item.group.limit) then
        player:changeItemCount(item.group.id,1)
      end
      if jsTruthy(item.pps) then player.pps=player.pps+item.pps end
      world:addDynamic(x,y,player.dir,item.scale,item.type,item,player)
    end
    if worked then
      player:useRes(item)
      player.buildIndex=-1
    end
  end
end
return Build
