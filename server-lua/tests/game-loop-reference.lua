-- SPDX-License-Identifier: AGPL-3.0-only
-- Same six clocks and four room profiles as real Game.tick reference.
local Config=require("src.game.config")
local Loop=require("server-lua.world.game_loop")
local profiles={
 {id="full",bots=true,players=3,projectiles=2,ais=2},
 {id="simple",bots=false,players=1,projectiles=0,ais=0},
 {id="empty",bots=false,players=0,projectiles=0,ais=0},
 {id="inactive",bots=true,players=2,projectiles=1,ais=3,noStats=true}
}
local function str(v)
 if type(v)=="table" and v.label then return v.label end
 if type(v)=="number" then return string.format("%.0f",v) end
 return tostring(v)
end
for _,profile in ipairs(profiles) do
 local events={}
 local function log(line) events[#events+1]=line end
 local function fn(name,method)
   return function(_, ...)
     local args={}
     for i=1,select("#",...) do args[i]=str(select(i,...)) end
     log(name.."."..method..":"..table.concat(args,","))
   end
 end
 local players={}
 for i=0,profile.players-1 do
   local p={
     label="p"..i,alive=i~=1,
     watchStats=profile.noStats and -1 or (i==2 and -1 or i),
     chatCooldown=250,tribeCooldown=350,pingCooldown=450
   }
   p.update=function(self,delta)log(self.label..".update:"..str(delta))end
   if i==0 then
     p.anticheat={tick=function(_,now)log("anti.tick:"..str(now))end}
   end
   players[#players+1]=p
 end
 local projectiles={}
 for i=0,profile.projectiles-1 do
   local id=i
   projectiles[#projectiles+1]={
     update=function(_,delta)log("shot"..id..".update:"..str(delta))end
   }
 end
 local ais={}
 for i=0,profile.ais-1 do
   local id=i
   ais[#ais+1]={
     active=i~=1,
     update=function(_,delta)log("ai"..id..".update:"..str(delta))end
   }
 end
 local game={
   config=Config,lastTick=10000,leaderboardTimer=0,minimapTimer=0,
   statsTimer=0,spawnTimer=0,players=players,projectiles=projectiles,ais=ais
 }
 if profile.bots then game.bots={tick=function(_,d)log("bots.tick:"..str(d))end} end
 for _,method in ipairs({"updateStructures","ensureAnimals","updateLeaders",
   "sendLeaderboard","syncPlayers","syncObjects","syncAnimals",
   "sendMinimap","sendStats"}) do
   game[method]=fn("game",method)
 end
 for _,clock in ipairs({10000,10100,10500,11150,11500,13250}) do
   Loop.tick(game,clock)
   local pfields={}
   for _,p in ipairs(players) do
     pfields[#pfields+1]=table.concat({
       str(p.chatCooldown),str(p.tribeCooldown),str(p.pingCooldown)
     },",")
   end
   print(table.concat({"LOOP",profile.id,str(clock),str(game.lastTick),
     str(game.spawnTimer),str(game.leaderboardTimer),str(game.minimapTimer),
     str(game.statsTimer),table.concat(pfields,";"),
     table.concat(events,"|")},"#"))
 end
end
