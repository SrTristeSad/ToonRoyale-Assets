-- SPDX-License-Identifier: AGPL-3.0-only
local Input=require("server-lua.world.input")
local events={}
local function event(x) events[#events+1]=x end
local reporter={sid=1,role=nil,anticheat={invalid=function(_,p,r)event("invalid:"..p..":"..r) end}}
local target={sid=2,reports=0,ip="local",name="Target",kick=function(_,r)event("kick:"..r) end}
local accounts={setVerdict=function(name,verdict)event("verdict:"..name..":"..verdict) end}
local moderation={
 report=function(data)
   assert(data.reporter==reporter and data.target==target)
   event("report:"..data.sessionReports)
   return {reason=nil}
 end,
 reportReason=function(data)
   assert(data.target==target)
   data.entry.reason=data.reason
   event("reason:"..data.reason)
 end,
 ban=function(data,by)
   assert(by==reporter and data.name=="Target")
   event("ban")
 end
}
local ctx={items={weapons={},list={}},players={reporter,target},moderation=moderation,accounts=accounts}
local function send(args) Input.handle(ctx,reporter,"R",args) end
send({"bad"})
send({1})
send({99})
send({2})
send({2})
assert(target.reports==1,"duplicate must not count")
send({2,0,2})
send({2,0,3})
send({2,0,9})
send({2,1})
reporter.role="mod"
send({2,1})
assert(target.shadowed==true)
target.account={id=7,name="Member"}
send({2,2})
local expected={
 "invalid:R:report","report:1","reason:Hack","invalid:R:report reason",
 "invalid:R:staff action","ban","verdict:Member:ban","kick:kicked"
}
-- Shadow action performed before assigning account: no persisted verdict yet.
assert(#events==#expected,"wrong event count: "..table.concat(events,","))
for i=1,#expected do
 assert(events[i]==expected[i],i..": "..events[i].." ~= "..expected[i])
end
-- A missing persistence service must never silently accept account sanctions.
ctx.accounts=nil
local ok=pcall(function() send({2,2}) end)
assert(not ok,"account sanctions require persistence")
print("PASS pacote R: 12 entradas, permissão, deduplicação e persistência obrigatória")
