-- SPDX-License-Identifier: AGPL-3.0-only
-- Faithful storage port of ModerationStore in LOCAL server/src/anticheat/index.js.
-- No V2 behavior and no substitute/ephemeral ban store in production.
local Json=require("server-lua.vendor.dkjson")
local Store={}
Store.__index=Store
local function object()return setmetatable({},{__jsontype="object"})end
local function array()return setmetatable({},{__jsontype="array"})end
local function truth(v)return v~=nil and v~=Json.null and v~=false and v~=0 and v~="" end
local function load(path,default)
 local f=io.open(path,"rb")
 if not f then return default end
 local raw=f:read("*a");f:close()
 local data,_,err=Json.decode(raw,1,Json.null)
 if err or type(data)~="table" then return default end
 return data
end
local function write(path,obj)
 local encoded,err=Json.encode(obj,{indent=true})
 assert(encoded,err)
 local f,why=io.open(path,"wb")
 assert(f,why)
 assert(f:write(encoded))
 assert(f:close())
end
local function iso(ms)
 return os.date("!%Y-%m-%dT%H:%M:%S",math.floor(ms/1000))..
   string.format(".%03dZ",math.floor(ms%1000))
end
local function append(path,entry)
 local raw,err=Json.encode(entry)
 assert(raw,err)
 local f,why=io.open(path,"ab")
 assert(f,why);assert(f:write(raw,"\n"));assert(f:close())
end
function Store.open(dataDir,opts)
 opts=opts or {}
 assert(type(dataDir)=="string" and #dataDir>0,"existing LOCAL data directory required")
 local bans=load(dataDir.."/bans.json",{ips=object(),accounts=object(),devices=object()})
 bans.ips=bans.ips or object()
 bans.accounts=bans.accounts or object()
 bans.devices=bans.devices or object()
 return setmetatable({
  dir=dataDir,reportsFile=dataDir.."/reports.jsonl",
  bansFile=dataDir.."/bans.json",recordsFile=dataDir.."/moderation.json",
  bans=bans,records=load(dataDir.."/moderation.json",object()),
  locks={},nowMs=opts.nowMs or function()return os.time()*1000 end
 },Store)
end
function Store:saveBans() write(self.bansFile,self.bans) end
function Store:saveRecords() write(self.recordsFile,self.records) end
function Store:migrateIds(remap)
 if not remap or next(remap)==nil then return end
 for old,new in pairs(remap) do
  if self.records[old] then
   self.records[new]=self.records[old];self.records[old]=nil
  end
  if self.bans.accounts[old] then
   self.bans.accounts[new]=self.bans.accounts[old];self.bans.accounts[old]=nil
  end
 end
 self:saveRecords();self:saveBans()
end
function Store:record(accountId)
 if not self.records[accountId] then
  self.records[accountId]={reports=array(),flags=array(),verdict=Json.null}
 end
 return self.records[accountId]
end
function Store:banEntry(ip,accountId,did)
 local now=self.nowMs()
 local found,changed=nil,false
 for _,candidate in ipairs({{"ips",ip},{"accounts",accountId},{"devices",did}}) do
  local kind,key=candidate[1],candidate[2]
  local entry=truth(key) and self.bans[kind][key] or nil
  if entry then
   if truth(entry.until) and entry.until<=now then
    self.bans[kind][key]=nil;changed=true
   elseif not found or (truth(found.until) and
       (not truth(entry.until) or entry.until>found.until)) then
    found=entry
   end
  end
 end
 if changed then self:saveBans() end
 return found
end
function Store:isBanned(ip,accountId,did)
 return self:banEntry(ip,accountId,did)~=nil
end
function Store:ban(data,by)
 local now=self.nowMs()
 local entry={
  name=data.name,by=by and by.name or "system",
  reason=truth(data.reason) and data.reason or nil,
  until=truth(data.until) and data.until or nil,at=iso(now)
 }
 for _,key in ipairs({{"ips","ip"},{"devices","did"},{"accounts","accountId"}}) do
  local kind,field=key[1],key[2]
  if truth(data[field]) then self.bans[kind][data[field]]=entry end
 end
 self:saveBans()
end
function Store:unbanAccount(id)
 self.bans.accounts[id]=nil
 self:saveBans()
end
function Store:unbanIp(ip,did)
 if truth(ip) then self.bans.ips[ip]=nil end
 if truth(did) then self.bans.devices[did]=nil end
 self:saveBans()
end
local function lockKeys(ip,accountId,did)
 local keys={}
 if truth(ip) then keys[#keys+1]="ip:"..ip end
 if truth(did) then keys[#keys+1]="did:"..did end
 if truth(accountId) then keys[#keys+1]="acc:"..accountId end
 return keys
end
function Store:lock(data,seconds)
 local untilMs=self.nowMs()+seconds*1000
 for _,key in ipairs(lockKeys(data.ip,data.accountId,data.did)) do
  self.locks[key]=math.max(untilMs,self.locks[key] or 0)
 end
end
function Store:unlock(data)
 for _,key in ipairs(lockKeys(data.ip,data.accountId,data.did)) do
  self.locks[key]=nil
 end
end
function Store:lockedFor(ip,accountId,did)
 local now,untilMs=self.nowMs(),0
 for _,key in ipairs(lockKeys(ip,accountId,did)) do
  local value=self.locks[key]
  if value and value>now then untilMs=math.max(untilMs,value) end
 end
 return untilMs>0 and math.ceil((untilMs-now)/1000) or 0
end
function Store:report(data)
 local target,reporter=data.target,data.reporter
 local now=self.nowMs()
 local entry={at=now,by={
   name=reporter.name,kind=reporter.account and "account" or "guest"
  },sessionReports=data.sessionReports}
 append(self.reportsFile,{
  at=iso(now),
  target={name=target.name,
    account=target.account and target.account.id or Json.null,
    flags=target.anticheat and target.anticheat:summary() or Json.null},
  reporter={name=reporter.name,
    account=reporter.account and reporter.account.id or Json.null}
 })
 if target.account then
  local row=self:record(target.account.id)
  row.reports[#row.reports+1]=entry
  self:saveRecords()
 else
  target.reportLog=target.reportLog or array()
  target.reportLog[#target.reportLog+1]=entry
 end
 return entry
end
function Store:reportReason(data)
 local target,reporter,entry=data.target,data.reporter,data.entry
 entry.reason=data.reason
 append(self.reportsFile,{
  at=iso(self.nowMs()),reason=data.reason,
  target={name=target.name,
    account=target.account and target.account.id or Json.null},
  reporter={name=reporter.name,
    account=reporter.account and reporter.account.id or Json.null}
 })
 if target.account then self:saveRecords() end
end
function Store:flag(accountId,signal)
 if not truth(accountId) then return end
 local r=self:record(accountId)
 r.flags[#r.flags+1]={at=self.nowMs(),signal=signal}
 self:saveRecords()
end
function Store:recordVerdict(account,level,reason,staff,opts)
 opts=opts or {}
 local row=self:record(account.id)
 row.verdict=level=="clear" and Json.null or
   {level=level,reason=reason,by=staff.name,at=self.nowMs()}
 if level=="ban" and not opts.keepBans then
  self:ban({accountId=account.id,name=account.name,reason=reason},staff)
 end
 if level=="clear" then self:unbanAccount(account.id) end
 self:saveRecords()
end
local WEEK_MS=7*24*60*60*1000
local function signals(entries)
 local counts=object()
 for _,f in ipairs(entries) do
  counts[f.signal]=(counts[f.signal] or 0)+1
 end
 return counts
end
local function recent(entries)
 local output=array()
 for i=#entries,math.max(1,#entries-4),-1 do
  local row=entries[i]
  output[#output+1]={by=row.by,at=row.at,reason=row.reason}
 end
 return output
end
local function sessionInfo(session)
 if not session then return Json.null end
 return {at=session.at,server=session.server,ip=session.ipHash}
end
function Store:playerRecord(account,session)
 local row=self:record(account.id)
 local since=self.nowMs()-WEEK_MS
 local weekFlags,weekReports=array(),0
 for _,flag in ipairs(row.flags) do
  if flag.at>=since then weekFlags[#weekFlags+1]=flag end
 end
 for _,report in ipairs(row.reports) do
  if report.at>=since then weekReports=weekReports+1 end
 end
 return {
  reports={session=session and session.reports or 0,
   week=weekReports,lifetime=#row.reports},
  flags={week={total=#weekFlags,signals=signals(weekFlags)},
   lifetime={total=#row.flags,signals=signals(row.flags)}},
  verdict=truth(row.verdict) and
    {level=row.verdict.level,reason=row.verdict.reason} or Json.null,
  session=sessionInfo(session),recent=recent(row.reports)
 }
end
function Store:guestRecord(player,session)
 local names=player.anticheat and player.anticheat.flagOrder or array()
 local flags=array()
 for _,name in ipairs(names) do flags[#flags+1]={signal=name} end
 local reports=player.reportLog or array()
 return {
  reports={session=player.reports or 0,week=#reports,lifetime=#reports},
  flags={week={total=#flags,signals=signals(flags)},
   lifetime={total=#flags,signals=signals(flags)}},
  verdict=player.shadowed and {level="shadow",reason=""} or Json.null,
  session=sessionInfo(session),recent=recent(reports)
 }
end
return Store
