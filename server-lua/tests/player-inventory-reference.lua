-- Uses the same original 23-item group IDs as shared/config/items.js.
local Player=require("server-lua.world.player_constructor")
local Config=require("src.game.config")
local Items=require("server-lua.world.item_groups")
local Pack=require("src.protocol.msgpack")
local function newPlayer()
 return Player.new("client",9,{hats={},accessories={},items=Items,config=Config})
end
local cases={
 {name="starter",items={0,3,6,10},buildIndex=3,
   seq={4,5,7,8,11,12,1,2,14,15,16,19,22,0,23,-1}},
 {name="empty",items={},buildIndex=-1,
   seq={0,3,6,10,5,8,11,20,21}},
 {name="selected-food",items={0,3,6,10},buildIndex=0,
   seq={1,2,2,6,5,4}},
 {name="selected-mill",items={0,3,6,10},buildIndex=10,
   seq={11,12,11,10}}
}
for _,c in ipairs(cases) do
 local p=newPlayer()
 p.items={table.unpack(c.items)}
 p.buildIndex=c.buildIndex
 for _,id in ipairs(c.seq) do
   local ok=p:addItem(id)
   local str={}
   for _,v in ipairs(p.items) do str[#str+1]=tostring(v) end
   print(table.concat({"ITEM",c.name,id,ok and 1 or 0,p.buildIndex,table.concat(str,",")},"|"))
 end
end
local resources={
 {name="no-moofoll",moofoll=false},
 {name="moofoll",moofoll=true},
 {name="none",moofoll=nil}
}
for _,c in ipairs(resources) do
 local p=newPlayer()
 p.points=11;p.wood=31;p.food=39;p.stone=43;p.gold=50
 p:resetResources(c.moofoll)
 local fields={"RESET",c.name}
 for _,name in ipairs(Config.resourceTypes) do fields[#fields+1]=p[name] end
 fields[#fields+1]=p.points
 print(table.concat(fields,"|"))
end
local scenes={
 {name="normal",x=125.135,y=-50.476,dir=0.67891},
 {name="anon",x=-315.456,y=7260.824,dir=-2.1276,anon=true,clanTag="ABC"},
 {name="clan",x=100.569,y=101.675,dir=3.141592,clanTag="TEST",morph=2,dive=1},
 {name="invisible",x=-650,y=7300,dir=-3.14159,invisible=1,disguised=true},
 {name="powers",x=920.115,y=42.675,dir=1.23456,aura=1,boss=1,disguised=true},
 {name="anon-morph",x=230.445,y=60.995,dir=-0.005,anon=true,morph=3,dive=2,disguised=true},
 {name="zeros",x=0,y=0,dir=0,clanTag=""},
 {name="negative",x=-0.12,y=-0.09,dir=-0.12999}
}
local function fmt(v)
 if v==nil or v==Pack.null then return "~" end
 if type(v)=="number" then return string.format("%.5f",v) end
 return tostring(v)
end
for _,scene in ipairs(scenes) do
 local p=newPlayer()
 p.name="Hero";p.x=scene.x;p.y=scene.y;p.dir=scene.dir
 p.health=76;p.maxHealth=150;p.scale=37;p.skinColor=2
 p.powers.aura=scene.aura or 0;p.powers.boss=scene.boss or 0
 p.powers.invisible=scene.invisible or 0
 p.clanTag=scene.clanTag~="" and scene.clanTag or nil
 p.morph=scene.morph or -1;p.dive=scene.dive or 0
 p.disguised=scene.disguised or false;p.anon=scene.anon or false
 local data=p:getData(scene.anon and {} or p)
 local wire={}
 for _,v in ipairs(data) do wire[#wire+1]=fmt(v) end
 local restored=newPlayer()
 restored:setData(data)
 local fields={"WIRE",scene.name,table.concat(wire,",")}
 for _,key in ipairs({"id","sid","name","x","y","dir","health",
   "maxHealth","scale","skinColor","aura","bossMode","clan"}) do
   fields[#fields+1]=fmt(restored[key])
 end
 print(table.concat(fields,"|"))
end
