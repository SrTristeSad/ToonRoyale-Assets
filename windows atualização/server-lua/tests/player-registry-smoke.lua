-- SPDX-License-Identifier: AGPL-3.0-only
-- Host RoomTransport -> PlayerRegistry -> fully composed Lua Player.
-- Strictly observable lifecycle order from original Game.add/removePlayer.
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local Transport=require("server-lua.net.room_transport")
local Config=require("src.game.config")
local events={}
local function log(e)events[#events+1]=e end
local group={id=1,limit=30}
local items={
 weapons={[0]={id=0,type=0,speed=300,dmg=25,gather=1,range=65}},
 projectiles={[0]={range=1000,speed=1.6,dmg=25,scale=103,layer=0}},
 list={[0]={id=0,group={id=0}},[3]={id=3,group=group}}
}
local room=Room.new({nowMs=10000,items=items,
 services={ensureAnimals=function()end}})
local n=0
local registry=Registry.new(room,{
 hats={{id=0,price=0},{id=5,price=200}},
 accessories={{id=0,price=0}},
 nameWords={"qweir","discord"},
 randomString=function(size)
   assert(size==16);n=n+1
   return string.format("%016d",n)
 end,
 accountForTicket=function(ticket)
   if ticket.did=="account" then
     return {name="Permanent",role="admin",verdict="shadow",clan="CLAN"}
   end
   return nil
 end,
 anticheatFactory=function(id,sid,ip,account)
   return {
     invalid=function()end,
     onGameStart=function()end,
     tick=function()end
   }
 end,
 onDeath=function(p)log("death:"..p.sid)end,
 clanList=function()return {{name="TRIBE"}}end,
 recordLife=function(p,died)log("record:"..p.sid..":"..tostring(died))end,
 leaveTribe=function(p)log("leave:"..p.sid)end,
 forget=function(p)log("forget:"..p.sid)end,
 removeItems=function(sid)log("items:"..sid)end,
 presence=function(account,game)log("presence:"..account.name..":"..game)end,
 count=function(key,count)log("count:"..count)end
})
local bridge=Transport.new(registry:transportOptions())
local function makePeer()
 local peer={ip="127.0.0.1",closed=false,sent={}}
 peer.send=function(self,name,args)
   self.sent[#self.sent+1]={name=name,args=args}
   return true
 end
 return peer
end
local p1=makePeer()
local one=bridge:connected(p1,{did="guest"})
assert(one.sid==0 and #one.id==16 and room.players[1]==one)
assert(one.ip=="127.0.0.1" and #one.ipHash==12)
assert(one.connectedAt==10000 and one.reports==0)
assert(one.skins[0]==1 and one.tails[0]==1)
assert(not one.alive and not one.spawned and one.chatCooldown==0)
assert(p1.sent[1].name=="A" and #p1.sent[1].args[1].animals==15,
 "welcome must include all 15 real animal kinds")
assert(p1.sent[1].args[1].teams[1].name=="TRIBE")
local p2=makePeer()
local two=bridge:connected(p2,{did="account"})
assert(two.sid==1 and two.isMember and two.role=="admin")
assert(two.shadowed and two.name=="Permanent" and two.clanTag=="CLAN")
assert(registry.playersById[one.id]==one and registry.playersById[two.id]==two)
-- Original input ignores movement until the client sends spawn packet M.
bridge:packet(p1,"M",{{name="Hero",skin=0,moofoll=false}})
assert(one.alive and one.spawned and one.name=="Hero")
bridge:packet(p1,"D",{1.2})
assert(one.dir==1.2,"real input goes to correct Player")
room.crabKillers[one.sid]=true
assert(bridge:closed(p1))
assert(room.players[1]==two and registry.available[0]==true)
assert(registry.playersById[one.id]==nil and room.crabKillers[0]==nil)
assert(p2.sent[#p2.sent].name=="E" and p2.sent[#p2.sent].args[1]==one.id)
local found=table.concat(events,",")
assert(found:find("record:0:false,leave:0,forget:0,items:0,count:1",1,true),
 "original disconnect cleanup and count must remain ordered")
assert(not bridge:closed(p1),"repeat close must not mutate room")
local p3=makePeer()
local three=bridge:connected(p3,{did="guest2"})
assert(three.sid==0 and three.id~=one.id,"released SID reused only after cleanup")
assert(#room.players==2 and room.players[2]==three)
assert(bridge:closed(p3))
assert(bridge:closed(p2))
assert(#room.players==0 and registry.available[0] and registry.available[1])
assert(events[#events-1]=="count:0" or events[#events]=="count:0",
 "final disconnect count must reach zero")
assert(table.concat(events,","):find("presence:Permanent:",1,true),
 "authenticated account presence cleared")
print("PASS Node-style SID allocate/reuse, IP hash, welcome A, member metadata")
print("PASS Host->real Player commands, ordered leave/cleanup/count/broadcast E")
