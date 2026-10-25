-- Sandboxed manifest vocabulary for animation-only rule mods and additional
-- AI species. A new species is a bounded data object, never executable Lua.
local Creatures={}
local function validNumber(v,min,max,integral)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
   and v>=min and v<=max and (not integral or v%1==0)
end
local function only(t,allowed)
 assert(type(t)=="table","expected JSON object")
 for k in pairs(t) do assert(allowed[k],"unknown creature field: "..tostring(k)) end
end
local function safeName(s,max)
 return type(s)=="string" and #s>0 and #s<=(max or 64)
    and s:match("^[%w_%-]+$")~=nil
end
local states={idle=true,walk=true,attack=true,hurt=true,death=true}
function Creatures.animations(definitions,maxIndex)
 assert(type(definitions)=="table","animations must be a JSON object")
 local count=0
 for raw,set in pairs(definitions) do
  count=count+1
  assert(count<=64 and type(raw)=="string" and raw:match("^%d+$")
    and tonumber(raw)<=maxIndex and tonumber(raw)>=0
    and tostring(tonumber(raw))==raw,"unknown animation creature id")
  only(set,{sheet=true,frameWidth=true,frameHeight=true,
    idle=true,walk=true,attack=true,hurt=true,death=true})
  assert(safeName(set.sheet and set.sheet:gsub("%.png$",""),60)
    and set.sheet:match("^[%w_%-]+%.png$"),
    "invalid sprite sheet name")
  assert(validNumber(set.frameWidth,8,512,true)
     and validNumber(set.frameHeight,8,512,true),"invalid frame geometry")
  local clips=0
  for key in pairs(states) do
   local clip=set[key]
   if clip~=nil then
    clips=clips+1
    only(clip,{row=true,frames=true,fps=true,loop=true})
    assert(validNumber(clip.row,0,31,true)
      and validNumber(clip.frames,1,24,true)
      and validNumber(clip.fps,1,30,true)
      and (clip.loop==nil or type(clip.loop)=="boolean"),
      "invalid animation state: "..key)
   end
  end
  assert(clips>=1,"at least one animation clip required")
 end
 return definitions
end
function Creatures.newSpecies(definitions)
 assert(type(definitions)=="table","newAnimals must be a JSON object")
 local count=0
 local result={}
 for raw,s in pairs(definitions) do
  count=count+1
  assert(count<=24 and type(raw)=="string" and raw:match("^%d+$")
    and tonumber(raw)>=15 and tonumber(raw)<=63
    and tostring(tonumber(raw))==raw,"species ids must be 15..63")
  only(s,{name=true,src=true,health=true,scale=true,speed=true,
    turnSpeed=true,weightM=true,hostile=true,chargePlayer=true,
    dmg=true,viewRange=true,killScore=true,drop=true,desired=true})
  assert(type(s.name)=="string" and #s.name>=1 and #s.name<=50,
    "invalid species name")
  assert(safeName(s.src,55),"species sprite name must be a basename")
  assert(validNumber(s.health,1,100000,true)
    and validNumber(s.scale,20,200,true)
    and validNumber(s.speed,0,0.02)
    and validNumber(s.turnSpeed,0,0.1)
    and validNumber(s.weightM,0.1,4),
    "invalid new species physics")
  assert(s.hostile==nil or type(s.hostile)=="boolean","invalid hostile flag")
  assert(s.chargePlayer==nil or type(s.chargePlayer)=="boolean",
    "invalid charging flag")
  assert(s.hostile~=false or s.chargePlayer~=true,
    "passive species cannot charge players")
  assert(s.dmg==nil or validNumber(s.dmg,0,1000),"invalid mob damage")
  assert(s.viewRange==nil or validNumber(s.viewRange,1,4000),
    "invalid view range")
  assert(s.killScore==nil or validNumber(s.killScore,0,20000,true),
    "invalid kill score")
  assert(validNumber(s.desired or 0,0,30,true),"invalid spawn count")
  if s.drop~=nil then
   assert(type(s.drop)=="table" and #s.drop==2
     and (s.drop[1]=="food" or s.drop[1]=="wood"
       or s.drop[1]=="stone")
     and validNumber(s.drop[2],0,500,true),"invalid resource drop")
  end
  result[tonumber(raw)]=s
 end
 return result
end
return Creatures
