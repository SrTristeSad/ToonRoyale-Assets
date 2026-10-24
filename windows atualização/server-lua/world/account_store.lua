-- SPDX-License-Identifier: AGPL-3.0-only
-- Incremental port of server/src/api/store.js. This is an independent copy
-- of accounts.json: never point it at a running Node server's data directory.
local json=require("server-lua.vendor.dkjson")
local SecureRandom=require("src.net.secure_random")
local Store={}
Store.__index=Store

local function object() return setmetatable({}, {__jsontype="object"}) end
local function array() return setmetatable({}, {__jsontype="array"}) end
local function absent(v) return v==nil or v==json.null end
local function number(v) return type(v)=="number" and v or 0 end
local function today(nowMs)
  local seconds=math.floor(nowMs/1000)
  local days=math.floor(seconds/86400)
  local monday=days-((days+3)%7)
  return {day=os.date("!%Y-%m-%d",seconds),
    week=os.date("!%Y-%m-%d",monday*86400),
    month=os.date("!%Y-%m",seconds)}
end
local function period(stats,span,key,hasBest)
  stats.periods=stats.periods or object()
  local p=stats.periods[span]
  if not p or p.key~=key then
    p={key=key,kills=0}
    if hasBest then p.bestScore=0 end
    stats.periods[span]=p
  end
  return p
end
local function has(arr,v)
  for _,x in ipairs(arr) do if x==v then return true end end
  return false
end
local function defaultData()
  return {accounts=object(),emails=object(),names=object(),clans=object(),
    social={friends=object(),requests=array()},legacyIds=object()}
end
local function fill(base,existing)
  for k,v in pairs(existing) do
    if not absent(v) then base[k]=v end
  end
  base.social=base.social or object()
  base.social.friends=base.social.friends or object()
  base.social.requests=base.social.requests or array()
  return base
end
local function readFile(path)
  local f,err=io.open(path,"rb")
  if not f then
    if err and not err:find("No such file",1,true) and
       not err:find("no such file",1,true) then error(err) end
    return nil
  end
  local raw=f:read("*a")
  assert(f:close(),"cannot close accounts file")
  assert(#raw<=16*1024*1024,"accounts.json exceeds 16 MiB limit")
  local data,pos,why=json.decode(raw,1,json.null)
  assert(not why and type(data)=="table","invalid accounts.json: "..tostring(why))
  assert(raw:sub(pos):match("^%s*$"),"accounts.json has trailing content")
  return data
end

function Store.open(path,opts)
  assert(type(path)=="string" and #path>0,"explicit copy accounts.json path required")
  opts=opts or {}
  local loaded=readFile(path)
  local data=fill(defaultData(),loaded or {})
  assert(type(data.accounts)=="table" and type(data.clans)=="table"
    and type(data.names)=="table" and type(data.social)=="table",
    "invalid account store structure")
  local self=setmetatable({file=path,data=data,
    nowMs=opts.nowMs or function() return os.time()*1000 end,
    isRude=opts.isRude,
    randomBytes=opts.randomBytes or SecureRandom.bytes,
    tickets={},devices={}},Store)
  self.migratedIds=self:migrateIds()
  return self
end
function Store:save()
  -- Write the complete document, preserving all unported account/social fields.
  local encoded=json.encode(self.data,{indent=true})
  local tmp=self.file..".lua-new"
  local f,err=io.open(tmp,"wb")
  assert(f,err)
  local wrote,why=f:write(encoded)
  if not wrote then f:close();os.remove(tmp);error(why) end
  local ok,closeErr=f:close()
  if not ok then os.remove(tmp);error(closeErr) end
  -- Keep a recoverable original during the Windows-safe replacement.
  local bak=self.file..".lua-backup"
  local old=io.open(self.file,"rb")
  if old then
    old:close()
    os.remove(bak)
    local moved,merr=os.rename(self.file,bak)
    if not moved then os.remove(tmp);error(merr) end
  end
  local moved,merr=os.rename(tmp,self.file)
  if not moved then
    os.rename(bak,self.file)
    os.remove(tmp)
    error(merr)
  end
end
function Store:nameOwner(name)
  if type(name)~="string" then return nil end
  local id=self.data.names[name:match("^%s*(.-)%s*$"):lower()]
  return id and self.data.accounts[id] or nil
end
function Store:setVerdict(name,level)
  local account=self:nameOwner(name)
  if not account then return false end
  account.verdict=(level=="clear" and json.null or level)
  self:save()
  return true
end
function Store:recordUnlocks(account,unlock)
  assert(account and type(unlock)=="table","registered account required")
  local u=account.unlocks
  if absent(u) then u={hats=array(),accs=array(),weapons=object()};account.unlocks=u end
  local changed=false
  if unlock.hat and unlock.hat~=0 and not has(u.hats,unlock.hat) then
    u.hats[#u.hats+1]=unlock.hat;changed=true
  end
  if unlock.acc and unlock.acc~=0 and not has(u.accs,unlock.acc) then
    u.accs[#u.accs+1]=unlock.acc;changed=true
  end
  local w,v=unlock.weapon,unlock.variant
  if type(w)=="number" and w%1==0 and type(v)=="number" and v%1==0 then
    local key=tostring(w)
    if u.weapons[key]==nil or u.weapons[key]<v then
      u.weapons[key]=v;changed=true
    end
  end
  if changed then self:save() end
end
function Store:currentPeriods(stats)
  local keys=today(self.nowMs())
  local result=object()
  for _,span in ipairs({"day","week","month"}) do
    local p=stats and stats[span]
    if p and p.key==keys[span] then
      result[span]={kills=number(p.kills),bestScore=number(p.bestScore)}
    else
      result[span]={kills=0,bestScore=0}
    end
  end
  return result
end
function Store:profile(account)
  local s=assert(account.stats,"account stats missing")
  local clan=account.clan and self.data.clans[account.clan] or nil
  return {
    id=account.id,name=account.name,role=account.role or json.null,
    clan=clan and {name=clan.name} or json.null,guest=false,
    kills=s.kills,deaths=s.deaths,damage=s.damage,healing=s.healing,
    wood=s.wood,food=s.food,stone=s.stone,gold=s.gold,
    animalDamage=s.animalDamage,animalKills=s.animalKills,
    bestScore=s.bestScore,maxKills=s.maxKills,lives=s.lives,
    playtime=s.playtime,periods=self:currentPeriods(s.periods),
    socials=account.socials or object()
  }
end
function Store:weeklyTopClan()
  local key=today(self.nowMs()).week
  local top,best=nil,0
  for _,clan in pairs(self.data.clans) do
    local p=clan.stats and clan.stats.periods and clan.stats.periods.week
    local kills=p and p.key==key and number(p.kills) or 0
    if clan.shadowed~=true and kills>best then
      top,best=clan.name,kills
    end
  end
  return top
end
function Store:recordLife(account,life)
  local s=assert(account.stats,"account stats missing")
  assert(type(life)=="table" and type(life.animalKills)=="table",
    "complete original lifeStats required")
  local keys=today(self.nowMs())
  s.lives=s.lives+1
  if life.died then s.deaths=s.deaths+1 end
  for _,name in ipairs({"kills","damage","healing","wood","food","stone","gold",
    "animalDamage","playtime"}) do s[name]=s[name]+life[name] end
  if life.look and life.score>=s.bestScore then account.bestLook=life.look end
  s.bestScore=math.max(s.bestScore,life.score)
  s.maxKills=math.max(s.maxKills,life.kills)
  for animal,count in pairs(life.animalKills) do
    s.animalKills[animal]=(s.animalKills[animal] or 0)+count
  end
  for _,span in ipairs({"day","week","month"}) do
    local p=period(s,span,keys[span],true)
    p.kills=p.kills+life.kills
    p.bestScore=math.max(p.bestScore,life.score)
  end
  local clan=account.clan and self.data.clans[account.clan] or nil
  if clan then
    clan.stats.kills=clan.stats.kills+life.kills
    clan.stats.raidKills=clan.stats.raidKills+(life.bossKills or 0)
    for _,span in ipairs({"week","month"}) do
      local p=period(clan.stats,span,keys[span],false)
      p.kills=p.kills+life.kills
    end
    for _,member in ipairs(clan.members) do
      if member.id==account.id then
        member.kills=(member.kills or 0)+life.kills
        for _,span in ipairs({"week","month"}) do
          member.periods=member.periods or object()
          local p=period(member,span,keys[span],false)
          p.kills=p.kills+life.kills
        end
        break
      end
    end
  end
  self:save()
end
-- Direct ports of account settings, cosmetic look, account selectors and clan view.
local DEFAULT_PREFS={friendNotifs=true,friendRequests=true,clanInvites=true,
  clanChat=true,whispers=true}
local function truth(v)
  return v~=nil and v~=false and v~=0 and v~="" and v~=json.null
end
local function jsNumber(v)
  if type(v)=="number" then return (v==v and v~=math.huge and v~=-math.huge) and v or 0 end
  if type(v)=="boolean" then return v and 1 or 0 end
  if type(v)=="string" then
    if v:match("^%s*$") then return 0 end
    return tonumber(v) or 0
  end
  return 0
end
function Store:prefsOf(account)
  local prefs=object()
  for k,v in pairs(DEFAULT_PREFS) do prefs[k]=v end
  if account and type(account.prefs)=="table" then
    for k,v in pairs(account.prefs) do prefs[k]=v end
  end
  return prefs
end
function Store:setPrefs(account,changes)
  local prefs=self:prefsOf(account)
  for key in pairs(DEFAULT_PREFS) do
    if changes and type(changes[key])=="boolean" then
      prefs[key]=changes[key]
    end
  end
  account.prefs=prefs
  self:save()
  return prefs
end
function Store:lookOptions(account)
  local u=absent(account.unlocks) and {} or account.unlocks
  local hats,accs,weapons=array(),array(),object()
  hats[1]=0;accs[1]=0;weapons["0"]=0
  for _,id in ipairs(u.hats or {}) do hats[#hats+1]=id end
  for _,id in ipairs(u.accs or {}) do accs[#accs+1]=id end
  for id,variant in pairs(u.weapons or {}) do weapons[tostring(id)]=variant end
  return {hats=hats,accs=accs,weapons=weapons}
end
function Store:lookInfo(account)
  return {options=self:lookOptions(account),
    look=truth(account.look) and account.look or json.null,
    best=truth(account.bestLook) and account.bestLook or json.null}
end
function Store:setLook(account,look)
  local opts=self:lookOptions(account)
  look=type(look)=="table" and look or {}
  local pick={
    hat=jsNumber(look.hat),acc=jsNumber(look.acc),
    weapon=jsNumber(look.weapon),variant=jsNumber(look.variant),
    color=jsNumber(look.color)
  }
  local maxVariant=opts.weapons[tostring(pick.weapon)]
  local valid=has(opts.hats,pick.hat) and has(opts.accs,pick.acc)
    and maxVariant~=nil and pick.variant>=0 and pick.variant<=maxVariant
    and pick.color%1==0 and pick.color>=0 and pick.color<10
  if not valid then return {status=400,body={error="not yours"}} end
  account.look=pick
  self:save()
  return {status=200,body=self:lookInfo(account)}
end
function Store:accountInfo(account)
  local clan=truth(account.clan) and self.data.clans[account.clan] or nil
  local member
  if clan then
    for _,m in ipairs(clan.members) do if m.id==account.id then member=m;break end end
  end
  local notes=clan and member and member.role~="member" and #clan.requests or 0
  return {
    name=account.name,role=account.role or json.null,
    clan=clan and {name=clan.name,role=member and member.role or "member"} or json.null,
    clanNotes=notes,prefs=self:prefsOf(account)
  }
end
function Store:setRole(name,role)
  local account=self:nameOwner(name)
  if not account then return false end
  account.role=(role=="admin" or role=="mod") and role or json.null
  self:save()
  return true
end
function Store:setClanShadow(name,shadow)
  local clan=self.data.clans[name]
  if not clan then return false end
  clan.shadowed=truth(shadow)
  self:save()
  return true
end
function Store:namesFor(ids)
  local result=object()
  if type(ids)~="table" then return result end
  for i=1,math.min(#ids,200) do
    local id=ids[i]
    local mapped=self.data.legacyIds[tostring(id)] or id
    local a=self.data.accounts[mapped]
    result[tostring(id)]=a and truth(a.name) and a.name or json.null
  end
  return result
end
function Store:friendsOf(id)
  return self.data.social.friends[id] or array()
end
function Store:areFriends(a,b)
  for _,entry in ipairs(self:friendsOf(a)) do
    if entry.id==b then return true end
  end
  return false
end
function Store:requestsFor(id)
  local result=array()
  for _,request in ipairs(self.data.social.requests) do
    if request.recipientId==id then result[#result+1]=request end
  end
  return result
end
function Store:requestsFrom(id)
  local result=array()
  for _,request in ipairs(self.data.social.requests) do
    if request.senderId==id then result[#result+1]=request end
  end
  return result
end
function Store:accountByEmail(email)
  local key=type(email)=="string" and email:match("^%s*(.-)%s*$"):lower() or ""
  local id=self.data.emails[key]
  return id and self.data.accounts[id] or nil
end
function Store:accountById(id)
  local resolved=self.data.legacyIds[id] or id
  return self.data.accounts[resolved]
end

-- Persistent clans: direct port of AccountStore.clanView, myClan and clanAction.
local ranks={member=0,officer=1,owner=2}
local function findById(list,id)
  for i,m in ipairs(list or {}) do if m.id==id then return m,i end end
end
local function exclude(list,predicate)
  local result=array()
  for _,value in ipairs(list or {}) do
    if not predicate(value) then result[#result+1]=value end
  end
  return result
end
function Store:clanView(clan)
  local function nameOf(id)
    local account=self.data.accounts[id]
    return account and truth(account.name) and account.name or "unknown"
  end
  local members,past=array(),array()
  for _,member in ipairs(clan.members) do
    members[#members+1]={name=nameOf(member.id),role=member.role,
      stint=truth(member.stint) and member.stint or 1,
      stats={kills=truth(member.kills) and member.kills or 0,
        periods=self:currentPeriods(member.periods)}}
  end
  local history=clan.past or {}
  for i=math.max(1,#history-19),#history do
    local entry=history[i]
    past[#past+1]={name=nameOf(entry.id),
      stint=truth(entry.stint) and entry.stint or 1,
      left=entry.left,kicked=truth(entry.kicked),
      stats={kills=truth(entry.kills) and entry.kills or 0}}
  end
  return {name=clan.name,closed=truth(clan.closed),members=members,past=past,
    stats={kills=clan.stats.kills,raidKills=clan.stats.raidKills,
      periods=self:currentPeriods(clan.stats.periods)}}
end
function Store:myClan(account)
  local clan=truth(account.clan) and self.data.clans[account.clan] or nil
  if not clan then
    local invites=array()
    for _,c in pairs(self.data.clans) do
      for _,invite in ipairs(c.invites or {}) do
        if invite.id==account.id then
          local sender=self.data.accounts[invite.by]
          invites[#invites+1]={clan=c.name,by=sender and sender.name or "unknown"}
        end
      end
    end
    return {clan=json.null,invites=invites}
  end
  local member=findById(clan.members,account.id)
  local role=member and member.role or "member"
  local requests,invited=array(),array()
  if role~="member" then
    for _,id in ipairs(clan.requests) do
      local person=self.data.accounts[id]
      requests[#requests+1]=person and person.name or "unknown"
    end
    for _,entry in ipairs(clan.invites or {}) do
      local person=self.data.accounts[entry.id]
      if person and truth(person.name) then invited[#invited+1]=person.name end
    end
  end
  return {clan=self:clanView(clan),role=role,requests=requests,invited=invited}
end
function Store:clanAction(account,action,body)
  body=body or {}
  local function err(message,status)
    return {status=status or 400,body={error=message}}
  end
  local function ok(result)
    return {status=200,body=result or object()}
  end
  if not truth(account.name) then return err("no name") end
  local clans=self.data.clans
  local mine=truth(account.clan) and clans[account.clan] or nil
  local me=mine and findById(mine.members,account.id) or nil
  local rank=me and ranks[me.role] or -1
  local target=truth(body.name) and self:nameOwner(body.name) or nil
  local function clanEvent(clan,message)
    if type(self.onClanEvent)=="function" and #clan.members>0 then
      self.onClanEvent(clan.name,message)
    end
  end
  local function leave(clan,id,kicked)
    local m,index=findById(clan.members,id)
    if not m then return end
    table.remove(clan.members,index)
    clan.past=clan.past or array()
    clan.past[#clan.past+1]={id=id,stint=truth(m.stint) and m.stint or 1,
      left=self.nowMs(),kicked=kicked,kills=truth(m.kills) and m.kills or 0}
    local who=self.data.accounts[id]
    if who then who.clan=json.null end
    clanEvent(clan,(who and who.name or "Someone")..
      (kicked and " was removed from the clan" or " left the clan"))
  end
  local function join(clan,id)
    local prev=0
    for _,p in ipairs(clan.past or {}) do if p.id==id then prev=prev+1 end end
    clan.members[#clan.members+1]={id=id,role="member",stint=prev+1,
      joinedAt=self.nowMs(),kills=0,periods=object()}
    clan.requests=exclude(clan.requests,function(r)return r==id end)
    clan.invites=exclude(clan.invites,function(i)return i.id==id end)
    self.data.accounts[id].clan=clan.name
    if type(self.onClanEvent)=="function" and #clan.members>1 then
      self.onClanEvent(clan.name,self.data.accounts[id].name.." joined the clan")
    end
  end
  if action=="mine" then
    return ok(self:myClan(account))
  elseif action=="create" then
    local name=type(body.name)=="string" and body.name:match("^%s*(.-)%s*$") or ""
    if not name:match("^[A-Za-z0-9]+$") or #name<3 or #name>4 then return err("invalid") end
    assert(type(self.isRude)=="function",
      "original nameFilter.isRude required for clan creation")
    if self.isRude(name) then return err("unclean") end
    if mine then return err("in a clan") end
    for existing in pairs(clans) do
      if existing:lower()==name:lower() then return err("taken",409) end
    end
    clans[name]={name=name,createdAt=self.nowMs(),members=array(),past=array(),
      invites=array(),requests=array(),shadowed=false,
      stats={kills=0,raidKills=0,periods=object()}}
    join(clans[name],account.id)
    clans[name].members[1].role="owner"
  elseif action=="request" then
    local clan
    local name=tostring(body.clan or ""):lower()
    for _,c in pairs(clans) do if c.name:lower()==name then clan=c;break end end
    if not clan then return err("not found",404) end
    if mine then return err("in a clan") end
    if truth(clan.closed) then return err("closed",403) end
    if #clan.members>=80 then return err("full") end
    if has(clan.requests,account.id) then return err("asked",409) end
    clan.requests[#clan.requests+1]=account.id
  elseif action=="uninvite" then
    if rank<1 then return err("rank",403) end
    local before=#(mine.invites or {})
    mine.invites=exclude(mine.invites,function(entry)
      return not target or entry.id==target.id
    end)
    if #mine.invites==before then return err("no player",404) end
  elseif action=="requests" then
    if not mine then return err("not found",404) end
    if rank<2 then return err("rank",403) end
    mine.closed=not truth(body.open)
    if mine.closed then mine.requests=array() end
  elseif action=="answer" then
    local clan=clans[body.clan]
    if not clan then return err("not found",404) end
    local invited=false
    for _,inv in ipairs(clan.invites or {}) do
      if inv.id==account.id then invited=true;break end
    end
    if not invited then return err("not found",404) end
    if truth(body.accept) then
      if mine then return err("in a clan") end
      if #clan.members>=80 then return err("full") end
      join(clan,account.id)
    else
      clan.invites=exclude(clan.invites,function(i)return i.id==account.id end)
    end
  elseif action=="invite" then
    if rank<1 then return err("rank",403) end
    if not target then return err("no player",404) end
    if truth(target.clan) then return err("in a clan") end
    if not truth(self:prefsOf(target).clanInvites) then return err("no invites",403) end
    for _,entry in ipairs(mine.invites or {}) do
      if entry.id==target.id then return err("invited",409) end
    end
    mine.invites=mine.invites or array()
    mine.invites[#mine.invites+1]={id=target.id,by=account.id}
  elseif action=="decide" then
    if rank<1 then return err("rank",403) end
    if not target or not has(mine.requests,target.id) then
      return err("no player",404)
    end
    if truth(body.accept) then
      if truth(target.clan) then return err("in a clan") end
      if #mine.members>=80 then return err("full") end
      join(mine,target.id)
    else
      mine.requests=exclude(mine.requests,function(id)return id==target.id end)
    end
  elseif action=="kick" then
    local them=target and mine and findById(mine.members,target.id) or nil
    if not them then return err("no member",404) end
    if rank<1 or rank<=ranks[them.role] then return err("rank",403) end
    leave(mine,target.id,true)
  elseif action=="role" then
    local them=target and mine and findById(mine.members,target.id) or nil
    if not them then return err("no member",404) end
    if rank<2 then return err("rank",403) end
    if body.role=="owner" then
      them.role="owner";me.role="officer"
    elseif body.role=="officer" or body.role=="member" then
      them.role=body.role
    else return err("invalid") end
  elseif action=="leave" then
    if not mine then return err("not found",404) end
    if me.role=="owner" and #mine.members>1 then return err("owner") end
    leave(mine,account.id,false)
    if #mine.members==0 then clans[mine.name]=nil end
  elseif action=="disband" then
    if not mine then return err("not found",404) end
    if rank<2 then return err("rank",403) end
    local ids={}
    for _,m in ipairs(mine.members) do ids[#ids+1]=m.id end
    for _,id in ipairs(ids) do leave(mine,id,false) end
    clans[mine.name]=nil
  else
    return err("not found",404)
  end
  self:save()
  return ok(object())
end

-- AccountStore social graph from server/src/api/store.js.
-- Identifiers and timestamps use the same ObjectId / ISO8601 encoding as Node.
local function isoUtc(ms)
  local seconds=math.floor(ms/1000)
  return os.date("!%Y-%m-%dT%H:%M:%S",seconds)..
    string.format(".%03dZ",math.floor(ms%1000))
end
local function objectId(ms,random)
  local raw=random(8)
  assert(type(raw)=="string" and #raw==8,
    "8 cryptographically secure random bytes required for ObjectId")
  return string.format("%08x",math.floor(ms/1000))..
    (raw:gsub(".",function(ch)return string.format("%02x",ch:byte())end))
end
function Store:createFriendRequest(senderId,recipientId)
  if not self.data.accounts[recipientId] or senderId==recipientId then
    return {status=404}
  end
  if self:areFriends(senderId,recipientId) then return {status=409} end
  local social=self.data.social
  for _,request in ipairs(social.requests) do
    if request.senderId==senderId and request.recipientId==recipientId then
      return {status=409}
    end
  end
  for _,request in ipairs(social.requests) do
    if request.senderId==recipientId and request.recipientId==senderId then
      self:answerFriendRequest(recipientId,request.id,true)
      return {status=200,friends=true}
    end
  end
  local now=self.nowMs()
  local request={id=objectId(now,self.randomBytes),senderId=senderId,
    recipientId=recipientId,createdAt=isoUtc(now)}
  social.requests[#social.requests+1]=request
  self:save()
  return {status=201,request=request}
end
function Store:answerFriendRequest(recipientId,requestId,accept)
  local social=self.data.social
  local request
  for _,entry in ipairs(social.requests) do
    if entry.id==requestId and entry.recipientId==recipientId then
      request=entry;break
    end
  end
  if not request then return false end
  social.requests=exclude(social.requests,function(entry)
    return entry==request or
      (entry.senderId==request.recipientId and
       entry.recipientId==request.senderId)
  end)
  if truth(accept) and not self:areFriends(request.senderId,request.recipientId) then
    local since=isoUtc(self.nowMs())
    local from=self:friendsOf(request.senderId)
    local to=self:friendsOf(request.recipientId)
    social.friends[request.senderId]=array()
    for _,entry in ipairs(from) do
      social.friends[request.senderId][#social.friends[request.senderId]+1]=entry
    end
    social.friends[request.senderId][#social.friends[request.senderId]+1]={
      id=request.recipientId,createdAt=since
    }
    social.friends[request.recipientId]=array()
    for _,entry in ipairs(to) do
      social.friends[request.recipientId][#social.friends[request.recipientId]+1]=entry
    end
    social.friends[request.recipientId][#social.friends[request.recipientId]+1]={
      id=request.senderId,createdAt=since
    }
  end
  self:save()
  return request
end
function Store:cancelFriendRequest(senderId,requestId)
  local social=self.data.social
  local before=#social.requests
  social.requests=exclude(social.requests,function(entry)
    return entry.id==requestId and entry.senderId==senderId
  end)
  if #social.requests==before then return false end
  self:save()
  return true
end
function Store:removeFriend(id,friendId)
  if not self:areFriends(id,friendId) then return false end
  local social=self.data.social
  social.friends[id]=exclude(self:friendsOf(id),function(entry)
    return entry.id==friendId
  end)
  social.friends[friendId]=exclude(self:friendsOf(friendId),function(entry)
    return entry.id==id
  end)
  self:save()
  return true
end

-- AccountStore.setSocials: same five permitted fields and validation order.
function Store:setSocials(account,socials)
  local fields={"youtube","twitch","tiktok","x","discord"}
  local result=object()
  for _,field in ipairs(fields) do
    local raw=type(socials)=="table" and socials[field] or nil
    local value=type(raw)=="string" and raw:match("^%s*(.-)%s*$") or ""
    if value~="" then
      if #value<1 or #value>32 or value:find("[^A-Za-z0-9._%-]") then
        return {status=400,body={field=field,why="format"}}
      end
      assert(type(self.isRude)=="function",
        "original nameFilter.isRude required for social handles")
      local spaced=value:gsub("[._%-]+"," ")
      if self.isRude(value) or self.isRude(spaced) then
        return {status=400,body={field=field,why="rude"}}
      end
      result[field]=value
    end
  end
  account.socials=result
  self:save()
  return {status=200,body={socials=result}}
end

-- AccountStore.migrateIds: preserve Node's remapping across every reference.
function Store:migrateIds()
  local remap=object()
  for old,account in pairs(self.data.accounts) do
    if not (#old==24 and old:match("^[a-f0-9]+$")) then
      local seconds=math.floor(((type(account.createdAt)=="number" and account.createdAt~=0)
          and account.createdAt or self.nowMs())/1000)
      local suffix=(#old==16 and old:match("^[a-f0-9]+$")) and old
          or (self.randomBytes(8):gsub(".",function(ch)
              return string.format("%02x",ch:byte()) end))
      remap[old]=string.format("%08x",seconds)..suffix
    end
  end
  if next(remap)==nil then return remap end
  local function mapped(id) return remap[id] or id end
  local accounts=object()
  for _,account in pairs(self.data.accounts) do
    account.id=mapped(account.id)
    accounts[account.id]=account
  end
  self.data.accounts=accounts
  for _,index in ipairs({self.data.emails,self.data.names}) do
    for name,id in pairs(index) do index[name]=mapped(id) end
  end
  for _,clan in pairs(self.data.clans) do
    for _,member in ipairs(clan.members) do member.id=mapped(member.id) end
    for _,past in ipairs(clan.past or {}) do past.id=mapped(past.id) end
    for _,invite in ipairs(clan.invites or {}) do
      invite.id=mapped(invite.id)
      invite.by=mapped(invite.by)
    end
    for i,id in ipairs(clan.requests) do clan.requests[i]=mapped(id) end
  end
  local friends=object()
  for id,entries in pairs(self.data.social.friends) do
    for _,entry in ipairs(entries) do entry.id=mapped(entry.id) end
    friends[mapped(id)]=entries
  end
  self.data.social.friends=friends
  for _,request in ipairs(self.data.social.requests) do
    request.senderId=mapped(request.senderId)
    request.recipientId=mapped(request.recipientId)
  end
  self.data.legacyIds=self.data.legacyIds or object()
  for old,new in pairs(remap) do self.data.legacyIds[old]=new end
  self:save()
  return remap
end

-- AccountStore.issueTicket / recentDevice / consumeTicket from Node store.js.
local function hexBytes(value,n)
  assert(type(value)=="string" and #value==n,
    "cryptographically secure random bytes unavailable")
  return (value:gsub(".",function(ch)
    return string.format("%02x",ch:byte())
  end))
end
function Store:issueTicket(options)
  options=assert(options,"ticket options required")
  local account,did,server=options.account,options.did,options.server
  local ticket=hexBytes(self.randomBytes(18),18)
  local validDid=type(did)=="string" and #did>=16 and #did<=64
    and did:match("^[a-f0-9]+$")~=nil
  local deviceId=validDid and did or hexBytes(self.randomBytes(12),12)
  self.tickets[ticket]={
    accountId=truth(account) and account.id or json.null,
    did=deviceId,server=truth(server) and server or json.null,
    at=self.nowMs()
  }
  self.devices[deviceId]=self.nowMs()
  return {ticket=ticket,did=deviceId}
end
function Store:recentDevice(did)
  local key=truth(did) and tostring(did) or ""
  local at=self.devices[key]
  return at~=nil and at~=0 and self.nowMs()-at<15*60*1000 or false
end
function Store:consumeTicket(ticket,maxAgeMs)
  local entry=self.tickets[ticket]
  if not entry then return json.null end
  self.tickets[ticket]=nil
  if type(maxAgeMs)=="number" and self.nowMs()-entry.at>maxAgeMs then
    return json.null
  end
  local account=truth(entry.accountId) and self.data.accounts[entry.accountId] or nil
  return {account=account or json.null,did=entry.did,server=entry.server}
end

-- Ranked stats: port of AccountStore.top and weeklyCrowns from store.js.
-- Numeric ties need insertion order to match Object.values; never claim stable
-- Node/Lua tie parity until the JSON object-order bridge is validated.
function Store:top(span)
  local keys=today(self.nowMs())
  local function periodKills(periods)
    if span=="all" then return nil end
    local p=periods and periods[span]
    local key=keys[span]
    return p and key and p.key==key and (p.kills or 0) or 0
  end
  local players,clans=array(),array()
  for _,account in pairs(self.data.accounts) do
    if truth(account.name) then
      local kills=span=="all" and account.stats.kills or periodKills(account.stats.periods)
      if kills and kills>0 then
        local row={name=account.name,kills=kills}
        if truth(account.clan) then row.clan=account.clan end
        if account.verdict=="shadow" then row.shadowed=true end
        players[#players+1]=row
      end
    end
  end
  for _,clan in pairs(self.data.clans) do
    local kills=span=="all" and clan.stats.kills or periodKills(clan.stats.periods)
    if kills and kills>0 then
      local row={name=clan.name,kills=kills,members=#clan.members}
      if truth(clan.shadowed) then row.shadowed=true end
      clans[#clans+1]=row
    end
  end
  local function ranked(left,right)
    if left.kills~=right.kills then return left.kills>right.kills end
    return left.name<right.name
  end
  table.sort(players,ranked)
  table.sort(clans,ranked)
  while #players>10 do table.remove(players) end
  while #clans>10 do table.remove(clans) end
  return {players=players,clans=clans}
end
function Store:weeklyCrowns()
  local week=today(self.nowMs()).week
  local ranked={}
  for _,account in pairs(self.data.accounts) do
    if truth(account.name) and account.verdict~="shadow" then
      local periods=account.stats.periods
      local p=periods and periods.week
      local kills=p and p.key==week and (p.kills or 0) or 0
      if kills>0 then
        ranked[#ranked+1]={id=account.id,kills=kills}
      end
    end
  end
  table.sort(ranked,function(left,right)
    if left.kills~=right.kills then return left.kills>right.kills end
    return left.id<right.id
  end)
  local crowns=object()
  for i=1,math.min(3,#ranked) do crowns[ranked[i].id]=i end
  return crowns
end

-- Node uses dot-method calls; this wrapper retains that shape for existing Lua ports.
function Store:callbacks()
  return {
    data=self.data,
    profile=function(a) return self:profile(a) end,
    recordUnlocks=function(a,u) return self:recordUnlocks(a,u) end,
    recordLife=function(a,l) return self:recordLife(a,l) end,
    weeklyTopClan=function() return self:weeklyTopClan() end,
    top=function(span) return self:top(span) end,
    weeklyCrowns=function() return self:weeklyCrowns() end,
    setVerdict=function(name,v) return self:setVerdict(name,v) end,
    setRole=function(name,role) return self:setRole(name,role) end,
    setClanShadow=function(name,shadow) return self:setClanShadow(name,shadow) end,
    lookOptions=function(a) return self:lookOptions(a) end,
    lookInfo=function(a) return self:lookInfo(a) end,
    setLook=function(a,look) return self:setLook(a,look) end,
    prefsOf=function(a) return self:prefsOf(a) end,
    setPrefs=function(a,prefs) return self:setPrefs(a,prefs) end,
    setSocials=function(a,socials) return self:setSocials(a,socials) end,
    accountInfo=function(a) return self:accountInfo(a) end,
    clanView=function(clan) return self:clanView(clan) end,
    myClan=function(a) return self:myClan(a) end,
    clanAction=function(a,action,body) return self:clanAction(a,action,body) end,
    friendsOf=function(id) return self:friendsOf(id) end,
    areFriends=function(a,b) return self:areFriends(a,b) end,
    requestsFor=function(id) return self:requestsFor(id) end,
    requestsFrom=function(id) return self:requestsFrom(id) end,
    namesFor=function(ids) return self:namesFor(ids) end,
    createFriendRequest=function(a,b) return self:createFriendRequest(a,b) end,
    answerFriendRequest=function(a,b,c) return self:answerFriendRequest(a,b,c) end,
    cancelFriendRequest=function(a,b) return self:cancelFriendRequest(a,b) end,
    removeFriend=function(a,b) return self:removeFriend(a,b) end,
    accountByEmail=function(email) return self:accountByEmail(email) end,
    accountById=function(id) return self:accountById(id) end,
    issueTicket=function(opts) return self:issueTicket(opts) end,
    recentDevice=function(did) return self:recentDevice(did) end,
    consumeTicket=function(ticket,maxAgeMs)
      return self:consumeTicket(ticket,maxAgeMs) end
  }
end
return Store
