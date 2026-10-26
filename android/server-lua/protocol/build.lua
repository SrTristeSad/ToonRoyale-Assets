-- SPDX-License-Identifier: AGPL-3.0-only
-- Random protocol build compatible with Node server/src/protocol/build.js.
-- Never derive protocol secrets from math.random.
local Random=require("src.net.secure_random")
local C=require("src.protocol.original_crypto")
local M={}
local function u32() return C.readU32LE(Random.bytes(4),0) end
local function range(low,high) return low+u32()%(high-low+1) end
function M.new()
  local letters="abcdefghijklmnopqrstuvwxyz0123456789"
  local bytes=Random.bytes(10)
  local id={}
  for i=1,#bytes do local x=bytes:byte(i)%#letters+1;id[i]=letters:sub(x,x) end
  local constants={}
  for i=1,8 do constants[i]=u32() end
  local tapA=range(1,7)
  local tapB=range(1,7)
  while tapA==tapB do tapB=range(1,7) end
  return {
    buildId=table.concat(id),salt=u32(),constants=constants,
    rounds=range(4,8),tapA=tapA,tapB=tapB,
    rotA=range(5,27),rotB=range(5,27),mult=C.bor(u32(),1)
  }
end

-- LOCAL Node createProtocolBuild pins parameters in protocol-build.json.
-- Reuse an already generated Node pin without changing its build identity.
local Json=require("server-lua.vendor.dkjson")
local function pinValid(p)
 if type(p)~="table" or type(p.buildId)~="string" or
  type(p.salt)~="number" or type(p.constants)~="table" or
  #p.constants~=8 or type(p.rounds)~="number" then return false end
 for _,key in ipairs({"tapA","tapB","rotA","rotB","mult"}) do
  if type(p[key])~="number" then return false end
 end
 return true
end
function M.open(path,opts)
 opts=opts or {}
 assert(type(path)=="string" and #path>0,"original protocol-build.json path required")
 if not opts.rotate then
  local f=io.open(path,"rb")
  if f then
   local raw=f:read("*a");f:close()
   local p,_,err=Json.decode(raw,1,Json.null)
   assert(not err and pinValid(p),"invalid original protocol-build.json")
   return p
  end
 end
 local p=M.new()
 local random=Random.bytes
 local function hex(data)
  return data:gsub(".",function(c)return string.format("%02x",c:byte()) end)
 end
 local alphabet="abcdefghijklmnopqrstuvwxyz0123456789"
 local id={}
 for i=1,6 do
  local byte=random(1):byte()
  local k=byte%#alphabet+1
  id[i]=alphabet:sub(k,k)
 end
 p.modulePath=table.concat(id)
 p.sealHex=hex(random(16))
 p.createdAt=opts.nowMs and opts.nowMs() or os.time()*1000
 local encoded,err=Json.encode(p,{indent=true})
 assert(encoded,err)
 local f,why=io.open(path,"wb")
 assert(f,why);assert(f:write(encoded));assert(f:close())
 return p
end

return M
