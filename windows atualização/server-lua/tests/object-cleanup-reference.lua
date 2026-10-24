local World=require("server-lua.world.objects")
local records={
 {sid=10,active=true,owner={sid=4}},
 {sid=11,active=true,owner={sid=4}},
 {sid=12,active=false,owner={sid=4}},
 {sid=13,active=true,owner={sid=5}},
 {sid=14,active=true,owner=nil}
}
local emitted={}
local world=setmetatable({objects=records},World)
function world:disableObject(obj)
 obj.active=false
 emitted[#emitted+1]="off:"..obj.sid
end
local function broadcast(name,sid)
 emitted[#emitted+1]=name..":"..sid
end
world:removeAllItems(4,{broadcast=broadcast})
world:removeAllItems(4,{broadcast=broadcast})
print("CLEANUP|"..table.concat(emitted,","))
local alive={}
for _,obj in ipairs(records) do
 if obj.active then alive[#alive+1]=obj.sid end
end
print("REMAIN|"..table.concat(alive,","))
