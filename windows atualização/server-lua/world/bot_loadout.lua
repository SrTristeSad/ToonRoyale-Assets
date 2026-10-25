-- Real bot weapon/item progression through the same H upgrade path as players.
-- All age, prerequisite, resource and ownership checks remain server-owned.
local Equipment=require("server-lua.world.equipment_input")
local Catalogue=require("server-lua.world.catalogue")
local Loadout={}
local styles={
 {primary={1,2,8,5,3,7},secondary={9,12,13,15,10,11}},
 {primary={3,4,7,5,1,2},secondary={11,9,12,10,13,15}},
 {primary={5,3,4,7,1,2},secondary={9,12,15,13,10,11}},
 {primary={7,3,4,5,1,2},secondary={9,13,12,15,10,11}},
 {primary={1,2,8,5,3,7},secondary={10,9,12,13,15,11}},
 {primary={3,4,5,7,1,2},secondary={9,12,13,15,11,10}},
 {primary={5,3,7,4,1,2},secondary={9,12,15,13,11,10}},
 {primary={7,3,5,4,1,2},secondary={9,12,13,15,11,10}}
}
local function owns(container,id)
 if not container then return false end
 for _,value in pairs(container) do if value==id then return true end end
 return false
end
local function affordable(player,weapon)
 local req=weapon and weapon.req
 if not req then return true end
 for i=1,#req,2 do
  if type(player[req[i]])~="number" or player[req[i]]<req[i+1] then
   return false
  end
 end
 return true
end
local function weaponWeight(style,id)
 local ranking=styles[style] or styles[1]
 for i,v in ipairs(ranking.primary) do
  if id==v then return #ranking.primary-i+1 end
 end
 for i,v in ipairs(ranking.secondary) do
  if id==v then return #ranking.secondary-i+1 end
 end
 return 0
end
local function eligible(player,entry)
 return entry and entry.age==player.upgrAge
   and (entry.pre==nil or owns(player.weapons,entry.pre))
end
function Loadout.choose(player,catalogue,style)
 catalogue=catalogue or Catalogue
 if type(player.upgrAge)~="number" or
    type(player.upgradePoints)~="number" or player.upgradePoints<=0 then
  return nil
 end
 local primary=styles[style] or styles[1]
 local choices={}
 for id=0,15 do
  local weapon=catalogue.weapons[id]
  if eligible(player,weapon) then
   local pref=weapon.type==0 and primary.primary or primary.secondary
   local rank=0
   for i,v in ipairs(pref) do if v==id then rank=#pref-i+1;break end end
   choices[#choices+1]={id=id,rank=rank,weapon=true}
  end
 end
 local total=0
 while catalogue.weapons[total] do total=total+1 end
 for id=0,22 do
  local item=catalogue.list[id]
  if item and item.age==player.upgrAge
    and (item.pre==nil or owns(player.items,item.pre)) then
   local priority=item.group and item.group.id==0 and 120
      or item.group and item.group.id==1 and 100
      or item.group and item.group.id==2 and 95
      or item.group and item.group.id==3 and 90 or 30
   -- If a weapon is available at this age, choose it. The remaining
   -- ages grant the same ordinary food/walls/traps/mill unlocks as players.
   choices[#choices+1]={id=total+id,rank=priority,weapon=false}
  end
 end
 table.sort(choices,function(a,b)
  -- Stage decisions should prefer weapons at 2, 6 and 8/9.
  -- At item stages 3/4/5/7 weapons are usually absent.
  local ai=a.weapon and 300+a.rank or a.rank
  local bi=b.weapon and 300+b.rank or b.rank
  if ai~=bi then return ai>bi end
  return a.id<b.id
 end)
 return choices[1] and choices[1].id or nil
end
function Loadout.upgrade(player,catalogue,style)
 catalogue=catalogue or Catalogue
 if not player.alive or type(player.upgradePoints)~="number"
   or player.upgradePoints<=0 then return false end
 local choice=Loadout.choose(player,catalogue,style)
 if not choice then return false end
 local points,age=player.upgradePoints,player.upgrAge
 Equipment.handle({items=catalogue},player,"H",{choice})
 return player.upgradePoints==points-1 and player.upgrAge==age+1
end
function Loadout.chooseWeapon(player,catalogue,mode,distance,style)
 catalogue=catalogue or Catalogue
 local weapons=catalogue.weapons
 local p=player.weapons or {}
 local primary=weapons[p[0]] or weapons[0]
 if not primary then return player.weaponIndex end
 local secondary=p[1] and weapons[p[1]] or nil
 if (mode=="fight" or mode=="hunt") and secondary
   and secondary.projectile~=nil and affordable(player,secondary)
   and distance>math.max(145,(primary.range or 65)+40) then
   return secondary.id
 end
 -- Combatants can use the secondary shield or heavy hammer when
 -- appropriate; gatherers always return to their gathering implement.
 if mode=="fight" and secondary and secondary.dmg
   and not secondary.projectile and secondary.dmg>primary.dmg
   and distance<(secondary.range or 65)+45 then
   return secondary.id
 end
 return primary.id
end
function Loadout.attackRange(weapon,catalogue)
 if not weapon then return 70 end
 if weapon.projectile~=nil then
  local proj=(catalogue or Catalogue).projectiles[weapon.projectile]
  return math.min((proj and proj.range or 700),1000)
 end
 return weapon.range or 70
end
return Loadout
