-- SPDX-License-Identifier: AGPL-3.0-only
-- Game.sendProfile port from server/src/moomoo/server.js.
-- JSON serialization and registered account profiles are provided by real services.
local Profile={}
local function truth(v) return v~=nil and v~=false and v~=0 end
function Profile.send(game,viewer,sid)
  local target
  for _,p in ipairs(assert(game.players,"Game.players required")) do
    if p.sid==sid then target=p;break end
  end
  if not target then return end
  local data
  if truth(target.anon) and target~=viewer then
    assert(type(target.shownName)=="function","Player.shownName required")
    data={name=target:shownName(viewer),anon=true,guest=true}
  elseif target.account and target.account.name and game.accounts then
    local accounts=game.accounts
    assert(type(accounts.profile)=="function","accounts.profile required")
    local original=accounts.profile(target.account)
    assert(type(original)=="table","accounts.profile must return a profile table")
    data={}
    for k,v in pairs(original) do data[k]=v end
    data.online={server=game.key}
    if truth(target.anon) then data.anon=true else data.anon=nil end
  else
    data={name=target.name,guest=true}
  end
  local encode=assert(game.services and game.services.encodeJson,
    "authoritative JSON serializer required for profile wire payload")
  assert(type(encode)=="function","encodeJson must be a function")
  local wire=encode(data)
  assert(type(wire)=="string","profile JSON must serialize to a string")
  return viewer:send("p",sid,wire)
end
return Profile
