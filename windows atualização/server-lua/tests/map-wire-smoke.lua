-- Insertion of local-only j cannot permute any classic packet, in either
-- legacy or pinned HMAC / masked sessions.
local Client=require("src.protocol.original_session")
local Server=require("server-lua.protocol.session")
local Crypto=require("src.protocol.original_crypto")
local Digest=require("server-lua.protocol.sha256")
local raw="0123456789ABCDEF"
local hex=raw:gsub(".",function(c)return string.format("%02x",c:byte())end)
local hash=Digest.digest
local build={buildId="mappin",salt=230319,constants={1,2,3,4,5,6,7,8},
 rounds=4,tapA=1,tapB=2,rotA=7,rotB=11,mult=3}
for _,pinned in ipairs({false,true}) do
 local seed=123456789
 local server=Server.new({pinned=pinned,seed=seed,rawKey=raw,
  build=pinned and build or nil,sha256=hash})
 local client=assert(Client.new({mode=1,pinned=pinned,seed=seed,
  rawKeyHex=hex,sealMode=0},pinned and build or nil,hash))
 local classic=Crypto.buildTables(seed,pinned and build.salt or nil)
 for _,name in ipairs({"M","D","9","F","T","Y"}) do
  assert(server.tables.c2s.enc[name]==classic.c2s.enc[name])
  assert(client.tables.c2s.enc[name]==classic.c2s.enc[name])
 end
 for _,name in ipairs({"A","C","D","a","H","I","Y","Z"}) do
  assert(server.tables.s2c.enc[name]==classic.s2c.enc[name])
  assert(client.tables.s2c.enc[name]==classic.s2c.enc[name])
 end
 assert(not classic.c2s.enc.j and not classic.s2c.enc.j)
 assert(server.tables.c2s.enc.j==client.tables.c2s.enc.j)
 assert(server.tables.s2c.enc.j==client.tables.s2c.enc.j)
 local decoded=assert(server:decode(assert(client:encode("j",{}))))
 assert(decoded.name=="j" and #decoded.args==0)
 local reply=assert(client:decode(assert(server:encode("j",{
  "cabana",600,900,{id="cabana",type="interior",width=1200,height=1200,obstacles={},portals={}}
 }))))
 assert(reply.name=="j" and reply.args[1]=="cabana" and reply.args[2]==600)
 local original=assert(server:decode(assert(client:encode("9",{1.2}))))
 assert(original.name=="9" and original.args[1]==1.2)
end
print("PASS map wire: HMAC, pinned masks, custom world packet and original IDs unchanged")
