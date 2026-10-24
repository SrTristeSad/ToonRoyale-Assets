-- SPDX-License-Identifier: AGPL-3.0-only
local Profile=require("server-lua.world.profile")
local seen={}
local function encode(v)
 -- Verify values and preserve this test's intent without claiming a production encoder.
 seen[#seen+1]=v
 return "JSON"
end
local viewer={sid=1,name="Viewer"}
viewer.send=function(_,name,sid,wire)
 assert(name=="p" and wire=="JSON")
 seen[#seen+1]=sid
end
local target={sid=2,name="Guest",anon=false}
target.shownName=function() return "Anon#2" end
local game={players={viewer,target},key="LC",services={encodeJson=encode}}
Profile.send(game,viewer,2)
assert(seen[1].guest and seen[1].name=="Guest" and seen[2]==2)
seen={}
target.anon=true
Profile.send(game,viewer,2)
assert(seen[1].anon and seen[1].guest and seen[1].name=="Anon#2")
seen={}
target.account={name="Account",id=7}
game.accounts={profile=function(account)
 assert(account==target.account)
 return {name="Account",wins=9}
end}
Profile.send(game,viewer,2)
assert(seen[1].anon and seen[1].guest and seen[1].name=="Anon#2")
seen={}
target.anon=false
Profile.send(game,viewer,2)
assert(seen[1].online.server=="LC" and seen[1].wins==9 and seen[1].anon==nil)
seen={}
local before=#seen
Profile.send(game,viewer,999)
assert(#seen==before)
game.accounts.profile=nil
assert(not pcall(function() Profile.send(game,viewer,2) end))
print("PASS perfis guest, anon, conta, ausente e dependencia real")
