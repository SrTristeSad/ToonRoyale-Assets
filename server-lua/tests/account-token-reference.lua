-- Same JWT cases as Node AccountStore.issueToken/verifyToken.
local Store=require("server-lua.world.account_store")
local Json=require("server-lua.vendor.dkjson")
local now=1792864800000
local account={id="0123456789abcdef01234567",email="user@example.com"}
local store=Store.open("server-lua/tests/.does-not-exist.json",{
 nowMs=function()return now end,secret=string.rep("K",32)})
store.data={accounts={[account.id]=account},legacyIds={}}
local token=store:issueToken(account,{ttlSeconds=3600})
print("JWT|"..token)
print("ACCEPT|"..tostring(store:verifyToken(token)==account))
print("REJECT_TAMPER|"..tostring(store:verifyToken(token:sub(1,-2).."*")==nil))
store.passwordMode=true
print("REJECT_INSECURE|"..tostring(store:verifyToken(token)==nil))
local secure=store:issueToken(account,{ttlSeconds=3600})
print("SECURE_JWT|"..secure)
print("ACCEPT_SECURE|"..tostring(store:verifyToken(secure)==account))
local ok=pcall(function()store:issueToken(account,{ttlSeconds=59})end)
print("REJECT_TTL|"..tostring(not ok))
now=1792868400001
print("EXPIRED|"..tostring(store:verifyToken(secure)==nil))
