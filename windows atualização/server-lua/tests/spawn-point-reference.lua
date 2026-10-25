-- Exact Lua ObjectManager.fetchSpawnObj behavior against the original Node function.
local World=require("server-lua.world.objects")
local events={}
local owner={sid=7}
function owner:changeItemCount(group,delta)
 events[#events+1]="count:"..group..":"..delta
end
local points={
 {sid=91,x=513,y=726,active=true,owner=owner,spawnPoint=true,group={id=42}},
 {sid=92,x=600,y=800,active=true,owner=owner,spawnPoint=true,group={id=42}},
 {sid=93,x=700,y=900,active=true,owner={sid=8},spawnPoint=true,group={id=42}}
}
local world=setmetatable({objects=points},World)
function world:disableObject(point)
 point.active=false
 events[#events+1]="disable:"..point.sid
end
local function broadcast(name,sid)
 events[#events+1]=name..":"..sid
end
for i=0,3 do
 local pos=world:fetchSpawnObj(7,{broadcast=broadcast})
 local status={}
 for _,point in ipairs(points) do status[#status+1]=tostring(point.active)end
 print("SPAWN_"..i.."|"..(pos and table.concat(pos,",") or "null").."|"..
  table.concat(events,",").."|"..table.concat(status,","))
end
