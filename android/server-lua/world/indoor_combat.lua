-- Local Lua custom-map combat: reuse real weapon stats, player variants,
-- Gathering's damage/shields/status effects and the normal Player callbacks.
-- No surface resources or buildings are ever hit from an interior.
local Gather=require("server-lua.world.gather")
local Combat={}
local function truthy(v)return v~=nil and v~=false and v~=0 end
function Combat.melee(player)
 local room=assert(player.room,"real room required")
 local zone=assert(room.mapSpaces and room.mapSpaces:get(player.spaceId),
   "interior combat requires an authoritative zone")
 local weapon=assert(room.items.weapons[player.weaponIndex],"weapon required")
 local variant=assert(player:variant(),"weapon variant required")
 player.noMovTimer=0
 player.slowMult=math.max(0,player.slowMult-
   ((weapon.hitSlow==nil or weapon.hitSlow==0) and 0.3 or weapon.hitSlow))
 local hit=false
 local function targetActor(target)
  if target==player or not target.alive or not target.active
     or (target.spaceId or "surface")~=player.spaceId
     or truthy(target.submerged)
     or (truthy(target.team) and target.team==player.team) then return end
  -- Actors behind an interior wall cannot be hit even when in weapon range.
  if room.mapSpaces:lineBlocked(player.spaceId,player.x,player.y,target.x,target.y) then return end
  local applied=Gather.hitActor(player,target,weapon,variant,
    variant.poison,room.items.weapons,room.config,{nowMs=room.nowMs})
  if applied then hit=true end
 end
 for _,target in ipairs(room.players) do targetActor(target) end
 for _,target in ipairs(room.ais) do targetActor(target) end
 player:sendAnimation(hit and 1 or 0)
 return hit
end
return Combat
