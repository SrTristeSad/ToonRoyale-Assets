-- Node created protocol-build.json is reused across LOCAL Lua restarts.
local Json=require("server-lua.vendor.dkjson")
local Build=require("server-lua.protocol.build")
local path="server-lua/tests/.protocol-pin-smoke.json"
local original={buildId="pinned12xx",salt=123456,
 constants={1,2,3,4,5,6,7,8},rounds=5,
 tapA=1,tapB=3,rotA=9,rotB=17,mult=733335361,
 modulePath="pinned",sealHex=string.rep("a",32),createdAt=1792864800000}
local f=assert(io.open(path,"wb"))
assert(f:write(assert(Json.encode(original))))
assert(f:close())
local ok,err=pcall(function()
 local a=Build.open(path)
 assert(a.buildId==original.buildId and a.salt==original.salt)
 assert(a.modulePath==original.modulePath and a.sealHex==original.sealHex)
 assert(a.constants[8]==8 and a.createdAt==1792864800000)
 local reread=assert(io.open(path,"rb"))
 local raw=reread:read("*a");reread:close()
 assert(raw==assert(Json.encode(original)),
   "pinned Node build must not be rewritten")
 os.remove(path)
 local fresh=Build.open(path,{nowMs=function()return 1792864800000 end})
 assert(#fresh.buildId==10 and #fresh.constants==8)
 assert(#fresh.modulePath==6 and #fresh.sealHex==32)
 assert(fresh.createdAt==1792864800000)
 local reopened=Build.open(path)
 assert(reopened.buildId==fresh.buildId and reopened.salt==fresh.salt)
 assert(reopened.sealHex==fresh.sealHex)
 assert(reopened.mult==fresh.mult and reopened.tapA==fresh.tapA)
end)
os.remove(path)
assert(ok,err)
print("PASS LOCAL protocolo Node pin persistente, build Lua e reinicio")
