-- SPDX-License-Identifier: AGPL-3.0-only
-- ModerationStore from LOCAL server/src/anticheat/index.js (not V2).
local Json=require("server-lua.vendor.dkjson")
local Moderation={}
Moderation.__index=Moderation
local function absent(v)return v==nil or v==Json.null end
local function object()return setmetatable({},{__jsontype="object"})end
local function arr()return setmetatable({},{__jsontype="array"})end
local function isoUtc(ms)
 return os.date("!%Y-%m-%dT%H:%M:%S",math.floor(ms/1000))..
  string.format(".%03dZ",math.floor(ms%1000))
end
local function read(path,fallback)
 local f=io.open(path,"rb")
 if not f then return fallback end
 local contents=f:read("*a");f:close()
 local data,_,err=Json.decode(contents,1,Json.null)
 assert(not err and type(data)=="table","corrupt LOCAL moderation JSON: "..path)
 return data
end
local function write(path,tableValue)
 local f=assert(io.open(path,"wb"))
 assert(f:write(assert(Json.encode(tableValue,{indent=true}))))
 assert(f:close())
end
function Moderation.open(dataDir,opts)
 opts=opts or {}
 assert(type(dataDir)=="string" and #dataDir>0,"original data dir required")
 local bans=read(dataDir.."/bans.json",{ips=object(),accounts=object(),devices=object()})
 bans.ips=bans.ips or object()
 bans.accounts=bans.accounts or object()
 bans.devices=bans.devices or object()
 return setmetatable({dir=dataDir,bans=bans,
  records=read(dataDir.."/moderation.json",object()),
  locks={},nowMs=opts.nowMs or function()return os.time()*1000 end},Moderation)
end
function Moderation:saveBans()write(self.dir.."/bans.json",self.bans)end
function Moderation:saveRecords()write(self.dir.."/moderation.json",self.records)end
function Moderation:migrateIds(remap)
 if not remap or next(remap)==nil then return end
 for from,to in pairs(remap) do
  if self.records[from] then
   self.records[to]=self.records[from];self.records[from]=nil
  end
  if self.bans.accounts[from] then
   self.bans.accounts[to]=self.bans.accounts[from];self.bans.accounts[from]=nil
  end
 end
 self:saveRecords();self:saveBans()
end
function Moderation:record(accountId)
 local existing=self.records[accountId]
 if existing then return existing end
 existing={reports=arr(),flags=arr(),verdict=Json.null}
 self.records[accountId]=existing
 return existing
end
function Moderation:banEntry(ip,accountId,did)
 local now=self.nowMs()
 local best,changed=nil,false
 for _,pair in ipairs({{"ips",ip},{"accounts",accountId},{"devices",did}}) do
  local kind,key=pair[1],pair[2]
  local entry=not absent(key) and self.bans[kind][key] or nil
  if entry then
   if not absent(entry.until) and entry.until~=0 and entry.until<=now then
    self.bans[kind][key]=nil;changed=true
   elseif not best or (not absent(best.until) and best.until~=0 and
      (absent(entry.until) or entry.until==0 or entry.until>best.until)) then
    best=entry
   end
  end
 end
 if changed then self:saveBans() end
 return best
end
function Moderation:isBanned(ip,accountId,did)
 return self:banEntry(ip,accountId,did)~=nil
end
function Moderation:ban(data,by)
 local now=self.nowMs()
 local row={name=data.name,by=by and by.name or "system",
   at=isoUtc(now)}
 if data.reason and data.reason~="" then row.reason=data.reason end
 if data.until and data.until~=0 then row.until=data.until end
 for _,item in ipairs({{"ips",data.ip},{"devices",data.did},
     {"accounts",data.accountId}}) do
  if not absent(item[2]) and item[2]~="" then
   self.bans[item[1]][item[2]]=row
  end
 end
 self:saveBans()
end
function Moderation:unbanAccount(id)
 self.bans.accounts[id]=nil;self:saveBans()
end
function Moderation:unbanIp(ip,did)
 if ip then self.bans.ips[ip]=nil end
 if did then self.bans.devices[did]=nil end
 self:saveBans()
end
function Moderation:lock(data,seconds)
 local untilMs=self.nowMs()+seconds*1000
 for _,part in ipairs({{"ip:",data.ip},{"did:",data.did},{"acc:",data.accountId}}) do
  if not absent(part[2]) and part[2]~="" then
   local key=part[1]..part[2]
   self.locks[key]=math.max(untilMs,self.locks[key] or 0)
  end
 end
end
function Moderation:unlock(data)
 for _,part in ipairs({{"ip:",data.ip},{"did:",data.did},{"acc:",data.accountId}}) do
  if not absent(part[2]) and part[2]~="" then
   self.locks[part[1]..part[2]]=nil
  end
 end
end
function Moderation:lockedFor(ip,accountId,did)
 local untilMs,now=0,self.nowMs()
 for _,part in ipairs({{"ip:",ip},{"did:",did},{"acc:",accountId}}) do
  if not absent(part[2]) and part[2]~="" then
   local expiry=self.locks[part[1]..part[2]]
   if expiry and expiry>now then untilMs=math.max(untilMs,expiry) end
  end
 end
 return untilMs>now and math.ceil((untilMs-now)/1000) or 0
end
function Moderation:appendReport(value)
 local f=assert(io.open(self.dir.."/reports.jsonl","ab"))
 assert(f:write(assert(Json.encode(value)).."\n"));assert(f:close())
end
function Moderation:report(data)
 local target,reporter=data.target,data.reporter
 local at=self.nowMs()
 local entry={at=at,by={name=reporter.name,
  kind=reporter.account and "account" or "guest"},
  sessionReports=data.sessionReports}
 self:appendReport({at=isoUtc(at),
  target={name=target.name,account=target.account and target.account.id or Json.null,
    flags=target.anticheat and target.anticheat:summary() or Json.null},
  reporter={name=reporter.name,
    account=reporter.account and reporter.account.id or Json.null}})
 if target.account then
  local reports=self:record(target.account.id).reports
  reports[#reports+1]=entry
  self:saveRecords()
 else
  target.reportLog=target.reportLog or arr()
  target.reportLog[#target.reportLog+1]=entry
 end
 return entry
end
function Moderation:reportReason(data)
 local entry=data.entry
 entry.reason=data.reason
 local target,reporter=data.target,data.reporter
 self:appendReport({at=isoUtc(self.nowMs()),reason=data.reason,
  target={name=target.name,account=target.account and target.account.id or Json.null},
  reporter={name=reporter.name,
    account=reporter.account and reporter.account.id or Json.null}})
 if target.account then self:saveRecords() end
end
function Moderation:flag(accountId,signal)
 if absent(accountId) then return end
 local flags=self:record(accountId).flags
 flags[#flags+1]={at=self.nowMs(),signal=signal}
 self:saveRecords()
end
function Moderation:recordVerdict(account,level,reason,staff,opts)
 opts=opts or {}
 local rec=self:record(account.id)
 rec.verdict=level=="clear" and Json.null or {
  level=level,reason=reason,by=staff.name,at=self.nowMs()}
 if level=="ban" and not opts.keepBans then
  self:ban({accountId=account.id,name=account.name,reason=reason},staff)
 elseif level=="clear" then self:unbanAccount(account.id) end
 self:saveRecords()
end
function Moderation:callbacks()
 return {
  banEntry=function(...)return self:banEntry(...)end,
  lockedFor=function(...)return self:lockedFor(...)end,
  isBanned=function(...)return self:isBanned(...)end,
  ban=function(...)return self:ban(...)end,
  report=function(data)return self:report(data)end,
  reportReason=function(data)return self:reportReason(data)end,
  flag=function(id,signal)return self:flag(id,signal)end,
  lock=function(data,seconds)return self:lock(data,seconds)end
 }
end
return Moderation
