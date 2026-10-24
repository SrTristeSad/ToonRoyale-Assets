-- SPDX-License-Identifier: AGPL-3.0-only
-- HTTP handlers from the Windows LOCAL server/src/api/routes.js.
-- This is the original non-V2 AccountStore flow, not a new login service.
local Json=require("server-lua.vendor.dkjson")
local Social=require("server-lua.net.local_social")
local AntiCheatConfig=require("server-lua.anticheat.config")
local API={}
API.__index=API
local function truth(v) return v~=nil and v~=false and v~=0 and v~="" and v~=Json.null end
local function str(v)
 if v==nil or v==Json.null then return "" end
 if type(v)=="string" then return v end
 if type(v)=="table" then return "[object Object]" end
 return tostring(v)
end
local function queryPart(raw)
 return (raw or ""):gsub("%+"," "):gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)
end
local function query(raw,key)
 for part in (raw or ""):gmatch("[^&]+") do
  local k,v=part:match("^([^=]+)=?(.*)$")
  if queryPart(k)==key then return queryPart(v) end
 end
 return ""
end
local function response(status,payload) return status,payload end
local function invalid(error,status) return response(status or 403,{error=error}) end
function API.new(opts)
 opts=opts or {}
 assert(opts.store and type(opts.store.issueTicket)=="function"
  and type(opts.store.consumeTicket)=="function"
  and type(opts.store.verifyToken)=="function",
  "original AccountStore required")
 assert(opts.moderation and type(opts.moderation.banEntry)=="function"
  and type(opts.moderation.lockedFor)=="function",
  "original ModerationStore banEntry/lockedFor required")
 return setmetatable({store=opts.store,moderation=opts.moderation,
  roomCode=assert(opts.roomCode,"local invitation code required"),
  game=opts.game,
  servers=assert(opts.servers,"original local LC and MB server list required"),
  nowMs=opts.nowMs or function()return os.time()*1000 end,
  friendRate={},social=Social.new({store=opts.store,
    friendshipChanged=opts.friendshipChanged})},API)
end
function API:authenticated(body)
 local account=self.store:verifyToken(body.auth)
 if not truth(account) then return nil end
 return account
end
function API:handle(method,target,headers,raw,ip)
 headers=headers or {}
 local path,qs=target:match("^([^?]*)%??(.*)$")
 if not path or path:sub(1,5)~="/api/" then return nil end
 local store=self.store
 local body={}
 if method=="POST" or method=="DELETE" then
  if type(raw)~="string" or #raw>32768 then return response(413,{error="too large"}) end
  if raw~="" then
   local decoded,pos,why=Json.decode(raw,1,Json.null)
   if why or type(decoded)~="table" or not raw:sub(pos):match("^%s*$") then
    return response(400,{error="invalid JSON"})
   end
   body=decoded
  end
 end
 if path:match("^/api/social/friends/") then
  return self.social:handle(method,path,headers,body)
 end
 if path=="/api/join" and method=="POST" then
  if headers["x-mooio-code"]~=self.roomCode then
   return invalid("invite_required")
  end
  local account=truth(body.auth) and store:verifyToken(body.auth) or nil
  if truth(body.auth) and not truth(account) then return invalid("auth") end
  local did=type(body.did)=="string" and body.did or nil
  local banned=self.moderation:banEntry(ip,account and account.id or nil,did)
  if truth(banned) or (account and account.verdict=="ban") then
   return response(403,{error="banned",until=truth(banned) and (banned.until or 0) or 0})
  end
  local seconds=self.moderation:lockedFor(ip,account and account.id or nil,did)
  if truth(seconds) then return response(403,{error="locked",seconds=seconds}) end
  if not account and not truth(body.captcha) and not store:recentDevice(did) then
   return invalid("captcha")
  end
  local server=type(body.host)=="string" and body.host:match("/s/([%w]+)$") or nil
  return response(200,store:issueTicket({account=account,did=did,server=server}))
 end
 if method=="POST" and path=="/api/auth/code" then
  local flow=store:startLogin(body.email)
  if not truth(flow) then return response(400,{type="invalidEmail"}) end
  return response(200,{flow=flow})
 end
 if method=="POST" and path=="/api/auth/verify" then
  local code=str(body.code)
  if not code:match("^%d%d%d%d%d%d$") then return response(400,{type="invalidCode"}) end
  local account=store:finishLogin(body.flow)
  if not truth(account) then return response(400,{type="serverError"}) end
  return response(200,{token=store:issueToken(account),email=account.email,id=account.id})
 end
 if method=="POST" and path=="/api/auth/password" then
  local password=str(body.password)
  local account=store:accountForEmail(body.email)
  if not truth(account) or #password==0 then
   return response(400,{type="invalidCredentials"})
  end
  return response(200,{token=store:issueToken(account),email=account.email,id=account.id})
 end
 if method=="POST" and path=="/api/auth/refresh" then
  local account=store:verifyToken(body.token)
  if not truth(account) then return response(403,{type="accountNotActive"}) end
  return response(200,{token=store:issueToken(account),email=account.email,id=account.id})
 end
 if method=="GET" and path=="/api/servers" then return response(200,self.servers()) end
 if method=="GET" and path=="/api/name-check" then
  return response(200,{reserved=store:nameOwner(query(qs,"name"))~=nil})
 end
 if method=="GET" and path=="/api/clan-check" then
  local name=query(qs,"name"):match("^%s*(.-)%s*$"):lower()
  local reserved=name=="solo"
  for _,clan in pairs(store.data.clans) do
   if clan.name:lower()==name then reserved=true;break end
  end
  return response(200,{reserved=reserved})
 end
 if method=="GET" and path=="/api/top" then
  local span=query(qs,"span")
  if span~="week" and span~="month" and span~="all" then span="week" end
  local board=store:top(span)
  local players,clans={},{}
  for _,p in ipairs(board.players) do if not p.shadowed then players[#players+1]=p end end
  for _,c in ipairs(board.clans) do if not c.shadowed then clans[#clans+1]=c end end
  return response(200,{players=players,clans=clans})
 end
 if method=="GET" and path=="/api/profile" then
  local account=store:nameOwner(query(qs,"name"))
  if not account then return invalid("not found",404) end
  return response(200,store:profile(account))
 end
 if method=="GET" and path=="/api/clan" then
  local name=query(qs,"name"):lower()
  for _,clan in pairs(store.data.clans) do
   if clan.name:lower()==name then return response(200,store:clanView(clan)) end
  end
  return invalid("not found",404)
 end
 if method=="GET" and path=="/api/discord/link" then
  local entry=store:discordCode(query(qs,"code"))
  if not truth(entry) then return invalid("code",404) end
  return response(200,{discord=entry.discord})
 end
 if method=="POST" and path=="/api/names-for" then
  return response(200,{names=store:namesFor(body.ids)})
 end
 if method=="POST" and path=="/api/client-log" then return response(204,{}) end
 if method~="POST" then return nil end
 local authPaths={
  ["/api/account"]=true,["/api/account/prefs"]=true,
  ["/api/account/look"]=true,["/api/name"]=true,
  ["/api/account/socials"]=true,["/api/discord/link"]=true,
  ["/api/friends/allow"]=true,["/api/top"]=true,
  ["/api/mod/role"]=true,["/api/mod/clan"]=true,
  ["/api/mod/verdict"]=true,["/api/mod/kick"]=true,
  ["/api/mod/player"]=true
 }
 local clanAction=path:match("^/api/clan/([%w]+)$")
 if not authPaths[path] and not clanAction then return nil end
 local account=self:authenticated(body)
 if not account then return invalid("auth") end
 if path=="/api/mod/role" then
  if account.role~="admin" then return invalid("rank") end
  if not store:setRole(body.name,body.role) then return invalid("no player",404) end
  return response(200,{})
 end
 if path=="/api/mod/clan" then
  if account.role~="admin" and account.role~="mod" then return invalid("rank") end
  if not store:setClanShadow(body.clan,body.shadow) then return invalid("not found",404) end
  return response(200,{})
 end
 if path=="/api/mod/verdict" then
  if account.role~="admin" and account.role~="mod" then return invalid("rank") end
  local game=assert(self.game,"original gameApi required for staff verdict")
  local level=(body.level=="ban" or body.level=="shadow" or body.level=="clear")
    and body.level or "clear"
  local reason=str(body.reason):sub(1,80)
  local minutes=tonumber(body.minutes) or 0
  if minutes==0 then minutes=(tonumber(body.days) or 0)*24*60 end
  local untilMs=minutes>0 and self.nowMs()+minutes*60*1000 or 0
  if truth(body.id) and not truth(body.name) then
   local guest=game.playerBySession(str(body.id))
   if not guest then return invalid("no player",404) end
   if level=="ban" then
    self.moderation:ban({ip=guest.ip,did=guest.did,
      name=guest.name,reason=reason,until=untilMs},account)
    if guest.kick then guest.kick("kicked") end
   elseif level=="shadow" then
    guest.shadowed=true
   elseif truth(body.ip) then
    self.moderation:unbanIp(guest.ip,guest.did)
   end
   return response(200,{})
  end
  local target=store:nameOwner(body.name)
  if not target then return invalid("no player",404) end
  if level=="ban" and untilMs>0 then
   self.moderation:ban({accountId=target.id,name=target.name,
      reason=reason,until=untilMs},account)
   local date=os.date("!%Y-%m-%d %H:%M",math.floor(untilMs/1000))
   self.moderation:recordVerdict(target,"ban",
      reason.." (until "..date..")",account,{keepBans=true})
  else
   store:setVerdict(target.name,level)
   self.moderation:recordVerdict(target,level,reason,account)
  end
  local last=type(target.lastSeen)=="table" and target.lastSeen or {}
  if level=="ban" and truth(body.ip) and truth(last.ip) then
   self.moderation:ban({ip=last.ip,did=last.did,
     name=target.name,reason=reason,until=untilMs},account)
  end
  if level=="clear" and truth(body.ip) and truth(last.ip) then
   self.moderation:unbanIp(last.ip,last.did)
  end
  if level=="ban" then game.kickAccount(target.id,"kicked") end
  game.setShadow(target.id,level=="shadow")
  return response(200,{})
 end
 if path=="/api/mod/player" or path=="/api/mod/kick" then
  if account.role~="admin" and account.role~="mod" then return invalid("rank") end
  local game=assert(self.game,"original gameApi required for staff requests")
  local guest=truth(body.id) and not truth(body.name) and
    game.playerBySession(str(body.id)) or nil
  local target=not guest and store:nameOwner(body.name) or nil
  if path=="/api/mod/player" then
   if guest then
    return response(200,self.moderation:guestRecord(guest,game.sessionOf(guest)))
   end
   if not target then return invalid("no player",404) end
   return response(200,self.moderation:playerRecord(target,game.sessionFor(target.id)))
  end
  local kicked=0
  local seconds=AntiCheatConfig.kickLock.staffSeconds
  if truth(body.id) and not truth(body.name) then
   if guest and guest.kick then
    self.moderation:lock({ip=guest.ip,did=guest.did},seconds)
    guest.kick("kicked");kicked=1
   end
  elseif target then
   local last=type(target.lastSeen)=="table" and target.lastSeen or {}
   self.moderation:lock({accountId=target.id,ip=last.ip,did=last.did},seconds)
   kicked=game.kickAccount(target.id,"kicked")
  end
  if kicked==0 then return invalid("not online",404) end
  return response(200,{})
 end
 if path=="/api/account" then return response(200,store:accountInfo(account)) end
 if path=="/api/account/prefs" then
  return response(200,{prefs=store:setPrefs(account,body.prefs)})
 end
 if path=="/api/account/look" then
  if body.look==nil then return response(200,store:lookInfo(account)) end
  local result=store:setLook(account,body.look)
  return response(result.status,result.body)
 end
 if path=="/api/name" then
  local result=store:claimName(account,body.name)
  return response(result.status,result.body)
 end
 if path=="/api/account/socials" then
  local result=store:setSocials(account,body.socials)
  return response(result.status,result.body)
 end
 if path=="/api/discord/link" then
  local result=store:linkDiscord(account,body.code)
  return response(result.status,result.body)
 end
 if path=="/api/friends/allow" then
  local recipient=store:accountById(str(body.to))
  if not recipient or recipient.id==account.id then return invalid("not found",404) end
  if not store:prefsOf(recipient).friendRequests then return invalid("closed") end
  local hits=self.friendRate[account.id] or {}
  local now=self.nowMs()
  local within={}
  for _,timestamp in ipairs(hits) do
   if now-timestamp<60*60*1000 then within[#within+1]=timestamp end
  end
  self.friendRate[account.id]=within
  if #within>=20 then return invalid("rate",429) end
  within[#within+1]=now
  return response(200,{silent=account.verdict=="shadow"})
 end
 if path=="/api/top" then
  if account.role~="admin" and account.role~="mod" then return invalid("rank") end
  local span=body.span
  if span~="week" and span~="month" and span~="all" then span="week" end
  return response(200,store:top(span))
 end
 if clanAction then
  local result=store:clanAction(account,clanAction,body)
  return response(result.status,result.body)
 end
 return nil
end
return API
