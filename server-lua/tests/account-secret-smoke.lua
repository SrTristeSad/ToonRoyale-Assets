-- Integration: original secret.key survives AccountStore reopening.
local Store=require("server-lua.world.account_store")
local dir="server-lua/tests/.jwt-secret-smoke"
assert(os.execute("mkdir -p "..dir))
local path=dir.."/accounts.json"
local secretFile=dir.."/secret.key"
os.remove(secretFile)
local account={id="0123456789abcdef01234567",email="user@example.com"}
local cfg={nowMs=function()return 1792864800000 end,
 randomBytes=function(n)return string.rep("K",n) end}
local ok,err=pcall(function()
 local store=Store.open(path,cfg)
 store.data.accounts[account.id]=account
 local token=store:issueToken(account,{ttlSeconds=3600})
 local f=assert(io.open(secretFile,"rb"))
 local raw=f:read("*a")
 assert(f:close())
 assert(raw==string.rep("4b",32),"secret.key must use original 64-char hex")
 assert(store:verifyToken(token)==account)
 local store2=Store.open(path,{nowMs=cfg.nowMs})
 store2.data.accounts[account.id]=account
 assert(store2:verifyToken(token)==account,
  "restarted Lua AccountStore must honor persisted secret.key")
 assert(store2:issueToken(account,{ttlSeconds=3600})==token,
  "same secret and clock must produce original token")
end)
os.remove(secretFile);os.remove(path);os.remove(path..".lua-backup")
os.execute("rmdir "..dir)
assert(ok,err)
print("PASS secret.key original: salvamento, recarga, verificacao e token identico")
