-- Differential against ORIGINAL LOCAL Node routes.js auth/password handler.
local Json=require("server-lua.vendor.dkjson")
local API=require("server-lua.net.local_api")
local account={id="local",email="login@example.com"}
local store={
 accountForEmail=function(_,email)
  if email=="login@example.com" then return account end
  return Json.null
 end,
 issueToken=function()return "test-token"end,
 issueTicket=function()return {ticket="unused"}end,
 consumeTicket=function()return Json.null end,
 verifyToken=function()return account end
}
local api=API.new({store=store,moderation={
 banEntry=function()return nil end,
 lockedFor=function()return 0 end},
 roomCode="testing42",servers=function()return {} end})
local function arr()return setmetatable({},{__jsontype="array"})end
local function obj()return setmetatable({},{__jsontype="object"})end
local cases={
 {"empty",""},{"false",false},{"zero",0},
 {"null",Json.null},{"empty-array",arr()},
 {"nonempty","x"},{"one",1},{"true",true},
 {"object",obj()},{"empty-email","x"}
}
for _,case in ipairs(cases) do
 local label,password=case[1],case[2]
 local email=label=="empty-email" and "" or account.email
 local status,response=api:handle("POST","/api/auth/password",{},
  assert(Json.encode({email=email,password=password})),"127.0.0.1")
 print(label.."|"..status.."|"..
  tostring(response.type or response.email or "").."|"..
  tostring(response.token or ""))
end
