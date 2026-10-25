-- SPDX-License-Identifier: AGPL-3.0-only
-- Full port of server/src/moomoo/modules/clanManager.js (tribes).
-- The Node Map insertion order is retained for welcome packet A.
-- This is the game-world tribe manager, not the registered account clan API.
local Tribes={}
Tribes.__index=Tribes
function Tribes.new(players,broadcast)
 assert(type(players)=="table","original Game.players required")
 assert(type(broadcast)=="function","real Server.broadcast required")
 return setmetatable({
   players=players,broadcast=broadcast,tribes={},ordered={}
 },Tribes)
end
function Tribes:list()
 local result={}
 for _,name in ipairs(self.ordered) do
   local tribe=self.tribes[name]
   if tribe then result[#result+1]=self:info(tribe) end
 end
 return result
end
function Tribes:info(tribe)
 assert(tribe and tribe.owner,"original tribe owner required")
 local ret={sid=tribe.sid,owner=tribe.owner.sid}
 if tribe.clan then ret.clan=true end
 return ret
end
function Tribes:members(tribe)
 local result={}
 for _,player in ipairs(self.players) do
   if player.team==tribe.sid then result[#result+1]=player end
 end
 return result
end
function Tribes:sendMembers(tribe)
 local members=self:members(tribe)
 local payload={}
 for _,player in ipairs(members) do
   payload[#payload+1]=player.sid
   payload[#payload+1]=player.name
 end
 for _,player in ipairs(members) do player:send("4",payload) end
end
function Tribes:create(name,owner)
 if owner.team or self.tribes[name] then return false end
 local clan=not not (owner.clanTag and owner.clanTag~="" and
    string.lower(name)==string.lower(tostring(owner.clanTag)))
 local sid=clan and owner.clanTag or name
 if self.tribes[sid] then return false end
 local tribe={sid=sid,owner=owner,clan=clan}
 self.tribes[sid]=tribe
 self.ordered[#self.ordered+1]=sid
 owner.team=sid
 owner.isOwner=true
 owner.joinRequests={}
 self.broadcast("g",self:info(tribe))
 owner:send("3",sid,true)
 self:sendMembers(tribe)
 return true
end
function Tribes:remove(name)
 local tribe=self.tribes[name]
 if not tribe then return end
 for _,member in ipairs(self:members(tribe)) do
   member.team=nil
   member.isOwner=false
   member:send("3",nil,false)
 end
 tribe.owner.joinRequests={}
 self.tribes[name]=nil
 for i,old in ipairs(self.ordered) do
   if old==name then table.remove(self.ordered,i);break end
 end
 self.broadcast("1",name)
end
function Tribes:requestJoin(player,name)
 local tribe=self.tribes[name]
 if not tribe or player.team or tribe.owner.joinRequests[player.sid] then return end
 if tribe.clan and player.clanTag~=tribe.sid then return end
 tribe.owner.joinRequests[player.sid]=true
 tribe.owner:send("2",player.sid,player.name)
end
function Tribes:answerRequest(owner,sid,accept)
 if not owner.isOwner or not owner.team then return end
 local tribe=self.tribes[owner.team]
 if not tribe or not owner.joinRequests[sid] then return end
 owner.joinRequests[sid]=nil
 if not accept then return end
 local player=nil
 for _,p in ipairs(self.players) do
   if p.sid==sid then player=p;break end
 end
 if not player or player.team
   or (tribe.clan and player.clanTag~=tribe.sid) then return end
 player.team=tribe.sid
 player.isOwner=false
 player:send("3",tribe.sid,false)
 self:sendMembers(tribe)
end
function Tribes:kick(owner,sid)
 if not owner.isOwner or not owner.team or owner.sid==sid then return end
 local tribe=self.tribes[owner.team]
 local player=nil
 for _,p in ipairs(self.players) do
   if p.sid==sid and p.team==owner.team then player=p;break end
 end
 if not tribe or not player then return end
 self:leaveTribe(player)
end
function Tribes:leaveTribe(player)
 if not player.team then return end
 local tribe=self.tribes[player.team]
 if not tribe then
   player.team=nil
   player.isOwner=false
   return
 end
 if tribe.owner==player then
   self:remove(tribe.sid)
   return
 end
 player.team=nil
 player.isOwner=false
 player:send("3",nil,false)
 self:sendMembers(tribe)
end
function Tribes:forget(player)
 for _,name in ipairs(self.ordered) do
   local tribe=self.tribes[name]
   if tribe then tribe.owner.joinRequests[player.sid]=nil end
 end
end
return Tribes
