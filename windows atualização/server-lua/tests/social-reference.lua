-- SPDX-License-Identifier: AGPL-3.0-only
-- Mirrors social-reference.mjs while invoking the actual Lua game service.
local Social=require("server-lua.world.social_sync")
local MP=require("src.protocol.msgpack")
local profiles={
 {name="normal",staff=false,anon=false,accounts=true},
 {name="staff",staff=true,anon=false,accounts=true},
 {name="anonymous",staff=false,anon=true,accounts=true},
 {name="guest",staff=false,anon=false,accounts=false}
}
local function fmt(v)
 if v==nil or v==MP.null then return "~" end
 if type(v)=="number" then
   if v==math.floor(v) then return string.format("%.0f",v) end
   return string.format("%.6f",v)
 end
 return tostring(v)
end
local function fmtPacket(v)
 if type(v)=="table" and v~=MP.null then
   local fields={}
   for _,a in ipairs(v) do fields[#fields+1]=fmt(a) end
   return "["..table.concat(fields,",").."]"
 end
 return fmt(v)
end
for _,profile in ipairs(profiles) do
 local events={}
 local function create(sid,x,y,extra)
   local p={
     sid=sid,id="p"..sid,name="Person"..sid,x=x,y=y,dir=0,scale=35,
     health=100,points=50,age=1,kills=0,alive=true,spawned=true,
     anon=false,shadowed=false,visibleAis={}
   }
   for k,v in pairs(extra or {}) do p[k]=v end
   p.shownName=function(self,viewer)
     return self.anon and viewer~=self and ("Anon#"..self.sid) or self.name
   end
   p.canSee=function(self,other)
     return math.abs(other.x-self.x)<1000 and math.abs(other.y-self.y)<1000
   end
   p.send=function(_,name,...)
     local fields={}
     for i=1,select("#",...) do fields[#fields+1]=fmtPacket(select(i,...)) end
     events[#events+1]="P"..sid..":"..name..":"..table.concat(fields,"|")
   end
   return p
 end
 local viewer=create(0,100,100,{
   team=profile.name=="guest" and nil or "RED",
   role=profile.staff and "mod" or nil,points=50,kills=0
 })
 local ally=create(1,180,120,{
   team="RED",points=215,kills=2,
   anon=profile.anon,role="admin",
   account=profile.accounts and {id="A1"} or nil,
   clanTag="Tag",
   lifeStats={kills=2,wood=13,food=12,stone=3,gold=100,
     damage=83.5,animalDamage=51.75,healing=15.1,animals=3,bosses=1,score=215}
 })
 local other=create(2,400,110,{
   team="BLUE",points=149.5,kills=1,clanTag="Other",shadowed=true,
   account=profile.accounts and {id="A2"} or nil
 })
 local offline=create(3,5000,5000,{points=250,kills=8,alive=false})
 local equal=create(4,280,150,{team="RED",points=215,kills=2})
 local players={viewer,ally,other,offline,equal}
 local ais={
   {sid=20,index=3,active=true,spawnCounter=0,x=155,y=170,dir=0.354,
     health=88.8,nameIndex=2,state=0,scale=65},
   {sid=21,index=4,active=true,spawnCounter=100,x=250,y=190,dir=2.115,
     health=65,nameIndex=0,state=1,scale=70},
   {sid=22,index=6,active=true,spawnCounter=0,x=8000,y=8000,dir=1,
     health=200,nameIndex=1,state=2,scale=100}
 }
 local game={
   players=players,ais=ais,crabKillers={[1]=true,[3]=true},
   accounts=profile.accounts and {} or nil,
   crownOf=function(_,p) return p.account and (p.sid==1 and 3 or 2) or 0 end
 }
 for stage=1,3 do
   if stage==2 then
     ais[1].x=1600;ais[2].spawnCounter=0;ais[3].active=false
     viewer.x=230;ally.points=219
   elseif stage==3 then
     ais[1].x=180;ais[2].x=2600;ais[3].active=true;ais[3].x=250
     other.alive=false;ally.anon=false
     viewer.role=profile.staff and "admin" or nil
   end
   Social.updateLeaders(game)
   Social.syncAnimals(game,viewer)
   Social.sendMinimap(game,viewer)
   Social.sendLeaderboard(game)
   Social.sendStats(game,viewer,1)
   local state={}
   for _,p in ipairs(players) do
     state[#state+1]=table.concat({p.sid,p.isLeader and 1 or 0,p.iconIndex},",")
   end
   local v={}
   for _,sid in ipairs(viewer.visibleAis) do v[#v+1]=fmt(sid) end
   print("SOCIAL|"..profile.name.."|"..stage.."|"..
     table.concat(state,";").."|"..table.concat(v,",").."|"..table.concat(events,";"))
   events={}
 end
end
