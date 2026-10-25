local Player=require("server-lua.world.player_constructor")
-- Original store items with zero price, preserving all IDs and dontSell flags.
-- The JS reference uses the complete shared/config/store.js catalogue.
local freeHats={51,50,28,29,30,36,37,38,44,35,42,43,49}
local freeAccessories={}
local function catalog(ids)
 local data={}
 for _,id in ipairs(ids) do data[#data+1]={id=id,price=0} end
 return data
end
local function listed(tbl)
 local keys={}
 for k,v in pairs(tbl) do if v==1 then keys[#keys+1]=k end end
 table.sort(keys)
 local out={}
 for _,k in ipairs(keys) do out[#out+1]=tostring(k) end
 return table.concat(out,",")
end
for _,t in ipairs({{id="abc",sid=0},{id="another-client",sid=47},{id="last",sid=2}}) do
 local p=Player.new(t.id,t.sid,{hats=catalog(freeHats),accessories=catalog(freeAccessories)})
 print(table.concat({"CONSTRUCTOR",p.id,p.sid,p.name,p.active and 1 or 0,p.alive and 1 or 0,
 p.spawned and 1 or 0,p.watchStats,p.morph,p.dive,p.team==nil and 1 or 0,
 p.points,p.pps,p.skinIndex,p.tailIndex,p.tribeCooldown,p.chatCooldown,
 p.pingCooldown,p.powers.god,p.powers.aura,p.powers.godlike,p.powers.boss,
 p.powers.invisible,p.powers.size,p.powers.power,p.powers.speed,p.powers.health,
 listed(p.skins),listed(p.tails),0,0},"|"))
end
