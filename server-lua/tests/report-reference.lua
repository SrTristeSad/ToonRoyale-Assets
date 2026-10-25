-- Exact packet R behavior against the original Node reference.
local Input=require("server-lua.world.input")
local events={}
local function emit(value)events[#events+1]=value end
local reporter={sid=1,reported={},anticheat={
 invalid=function(_,name,why)emit("invalid:"..name..":"..why)end}}
local nilTarget={sid=2,name="Two",reports=0,ip="127.0.0.1"}
local storedTarget={sid=3,name="Three",reports=0,ip="127.0.0.2"}
function storedTarget:kick(reason)emit("kick:"..reason)end
local returnEntry=false
local ctx={players={reporter,nilTarget,storedTarget},items={weapons={},list={}},
 moderation={
  report=function(data)
    emit("report:"..data.target.sid..":"..data.sessionReports)
    if returnEntry then return {reason=nil} end
    return nil
  end,
  reportReason=function(data)
    emit("reason:"..data.reason)
    data.entry.reason=data.reason
  end,
  ban=function(data,by)
    emit("ban:"..data.name)
    assert(by==reporter)
  end
 }}
local function send(...)return Input.handle(ctx,reporter,"R",{...})end
send(2);send(2);send(2,0,1)
print("NIL_REPORT|"..nilTarget.reports.."|"..table.concat(events,","))
events={};returnEntry=true
send(3);send(3);send(3,0,2);send(3,0,3)
print("STORED_REPORT|"..storedTarget.reports.."|"..table.concat(events,","))
events={}
send(3,2)
print("NO_ROLE|"..table.concat(events,","))
events={};reporter.role="mod"
send(3,2)
print("LOCAL_BAN|"..table.concat(events,","))
events={}
send(3,1)
print("LOCAL_SHADOW|"..tostring(storedTarget.shadowed).."|"..table.concat(events,","))
