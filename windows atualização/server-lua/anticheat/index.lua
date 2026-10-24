-- SPDX-License-Identifier: AGPL-3.0-only
-- Parity port of Windows LOCAL COMPATIBILITY
-- server/src/anticheat/index.js (AntiCheat + Bucket).
-- Unlike the unpublished upstream policy, this repo's rules are testable.
-- Transport/ledger HMAC remains in protocol/session.lua, NOT duplicated here.
local Config=require("server-lua.anticheat.config")
local AntiCheat={}
AntiCheat.__index=AntiCheat
local Bucket={}
Bucket.__index=Bucket
local function truth(v) return v~=nil and v~=false and v~=0 and v~="" end
local function integer(v)return type(v)=="number" and v%1==0 and v==v end
local function jsString(v)
 if v==nil then return "undefined" end
 if v==true then return "true" end
 if v==false then return "false" end
 return tostring(v)
end
function Bucket.new(rate,now)
 assert(type(rate)=="table" and #rate==2,"original [rate,burst] tuple required")
 return setmetatable({rate=rate[1]/1000,capacity=rate[2],
   tokens=rate[2],updated=now},Bucket)
end
function Bucket:take(now)
 self.tokens=math.min(self.capacity,self.tokens+(now-self.updated)*self.rate)
 self.updated=now
 if self.tokens<1 then return false end
 self.tokens=self.tokens-1
 return true
end
local function signalName(reason)
 local tag=reason:match("reported ([A-Z_]+)")
 if tag then return tag end
 if reason:find("untrusted",1,true) then return "UNTRUSTED_EVENTS" end
 return reason:gsub("[^a-zA-Z]+","_"):upper():sub(1,32)
end
function AntiCheat.new(options)
 options=options or {}
 assert(type(options.nowMs)=="function",
   "original Date.now-compatible milliseconds clock required")
 assert(options.player and type(options.log)=="function"
   and type(options.kick)=="function" and type(options.close)=="function",
   "original player, log, kick and close callbacks required")
 local now=options.nowMs()
 assert(type(now)=="number" and now==now,"valid clock required")
 local cfg=options.config or Config
 return setmetatable({
  player=options.player,config=cfg,nowMs=options.nowMs,
  log=options.log,kickFn=options.kick,closeFn=options.close,
  store=options.store,session=options.session,
  sendProbes=options.sendProbes,randomSalt=options.randomSalt,
  global=Bucket.new(cfg.rateLimits.global,now),buckets={},
  strikes=0,strikeTime=now,flags=0,flagNames={},flagOrder={},
  untrustedEvents=0,lastTelemetry=0,joinedAt=0,nextProbeAt=0,
  pending=nil,rounds=0,answered=0,closed=false,
 },AntiCheat)
end
function AntiCheat:apply(action,reason)
 if self.closed then return end
 if action=="close" then
  self.log("close ("..reason..")")
  self.closed=true
  self.closeFn(4001) -- CLOSE.INVALID_CONNECTION in original constants.js
 elseif action=="kick" then
  self.log("kick ("..reason..")")
  self.closed=true
  if self.store then
   assert(type(self.store.lock)=="function","original moderation.store.lock required")
   local p=self.player
   self.store:lock({
     ip=p.ip,did=p.did,accountId=p.account and p.account.id
   },self.config.kickLock.anticheatSeconds)
  end
  self.kickFn("kicked")
 elseif action=="shame" then
  self.log("shame ("..reason..")")
  self.player.shameTimer=self.config.shame.durationMs
  self.player.skinIndex=45
 elseif action=="flag" then
  if not self.flagNames[reason] then
   self.log("flag ("..reason..")")
   if self.store and self.player.account then
    assert(type(self.store.flag)=="function","original moderation.store.flag required")
    self.store:flag(self.player.account.id,signalName(reason))
   end
   self.flagNames[reason]=true
   self.flagOrder[#self.flagOrder+1]=reason
  end
  self.player.flagged=true
 end
end
function AntiCheat:onTransportError(errorName,detail)
 local mapping={
  ["bad tag"]="badTag",["bad sequence"]="badSequence",
  ["unknown packet id"]="unknownPacket",["malformed body"]="malformed",
  ["short frame"]="malformed",["bad arguments"]="malformed"
 }
 local key=mapping[errorName] or "malformed"
 local suffix=truth(detail) and ": "..jsString(detail) or ""
 self:apply(self.config.transport[key],errorName..suffix)
end
function AntiCheat:strike(amount,reason)
 local now=self.nowMs()
 local policy=self.config.rateLimits
 local decay=math.floor((now-self.strikeTime)/policy.strikeDecayMs)
 if decay>0 then
  self.strikes=math.max(0,self.strikes-decay)
  self.strikeTime=now
 end
 self.strikes=self.strikes+amount
 if self.strikes>=policy.strikesToKick then
  self:apply("kick","too many strikes (last: "..reason..")")
 end
end
function AntiCheat:allow(name)
 local now=self.nowMs()
 if not self.global:take(now) then
  self:strike(1,"global packet rate")
  return false
 end
 local limit=self.config.rateLimits.packets[name]
 if not limit then return true end
 local bucket=self.buckets[name]
 if not bucket then
  bucket=Bucket.new(limit,now)
  self.buckets[name]=bucket
 end
 if not bucket:take(now) then
  self:strike(1,'rate of "'..name..'"')
  return false
 end
 return true
end
function AntiCheat:invalid(name,why)
 self:strike(self.config.validation.strikesPerInvalid,
  'invalid "'..name..'": '..why)
end
function AntiCheat:onGameStart()
 if truth(self.joinedAt) then return end
 self.joinedAt=self.nowMs()
 self.nextProbeAt=self.joinedAt+self.config.telemetry.firstProbeMs
end
-- Mirrors the client telemetry response. A "q" round is only sent when
-- sendProbes AND a cryptographically generated randomSalt are supplied.
function AntiCheat:onTelemetry(args)
 assert(type(args)=="table","decoded telemetry arguments required")
 local flags,untrusted,result,seal,salt=args[1],args[2],args[3],args[4],args[5]
 if not integer(flags) or flags<0 or flags>255 or
    not integer(untrusted) or untrusted<0 then
  return self:invalid("T","bad telemetry values")
 end
 local pending=self.pending
 if not pending or not integer(salt) or salt%4294967296~=pending.salt then
  return self:invalid("T","telemetry without a probe round")
 end
 self.pending=nil
 self.answered=self.answered+1
 self.lastTelemetry=self.nowMs()
 self.nextProbeAt=self.lastTelemetry+self.config.telemetry.intervalMs
 self.flags=self.flags | flags
 for bit,rule in pairs(self.config.telemetry.flags) do
  if (flags & tonumber(bit))~=0 then
   self:apply(rule.action,"client reported "..rule.name)
  end
 end
 self.untrustedEvents=untrusted
 local badEvents=self.config.telemetry.untrustedEvents
 if untrusted>=badEvents.threshold then
  self:apply(badEvents.action,untrusted.." untrusted input events")
 end
 if integer(result) and result>0 then
  for i,rule in ipairs(pending.rules) do
   if (result & (1<<(i-1)))~=0 then
    local suffix=rule.value~=nil and " "..jsString(rule.value) or ""
    local reason="client reported "..rule.name..
      " (probe "..rule.kind.." "..(rule.path or "")..suffix..")"
    self:apply(rule.action,reason)
   end
  end
 end
 local session=self.session
 if session and session.sealMode~=0 and seal~=session.sealReport then
  self:apply(self.config.seal.mismatchAction,
   "client reported SEAL_MISMATCH ("..
   (seal==nil and "no seal" or "modified bundle")..")")
 end
 if session and session.pinned and args[6]~=nil then
  local seq,ledger=args[6],args[7]
  local okSeq=integer(seq) and seq==session.lastSeq-1
  local okLedger=integer(ledger) and
   (ledger & 0xFFFFFFFF)==((session.ledgerBefore or 0) & 0xFFFFFFFF)
  if not okSeq or not okLedger then
   local message=string.format(
    "client reported LEDGER_MISMATCH (seq %s/%s, hash %s/%s)",
    jsString(seq),jsString(session.lastSeq-1),
    tostring(integer(ledger) and ledger%4294967296 or 0),
    tostring((session.ledgerBefore or 0)%4294967296))
   self:apply(self.config.telemetry.ledger.mismatchAction,message)
  end
 end
end
function AntiCheat:tick(now)
 if self.closed or not self.config.telemetry.required or
   not truth(self.joinedAt) or not self.sendProbes then return end
 local telemetry=self.config.telemetry
 if self.pending then
  if now-self.pending.sentAt>telemetry.answerMs then
   self:apply(telemetry.missingAction,self.rounds>1 and
    "telemetry stopped answering probes" or
    "telemetry never answered")
  end
  return
 end
 if now>=self.nextProbeAt then
  assert(self.config.probes.perRound==0 and #self.config.probes.list==0,
   "nonempty proprietary integrity probes have not been ported")
  assert(type(self.randomSalt)=="function",
   "fresh cryptographically random u32 salt callback required")
  local salt=self.randomSalt()
  assert(integer(salt) and salt>=0 and salt<4294967296,
   "valid 32-bit cryptographic challenge salt required")
  self.pending={salt=salt,rules={},sentAt=now}
  self.rounds=self.rounds+1
  self.sendProbes(salt,{})
 end
end
function AntiCheat:summary()
 return {
  flags=self.flags,flagNames=self.flagOrder,
  untrustedEvents=self.untrustedEvents,strikes=self.strikes,
  probes={sent=self.rounds,answered=self.answered,
    lastAnswer=self.lastTelemetry}
 }
end
return AntiCheat
