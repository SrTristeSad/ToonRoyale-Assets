local Store=require("server-lua.world.account_store")
local API=require("server-lua.net.local_api")
local Json=require("server-lua.vendor.dkjson")
local path="server-lua/tests/.social-api-check.json"
local id=0
local function bytes(n)id=id+1;return string.rep(string.char(64+(id%20)+1),n)end
local store=Store.open(path,{nowMs=function()return 1792864800000 end,
 randomBytes=bytes,secret=string.rep("K",32)})
local a=store:accountForEmail("a@example.com")
local b=store:accountForEmail("b@example.com")
assert(a.id~=b.id)
local ta=store:issueToken(a)
local tb=store:issueToken(b)
local mod={banEntry=function()return nil end,lockedFor=function()return 0 end}
local api=API.new({store=store,moderation=mod,roomCode="testing42",
 servers=function()return {}end})
local function call(method,route,token,body)
 return api:handle(method,route,
 {authorization=token and ("Bearer "..token) or ""},
 body and Json.encode(body) or "","127.0.0.1")
end
local base="/api/social/friends/"
local status,body=call("GET",base..a.id,nil)
assert(status==401)
status,body=call("GET",base..b.id,ta)
assert(status==403)
status,body=call("POST",base..a.id.."/requests",ta,{recipientId=b.id})
assert(status==201 and body.senderId==a.id)
local requestId=body.id
status,body=call("GET",base..b.id.."/requests",tb)
assert(status==200 and #body==1 and body[1].id==requestId)
status,body=call("POST",base..b.id.."/requests/"..requestId,tb,{accept=true})
assert(status==200 and body.accepted==true)
status,body=call("GET",base..a.id,ta)
assert(status==200 and body[1].id==b.id)
status,body=call("DELETE",base..a.id,ta,{friendId=b.id})
assert(status==204)
status,body=call("GET",base..a.id,ta)
assert(status==200 and #body==0)
for _,ext in ipairs({"",".lua-new",".lua-backup"}) do os.remove(path..ext)end
print("PASS LOCAL social HTTP Bearer, requests, accept, friend and remove")
