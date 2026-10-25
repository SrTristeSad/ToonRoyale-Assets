-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of the first-party gameplay packets in server/src/network/packets.js:
-- M, D, 9, e, F, z, K and 0.
-- Unknown packets follow Node's original anticheat.invalid('unhandled').
-- Original Player methods and anticheat strike accounting remain required.
local MP=require("src.protocol.msgpack")
local Equipment=require("server-lua.world.equipment_input")
local TribeInput=require("server-lua.world.tribe_input")
local Chat=require("server-lua.world.chat_input")
local Anonymous=require("server-lua.world.anon_input")
local Ranking=require("server-lua.world.mobile_rankings")
local Reports=require("server-lua.world.report_input")
local Admin=require("server-lua.world.admin_input")
local Input={}
local function truthy(v)
  return v~=nil and v~=false and v~=0 and v~="" and v~=MP.null
end
local function finite(v)
  return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function int(v)
  return finite(v) and v%1==0
end
local function bad(player,name,reason)
  assert(player.anticheat and type(player.anticheat.invalid)=="function",
    "original anticheat.invalid callback required")
  return player.anticheat:invalid(name,reason)
end
local function includes(arr,value)
  for _,v in ipairs(arr) do if v==value then return true end end
  return false
end

function Input.handle(ctx,player,name,args)
  ctx=ctx or {}
  args=args or {}
  assert(type(name)=="string" and type(args)=="table",
    "decoded MessagePack packet required")
  assert(ctx.items and ctx.items.weapons and ctx.items.list,
    "source item catalogue mandatory for authoritative input validation")
  if name=="j" then
    if ctx.gameKey~="LC" or not ctx.game or not ctx.game.customMap then
      return bad(player,name,"world space unsupported")
    end
    if #args==0 then return ctx.game:usePortal(player) end
    if #args==1 and args[1]=="build" then
      return ctx.game:buildHouse(player)
    end
    if #args==1 and args[1]=="wall" then
      return ctx.game:buildWall(player)
    end
    return bad(player,name,"invalid map command")
  elseif name=="M" then
    local data=args[1]
    if type(data)~="table" or data==MP.null or #data>0 then
      return bad(player,name,"bad spawn data")
    end
    if player.alive then return end
    assert(type(player.setUserData)=="function" and type(player.spawn)=="function",
      "real Player.spawn and setUserData required")
    player:setUserData(data)
    player:spawn(truthy(data.moofoll))
    player.attrCache={}
    player:send("C",player.sid)
    assert(player.anticheat and type(player.anticheat.onGameStart)=="function",
      "original anticheat.onGameStart callback required")
    player.anticheat:onGameStart()
    if ctx.log then
      ctx.log("["..tostring(ctx.gameKey or "LC").."] spawn sid "..
        tostring(player.sid)..' as "'..tostring(player.name)..'"')
    end
    return
  elseif name=="D" then
    if not finite(args[1]) then return bad(player,name,"dir") end
    if player.alive then player.dir=args[1] end
    return
  elseif name=="9" then
    local value=args[1]
    if value~=nil and value~=MP.null and not finite(value) then
      return bad(player,name,"moveDir")
    end
    if player.alive then
      if value==MP.null then player.moveDir=nil else player.moveDir=value end
    end
    return
  elseif name=="e" then
    if player.alive then
      assert(type(player.resetMoveDir)=="function",
        "Player.resetMoveDir required")
      player:resetMoveDir()
    end
    return
  elseif name=="F" then
    if not player.alive then return end
    -- Item placement still belongs to the classic surface ObjectManager.
    -- Until structures are zone-aware, ignore attempted indoor building
    -- rather than writing a house item into surface world coordinates.
    if player.spaceId and player.spaceId~="surface" then
      player.mouseState=0;player.hits=0
      return
    end
    local angle=args[2]
    if angle~=nil and angle~=MP.null and not finite(angle) then
      return bad(player,name,"build dir")
    end
    local down=truthy(args[1]) and 1 or 0
    player.mouseState=down
    if finite(angle) then player.dir=angle end
    if down==1 and player.buildIndex>=0 then
      local item=ctx.items.list[player.buildIndex]
      if item then
        assert(type(player.buildItem)=="function","Player.buildItem required")
        player:buildItem(item)
      end
      player.mouseState=0
    elseif down==1 then
      player.hits=player.hits+1
    end
    return
  elseif name=="z" then
    if not player.alive then return end
    local idx=args[1]
    if not int(idx) then return bad(player,name,"item index") end
    if truthy(args[2]) then
      local weapon=ctx.items.weapons[idx]
      if not weapon or player.weapons[weapon.type]~=idx then return end
      player.buildIndex=-1
      player.weaponIndex=idx
      return
    end
    local item=ctx.items.list[idx]
    if not item or not includes(player.items,idx) then return end
    if player.buildIndex==idx then player.buildIndex=-1
    else player.buildIndex=idx end
    player.mouseState=0
    return
  elseif name=="H" or name=="c" then
    return Equipment.handle(ctx,player,name,args)
  elseif name=="L" or name=="N" or name=="b" or name=="P" or name=="Q" then
    return TribeInput.handle(ctx,player,name,args)
  elseif name=="K" then
    if not player.alive then return end
    if args[1]==1 then player.autoGather=not truthy(player.autoGather)
    elseif args[1]==0 then player.lockDir=not truthy(player.lockDir)
    else return bad(player,name,"toggle") end
    return
  elseif name=="I" then
    return Anonymous.handle(ctx,player,args)
  elseif name=="6" then
    return Chat.handle(ctx,player,args)
  elseif name=="T" then
    -- Node handlePacket calls anticheat.onTelemetry(args) after allow("T").
    assert(player.anticheat and type(player.anticheat.onTelemetry)=="function",
      "original authenticated T packet requires anticheat.onTelemetry")
    return player.anticheat:onTelemetry(args)
  elseif name=="S" or name=="U" then
    if not player.alive or player.pingCooldown>0 then return end
    local x,y=player.x,player.y
    if name=="U" then
      x,y=args[1],args[2]
      local cfg=assert(ctx.config,"shared config required for map ping")
      if #args~=2 or not finite(x) or not finite(y)
         or x<0 or y<0 or x>cfg.mapScale or y>cfg.mapScale then
        return bad(player,name,"map coordinates")
      end
    end
    local cfg=assert(ctx.config,"original map ping time required")
    assert(type(cfg.mapPingTime)=="number","shared mapPingTime required")
    local roster=assert(ctx.players,"room players required for map ping")
    player.pingCooldown=cfg.mapPingTime
    local px,py=math.floor(x+0.5),math.floor(y+0.5)
    for _,other in ipairs(roster) do
      if (other.spaceId or "surface")==(player.spaceId or "surface")
         and (other==player or (truthy(player.team) and other.team==player.team)) then
        other:send("9",px,py)
      end
    end
    return
  elseif name=="A" then
    return Admin.handle(ctx,player,args)
  elseif name=="R" then
    return Reports.handle(ctx,player,args)
  elseif name=="Y" then
    local category=args[1]
    if #args~=1 or type(category)~="string" or not Ranking.valid(category) then
      return bad(player,name,"ranking category")
    end
    if not player.alive then return end
    local clock=assert(ctx.wallTimeMs,"authoritative wall clock required for mobile ranking")
    local now=clock()
    assert(type(now)=="number","wall clock must return milliseconds")
    if now-(player.lastMobileRankingAt or 0)<1000 then return end
    player.lastMobileRankingAt=now
    player:send("n",category,Ranking.build(assert(ctx.players,"room players required"),player,category))
    return
  elseif name=="V" then
    -- Node packets.js: watched profile SID; -1 clears the selection.
    local sid=args[1]
    if not int(sid) then return bad(player,name,"stats") end
    player.watchStats=sid
    if sid>=0 then
      local game=assert(ctx.game,"authoritative Game required for profile stats")
      assert(type(game.sendProfile)=="function",
        "real Game.sendProfile required; never fabricate account data")
      assert(type(game.sendStats)=="function",
        "real Game.sendStats required")
      game:sendProfile(player,sid)
      game:sendStats(player,sid)
    end
    return
  elseif name=="0" then
    player:send("0")
    return
  end
  -- Exact Node packets.js default: unknown packets count as anticheat invalid.
  return bad(player,name,"unhandled")
end

return Input
