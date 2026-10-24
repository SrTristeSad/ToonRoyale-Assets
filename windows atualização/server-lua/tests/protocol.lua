-- SPDX-License-Identifier: AGPL-3.0-only
-- Run at the Windows project root: lua5.4 server-lua/tests/protocol.lua [reference-fixtures]
local function fail(why) error(why,2) end
local function eq(actual,expected,label)
  if actual~=expected then fail((label or "mismatch")..": expected "..tostring(expected)..", got "..tostring(actual)) end
end
local function hex(raw) return (raw:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local SHA=require("server-lua.protocol.sha256")
local MP=require("src.protocol.msgpack")
local Crypto=require("src.protocol.original_crypto")
local Bootstrap=require("src.protocol.bootstrap")
local Client=require("src.protocol.original_session")
local Server=require("server-lua.protocol.session")
local Constants=require("src.protocol.constants")
local fixtures={}
if arg and arg[1] then
  local f=assert(io.open(arg[1],"rb"))
  for l in f:lines() do local k,v=l:match("^([^=]+)=(.+)$");if k then fixtures[k]=v end end
  f:close()
end
eq(hex(SHA.digest("")),"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","SHA256 empty")
eq(hex(SHA.digest("abc")),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","SHA256 abc")
eq(hex(Crypto.hmacSha256(string.rep(string.char(11),20),"Hi There",SHA.digest)),
   "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7","HMAC SHA256")
local seed,salt=0x10203040,0x12345678
local raw=Crypto.hexToBinary("000102030405060708090a0b0c0d0e0f")
local build={buildId="testbuild01",salt=salt,constants={
  111,222,333,444,555,666,777,888
},rounds=6,tapA=2,tapB=5,rotA=9,rotB=17,mult=733335361}
local masks=Crypto.deriveMasks(raw)
if fixtures.maskc2s then
  eq(masks.c2s,tonumber(fixtures.maskc2s),"JS mask.c2s")
  eq(masks.s2c,tonumber(fixtures.masks2c),"JS mask.s2c")
  eq(hex(Crypto.hmacSha256(raw,"lua-server-parity-v1",SHA.digest):sub(1,6)),fixtures.tag,"JS HMAC tag")
  eq(Crypto.fnvLedger(2166136261,"lua-server-parity-v1"),tonumber(fixtures.ledger),"JS ledger")
  eq(hex(Crypto.mask(Crypto.hexToBinary("0102030405060708"),0xaabbccdd)),fixtures.xor,"JS XOR stream")
  local tables=Crypto.buildTables(seed,salt)
  for _,name in ipairs(Constants.c2sList) do eq(tables.c2s.enc[name],tonumber(fixtures["c2s."..name]),"JS c2s "..name) end
  for _,name in ipairs(Constants.s2cList) do eq(tables.s2c.enc[name],tonumber(fixtures["s2c."..name]),"JS s2c "..name) end
end
local server=Server.new({build=build,seed=seed,rawKey=raw,socketId="0123456789abcdef",sha256=SHA.digest})
local handshake,err=Bootstrap.decodeHandshake(server:handshakeFrame())
assert(handshake,err)
eq(handshake.socketId,"0123456789abcdef","socket id")
eq(handshake.seed,seed,"seed")
eq(handshake.pinned,true,"pinned")
eq(handshake.sealMode,0,"seal disabled")
local client=assert(Client.new(handshake,build,SHA.digest))
local a=assert(client:encode("M",{MP.map({name="Player",moofoll=false,skin=2,anon=false})}))
local packet,decodeErr=server:decode(a)
assert(packet,decodeErr)
eq(packet.name,"M","spawn name")
eq(packet.args[1].name,"Player","spawn player")
eq(packet.seq,1,"first sequence")
eq(server.ledgerBefore,2166136261,"ledger before first")
eq(server.ledger,client.ledger,"ledger value")
local reply=assert(server:encode("C",{7}))
local inbound,replyErr=client:decode(reply)
assert(inbound,replyErr)
eq(inbound.name,"C","spawn confirmation")
eq(inbound.args[1],7,"player SID")
local movement=assert(client:encode("9",{math.pi/3}))
local move=assert(server:decode(movement))
eq(move.name,"9","movement id")
eq(move.seq,2,"second sequence")
local replay,why=server:decode(movement)
eq(replay,nil,"replay rejected")
eq(why,"bad sequence","replay reason")
local corrupted=string.char((a:byte(1)+1)%256)..a:sub(2)
local bad,badReason=server:decode(corrupted)
eq(bad,nil,"tamper rejected")
eq(badReason,"bad tag","tamper reason")
local pong=assert(server:encode("0",{}))
local pongMessage=assert(client:decode(pong))
eq(pongMessage.name,"0","pong")
-- Legacy unpinned table must also agree with the client.
local old=Server.new({pinned=false,seed=seed,rawKey=raw,socketId="fedcba9876543210",sha256=SHA.digest})
local oldHandshake=assert(Bootstrap.decodeHandshake(old:handshakeFrame()))
local oldClient=assert(Client.new(oldHandshake,nil,SHA.digest))
local oldMsg=assert(oldClient:encode("0",{}))
eq(assert(old:decode(oldMsg)).name,"0","legacy heartbeat")
eq(assert(oldClient:decode(assert(old:encode("0",{})))).name,"0","legacy pong")
print("OK: SHA256 / HMAC / JS fixtures / packet IDs / handshake / client-server / replay / tamper / legacy")
