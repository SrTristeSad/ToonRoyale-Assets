-- SPDX-License-Identifier: AGPL-3.0-only
-- Direct port of packet H (age upgrade) and packet c (store purchase/equip)
-- from server/src/network/packets.js. Uses the authoritative full
-- shared/config items/store catalogue, never a made-up shop or prices.
local MP=require("src.protocol.msgpack")
local Equipment={}
local function truth(v)
 return v~=nil and v~=false and v~=0 and v~="" and v~=MP.null
end
local function isInt(v)
 return type(v)=="number" and v==v and v%1==0
   and v~=math.huge and v~=-math.huge
end
local function invalid(player,packet,why)
 assert(player.anticheat and type(player.anticheat.invalid)=="function",
   "real Player.anticheat.invalid required")
 return player.anticheat:invalid(packet,why)
end
local function owns(arr,id)
 for _,value in ipairs(arr or {}) do if value==id then return true end end
 return false
end
local function weaponLength(weapons)
 local n=0
 while weapons[n] do n=n+1 end
 return n
end
local function storeEntry(list,id)
 -- Store arrays are 1-indexed, but ownership uses source id as a key.
 for _,item in ipairs(list) do if item.id==id then return item end end
end
function Equipment.handle(ctx,player,name,args)
 assert(ctx and ctx.items and ctx.items.list and ctx.items.weapons
   and ctx.items.hats and ctx.items.accessories,
   "full original items and store catalogue required")
 args=args or {}
 if name=="H" then
   if not player.alive or player.upgradePoints<=0 then return end
   local index=args[1]
   if not isInt(index) then return invalid(player,"H","upgrade index") end
   local total=weaponLength(ctx.items.weapons)
   if index<total then
     -- JS array[-1] is undefined. Lua must not reuse a negative key.
     local weapon=index>=0 and ctx.items.weapons[index] or nil
     if not weapon or weapon.age~=player.upgrAge then return end
     if weapon.pre~=nil and not owns(player.weapons,weapon.pre) then return end
     player.weapons[weapon.type]=weapon.id
     player.weaponXP[weapon.type]=0
     local activeType=player.weaponIndex<9 and 0 or 1
     if weapon.type==activeType then player.weaponIndex=weapon.id end
   else
     local item=ctx.items.list[index-total]
     if not item or item.age~=player.upgrAge then return end
     if item.pre~=nil and not owns(player.items,item.pre) then return end
     assert(type(player.addItem)=="function","original Player.addItem required")
     player:addItem(item.id)
   end
   player.upgrAge=player.upgrAge+1
   player.upgradePoints=player.upgradePoints-1
   player:send("V",player.items,0)
   player:send("V",player.weapons,1)
   player:send("U",player.upgradePoints,player.upgrAge)
   return
 elseif name=="c" then
   if not player.alive then return end
   local action,id=args[1],args[2]
   if not isInt(id) or (action~=0 and action~=1) then
     return invalid(player,"c","store")
   end
   local tail=truth(args[3])
   local list=tail and ctx.items.accessories or ctx.items.hats
   local owned=tail and player.tails or player.skins
   local entry=storeEntry(list,id)
   if action==1 then
     if not entry or truth(owned[id]) or truth(entry.dontSell)
       or player.points<entry.price then return end
     if entry.price>0 then
       assert(type(player.addResource)=="function",
         "Player.addResource required for paid store item")
       player:addResource(3,-entry.price,true)
     end
     owned[id]=1
     player:send("5",0,id,tail and 1 or 0)
     if player.account and ctx.accounts then
       assert(type(ctx.accounts.recordUnlocks)=="function",
         "real accounts.recordUnlocks required for account purchases")
       local unlock=tail and {acc=id} or {hat=id}
       ctx.accounts:recordUnlocks(player.account,unlock)
     end
     return
   end
   if id==0 then
     if tail then
       player.tail=nil;player.tailIndex=0
     else
       player.skin=nil;player.skinIndex=0
     end
     player:send("5",1,0,tail and 1 or 0)
     return
   end
   if not entry or not truth(owned[id]) then return end
   if tail then player.tail=entry;player.tailIndex=id
   else player.skin=entry;player.skinIndex=id end
   player:send("5",1,id,tail and 1 or 0)
   return
 end
 error("unsupported equipment packet "..tostring(name))
end
return Equipment
