-- Regressao ponta a ponta: H (evolucao) -> V MessagePack -> cliente / HUD.
-- O erro antigo deixava a espada em weapons[0], codificava MAP e sumia na UI.
local Equip=require("server-lua.world.equipment_input")
local Catalogue=require("server-lua.world.catalogue")
local MP=require("src.protocol.msgpack")
local World=require("src.game.world_state")
local Hud=require("src.game.reference_hud")
local Upgrades=require("src.game.reference_upgrades")
local function test(label,initial,age,choice,expected,expectedWeapons)
 local player={
  alive=true,upgradePoints=1,upgrAge=age,weaponIndex=initial[1],
  weapons=initial,weaponXP={},items={0,3,6,10},
 }
 local client=World.new()
 client.inventory={weapons={initial[1]},items={0,3,6,10}}
 local packets={}
 function player:send(name,...)
  local args={...}
  local wire=MP.encode(args)
  -- Como no cliente real, cada pacote atravessa MessagePack.
  local roundtrip=MP.decode(wire)
  if name=="V" then
   local inventory=roundtrip[1]
   -- O inventario JS original e uma lista, nunca um mapa.
   assert(#inventory==#args[1],"V inventory changed array length")
   for key in pairs(inventory) do
    assert(type(key)=="number" and key>=1 and key%1==0 and key<=#inventory,
     "V weapon inventory was encoded as MessagePack map")
   end
   assert(wire:byte(1)==0x92,"V packet requires two-element argument array")
  end
  assert(client:apply(name,roundtrip),"client rejected packet "..name)
  packets[#packets+1]=name
 end
 player.anticheat={invalid=function(_,packet,why)error(packet..":"..why)end}
 Equip.handle({items=Catalogue},player,"H",{choice})
 assert(player.upgradePoints==0 and player.upgrAge==age+1)
 assert(player.weaponIndex==expected, label.." active weapon is wrong")
 assert(#player.weapons==#expectedWeapons,label.." weapon array length")
 for i,id in ipairs(expectedWeapons) do
  assert(player.weapons[i]==id,label.." weapon slot "..i.." mismatch")
 end
 assert(player.weapons[0]==nil,label.." created illegal index zero")
 assert(#client.inventory.weapons==#expectedWeapons,label.." client lost a weapon slot")
 for i,id in ipairs(expectedWeapons) do
  assert(client.inventory.weapons[i]==id,label.." client dropped selected weapon")
 end
 assert(#packets==3 and packets[1]=="V" and packets[2]=="V" and packets[3]=="U")
 local weaponId,isWeapon=Hud.slotForKey(client,"1")
 assert(isWeapon and weaponId==expectedWeapons[1],
  label.." HUD weapon disappeared")
 print("PASS "..label..": H -> V array -> HUD weapon "..tostring(weaponId))
end
test("espada principal",{0},2,3,3,{3})
test("machado principal",{0},2,1,1,{1})
test("katana substitui espada",{3},8,4,4,{4})
-- Arma secundaria nao pode substituir a primaria: JS weapons[1].
test("arco secundario",{0},6,9,0,{0,9})
-- A UI de evolucao e o servidor usam o mesmo indice original 0-based.
local ui=World.new()
ui.upgradePoints=1;ui.upgradeAge=2
ui.inventory={weapons={0},items={0,3,6,10}}
local found=false
for _,entry in ipairs(Upgrades.offers(ui)) do
 if entry.kind=="weapon" and entry.id==3 then
  assert(entry.index==3,"UI must send original sword index on H")
  found=true
 end
end
assert(found,"the sword upgrade option must be visible")
print("PASS botao espada: o indice enviado pelo cliente e o indice original 3")
