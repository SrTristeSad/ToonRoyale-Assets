-- SPDX-License-Identifier: AGPL-3.0-only
-- Original packet I: registered Player anonymous mode, cooldown, observer
-- attribute cache invalidation and immediate leaderboard refresh.
local MP=require("src.protocol.msgpack")
local Policy=require("server-lua.anticheat.config")
local Anonymous={}
local function truth(v)return v~=nil and v~=false and v~=0 and v~="" and v~=MP.null end
function Anonymous.handle(ctx,player,args)
 args=args or {}
 local value=args[1]
 if value~=0 and value~=1 then
   assert(player.anticheat and type(player.anticheat.invalid)=="function",
     "real anticheat.invalid needed for anonymous toggle")
   return player.anticheat:invalid("I","anon")
 end
 if not player.account or not truth(player.account.name) then return end
 local clock=assert(ctx.wallTimeMs,"original Date.now milliseconds clock required")
 local now=clock()
 assert(type(now)=="number","authoritative clock must return ms")
 if now-(player.anonChangedAt or 0)<Policy.rateLimits.anonCooldownMs then return end
 player.anonChangedAt=now
 local enabled=value==1
 if player.anon==enabled then return end
 player.anon=enabled
 local game=assert(ctx.game,"original Game for data resend required")
 assert(type(player.sentTo)=="table" and type(game.players)=="table",
   "Player.sentTo and Game.players required for anonymous mode")
 for _,viewer in ipairs(game.players) do
   if viewer~=player then player.sentTo[viewer.id]=nil end
 end
 game.leaderboardTimer=0
end
return Anonymous
