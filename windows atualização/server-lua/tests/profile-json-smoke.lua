-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.sendProfile must serialize real JSON even without a test callback.
local Json=require("server-lua.vendor.dkjson")
local Profile=require("server-lua.world.profile")
local sent={}
local viewer={sid=1}
function viewer:send(name,sid,payload)
  assert(name=="p" and sid==2 and type(payload)=="string")
  local data,_,err=Json.decode(payload,1,Json.null)
  assert(not err)
  sent[#sent+1]=data
end
local target={sid=2,name="Player",anon=false}
function target:shownName()return "Anon#2" end
local game={key="LC",players={viewer,target},services={}}
Profile.send(game,viewer,2)
assert(sent[1].guest==true and sent[1].name=="Player")
local account={id="123",name="Permanent",stats={kills=4}}
target.account=account
game.accounts={profile=function(a)
 assert(a==account)
 return {name=a.name,kills=a.stats.kills,guest=false}
end}
Profile.send(game,viewer,2)
assert(sent[2].kills==4 and sent[2].online.server=="LC" and sent[2].guest==false)
target.anon=true
Profile.send(game,viewer,2)
assert(sent[3].name=="Anon#2" and sent[3].anon==true)
print("PASS perfil JSON de produção: convidado, conta e modo anônimo")
