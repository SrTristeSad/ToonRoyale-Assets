-- Node H/V/z: weapon evolution, switch, and admin grant must survive MessagePack.
local Input=require("server-lua.world.input")
local Cat=require("server-lua.world.catalogue")
local Pack=require("src.protocol.msgpack")
local World=require("src.game.world_state")
local Hud=require("src.game.reference_hud")
local function fixture()
 local client=World.new()
 local p={id="tester",sid=5,alive=true,upgradePoints=1,upgrAge=2,
   weaponIndex=0,buildIndex=-1,weapons={0},weaponXP={},items={0,3,6,10},
   anticheat={invalid=function(_,name,why)error(name..":"..why)end,
     allow=function()return true end}}
 function p:send(name,...)
   local args=Pack.decode(Pack.encode({...}))
   assert(client:apply(name,args),"client rejected "..name)
 end
 return p,client
end
local ctx={items=Cat}
local player,client=fixture()
Input.handle(ctx,player,"H",{3}) -- main sword
assert(player.weapons[1]==3 and player.weapons[0]==nil)
assert(client.inventory.weapons[1]==3)
assert(Hud.slotForKey(client,"1")==3)
player.buildIndex=3;player.weaponIndex=0
Input.handle(ctx,player,"z",{3,true})
assert(player.weaponIndex==3 and player.buildIndex==-1,"sword re-equip failed")
player.weaponIndex=0
Input.handle(ctx,player,"z",{1,true})
assert(player.weaponIndex==0,"unowned hammer was incorrectly selectable")
player.upgrAge=6;player.upgradePoints=1
Input.handle(ctx,player,"H",{9}) -- secondary bow
assert(#player.weapons==2 and player.weapons[1]==3 and player.weapons[2]==9)
assert(client.inventory.weapons[2]==9)
player.weaponIndex=3;player.buildIndex=10
Input.handle(ctx,player,"z",{9,true})
assert(player.weaponIndex==9 and player.buildIndex==-1,"bow re-equip failed")
Input.handle(ctx,player,"z",{3,true})
assert(player.weaponIndex==3,"primary re-equip failed after bow")
local admin,adminClient=fixture()
admin.role="admin";admin.powers={};admin.sentTo={}
admin.applyPowers=function()end
local adminCtx={items=Cat,config={weaponVariants={{id=0,xp=0}}},
 game={players={admin},ais={}}}
Input.handle(adminCtx,admin,"A",{"weapon",4,0})
assert(admin.weapons[1]==4 and admin.weapons[0]==nil)
assert(adminClient.inventory.weapons[1]==4)
admin.weaponIndex=0
Input.handle(adminCtx,admin,"z",{4,true})
assert(admin.weaponIndex==4,"admin granted weapon cannot be equipped")
print("PASS Node H/V/z: main sword, secondary bow, admin grant, HUD, MessagePack")
