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
return Chat
