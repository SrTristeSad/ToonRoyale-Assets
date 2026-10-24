local Json=require("server-lua.vendor.dkjson")
local Store=require("server-lua.world.account_store")
local API=require("server-lua.net.local_api")
local path="server-lua/tests/.api-local-test.json"
local ms=1792864800000
local store=Store.open(path,{nowMs=function()return ms end,
 secret=string.rep("K",32),randomBytes=function(n)return string.rep("a",n)end})
local moderation={banEntry=function()return nil end,lockedFor=function()return 0 end}
local api=API.new({store=store,moderation=moderation,roomCode="testing42",
 servers=function()return {{key="LC"},{key="MB"}}end,nowMs=function()return ms end})
local function send(method,route,body,headers)
 return api:handle(method,route,headers or {},body and Json.encode(body) or "",
  "127.0.0.1")
end
local code,a=send("POST","/api/auth/code",{email="Tester@Example.com"})
assert(code==200 and #a.flow==24)
local flow=a.flow
code,a=send("POST","/api/auth/verify",{code="123456",flow=flow})
assert(code==200 and a.email=="tester@example.com")
local token=a.token
code,a=send("POST","/api/name",{auth=token,name="PlayerOne"})
assert(code==200 and a.name=="PlayerOne")
code,a=send("GET","/api/name-check?name=playerone")
assert(code==200 and a.reserved==true)
code,a=send("POST","/api/join",{auth=token,host="localhost/s/LC",captcha=true},
 {["x-mooio-code"]="testing42"})
assert(code==200 and a.ticket and a.did)
local ticket=store:consumeTicket(a.ticket,45000)
assert(ticket.account.name=="PlayerOne" and ticket.server=="LC")
assert(store:consumeTicket(a.ticket,45000)==Json.null)
code,a=send("POST","/api/join",{host="localhost/s/LC"},
 {["x-mooio-code"]="wrong"})
assert(code==403 and a.error=="invite_required")
code,a=send("GET","/api/servers")
assert(code==200 and #a==2)
code,a=send("GET","/api/top")
assert(code==200 and #a.players==0 and #a.clans==0)
assert(getmetatable(a.players).__jsontype=="array")
os.remove(path);os.remove(path..".lua-backup")
os.remove(path..".lua-new")
print("PASS API LOCAL AccountStore: login, conta, convite, ticket one-use")
