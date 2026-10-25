-- SPDX-License-Identifier: AGPL-3.0-only
-- Real file load triggers the same ID migration as AccountStore.constructor.
local Json=require("server-lua.vendor.dkjson")
local Store=require("server-lua.world.account_store")
local path="server-lua/tests/.legacy-migration-smoke.json"
local old="abcdef0123456789"
local initial={
 accounts={[old]={id=old,name="Legacy",createdAt=1792864800000}},
 emails={["legacy@example.com"]=old},names={legacy=old},
 clans={LEG={name="LEG",members={{id=old}},past={},invites={},
   requests={old},stats={kills=0,periods={}}}},
 social={friends={[old]={{id=old}}},requests={{senderId=old,recipientId=old}}},
 legacyIds={}
}
local f=assert(io.open(path,"wb"))
assert(f:write(Json.encode(initial)))
assert(f:close())
local function cleanup()
 os.remove(path);os.remove(path..".lua-backup");os.remove(path..".lua-new")
end
local ok,err=pcall(function()
 local options={nowMs=function()return 1792864800000 end,
   randomBytes=function(n)return string.rep("a",n) end}
 local one=Store.open(path,options)
 local new=assert(one.migratedIds[old])
 assert(#new==24 and new:sub(-16)==old)
 assert(one:accountById(old)==one.data.accounts[new])
 assert(one.data.clans.LEG.members[1].id==new)
 assert(one.data.clans.LEG.requests[1]==new)
 assert(one.data.social.friends[new][1].id==new)
 assert(one.data.social.requests[1].recipientId==new)
 local two=Store.open(path,options)
 assert(next(two.migratedIds)==nil,"reopening must not remigrate modern IDs")
 assert(two.data.legacyIds[old]==new)
 assert(two.data.accounts[new].id==new)
end)
cleanup()
assert(ok,err)
print("PASS migracao real accounts.json: referencias, reload e idempotencia")
