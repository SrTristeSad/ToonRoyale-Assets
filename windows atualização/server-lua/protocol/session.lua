-- SPDX-License-Identifier: AGPL-3.0-only
-- Server half of Moo-IO's existing keyed MessagePack protocol.
-- This module is a Lua port of server/src/protocol/session.js, not a new wire protocol.
local Crypto=require("src.protocol.original_crypto")
local Pack=require("src.protocol.msgpack")
local Random=require("src.net.secure_random")
local MapWire=require("src.protocol.map_wire")
local Session={}
Session.__index=Session
local function hex(raw)
  return (raw:gsub(".",function(c) return string.format("%02x",c:byte()) end))
end
local function equalConstantTime(a,b)
  if #a~=#b then return false end
  local diff=0
  for i=1,#a do diff=Crypto.bor(diff,Crypto.bxor(a:byte(i),b:byte(i))) end
  return diff==0
end
local function packArgs(args)
  assert(type(args)=="table","packet args required")
  assert(#args<=16,"packet payload exceeds 16 entries")
  return args
end
local function numberIsInteger(v)
  return type(v)=="number" and v==math.floor(v)
end
local function u32LE(raw)
  return Crypto.readU32LE(raw,0)
end
-- opts: {build={buildId,salt,constants,rounds,tapA,tapB,rotA,rotB,mult},
--        seed?,rawKey?,socketId?, sha256?, pinned?, seal?={mode,value}}
-- Unspecified random values are generated with cryptographic OS entropy.
function Session.new(opts)
  opts=opts or {}
  local pinned=opts.pinned~=false
  local build=opts.build
  if pinned then assert(build and build.salt and build.constants,"pinned build required") end
  local raw=opts.rawKey or Random.bytes(16)
  assert(type(raw)=="string" and #raw==16,"rawKey must be 16 bytes")
  local socketId=opts.socketId or hex(Random.bytes(8))
  assert(type(socketId)=="string" and socketId:match("^[0-9a-fA-F]+$") and #socketId==16,"invalid socket id")
  local seed=opts.seed
  if seed==nil then seed=u32LE(Random.bytes(4)) end
  assert(numberIsInteger(seed) and seed>=0 and seed<=4294967295,"invalid seed")
  local sha256=opts.sha256 or function(data)
    if love and love.data then return love.data.hash("sha256",data) end
    return require("server-lua.protocol.sha256").digest(data)
  end
  local seal=opts.seal
  local sealMode=pinned and seal and seal.value and seal.mode or 0
  assert(sealMode==0 or sealMode==1 or sealMode==2,"invalid sealMode")
  local key=pinned and Crypto.mixKey(raw,seed,build) or raw
  if sealMode==2 then
    assert(type(seal.value)=="string" and #seal.value==16,"invalid browser seal")
    local bytes={}
    for i=1,#key do
      bytes[i]=string.char(i<=#seal.value and Crypto.bxor(key:byte(i),seal.value:byte(i)) or key:byte(i))
    end
    key=table.concat(bytes)
  end
  local tables=Crypto.buildTables(seed,pinned and build.salt or nil)
  MapWire.install(tables)
  local self=setmetatable({
    socketId=socketId,rawKey=raw,seed=seed,pinned=pinned,
    sealMode=sealMode,key=key,sha256=sha256,
    sealReport=nil,
    tables=tables,
    mask=pinned and Crypto.deriveMasks(key) or nil,
    lastSeq=0,sent=0,
    ledger=pinned and 2166136261 or 0,
    ledgerBefore=pinned and 2166136261 or 0
  },Session)
  return self
end
function Session:handshakeFrame()
  return Pack.encode({"io-init",{self.socketId,self.seed,hex(self.rawKey),1,self.pinned and 1 or 0,self.sealMode}})
end
function Session:canSend(name)
  return self.tables.s2c.enc[name]~=nil
end
function Session:encode(name,args)
  local id=self.tables.s2c.enc[name]
  if id==nil then return nil,"unknown packet "..tostring(name) end
  local body=Pack.encode({id,packArgs(args)})
  self.sent=self.sent+1
  if self.mask then body=Crypto.mask(body,Crypto.serverMaskSeed(self.mask.s2c,self.sent)) end
  return body
end
function Session:decode(frame)
  if type(frame)~="string" or #frame<=6 then return nil,"short frame" end
  local tag,body=frame:sub(1,6),frame:sub(7)
  if self.mask then body=Crypto.mask(body,Crypto.clientMaskSeed(self.mask.c2s,tag)) end
  local expected=Crypto.hmacSha256(self.key,body,self.sha256):sub(1,6)
  if not equalConstantTime(tag,expected) then return nil,"bad tag" end
  local ok,message=pcall(Pack.decode,body)
  if not ok or type(message)~="table" or #message~=3 then return nil,"malformed body" end
  local id,args,seq=message[1],message[2],message[3]
  if not numberIsInteger(seq) or seq~=self.lastSeq+1 then return nil,"bad sequence" end
  -- The JS reference advances the sequence even for an unknown id or bad args.
  self.lastSeq=seq
  local name=numberIsInteger(id) and self.tables.c2s.dec[id] or nil
  if not name then return nil,"unknown packet id" end
  if type(args)~="table" or args==Pack.null then return nil,"bad arguments" end
  -- Reject MessagePack maps in the arguments slot (Node requires Array.isArray).
  for k in pairs(args) do if type(k)~="number" or k<1 or k%1~=0 or k>#args then return nil,"bad arguments" end end
  if self.pinned then
    self.ledgerBefore=self.ledger
    self.ledger=Crypto.fnvLedger(self.ledger,body)
  end
  return {name=name,args=args,seq=seq}
end
return Session
