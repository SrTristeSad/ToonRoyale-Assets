-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact counterparts of equipment-reference.mjs against real Item catalogue.
local Equip=require("server-lua.world.equipment_input")
local Cat=require("server-lua.world.catalogue")
local Identity=require("server-lua.world.player_identity")
local MP=require("src.protocol.msgpack")
local accessory=nil
for _,entry in ipairs(Cat.accessories) do
 if entry.price>0 and not entry.dontSell then accessory=entry;break end
end
assert(accessory and Cat.weapons[15] and Cat.list[22],"authoritative source catalog required")
local cases={
 {id="upgrade-axe",n="H",args={1},upgrAge=2},
 {id="upgrade-sword",n="H",args={3},upgrAge=2,weaponIndex=1},
 {id="upgrade-bow",n="H",args={9},upgrAge=6},
 {id="upgrade-pre-fail",n="H",args={2},upgrAge=8},
 {id="upgrade-pre-pass",n="H",args={2},upgrAge=8,weapons={[0]=1}},
 {id="upgrade-wall",n="H",args={20},upgrAge=3,buildIndex=3},
 {id="upgrade-mill",n="H",args={27},upgrAge=5,buildIndex=10},
 {id="upgrade-pre-item-fail",n="H",args={21},upgrAge=7},
 {id="upgrade-pre-item-pass",n="H",args={21},upgrAge=7,items={0,4,6,10}},
 {id="upgrade-no-age",n="H",args={1},upgrAge=5},
 {id="upgrade-negative",n="H",args={-1}},
 {id="upgrade-invalid",n="H",args={"1"}},
 {id="upgrade-empty",n="H",args={}},
 {id="upgrade-no-points",n="H",args={1},upgradePoints=0},
 {id="upgrade-dead",n="H",args={1},alive=false},
 {id="purchase-hat",n="c",args={1,57,0},points=800},
 {id="purchase-hat-account",n="c",args={1,57,0},points=800,account=true},
 {id="purchase-free-owned",n="c",args={1,51,0},points=800},
 {id="purchase-shame",n="c",args={1,45,0},points=800},
 {id="purchase-no-money",n="c",args={1,2,0},points=0},
 {id="purchase-accessory",n="c",args={1,accessory.id,1},points=2000},
 {id="purchase-accessory-account",n="c",args={1,accessory.id,1},points=2000,account=true},
 {id="equip-hat",n="c",args={0,51,0}},
 {id="equip-tail",n="c",args={0,accessory.id,1},ownedTail=true},
 {id="equip-not-owned",n="c",args={0,57,0}},
 {id="equip-tail-not-owned",n="c",args={0,accessory.id,1}},
 {id="unequip-hat",n="c",args={0,0,0}},
 {id="unequip-tail",n="c",args={0,0,1}},
 {id="invalid-action",n="c",args={2,57,0}},
 {id="invalid-id",n="c",args={1,1.5,0}},
 {id="invalid-id-null",n="c",args={1,MP.null,0}},
 {id="store-dead",n="c",args={1,57,0},alive=false},
 {id="store-buy-unknown",n="c",args={1,999,0},points=2000}
}
local function value(v)
 if v==nil then return "~" end
 if v==MP.null then return "null" end
 return tostring(v)
end
local function sourceArray(arr)
 local parts={}
 for i=0,15 do
  if arr[i]~=nil then parts[#parts+1]=value(arr[i])
  else break end
 end
 return table.concat(parts,",")
end
local function itemArray(arr)
 local parts={}
 for _,v in ipairs(arr) do parts[#parts+1]=value(v) end
 return table.concat(parts,",")
end
local function storeEntry(list,id)
 for _,entry in ipairs(list) do if entry.id==id then return entry end end
end
for _,tc in ipairs(cases) do
 local events={}
 local p=Identity.new("test",7,{
   hats=Cat.hats,accessories=Cat.accessories
 })
 p.alive=tc.alive~=false
 p.upgradePoints=tc.upgradePoints or 1
 p.upgrAge=tc.upgrAge or 2
 p.weaponIndex=tc.weaponIndex or 0
 p.buildIndex=tc.buildIndex or -1
 p.weapons=tc.weapons or {[0]=0}
 p.weaponXP={[0]=15,[1]=30}
 p.items=tc.items or {0,3,6,10}
 p.points=tc.points or 1000
 p.skin=storeEntry(Cat.hats,51)
 p.tail=accessory
 p.skinIndex=51
 p.tailIndex=accessory.id
 if tc.account then p.account={id="account"} end
 if tc.ownedTail then p.tails[accessory.id]=1 end
 p.anticheat={
  invalid=function(_,packet,why)
   events[#events+1]="INVALID:"..packet..":"..why
  end
 }
 p.send=function(self,packet,...)
   local args={...}
   local v={}
   for i=1,select("#",...) do
     local a=select(i,...)
     if type(a)=="table" then
       if packet=="V" and select(2,...)==1 then
         v[#v+1]=sourceArray(a)
       else
         v[#v+1]=itemArray(a)
       end
     else
       v[#v+1]=value(a)
     end
   end
   events[#events+1]="SEND:"..packet..":"..table.concat(v,":")
 end
 p.addItem=function(self,id)return Identity.addItem(self,id,Cat)end
 p.addResource=function(self,id,count,doSend)
  events[#events+1]="RESOURCE:"..id..":"..count..":"..value(doSend)
  self.points=self.points+count
 end
 local accounts={
   recordUnlocks=function(self,account,obj)
     local entries={}
     if obj.hat~=nil then entries[1]='"hat":'..obj.hat
     else entries[1]='"acc":'..obj.acc end
     events[#events+1]="UNLOCK:"..account.id..":{"..table.concat(entries,",").."}"
   end
 }
 Equip.handle({items=Cat,accounts=accounts},p,tc.n,tc.args)
 print(table.concat({
   "EQUIP",tc.id,p.upgrAge,p.upgradePoints,p.weaponIndex,p.buildIndex,
   sourceArray(p.weapons),sourceArray(p.weaponXP),itemArray(p.items),
   p.points,p.skinIndex,p.tailIndex,p.skin and p.skin.id or "~",
   p.tail and p.tail.id or "~",p.skins[57] or 0,
   p.tails[accessory.id] or 0,table.concat(events,";")
 },"|"))
end
