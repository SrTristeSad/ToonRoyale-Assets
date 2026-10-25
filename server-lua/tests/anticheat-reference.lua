-- SPDX-License-Identifier: AGPL-3.0-only
-- Counterpart to the REAL Node AntiCheat implementation, with identical
-- timestamps and same supplied scenarios.
local AC=require("server-lua.anticheat.index")
local Config=require("server-lua.anticheat.config")
local clock=100000
local anti,events,player,scenario
local function fmt(v)return string.format("%.6f",v)end
local function text(v)return tostring(v)end
local function output(label)
 local summary=anti:summary()
 local names={}
 for key in pairs(anti.buckets) do names[#names+1]=key end
 table.sort(names)
 local buckets={}
 for _,key in ipairs(names) do
  buckets[#buckets+1]=key..":"..fmt(anti.buckets[key].tokens)
 end
 print(table.concat({
  "AC",scenario,label,anti.closed and 1 or 0,anti.strikes,
  fmt(anti.global.tokens),table.concat(buckets,","),anti.flags,
  anti.flagged and 1 or 0,player.flagged and 1 or 0,
  player.skinIndex,player.shameTimer or 0,
  table.concat(summary.flagNames,","),summary.untrustedEvents,
  summary.probes.sent,summary.probes.answered,summary.probes.lastAnswer,
  anti.pending and anti.pending.salt or "~",
  anti.joinedAt,anti.nextProbeAt,table.concat(events,";")
 },"|"))
end
local function parse(line)
 local result={}
 for field in (line.."|"):gmatch("(.-)|") do result[#result+1]=field end
 return result
end
local function operate(row)
 local a,b,c,d,e,f,g,h,i=table.unpack(row)
 if a=="case" then
  scenario=b;clock=100000;events={}
  player={id="player",name="Hero",ip="1.2.3.4",did="device",
   account={id="account"},flagged=false,skinIndex=0}
  local store={
   lock=function(self,ident,seconds)
    events[#events+1]="LOCK:"..table.concat({
      ident.ip,ident.did,ident.accountId,seconds},",")
   end,
   flag=function(self,id,signal)events[#events+1]="FLAG:"..id..":"..signal end
  }
  anti=AC.new({
   player=player,store=store,nowMs=function()return clock end,
   session={sealMode=1,sealReport="original",pinned=true,
     lastSeq=5,ledgerBefore=100},
   log=function(entry)events[#events+1]="LOG:"..entry end,
   kick=function(reason)events[#events+1]="KICK:"..reason end,
   close=function(code)events[#events+1]="CLOSE:"..code end
  })
  return
 end
 assert(a=="step","unexpected scenario step")
 clock=tonumber(b)
 local label=c
 if c=="burst" then
  local yes,no=0,0
  for _=1,tonumber(e) do
   if anti:allow(d) then yes=yes+1 else no=no+1 end
  end
  label="burst:"..d..":"..yes..":"..no
 elseif c=="allow" then
  label="allow:"..d..":"..(anti:allow(d) and 1 or 0)
 elseif c=="strike" then
  anti:strike(tonumber(d),e)
  label="strike:"..d
 elseif c=="invalid" then
  anti:invalid(d,e)
  label="invalid:"..d
 elseif c=="apply" then
  anti:apply(d,e)
  label="apply:"..d
 elseif c=="transport" then
  anti:onTransportError(d,e~="" and e or nil)
  label="transport:"..d
 elseif c=="joined" then
  anti:onGameStart()
 elseif c=="pending" then
  anti.sendProbes=function()events[#events+1]="PROBE"end
  anti.pending={salt=tonumber(d),rules={},sentAt=clock}
  anti.rounds=1
 elseif c=="rounds" then
  anti.rounds=tonumber(d)
 elseif c=="telemetry" then
  anti:onTelemetry({
    tonumber(d),tonumber(e),tonumber(f),g,tonumber(h),tonumber(i),
    tonumber(row[10])
  })
  label="telemetry:"..d..":"..e
 elseif c=="tick" then
  anti:tick(clock)
 else error("unexpected test command: "..c) end
 output(label)
end
for line in io.lines("server-lua/tests/anticheat-scenarios.txt") do
 if line~="" and line:sub(1,1)~="#" then operate(parse(line)) end
end
