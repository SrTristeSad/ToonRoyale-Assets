-- SPDX-License-Identifier: AGPL-3.0-only
-- Faithful port of server/src/moomoo/mobileRankings.js.
local Ranking={}
local categories={gold=true,health=true,food=true,wood=true,stone=true,kills=true,points=true}
function Ranking.valid(category) return categories[category]==true end
local function jsNumber(v)
  if type(v)=="number" then return v==v and v or 0 end
  if v==nil or v==false then return 0 end
  if v==true then return 1 end
  if type(v)=="string" then
    if v:match("^%s*$") then return 0 end
    return tonumber(v) or 0
  end
  return 0
end
local function truthy(v) return v~=nil and v~=false and v~=0 and v~="" end
local function round(v) return math.floor(v+0.5) end
function Ranking.build(players,viewer,category,limit)
  assert(Ranking.valid(category),"Invalid leaderboard category")
  limit=limit or 10
  local ranked={}
  for _,p in ipairs(players) do
    if truthy(p.spawned) and (not truthy(p.shadowed) or p==viewer or truthy(viewer.role)) then
      local count=math.max(0,jsNumber(p[category=="gold" and "points" or category]))
      ranked[#ranked+1]={player=p,count=count}
    end
  end
  table.sort(ranked,function(a,b)
    if a.count~=b.count then return a.count>b.count end
    return a.player.sid<b.player.sid
  end)
  local result={}
  for i=1,math.min(limit,#ranked) do
    local row=ranked[i]
    assert(type(row.player.shownName)=="function","original shownName required")
    result[#result+1]=row.player.sid
    result[#result+1]=row.player:shownName(viewer)
    result[#result+1]=round(row.count)
  end
  return result
end
return Ranking
