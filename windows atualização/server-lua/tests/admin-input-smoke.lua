-- SPDX-License-Identifier: AGPL-3.0-only
local Input=require("server-lua.world.input")
local events={}
local function emit(s) events[#events+1]=s end
local admin={id="a",sid=1,role="admin",alive=true,powers={},sentTo={b=true},x=10,y=20,xVel=3,yVel=4,scale=20,dir=0,weapons={},weaponXP={},items={}}
local other={id="b",sid=2,alive=true,x=50,y=60,xVel=1,yVel=2,scale=15,weapons={},weaponXP={},items={}}
admin.anticheat={invalid=function(_,packet,why)emit(packet..":"..why) end}
admin.applyPowers=function() emit("apply") end
admin.send=function(_,packet) emit("send:"..packet) end
other.send=admin.send
admin.addItem=function(self,id) self.items[#self.items+1]=id;emit("item:"..id) end
admin.addResource=function(_,kind,amount) emit("give:"..kind..":"..amount) end
local game={players={admin,other},ais={{index=3,active=true,x=100,y=200,scale=15}},
 animal_manager={aiTypes={[3]={scale=30}},spawn=function(_,x,y,dir,index,opts)
 assert(index==3 and opts.despawnOnDeath and dir==0)
 emit("spawn:"..x..":"..y)
 end}}
local removed
local ctx={game=game,items={weapons={[5]={id=5,type=1}},list={[2]={id=2}}},
 config={weaponVariants={{id=0,xp=0},{id=1,xp=100}}},tribes={remove=function(_,name)removed=name end}}
local function send(...)return Input.handle(ctx,admin,"A",{...}) end
send("godlike",1)
assert(admin.powers.godlike==1 and admin.powers.god==1 and admin.powers.aura==1 and admin.sentTo.b==nil)
send("speed",2)
assert(admin.powers.speed==2)
send("speed",999)
assert(admin.powers.speed==2)
send("tp",200,300)
assert(admin.x==200 and admin.y==300 and admin.xVel==0 and admin.yVel==0)
send("goto",2)
assert(admin.x==80 and admin.y==60)
send("summon",2)
assert(other.x==120 and other.y==60)
send("gotomob",3)
assert(admin.x==175 and admin.y==200)
send("spawn",3)
send("weapon",5,1)
assert(admin.weaponIndex==5 and admin.weaponXP[5]==100)
send("weapon",5,0)
assert(admin.weaponXP[5]==0,"variant zero must match Node index zero")
send("weapon",5,999)
assert(admin.weaponXP[5]==0,"invalid variant must fall back to index zero")
send("weapon",5,"1")
assert(admin.weaponXP[5]==100,"JS-style numeric string property must match Node")
send("item",2)
assert(admin.items[1]==2)
send("give",3,2000000)
send("deltribe","TEST")
assert(removed=="TEST")
admin.role="mod"
send("god",1)
assert(admin.powers.god==1 and events[#events]=="A:admin command")
print("PASS pacote A: 13 comandos, permissões e efeitos")
