-- SPDX-License-Identifier: AGPL-3.0-only
-- Differential full static data and native consumable semantics.
local cat=require("server-lua.world.catalogue")
local srcKinds={"groups","projectiles","weapons","list","hats","accessories"}
local function scalar(v)
  if type(v)=="string" then return "s:"..v end
  if type(v)=="number" then return "n:"..tostring(v) end
  if type(v)=="boolean" then return "b:"..tostring(v) end
  if type(v)=="function" then return "function" end
  if v==nil then return "nil" end
  error("unsupported scalar "..type(v))
end
local function flatten(kind,index,v,path)
  if path==".group" then
    assert(type(v)=="table" and v==cat.groups[v.id],"unknown group identity")
    print(table.concat({"CAT",kind,index,path,"ref:"..v.id},"|"))
  elseif type(v)=="table" then
    if #v>0 then
      for i,part in ipairs(v) do
        flatten(kind,index,part,path.."["..(i-1).."]")
      end
    else
      local keys={}
      for key in pairs(v) do keys[#keys+1]=key end
      table.sort(keys)
      for _,key in ipairs(keys) do
        flatten(kind,index,v[key],path.."."..key)
      end
    end
  else
    print(table.concat({"CAT",kind,index,path,scalar(v)},"|"))
  end
end
for _,kind in ipairs(srcKinds) do
  local arr=cat[kind]
  local count=0
  if kind=="hats" or kind=="accessories" then count=#arr
  else
    for key in pairs(arr) do count=count+1 end
  end
  print("COUNT|"..kind.."|"..count)
  for i=0,count-1 do
    flatten(kind,i,(kind=="hats" or kind=="accessories") and arr[i+1] or arr[i],"")
  end
end
for id=0,2 do
  for _,tc in ipairs({
    {name="hurt",health=50},{name="almost",health=90},
    {name="full",health=100},{name="over",health=120}
  }) do
    local calls={}
    local p={health=tc.health,maxHealth=100,dmgOverTime={dmg=0,time=0}}
    p.changeHealth=function(self,amount)
      calls[#calls+1]="HP:"..amount
      if self.health>=self.maxHealth then return false end
      self.health=math.min(self.maxHealth,self.health+amount)
      return true
    end
    local result=cat.list[id].consume(p)
    print(table.concat({"FOOD",id,tc.name,result and 1 or 0,p.health,
      p.dmgOverTime.dmg,p.dmgOverTime.time,
      p.dmgOverTime.doer==p and 1 or 0,table.concat(calls,";")},"|"))
  end
end
