-- SPDX-License-Identifier: AGPL-3.0-only
-- Same gameplay inputs as the unchanged Node handlePacket reference.
local MP=require("src.protocol.msgpack")
local Input=require("server-lua.world.input")
local items={
 weapons={
   [0]={id=0,type=0}
 },
 list={
   [0]={id=0},[3]={id=3},[5]={id=5}
 }
}
local cases={
 {id="spawn",packet="M",args={{name="Test",skin=0,moofoll=false}},alive=false},
 {id="spawn-invalid",packet="M",args={"bad"},alive=false},
 {id="spawn-alive",packet="M",args={{name="Test"}}},
 {id="dir",packet="D",args={0.9}},
 {id="dir-invalid",packet="D",args={"bad"}},
 {id="move",packet="9",args={2.4}},
 {id="stop",packet="9",args={MP.null}},
 {id="move-invalid",packet="9",args={false}},
 {id="reset",packet="e",args={}},
 {id="attack",packet="F",args={true,1.2}},
 {id="attack-empty",packet="F",args={false,MP.null}},
 {id="build",packet="F",args={1,1.5},buildIndex=3},
 {id="build-invalid",packet="F",args={1,"bad"}},
 {id="weapon-select",packet="z",args={0,true},buildIndex=3},
 {id="item-select",packet="z",args={3,false}},
 {id="item-toggle",packet="z",args={3,false},buildIndex=3},
 {id="item-invalid",packet="z",args={"bad",false}},
 {id="item-unowned",packet="z",args={5,false}},
 {id="toggle-gather",packet="K",args={1}},
 {id="toggle-lock",packet="K",args={0}},
 {id="toggle-invalid",packet="K",args={5}},
 {id="ping",packet="0",args={}},
 {id="dead-dir",packet="D",args={2.2},alive=false},
 {id="dead-attack",packet="F",args={true,0.5},alive=false}
}
local function g(v)
 if v==nil or v==MP.null then return "~" end
 if type(v)=="number" then
   if v==math.floor(v) then return string.format("%.0f",v) end
   return string.format("%.5f",v)
 end
 return tostring(v)
end
for _,s in ipairs(cases) do
 local events={}
 local player={
   id="guest",sid=7,alive=s.alive==nil and true or s.alive,
   name="Old",dir=0.25,moveDir=0.8,mouseState=0,hits=0,
   buildIndex=s.buildIndex or -1,weaponIndex=0,
   autoGather=0,lockDir=false,
   itemCounts={},items={0,3,6,10},weapons={[0]=0},
   attrCache={old=1},
   anticheat={
     invalid=function(_,name,why)events[#events+1]="INVALID:"..name..":"..why end,
     onGameStart=function()events[#events+1]="ACSTART" end
   }
 }
 player.setUserData=function(self,data)
   self.name=data.name
   events[#events+1]="SET:"..self.name
 end
 player.spawn=function(self,v)
   self.alive=true
   events[#events+1]="SPAWN:"..g(v)
 end
 player.resetMoveDir=function(self)
   self.moveDir=nil
   events[#events+1]="RESET"
 end
 player.buildItem=function(self,item)
   events[#events+1]="BUILD:"..item.id
 end
 player.send=function(self,name,...)
   local args={}
   for i=1,select("#",...) do args[i]=g(select(i,...)) end
   events[#events+1]="SEND:"..name..":"..table.concat(args,",")
 end
 local ctx={items=items,gameKey="LC",
   log=function(message)events[#events+1]="LOG:"..message end}
 Input.handle(ctx,player,s.packet,s.args)
 local cache=0
 for _ in pairs(player.attrCache) do cache=cache+1 end
 print(table.concat({"INPUT",s.id,player.alive and 1 or 0,g(player.dir),g(player.moveDir),
   g(player.mouseState),player.hits,player.buildIndex,player.weaponIndex,
   g(player.autoGather),g(player.lockDir),cache,table.concat(events,";")},"|"))
end
assert(not pcall(function()
 Input.handle({items=items},{alive=true},"6",{})
end),"unported packets must require an external real implementation")
