-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of the constructor preamble and Player.resetMoveDir, addItem,
-- setUserData, shownName, getData, applyPowers and displaySkin.
-- Original name moderation words and store catalogue MUST be injected.
local Config=require("src.game.config")
local NameWords=require("server-lua.world.name_words")
local Pack=require("src.protocol.msgpack")
local Sync=require("server-lua.world.snapshot")
local Spawn=require("server-lua.world.spawn")
local Identity={}
Identity.__index=Identity
local function jsTruth(v)return v~=nil and v~=false and v~=0 and v~="" and v~=Pack.null end
local function bool(v)return jsTruth(v) and true or false end
local function sliceJS(s,maxLength)
  local out,length={},0
  for _,code in utf8.codes(s) do
    local units=code>65535 and 2 or 1
    if length+units>maxLength then break end
    out[#out+1]=utf8.char(code)
    length=length+units
  end
  return table.concat(out)
end
local function validChar(char)
  return char:match("^[%a%d_:()%/? %-]$")~=nil and char:byte()<128
end
local function sanitize(raw,maxLength)
  local name=sliceJS(raw,maxLength)
  local list={}
  local previousInvalid=false
  for _,code in utf8.codes(name) do
    local char=utf8.char(code)
    if validChar(char) then
      list[#list+1]=char
      previousInvalid=false
    elseif not previousInvalid then
      -- JS /[^\\w:()\\/? -]+/gmi replaces one consecutive invalid
      -- *run*, not one replacement per Unicode codepoint/surrogate.
      list[#list+1]=" "
      previousInvalid=true
    end
  end
  return (table.concat(list):gsub("^%s+",""):gsub("%s+$",""))
end
local function replacement(s)
  return s:lower():gsub("%s",""):gsub("1","i"):gsub("0","o"):gsub("5","s")
end
local function jsString(value)
  if value==nil then return "undefined" end
  if value==Pack.null then return "null" end
  if value==true then return "true" end
  if value==false then return "false" end
  if type(value)=="table" then return "[object Object]" end
  return tostring(value)
end
-- Same name normalization used by Node nameFilter.gameName and Player.setUserData.
-- Used for permanent AccountStore.claimName; do not maintain a second filter.
function Identity.gameName(raw,maxLength,nameWords)
  local value
  if raw==nil or raw==Pack.null then value=""
  elseif type(raw)=="string" then value=raw
  else value=jsString(raw) end
  local name=sanitize(value,maxLength or 15)
  local normalized=replacement(name)
  local profane=false
  for _,word in ipairs(nameWords or NameWords) do
    if normalized:find(word,1,true) then profane=true;break end
  end
  return {name=name,profane=profane}
end

function Identity.new(id,sid,options)
  options=options or {}
  assert(type(id)=="string" and type(sid)=="number"
    and sid>=0 and sid%1==0,"original Player id and integer SID required")
  local hats=assert(options.hats,"original hats catalogue required")
  local accessories=assert(options.accessories,"original accessories catalogue required")
  assert(type(hats)=="table" and type(accessories)=="table",
    "original store catalogues required")
  local p={
    id=id,sid=sid,tmpScore=0,skinIndex=0,tailIndex=0,hitTime=0,
    tails={},skins={},points=0,dt=0,hidden=false,itemCounts={},
    isPlayer=true,pps=0,skinRot=0,lastPing=0,iconIndex=0,
    skinColor=0,account=nil,role=nil,isMember=false,isOwner=false,
    isLeader=false,flagged=false,shadowed=false,
    name="unknown",alive=false,active=false,spawned=false,
    sentTo={},watchStats=-1,joinRequests={},
    powers={god=0,aura=0,godlike=0,boss=0,invisible=0,
      size=1,power=1,speed=1,health=1},
    morph=-1,dive=0,disguised=false,anon=false,
    tribeCooldown=0,chatCooldown=0,pingCooldown=0
  }
  for _,item in ipairs(accessories) do
    if item.price<=0 and not jsTruth(item.dontSell) then p.tails[item.id]=1 end
  end
  for _,item in ipairs(hats) do
    if item.price<=0 and not jsTruth(item.dontSell) then p.skins[item.id]=1 end
  end
  p.config=options.config or Config
  p.nameWords=options.nameWords or NameWords
  return setmetatable(p,Identity)
end
function Identity:resetMoveDir()self.moveDir=nil end
function Identity:addItem(id,items)
  local definitions=assert(items and items.list,"original items.list required")
  local requested=definitions[id]
  if not requested then return false end
  assert(type(self.items)=="table","Player must be spawned before adding an item")
  for idx,existing in ipairs(self.items) do
    if definitions[existing] and definitions[existing].group==requested.group then
      if self.buildIndex==existing then self.buildIndex=id end
      self.items[idx]=id
      return true
    end
  end
  self.items[#self.items+1]=id
  return true
end
function Identity:setUserData(data)
  if jsTruth(data) then
    self.name="unknown"
    assert(type(self.nameWords)=="table",
      "original NAME_WORDS dictionary required for Player.setUserData")
    local cfg=self.config
    local name=sanitize(jsString(data.name),cfg.maxNameLength)
    local normalized=replacement(name)
    local profane=false
    for _,word in ipairs(self.nameWords) do
      if normalized:find(word,1,true) then profane=true;break end
    end
    if #name>0 and not profane then self.name=name end
    self.skinColor=0
    local index=data.skin
    if type(index)=="number" and index%1==0 and index>=0
      and cfg.skinColors[index+1] then self.skinColor=index end
    self.anon=bool(data.anon and self.account and jsTruth(self.account.name))
  end
  if self.account and jsTruth(self.account.name) then self.name=self.account.name end
end
function Identity:shownName(viewer)
  if self.anon and viewer~=self then return "Anon#"..self.sid end
  return self.name
end
function Identity:getData(viewer)
  return Sync.playerData(self,viewer)
end
-- These are unchanged server/client Player methods, shared by the
-- authoritative Player and the stand-alone constructor parity harness.
function Identity:resetResources(moofoll)
  return Spawn.resetResources(self,moofoll,self.config)
end
function Identity:canSee(other)
  return Sync.canSee(self,other,self.config)
end
function Identity:setData(data)
  assert(type(data)=="table","original Player.setData wire array required")
  local Pack=require("src.protocol.msgpack")
  self.id=data[1];self.sid=data[2];self.name=data[3]
  self.x=data[4];self.y=data[5];self.dir=data[6]
  self.health=data[7];self.maxHealth=data[8]
  self.scale=data[9];self.skinColor=data[10]
  self.aura=jsTruth(data[11]) and data[11]~=Pack.null
  self.bossMode=jsTruth(data[12]) and data[12]~=Pack.null
  local clan=data[13]
  if clan==nil or clan==Pack.null or not jsTruth(clan) or clan=="" then
    self.clan=nil
  else
    self.clan=clan
  end
end
function Identity:applyPowers()
  return Spawn.applyPowers(self,self.config)
end
function Identity:displaySkin()
  return self.shameTimer and self.shameTimer>0 and 45 or self.skinIndex
end
return Identity
