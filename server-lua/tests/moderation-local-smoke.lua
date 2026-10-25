-- ModerationStore LOCAL Node behavior through actual account/join API.
local Accounts=require("server-lua.world.account_store")
local Moderation=require("server-lua.anticheat.moderation_store")
local API=require("server-lua.net.local_api")
local Json=require("server-lua.vendor.dkjson")
local prefix="server-lua/tests/.moderation-local"
local data={
  prefix.."/bans.json",prefix.."/moderation.json",prefix.."/reports.jsonl"
}
-- CI creates this fixture directory; never write into production server/data.
assert(os.execute('mkdir -p "'..prefix..'"'))
for _,p in ipairs(data) do os.remove(p) end
local ms=1792864800000
local clock=function()return ms end
local ok,err=pcall(function()
 local accountFile=prefix.."/accounts.json"
 local accounts=Accounts.open(accountFile,{
   nowMs=clock,secret=string.rep("K",32),
   randomBytes=function(n)return string.rep("a",n)end
 })
 local moderation=Moderation.open(prefix,{nowMs=clock})
 local api=API.new({store=accounts,moderation=moderation,
   roomCode="testing42",servers=function()return {{key="LC"},{key="MB"}}end,
   nowMs=clock})
 local function join(body)
  local status,result=api:handle("POST","/api/join",
    {["x-mooio-code"]="testing42"},assert(Json.encode(body)),"10.0.0.3")
  return status,result
 end
 local status,result=join({host="/s/LC",captcha=true})
 assert(status==200 and result.ticket and result.did)
 local account=accounts:accountForEmail("tester@example.com")
 local token=accounts:issueToken(account)
 status,result=join({host="/s/LC",auth=token,captcha=true})
 assert(status==200 and result.ticket)
 moderation:ban({ip="10.0.0.3",name="Tester",reason="staff",until=ms+4000})
 status,result=join({host="/s/LC",captcha=true})
 assert(status==403 and result.error=="banned" and result.until==ms+4000)
 assert(moderation:isBanned("10.0.0.3")==true)
 local reopened=Moderation.open(prefix,{nowMs=clock})
 assert(reopened:isBanned("10.0.0.3")==true)
 ms=ms+4001
 assert(reopened:banEntry("10.0.0.3")==nil)
 local saved=Moderation.open(prefix,{nowMs=clock})
 assert(saved:isBanned("10.0.0.3")==false)
 saved:lock({ip="10.0.0.3",accountId=account.id},120)
 status,result=join({host="/s/LC",auth=token,captcha=true})
 -- The active API instance still uses moderation; verify lock via same instance.
 assert(status==200)
 moderation:lock({ip="10.0.0.3"},120)
 status,result=join({host="/s/LC",captcha=true})
 assert(status==403 and result.error=="locked" and result.seconds==120)
 ms=ms+120001
 assert(moderation:lockedFor("10.0.0.3")==0)
 local target={name="Target",account=account,reports=1}
 local reporter={name="Reporter",account=nil}
 local report=moderation:report({
   target=target,reporter=reporter,sessionReports=1
 })
 moderation:reportReason({
   target=target,reporter=reporter,entry=report,reason="Hack"
 })
 moderation:flag(account.id,"badTag")
 local record=moderation:playerRecord(account,nil)
 assert(record.reports.lifetime==1 and record.reports.week==1)
 assert(record.flags.lifetime.total==1 and record.flags.week.total==1)
 assert(record.recent[1].reason=="Hack")
 moderation:recordVerdict(account,"ban","staff",reporter)
 assert(moderation:isBanned(nil,account.id,nil))
 moderation:recordVerdict(account,"clear","resolved",reporter)
 assert(not moderation:isBanned(nil,account.id,nil))
 local second=Moderation.open(prefix,{nowMs=clock})
 assert(second:record(account.id).verdict==Json.null)
 assert(#second:record(account.id).reports==1)
 assert(#second:record(account.id).flags==1)
 local file=assert(io.open(prefix.."/reports.jsonl","rb"))
 local reports=file:read("*a");file:close()
 assert(reports:find('"reason":"Hack"',1,true))
 os.remove(accountFile)
 os.remove(accountFile..".lua-backup")
 os.remove(accountFile..".lua-new")
end)
for _,p in ipairs(data) do os.remove(p) end
os.execute('rmdir "'..prefix..'"')
assert(ok,err)
print("PASS LOCAL ModerationStore: bans persistentes, expiry, locks, report, verdict, /api/join")
