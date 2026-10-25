-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact observer/score packets from server/src/moomoo/server.js:
-- Game.syncAnimals (I), sendMinimap (7), sendLeaderboard (G),
-- updateLeaders and sendStats (F). Account crowns must use the real
-- externally provided account service, not a fabricated ranking.
local MP=require("src.protocol.msgpack")
local Social={}
local function truthy(x) return x~=nil and x~=false and x~=0 and x~=MP.null end
local function round(x) return math.floor(x+0.5) end
local function fix(x,digits)
  local mul=10^digits
  if x<0 then return -math.floor(-x*mul+0.5)/mul end
  return math.floor(x*mul+0.5)/mul
end
local function jsOr(x,other) return truthy(x) and x or other end
local function nullable(x) return x==nil and MP.null or x end
local function extend(target,...)
  for i=1,select("#",...) do target[#target+1]=select(i,...) end
end
local function crowned(game,player)
  if not player.account or truthy(player.anon) or not game.accounts then return 0 end
  assert(type(game.crownOf)=="function","account crown service must provide Game.crownOf")
  return jsOr(game:crownOf(player),0)
end

function Social.syncAnimals(game,viewer)
  assert(type(game.ais)=="table","Game.ais required")
  local list,hidden={},{}
  local visibleNow={}
  local seen={}
  for _,ai in ipairs(game.ais) do
    if ai.active and not truthy(ai.spawnCounter) and viewer:canSee(ai) then
      visibleNow[#visibleNow+1]=ai.sid
      seen[ai.sid]=true
      extend(list,ai.sid,ai.index,fix(ai.x,1),fix(ai.y,1),
        round(ai.dir*100),round(ai.health),nullable(ai.nameIndex),jsOr(ai.state,0))
    end
  end
  for _,sid in ipairs(viewer.visibleAis or {}) do
    if not seen[sid] then hidden[#hidden+1]=sid end
  end
  viewer.visibleAis=visibleNow
  if #list>0 or #hidden>0 then viewer:send("I",list,hidden) end
end

function Social.sendMinimap(game,viewer)
  if not viewer.alive then return end
  local staff=truthy(viewer.role)
  if not truthy(viewer.team) and not staff then return end
  local data={}
  for _,other in ipairs(game.players) do
    if other~=viewer and other.alive then
      if staff or (truthy(viewer.team) and other.team==viewer.team) then
        extend(data,round(other.x),round(other.y))
      end
    end
  end
  viewer:send("7",data)
end

function Social.updateLeaders(game)
  local pointsLeader,killLeader
  for _,player in ipairs(game.players) do
    player.isLeader=false
    player.iconIndex=0
    if player.alive then
      if not pointsLeader or player.points>pointsLeader.points then
        pointsLeader=player
      end
      if player.kills>0 and (not killLeader or player.kills>killLeader.kills) then
        killLeader=player
      end
    end
  end
  if pointsLeader then pointsLeader.isLeader=true end
  for _,player in ipairs(game.players) do
    if player.alive then
      local crown=crowned(game,player)
      local skull=player==killLeader
      player.iconIndex=(crown~=0) and ((skull and 4 or 1)+crown)
        or (skull and 1 or 0)
    end
  end
end

function Social.sendLeaderboard(game)
  local ranked={}
  for i,player in ipairs(game.players) do
    if truthy(player.spawned) then ranked[#ranked+1]={p=player,i=i} end
  end
  table.sort(ranked,function(a,b)
    if a.p.points==b.p.points then return a.i<b.i end
    return a.p.points>b.p.points
  end)
  for _,viewer in ipairs(game.players) do
    local entries,roles,dead,crab,clans,tribes,crowns={},{},{},{},{},{},{}
    local shown=0
    for _,rank in ipairs(ranked) do
      local p=rank.p
      if not truthy(p.shadowed) or p==viewer or truthy(viewer.role) then
        shown=shown+1
        if shown>10 then break end
        local anon=truthy(p.anon) and p~=viewer
        assert(type(p.shownName)=="function","real Player.shownName required")
        extend(entries,p.sid,p:shownName(viewer),round(p.points))
        if p.account then
          local role=0
          if not anon then
            if p.role=="mod" then role=1
            elseif p.role=="admin" then role=2 end
          end
          extend(roles,p.sid,role)
        end
        if not p.alive then dead[#dead+1]=p.sid end
        if game.crabKillers and game.crabKillers[p.sid] then
          crab[#crab+1]=p.sid
        end
        if truthy(p.clanTag) and not anon then
          extend(clans,p.sid,p.clanTag)
          extend(tribes,p.sid,jsOr(p.team,""))
        end
        local crown=crowned(game,p)
        if crown~=0 then extend(crowns,p.sid,crown) end
      end
    end
    viewer:send("G",entries,roles,dead,crab,clans,tribes,crowns)
  end
end

function Social.sendStats(game,viewer,sid)
  local target=nil
  for _,player in ipairs(game.players) do
    if player.sid==sid then target=player;break end
  end
  if not target or not target.lifeStats then return end
  local s=target.lifeStats
  local staff=viewer.role=="mod" or viewer.role=="admin"
  local guestId=staff and not target.account and target.id or MP.null
  viewer:send("F",sid,s.kills,s.wood,s.food,s.stone,s.gold,
    round(s.damage),round(s.animalDamage),round(s.healing),
    s.animals,s.bosses,guestId,round(s.score))
end
return Social
