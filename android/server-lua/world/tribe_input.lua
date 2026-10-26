-- SPDX-License-Identifier: AGPL-3.0-only
-- Original packet cases L/N/b/P/Q from server/src/network/packets.js.
local MP=require("src.protocol.msgpack")
local TribesInput={}
local function truth(v) return v~=nil and v~=false and v~=0 and v~="" and v~=MP.null end
local function isInt(v) return type(v)=="number" and v==v and v%1==0 and v~=math.huge end
local function invalid(player,name,reason)
 assert(player.anticheat and type(player.anticheat.invalid)=="function",
   "original anticheat.invalid required")
 return player.anticheat:invalid(name,reason)
end
local function trim(s)
 return (s:gsub("^%s+",""):gsub("%s+$",""))
end
function TribesInput.handle(ctx,player,name,args)
 local mgr=assert(ctx.tribes,"original Game.clan_manager required")
 args=args or {}
 if name=="L" then
   if not player.alive or truth(player.team) or player.tribeCooldown>0 then return end
   local raw=args[1]
   if type(raw)~="string" then return invalid(player,name,"tribe name") end
   local clean=trim(raw)
   if clean=="" or #clean>7 or clean:find("[^ -~]") then return end
   if clean:lower()=="solo" then return end
   local accounts=ctx.accounts
   if accounts and accounts.data and accounts.data.clans then
     local reserved=false
     for clanName in pairs(accounts.data.clans) do
       if type(clanName)=="string" and clanName:lower()==clean:lower() then
         reserved=true;break
       end
     end
     if reserved and clean:lower()~=tostring(player.clanTag or ""):lower() then return end
   end
   player.tribeCooldown=200
   return mgr:create(clean,player)
 elseif name=="N" then
   if not truth(player.team) or player.tribeCooldown>0 then return end
   player.tribeCooldown=200
   return mgr:leaveTribe(player)
 elseif name=="b" then
   if type(args[1])~="string" then return invalid(player,name,"tribe") end
   if not player.alive or truth(player.team) or player.tribeCooldown>0 then return end
   player.tribeCooldown=200
   return mgr:requestJoin(player,args[1])
 elseif name=="P" then
   if not isInt(args[1]) then return invalid(player,name,"join answer") end
   return mgr:answerRequest(player,args[1],truth(args[2]))
 elseif name=="Q" then
   if not isInt(args[1]) then return invalid(player,name,"kick") end
   return mgr:kick(player,args[1])
 end
 error("unrecognized tribe packet: "..tostring(name))
end
return TribesInput
