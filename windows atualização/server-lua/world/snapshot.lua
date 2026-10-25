-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of Game.syncPlayers + Game.syncObjects and related Player/GameObject visibility.
-- Exactly the Node S2C packet names: D, a, H, and N (sandbox resources).
-- Pure state-to-packets module; game simulation and join are NOT implemented here.
local Config=require("src.game.config")
local MP=require("src.protocol.msgpack")
local Fixed=require("server-lua.world.js_fixed")
local Sync={}
local fix=Fixed.toFloat
local function round(v) return math.floor(v+0.5) end
local function nullable(v) return v==nil and MP.null or v end

function Sync.canSee(viewer,other,cfg)
  cfg=cfg or Config
  if not other then return false end
  -- Node Math.abs(undefined - x) becomes NaN and comparison returns false.
  -- A connected viewer may not have sent its spawn M packet yet.
  if type(viewer.x)~="number" or type(viewer.y)~="number"
    or type(other.x)~="number" or type(other.y)~="number"
    or type(other.scale)~="number" then return false end
  if other.skin and other.skin.invisTimer and other.noMovTimer>=other.skin.invisTimer then
    return false
  end
  if other.isPlayer and other.powers
     and other.powers.invisible~=nil and other.powers.invisible~=false
     and other.powers.invisible~=0
     and viewer~=other and not viewer.role then return false end
  local dx=math.abs(other.x-viewer.x)-other.scale
  local dy=math.abs(other.y-viewer.y)-other.scale
  return dx<=cfg.maxScreenWidth/2*1.3 and dy<=cfg.maxScreenHeight/2*1.3
end
function Sync.objectVisible(object,viewer)
  if not object.hideFromEnemy then return true end
  local owner=object.owner
  return owner~=nil and (owner==viewer or
    (owner.team~=nil and owner.team~=false and viewer.team==owner.team))
end
function Sync.playerData(player,viewer)
  local hidden=player.anon and viewer~=player
  local powers=assert(player.powers,"player powers absent")
  local shownName=hidden and ("Anon#"..player.sid) or player.name
  return {
    player.id,player.sid,shownName,fix(player.x,2),fix(player.y,2),fix(player.dir,3),
    player.health,player.maxHealth,player.scale,player.skinColor,
    (powers.aura~=nil and powers.aura~=false and powers.aura~=0) and 1 or 0,
    (powers.boss~=nil and powers.boss~=false and powers.boss~=0) and 1 or 0,
    hidden and MP.null or nullable(player.clanTag),nullable(player.morph),nullable(player.dive),
    (powers.invisible~=nil and powers.invisible~=false and powers.invisible~=0) and 1 or 0,
    (player.disguised and not hidden) and 1 or 0
  }
end

local function attributeText(value)
  if value==MP.null or value==nil then return "" end
  return tostring(value)
end
local function attrKey(a)
  local parts={}
  for i=1,10 do parts[i]=attributeText(a[i]) end
  return table.concat(parts,",")
end
local function append(dst,src)
  for i=1,#src do dst[#dst+1]=src[i] end
end

function Sync.syncPlayers(game,viewer,cfg)
  cfg=cfg or Config
  assert(game and type(game.players)=="table","player list required")
  assert(viewer and type(viewer.send)=="function","network sender required")
  local positions,attrs,hidden={},{},{}
  local visibleNow,seen={},{}
  viewer.visiblePlayers=viewer.visiblePlayers or {}
  viewer.attrCache=viewer.attrCache or {}
  for _,other in ipairs(game.players) do
    if other.alive and Sync.canSee(viewer,other,cfg) then
      visibleNow[#visibleNow+1]=other.sid
      seen[other.sid]=true
      other.sentTo=other.sentTo or {}
      if not other.sentTo[viewer.id] then
        other.sentTo[viewer.id]=true
        viewer.attrCache[other.sid]=nil
        viewer:send("D",Sync.playerData(other,viewer),viewer==other)
        if viewer==other and cfg.unlimitedResources then
          for _,kind in ipairs(cfg.resourceTypes) do viewer:send("N",kind,viewer[kind],1) end
        end
      end
      append(positions,{other.sid,round(other.x),round(other.y),round(other.dir*100)})
      local variant=assert(type(other.variant)=="function" and other:variant(),
        "real weapon variant required")
      local attr={
        other.sid,other.buildIndex,other.weaponIndex,variant.id,nullable(other.team),
        other.isLeader and 1 or 0,
        other.shameTimer and other.shameTimer>0 and 45 or other.skinIndex,
        other.tailIndex,other.iconIndex,other.zIndex
      }
      local key=attrKey(attr)
      if viewer.attrCache[other.sid]~=key then
        viewer.attrCache[other.sid]=key
        append(attrs,attr)
      end
    end
  end
  for _,sid in ipairs(viewer.visiblePlayers) do
    if not seen[sid] then hidden[#hidden+1]=sid end
  end
  viewer.visiblePlayers=visibleNow
  viewer:send("a",positions,attrs,hidden)
end

function Sync.syncObjects(game,viewer,cfg)
  cfg=cfg or Config
  assert(game and type(game.game_objects)=="table","object list required")
  assert(viewer and type(viewer.send)=="function","network sender required")
  local fresh={}
  for _,obj in ipairs(game.game_objects) do
    obj.sentTo=obj.sentTo or {}
    if obj.active and not obj.sentTo[viewer.id]
       and Sync.objectVisible(obj,viewer) and Sync.canSee(viewer,obj,cfg) then
      obj.sentTo[viewer.id]=true
      append(fresh,{
        obj.sid,fix(obj.x,1),fix(obj.y,1),obj.dir,obj.scale,
        obj.type,nullable(obj.id),obj.owner and obj.owner.sid or -1
      })
    end
  end
  if #fresh>0 then viewer:send("H",fresh) end
end
return Sync
