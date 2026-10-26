-- SPDX-License-Identifier: AGPL-3.0-only
-- Port of handleAdmin in the copied Node server/src/network/packets.js.
local MP=require("src.protocol.msgpack")
local Admin={}
local lists={
 size={1,1.5,2,3},power={1,2,5,10,20,50,100},
 speed={1,1.5,2,5,10,20},health={1,2,5,10,20}
}
local powers={god=true,aura=true,godlike=true,boss=true,invisible=true}
local function number(v)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function integer(v) return number(v) and v%1==0 end
local function truth(v) return v~=nil and v~=false and v~=0 and v~="" and v~=MP.null end
local function teleport(p,x,y) p.x=x;p.y=y;p.xVel=0;p.yVel=0 end
local function resend(game,p)
 assert(type(p.sentTo)=="table","Player.sentTo required")
 for _,viewer in ipairs(game.players) do
  if viewer~=p then p.sentTo[viewer.id]=nil end
 end
end
local function targetFor(game,admin,sid)
 if sid==nil or sid==MP.null then return admin end
 for _,p in ipairs(game.players) do
  if p.sid==sid and p.alive then return p end
 end
end
function Admin.handle(ctx,admin,args)
 if admin.role~="admin" then
  assert(admin.anticheat and type(admin.anticheat.invalid)=="function","anticheat invalid required")
  return admin.anticheat:invalid("A","admin command")
 end
 local game=assert(ctx.game,"authoritative game required")
 local command,a,b,c=args[1],args[2],args[3],args[4]
 if powers[command] then
  local on=truth(a) and 1 or 0
  admin.powers[command]=on
  if command=="godlike" then admin.powers.god=on;admin.powers.aura=on end
  resend(game,admin)
  return
 end
 if lists[command] then
  local found=false
  for _,value in ipairs(lists[command]) do if value==a then found=true;break end end
  if not found then return end
  admin.powers[command]=a
  admin:applyPowers()
  resend(game,admin)
  return
 end
 if command=="spawn" then
  if not integer(a) then return end
  local mgr=assert(game.animal_manager,"real AI manager required")
  local typ=mgr.aiTypes and mgr.aiTypes[a]
  if not typ then return end
  local dist=admin.scale+typ.scale+60
  return mgr:spawn(admin.x+math.cos(admin.dir)*dist,admin.y+math.sin(admin.dir)*dist,admin.dir,a,{despawnOnDeath=true})
 elseif command=="tp" then
  if number(a) and number(b) then teleport(admin,a,b) end
 elseif command=="gotomob" then
  for _,mob in ipairs(assert(game.ais,"AI actors required")) do
   if mob.active and mob.index==a and not truth(mob.spawnCounter) then
    teleport(admin,mob.x+mob.scale+admin.scale+40,mob.y)
    return
   end
  end
 elseif command=="goto" or command=="summon" then
  local other=targetFor(game,admin,a)
  if other and other~=admin then
   if command=="goto" then
    teleport(admin,other.x+other.scale*2,other.y)
   else
    teleport(other,admin.x+admin.scale*2,admin.y)
   end
  end
 elseif command=="weapon" then
  local target=targetFor(game,admin,c)
  local weapon=ctx.items.weapons[a]
  local variants=assert(ctx.config.weaponVariants,"weapon variants required")
  -- Node config.weaponVariants is zero-based; Lua's config array is one-based.
  local index
  if integer(b) and b>=0 then index=b
  elseif type(b)=="string" and (b=="0" or b:match("^[1-9]%d*$")) then
   index=tonumber(b)
  end
  local variant=(index and variants[index+1]) or variants[1]
  if not target or not weapon then return end
  target.weapons[weapon.type]=weapon.id
  target.weaponXP[weapon.id]=variant.xp
  target.weaponIndex=weapon.id
  target.buildIndex=-1
  target:send("V",target.weapons,1)
 elseif command=="item" then
  local target=targetFor(game,admin,c)
  if not target or not ctx.items.list[a] then return end
  target:addItem(a)
  target:send("V",target.items,0)
 elseif command=="give" then
  local target=targetFor(game,admin,c)
  if not target or not integer(a) or a<0 or a>3 or not number(b) then return end
  target:addResource(a,math.min(b,1000000),true)
 elseif command=="deltribe" then
  if type(a)=="string" then
   local tribes=assert(ctx.tribes,"authoritative tribe manager required")
   return tribes:remove(a)
  end
 end
end
return Admin
