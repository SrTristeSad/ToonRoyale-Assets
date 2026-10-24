-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of packet "6" from original server/src/network/packets.js.
local Filter=require("server-lua.world.chat_filter")
local Chat={}
function Chat.handle(ctx,player,args)
 args=args or {}
 if not player.alive then return end
 if type(args[1])~="string" then
   assert(player.anticheat and type(player.anticheat.invalid)=="function",
     "real anticheat required for malformed chat")
   return player.anticheat:invalid("6","chat")
 end
 if player.chatCooldown>0 then return end
 local message=Filter.clean(args[1])
 if #message==0 then return end
 local cfg=assert(ctx.config,"original shared config required for chat")
 player.chatCooldown=assert(cfg.chatCooldown,"original chat cooldown required")
 if ctx.chat then
   assert(type(ctx.chat.gameChat)=="function",
     "real staff message log callback required")
   ctx.chat:gameChat(player,message,ctx.gameKey or "LC")
 end
 if player.shadowed then
   player:send("6",player.sid,message)
 else
   assert(type(ctx.broadcast)=="function",
     "real Game.server.broadcast required for normal chat")
   ctx.broadcast("6",player.sid,message)
 end
end
return Chat
