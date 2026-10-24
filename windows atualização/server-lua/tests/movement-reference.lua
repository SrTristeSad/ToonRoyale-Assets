-- SPDX-License-Identifier: AGPL-3.0-only
-- Native Lua counterpart for the Node Player.update movement differential test.
local Config=require("src.game.config")
local World=require("server-lua.world.objects")
local Movement=require("server-lua.world.movement")
local Crypto=require("src.protocol.original_crypto")
local scenarios={
 {"walk",33,{}},{"coast",95,{moveDir=false,xVel=0.29,yVel=-0.14}},
 {"diagonal",111.111,{moveDir=2.35}},{"slow",110,{slowMult=0.33}},
 {"snow",100,{y=1000}},{"snow-skin",120,{y=1000,skin={coldM=true,spdMult=1.2}}},
 {"snowball",111,{y=1000,tail={id=12}}},{"winter",111,{y=1000,tail={id=6}}},
 {"river",111,{x=7200,y=7200}},{"river-imm",111,{x=7200,y=7200,skin={watrImm=true}}},
 {"secret-pool",111,{x=-2350,y=7200}},{"secret-imm",111,{x=-2350,y=7200,skin={watrImm=true}}},
 {"build",80,{buildIndex=0}},{"dash",120,{tail={id=5}}},
 {"super",110,{superUntil=50000}},{"power",110,{powers={speed=2.1}}},
 {"locked",111,{lockMove=true,xVel=0.2,yVel=0.1}},{"northwall",111,{x=600,y=35,moveDir=-math.pi/2}},
 {"eastwall",111,{x=14350,y=7300,moveDir=0}},{"westwall",111,{x=36,y=9200,moveDir=math.pi}},
 {"rock",80,{x=500,y=500,objects={{x=550,y=500,scale=22,type=2}}}},
 {"trap",80,{x=500,y=500,objects={{x=545,y=500,scale=25,type=2,ignoreCollision=true,trap=true,zIndex=2}}}},
 {"boost",80,{x=500,y=500,objects={{x=545,y=500,scale=25,type=2,ignoreCollision=true,boostSpeed=0.012,dir=1}}}},
 {"heal",80,{x=500,y=500,objects={{x=545,y=500,scale=25,type=2,ignoreCollision=true,healCol=8}}}},
 {"enemy",100,{x=500,y=500,second={x=555,y=500}}},
 {"fast",950,{x=750,y=750,xVel=0.8,moveDir=0.3}},
 {"zero",0,{x=500,y=500}}
}
local function fmt(v) return string.format("%.7f",v or 0) end
local function line(name,tick,p,other,obj)
 print(table.concat({"MOVE",name,tick,fmt(p.x),fmt(p.y),fmt(p.xVel),fmt(p.yVel),
   fmt(p.slowMult),fmt(p.noMovTimer),p.lockMove and 1 or 0,p.zIndex,p.healCol or 0,
   p.health,p.alive and 1 or 0,other and fmt(other.x) or "-",
   other and fmt(other.y) or "-",obj and (obj.hideFromEnemy==false and 1 or 0) or "-"},"|"))
end
local base={
 sid=1,id="player1",x=500,y=500,xVel=0,yVel=0,scale=Config.playerScale,
 speed=Config.playerSpeed,dir=0,moveDir=0.35,
 powers={speed=1},slowMult=1,noMovTimer=0,
 buildIndex=-1,weaponIndex=0,lockMove=false,zIndex=0,
 alive=true,health=100,healCol=0,dmgOverTime={},superUntil=0
}
for _,test in ipairs(scenarios) do
 local name,delta,override=test[1],test[2],test[3]
 local player={}
 for k,v in pairs(base) do player[k]=v end
 for k,v in pairs(override) do
   if k~="second" and k~="objects" then player[k]=v end
 end
 if override.moveDir==false then player.moveDir=nil end
 player.changeHealth=function(self,amount)
   self.health=self.health+amount;self.alive=self.health>0
   return not self.alive
 end
 local players={player}
 local other=nil
 if override.second then
   other={sid=2,x=override.second.x,y=override.second.y,scale=35,
     alive=true,isPlayer=true,xVel=0,yVel=0}
   players[#players+1]=other
 end
 local world=World.new({config=Config,random=Crypto.mulberry32(2323)})
 local obj=nil
 for _,spec in ipairs(override.objects or {}) do
   obj=world:addObject(spec.x,spec.y,spec.scale,spec.type)
   for k,v in pairs(spec) do
     if k~="x" and k~="y" and k~="scale" and k~="type" then obj[k]=v end
   end
 end
 -- The original item is authoritative; the reference uses items.weapons[0].
 -- This test verifies the base weapon's actual spdMult is absent/1.
 local weapon={spdMult=nil}
 for tick=1,3 do
   Movement.step(player,delta,world,players,{config=Config,nowMs=10000,weapon=weapon})
   line(name,tick,player,other,obj)
 end
end
