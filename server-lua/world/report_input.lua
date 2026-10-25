-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of packets.js case R: report, report reason, staff shadow and ban.
-- Persistent reports and sanctions are delegated to mandatory real services.
local Reports={}
-- JS Map.has(sid) remains true when Map.set(sid, undefined) was used.
local UNDEFINED={}
local reasons={"Bot","Hack","Autoheal","Abuse"}
local function int(v)
  return type(v)=="number" and v==v and v%1==0 and v~=math.huge and v~=-math.huge
end
local function invalid(player,reason)
  assert(player.anticheat and type(player.anticheat.invalid)=="function",
    "real anticheat.invalid required")
  return player.anticheat:invalid("R",reason)
end
local function service(ctx,name)
  local moderation=assert(ctx.moderation,"original moderation service required for R")
  assert(type(moderation[name])=="function","moderation."..name.." required")
  return moderation[name]
end
function Reports.handle(ctx,player,args)
  local sid=args[1]
  if not int(sid) then return invalid(player,"report") end
  local target
  for _,candidate in ipairs(assert(ctx.players,"game players required")) do
    if candidate.sid==sid then target=candidate;break end
  end
  if not target or target==player then return end
  local action=args[2]
  if action==nil then
    player.reported=player.reported or {}
    if player.reported[sid]~=nil then return end
    target.reports=(target.reports or 0)+1
    local report=service(ctx,"report")({
      target=target,reporter=player,sessionReports=target.reports
    })
    player.reported[sid]=report==nil and UNDEFINED or report
    return
  end
  if action==0 then
    local reason=int(args[3]) and reasons[args[3]] or nil
    if not reason then return invalid(player,"report reason") end
    local entry=player.reported and player.reported[sid]
    if not entry or entry==UNDEFINED or entry.reason then return end
    return service(ctx,"reportReason")({
      target=target,reporter=player,entry=entry,reason=reason
    })
  end
  if player.role~="mod" and player.role~="admin" then
    return invalid(player,"staff action")
  end
  if action==2 then
    local ban=service(ctx,"ban")
    -- Node packets.js only persists verdict when an account store exists.
    local account=target.account
    ban({ip=target.ip,accountId=account and account.id or nil,name=target.name},player)
    if account and ctx.accounts then
      assert(type(ctx.accounts.setVerdict)=="function",
        "original AccountStore.setVerdict required when accounts is supplied")
      ctx.accounts.setVerdict(account.name,"ban")
    end
    if type(target.kick)=="function" then target:kick("kicked") end
  elseif action==1 then
    target.shadowed=true
    if target.account and ctx.accounts then
      assert(type(ctx.accounts.setVerdict)=="function",
        "original AccountStore.setVerdict required when accounts is supplied")
      ctx.accounts.setVerdict(target.account.name,"shadow")
    end
  end
end
return Reports
