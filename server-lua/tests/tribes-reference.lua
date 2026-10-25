-- SPDX-License-Identifier: AGPL-3.0-only
-- Differential scenarios equivalent to tribes-reference.mjs (real Node class).
local Tribes=require("server-lua.world.tribes")
local events={}
local function val(v)
 if v==nil then return "~" end
 if type(v)=="table" then
  if v.sid and v.owner then
   return v.sid..","..v.owner..","..(v.clan and 1 or 0)
  end
  local seq={}
  for _,x in ipairs(v)do seq[#seq+1]=tostring(x)end
  return table.concat(seq,",")
 end
 return tostring(v)
end
local players={}
for sid=0,3 do
 local p={id="p"..sid,sid=sid,name="Player"..sid,
   team=nil,isOwner=false,clanTag=nil,alive=true,joinRequests={}}
 p.send=function(self,name,...)
  local args={}
  for i=1,select("#",...)do args[#args+1]=val(select(i,...))end
  events[#events+1]=self.id..":"..name..":"..table.concat(args,":")
 end
 players[#players+1]=p
end
local mgr=Tribes.new(players,function(name,...)
 local args={}
 for i=1,select("#",...)do args[#args+1]=val(select(i,...))end
 events[#events+1]="ALL:"..name..":"..table.concat(args,":")
end)
local a,b,c,d=table.unpack(players)
local cases={
 {"create Alpha",function()mgr:create("Alpha",a)end},
 {"create duplicate",function()mgr:create("Alpha",c)end},
 {"request member",function()mgr:requestJoin(b,"Alpha")end},
 {"request duplicate",function()mgr:requestJoin(b,"Alpha")end},
 {"accept member",function()mgr:answerRequest(a,1,true)end},
 {"request other",function()mgr:requestJoin(c,"Alpha")end},
 {"decline other",function()mgr:answerRequest(a,2,false)end},
 {"kick member",function()mgr:kick(a,1)end},
 {"request again",function()mgr:requestJoin(b,"Alpha")end},
 {"accept again",function()mgr:answerRequest(a,1,true)end},
 {"leave member",function()mgr:leaveTribe(b)end},
 {"rejoin request",function()mgr:requestJoin(b,"Alpha")end},
 {"forget request",function()mgr:forget(b)end},
 {"ignored answer",function()mgr:answerRequest(a,1,true)end},
 {"create Beta",function()mgr:create("Beta",c)end},
 {"owner leaves",function()mgr:leaveTribe(a)end},
 {"remove beta",function()mgr:remove("Beta")end},
 {"clan create",function()d.clanTag="Clan";mgr:create("clan",d)end},
 {"clan forbidden",function()mgr:requestJoin(b,"Clan")end},
 {"clan allowed",function()b.clanTag="Clan";mgr:requestJoin(b,"Clan")end},
 {"clan accept",function()mgr:answerRequest(d,1,true)end},
 {"clan kick",function()mgr:kick(d,1)end},
 {"clan remove",function()mgr:remove("Clan")end},
 {"recreate order A",function()mgr:create("Alpha",a)end},
 {"recreate order B",function()mgr:create("Beta",c)end},
 {"recreate order A",function()mgr:remove("Alpha");mgr:create("Alpha",a)end}
}
local function queue(p)
 local vals={}
 for sid in pairs(p.joinRequests)do vals[#vals+1]=sid end
 table.sort(vals)
 for i,v in ipairs(vals)do vals[i]=tostring(v)end
 return table.concat(vals,",")
end
for _,entry in ipairs(cases)do
 local label,fn=entry[1],entry[2]
 for k=#events,1,-1 do events[k]=nil end
 fn()
 local list={}
 for _,item in ipairs(mgr:list())do
  list[#list+1]=table.concat({item.sid,item.owner,item.clan and 1 or 0},",")
 end
 local states={}
 for _,p in ipairs(players)do
  states[#states+1]=table.concat({p.sid,p.team or "~",p.isOwner and 1 or 0},",")
 end
 print(table.concat({"TRIBE",label,table.concat(list,";"),
  table.concat(states,";"),queue(a).."/"..queue(d),table.concat(events,";")},"|"))
end
