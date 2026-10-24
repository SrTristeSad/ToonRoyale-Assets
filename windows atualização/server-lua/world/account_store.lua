-- SPDX-License-Identifier: AGPL-3.0-only
-- Incremental port of server/src/api/store.js. This is an independent copy
-- of accounts.json: never point it at a running Node server's data directory.
local json=require("server-lua.vendor.dkjson")
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
    nowMs=opts.nowMs or function() return os.time()*1000 end},Store)
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
          local p=period(member,span,keys[span],false)
          p.kills=p.kills+life.kills
        end
        break
      end
    end
  end
  self:save()
end
-- Node uses dot-method calls; this wrapper retains that shape for existing Lua ports.
function Store:callbacks()
  return {
    data=self.data,
    profile=function(a) return self:profile(a) end,
    recordUnlocks=function(a,u) return self:recordUnlocks(a,u) end,
    recordLife=function(a,l) return self:recordLife(a,l) end,
    weeklyTopClan=function() return self:weeklyTopClan() end,
    setVerdict=function(name,v) return self:setVerdict(name,v) end
  }
end
return Store
