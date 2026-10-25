-- SPDX-License-Identifier: AGPL-3.0-only
local Anon=require("server-lua.world.anon_input")
local MP=require("src.protocol.msgpack")
local specs={
 {id="enable",data={1},account="Hero",now=100000,anon=false},
 {id="disable",data={0},account="Hero",now=100000,anon=true},
 {id="repeat-enable",data={1},account="Hero",now=100000,anon=true},
 {id="repeat-disable",data={0},account="Hero",now=100000,anon=false},
 {id="too-soon",data={1},account="Hero",now=100000,changed=95000},
 {id="border-before",data={1},account="Hero",now=100000,changed=90001},
 {id="border-exact",data={1},account="Hero",now=100000,changed=90000},
 {id="invalid",data={2},account="Hero",now=100000},
 {id="invalid-boolean",data={true},account="Hero",now=100000},
 {id="invalid-string",data={"1"},account="Hero",now=100000},
 {id="invalid-null",data={MP.null},account="Hero",now=100000},
 {id="invalid-empty",data={},account="Hero",now=100000},
 {id="guest",data={1},now=100000},
 {id="empty-account",data={1},account="",now=100000},
 {id="zero-time",data={1},account="Hero",now=9000},
 {id="early-exact",data={1},account="Hero",now=10000},
 {id="prior-change-noact",data={1},account="Hero",now=120000,changed=115000},
 {id="old-change",data={1},account="Hero",now=120000,changed=100000}
}
for _,tc in ipairs(specs) do
 local events={}
 local p={
   id="self",sid=7,anon=tc.anon or false,
   account=tc.account~=nil and {name=tc.account} or nil,
   anonChangedAt=tc.changed or 0,
   sentTo={self=1,other=2,third=3}
 }
 p.anticheat={invalid=function(_,n,reason)
   events[#events+1]="INVALID:"..n..":"..reason
 end}
 local game={players={p,{id="other"},{id="third"}},leaderboardTimer=1520}
 Anon.handle({game=game,wallTimeMs=function()return tc.now end},p,tc.data)
 local keys={}
 for name in pairs(p.sentTo)do keys[#keys+1]=name end
 table.sort(keys)
 print(table.concat({"ANON",tc.id,p.anon and 1 or 0,
  p.anonChangedAt,game.leaderboardTimer,table.concat(keys,","),
  table.concat(events,";")},"|"))
end
