-- Survival-first bot planning. All resources, XP, gold and shop equipment
-- are earned/processed by the same authoritative Player routines as humans.
local Catalogue=require("server-lua.world.catalogue")
local Equipment=require("server-lua.world.equipment_input")
local Goals={}
local function owns(set,id)return set and set[id]~=nil and set[id]~=false and set[id]~=0 end
local function metric(player,object)
 local dx,dy=player.x-object.x,player.y-object.y
 return math.sqrt(dx*dx+dy*dy)
end
function Goals.gearPlan(player,style,catalogue)
 catalogue=catalogue or Catalogue
 -- Upgrade the resource-gathering cape first, then save for protection.
 -- Survival/collector styles deliberately value different shop goods.
 local tails=style%3==1 and {3,17} or
   style%3==2 and {9,17} or {10,17}
 for _,id in ipairs(tails) do
  if not owns(player.tails,id) then
   for _,entry in ipairs(catalogue.accessories) do
    if entry.id==id then return {id=id,price=entry.price,tail=true} end
   end
  end
 end
 local hats=style%3==1 and {13,6,9} or
  style%3==2 and {9,6,13} or {6,13,9}
 for _,id in ipairs(hats) do
  if not owns(player.skins,id) then
   for _,entry in ipairs(catalogue.hats) do
    if entry.id==id then return {id=id,price=entry.price,tail=false} end
   end
  end
 end
end
function Goals.purchase(player,style,catalogue)
 catalogue=catalogue or Catalogue
 if not player.alive or type(player.points)~="number" then return false end
 local plan=Goals.gearPlan(player,style,catalogue)
 if not plan or player.points<plan.price then return false end
 local existing=player.points
 -- c:1 is exactly the human store purchase and resource debit.
 Equipment.handle({items=catalogue},player,"c",{1,plan.id,plan.tail and 1 or 0})
 local owned=plan.tail and player.tails or player.skins
 if not owns(owned,plan.id) then return false end
 if player.points>existing then error("bot shop gained gold") end
 -- c:0 is exactly the human equip action.
 Equipment.handle({items=catalogue},player,"c",{0,plan.id,plan.tail and 1 or 0})
 return true
end
function Goals.resourceType(player,style,catalogue)
 catalogue=catalogue or Catalogue
 local food=player.food or 0
 local hp=player.health or 100
 local max=math.max(1,player.maxHealth or 100)
 -- Eating is survival-critical. Demand food before purchases or XP grind.
 if food<28 or (hp/max<0.83 and food<55) then return 1,"food" end
 -- Ranged weapons cannot fire without paying normal projectile costs.
 local secondary=player.weapons and catalogue.weapons[player.weapons[1]]
 if secondary and secondary.req then
  for i=1,#secondary.req,2 do
   local resource,price=secondary.req[i],secondary.req[i+1]
   if (player[resource] or 0)<math.max(price*5,25) then
    if resource=="wood" then return 0,"ammo" end
    if resource=="stone" then return 2,"ammo" end
   end
  end
 end
 local goal=Goals.gearPlan(player,style,catalogue)
 if goal and (player.points or 0)<goal.price then return 3,"gold" end
 -- Every normal resource hit awards XP by the authoritative gather routine.
 -- Balance wood and stone rather than drifting around indefinitely.
 if (player.wood or 0)<70 then return 0,"level" end
 if (player.stone or 0)<50 then return 2,"level" end
 if food<65 then return 1,"food" end
 return nil,"level"
end
function Goals.selectResource(player,objects,style,catalogue,radius)
 local desired,purpose=Goals.resourceType(player,style,catalogue)
 local best,rank=nil,math.huge
 radius=radius or 1050
 for _,object in ipairs(objects or {}) do
  if object.active and not object.isItem and not object.dontGather
     and type(object.type)=="number" and object.type>=0 and object.type<=3
     and type(object.x)=="number" and type(object.y)=="number" then
   local distance=metric(player,object)
   if distance<=radius then
    local penalty=0
    if desired~=nil then
      penalty=object.type==desired and -440 or 260
    else
      penalty=(object.type==3 and -140 or 0)
    end
    -- Low-health bots avoid contested objects when alternatives exist;
    -- target choice remains distance-aware and doesn't grant free materials.
    local danger=(player.health or 100)<35 and object.type==3 and 120 or 0
    local value=distance+penalty+danger
    if value<rank then best,rank=object,value end
   end
  end
 end
 return best,purpose
end
function Goals.shouldFight(player,target,distance)
 local hp=(player.health or 100)/math.max(1,player.maxHealth or 100)
 if hp<0.48 then return false end
 if target and target.isPlayer and (target.health or 100)>
   (player.health or 100)*1.32 and distance>95 then return false end
 -- Not every nearby human is an enemy worth chasing. Fight defensively
 -- at short range, or when the bot has enough health and suitable gear.
 if target and target.isPlayer and distance>185 and hp<0.76 then return false end
 return true
end
return Goals
