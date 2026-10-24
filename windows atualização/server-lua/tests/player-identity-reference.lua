-- Compare real Player constructor/methods as extracted in reference.mjs.
local Identity=require("server-lua.world.player_identity")
local MP=require("src.protocol.msgpack")
local Config=require("src.game.config")
local groups={{id=0},{id=1},{id=2},{id=3}}
local items={list={
 [0]={id=0,group=groups[1]},[3]={id=3,group=groups[2]},
 [4]={id=4,group=groups[2]},[6]={id=6,group=groups[3]},
 [10]={id=10,group=groups[4]},[11]={id=11,group=groups[4]}
}}
local hats={
 {id=0,price=0},{id=5,price=0},{id=9,price=20},
 {id=40,price=0,dontSell=true},{id=61,price=0,dontSell=true}
}
local accessories={
 {id=0,price=0},{id=1,price=200},{id=6,price=0},
 {id=16,price=0,dontSell=true}
}
local cases={
 {name="initial",applyData=false},
 {name="basic",data={name=" Guest ",skin=2}},
 {name="punctuation",data={name="T(hi):/ ?-User",skin=9}},
 {name="truncation",data={name="LongPlayerName123456789",skin=0}},
 {name="nonascii",data={name="Café ✨ Rai",skin=50}},
 {name="profanity",data={name="hello qweir friend",skin=1}},
 {name="leetspeak",data={name="D1SC0RD",skin=3}},
 {name="empty",data={name="   ",skin=1}},
 {name="missing-name",data={skin=1}},
 {name="account",data={name="Moo",skin=4},account={name="AccountID",role="mod"}},
 {name="account-anon",data={name="Guest",skin=4,anon=true},
   account={name="Permanent",role="admin"}},
 {name="anon-guest",data={name="Guest",skin=3,anon=true}},
 {name="no-data",data=false,account={name="Existing"}},
 {name="replace",data={name="Name",skin=8},item=4,buildIndex=3},
 {name="new-item",data={name="Name",skin=8},item=11},
 {name="missing-item",data={name="Name",skin=8},item=99},
 {name="powers",data={name="Hero",skin=1},health=42,
   powers={size=1.5,health=2}},
 {name="shame",data={name="Hero",skin=1},shameTimer=1000}
}
local function owned(t)
 local ks={}
 for k in pairs(t) do ks[#ks+1]=k end
 table.sort(ks)
 for i,v in ipairs(ks) do ks[i]=tostring(v) end
 return table.concat(ks,",")
end
local function field(v)
 if v==nil or v==MP.null then return "~" end
 if type(v)=="boolean" then return v and "true" or "false" end
 return tostring(v)
end
local function formattedData(t)
 local args={}
 for i=1,17 do args[#args+1]=field(t[i]) end
 return table.concat(args,",")
end
for _,tc in ipairs(cases) do
 local p=Identity.new("session",17,{
   hats=hats,accessories=accessories,config=Config,
   nameWords={"qweir","discord","badword"}
 })
 if tc.account then p.account=tc.account;p.role=tc.account.role end
 p.items={0,3,6,10}
 p.buildIndex=tc.buildIndex or -1
 p.x=125.5549;p.y=502.4561;p.dir=1.23456
 p.health=tc.health or 80;p.maxHealth=100;p.scale=35
 if tc.powers then for k,v in pairs(tc.powers) do p.powers[k]=v end end
 p.clanTag="CLAN";p.shameTimer=tc.shameTimer or 0
 p.skinIndex=4;p.tailIndex=2;p.zIndex=0
 p.moveDir=1;p:resetMoveDir()
 if tc.applyData~=false then p:setUserData(tc.data==false and nil or tc.data) end
 local changed=nil
 if tc.item~=nil then changed=p:addItem(tc.item,items) end
 if tc.powers then p.alive=true;p:applyPowers()end
 local outsider={id="other"}
 local data=p:getData(outsider)
 local output={
   "IDENTITY",tc.name,p.id,p.sid,p.name,p:shownName(outsider),p:shownName(p),
   p.skinColor,p.anon and 1 or 0,p.isMember and 1 or 0,
   p.alive and 1 or 0,p.active and 1 or 0,
   p.moveDir==nil and "~" or tostring(p.moveDir),
   owned(p.skins),owned(p.tails),table.concat(p.items,","),p.buildIndex,
   changed==nil and "~" or (changed and 1 or 0),
   p:displaySkin(),p.scale,p.maxHealth,p.health,formattedData(data)
 }
 for i,v in ipairs(output) do output[i]=tostring(v) end
 print(table.concat(output,"|"))
end
