-- SPDX-License-Identifier: AGPL-3.0-only
-- Chat.gameChat, remember and clanSystem from LOCAL server/src/api/chat.js.
local Json=require("server-lua.vendor.dkjson")
local Random=require("src.net.secure_random")
local Chat={}
Chat.__index=Chat
local function object()return setmetatable({},{__jsontype="object"})end
local function arr()return setmetatable({},{__jsontype="array"})end
local function load(path)
 local f=io.open(path,"rb")
 if not f then return {whispers=object(),clans=object(),said=object()} end
 local data=Json.decode(f:read("*a"),1,Json.null)
 f:close()
 assert(type(data)=="table","invalid original chat.json")
 data.whispers=data.whispers or object()
 data.clans=data.clans or object()
 data.said=data.said or object()
 return data
end
local function push(list,item,max)
 list[#list+1]=item
 while #list>max do table.remove(list,1) end
end
function Chat.new(path,opts)
 opts=opts or {}
 return setmetatable({file=path,data=load(path),
  nowMs=opts.nowMs or function()return os.time()*1000 end,
  randomBytes=opts.randomBytes or Random.bytes,
  store=opts.store,stream=opts.stream},Chat)
end
function Chat:save()
 local file=assert(io.open(self.file,"wb"))
 assert(file:write(assert(Json.encode(self.data))))
 assert(file:close())
end
function Chat:remember(account,entry)
 local id=account.id
 local list=self.data.said[id] or arr()
 self.data.said[id]=list
 push(list,entry,200)
end
function Chat:gameChat(player,text,server)
 local entry={at=self.nowMs(),kind="game",server=server,text=text}
 if player.shadowed then entry.shadow=true end
 if player.account then
  self:remember(player.account,entry)
  self:save()
 else
  player.saidLog=player.saidLog or arr()
  push(player.saidLog,entry,50)
 end
end
function Chat:clanSystem(name,text)
 local clan=self.store and self.store.data.clans[name] or nil
 if not clan then return end
 local id=self.randomBytes(8):gsub(".",function(c)
  return string.format("%02x",c:byte())end)
 local entry={id=id,kind="clan",clan=clan.name,from={name=""},
  text=text,at=self.nowMs(),system=true}
 local list=self.data.clans[clan.name] or arr()
 self.data.clans[clan.name]=list
 push(list,entry,100)
 self:save()
 if self.stream then
  local audience={}
  for _,member in ipairs(clan.members) do
   local account=self.store:accountById(member.id)
   if account and self.store:prefsOf(account).clanChat then
    audience[#audience+1]=account.id
   end
  end
  self.stream:sendTo(audience,"chat",self:publicMessage(entry))
 end
end
function Chat:publicMessage(entry)
 local result={id=entry.id,kind=entry.kind,from={name=entry.from.name},
   text=entry.text,at=entry.at}
 if entry.to then result.to={name=entry.to.name} end
 if entry.system then result.system=true end
 return result
end
function Chat:history(account,kind,withName)
 local list
 if kind=="clan" then
  if not account.clan or account.clan==Json.null then return {error="no clan"} end
  list=self.data.clans[account.clan] or {}
 else
  local other=self.store:nameOwner(withName)
  if not other then return {error="not found"} end
  local left,right=account.id,other.id
  if left>right then left,right=right,left end
  list=self.data.whispers[left.."|"..right] or {}
 end
 local messages=arr()
 for _,entry in ipairs(list) do
  if not entry.shadow or (entry.from and entry.from.id==account.id) then
   messages[#messages+1]=self:publicMessage(entry)
  end
 end
 return {messages=messages}
end
function Chat:clanOnline(account,game)
 local clan=account.clan and self.store.data.clans[account.clan]
 if not clan then return {error="no clan"} end
 local online=arr()
 for _,member in ipairs(clan.members) do
  local other=self.store:accountById(member.id)
  local where=other and game.sessionFor(other.id)
  if where then online[#online+1]={name=other.name,server=where.server} end
 end
 return {online=online}
end
function Chat:friendsOnline(account,ids,game)
 local mine={}
 for _,friend in ipairs(self.store:friendsOf(account.id)) do mine[friend.id]=true end
 local online=arr()
 for i=1,math.min(type(ids)=="table" and #ids or 0,500) do
  local id=ids[i]
  if mine[id] then
   local friend=self.store:accountById(id)
   local where=friend and game.sessionFor(friend.id)
   if where then online[#online+1]={id=friend.id,name=friend.name,server=where.server} end
  end
 end
 return {online=online}
end
function Chat:said(from,game)
 local account=self.store:accountById(tostring(from)) or self.store:nameOwner(tostring(from))
 local list=account and self.data.said[account.id] or nil
 if not list then
  local guest=game.playerBySession(tostring(from))
  list=guest and guest.saidLog or nil
 end
 if not list then return nil end
 local result=arr()
 for i=#list,1,-1 do result[#result+1]=list[i] end
 return result
end
return Chat
