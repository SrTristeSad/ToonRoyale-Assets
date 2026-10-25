-- SPDX-License-Identifier: AGPL-3.0-only
-- AccountStore.issueToken / verifyToken from server/src/api/store.js.
-- HS256 is the original JWT wire format; no alternate authentication protocol.
local Json=require("server-lua.vendor.dkjson")
local Sha=require("server-lua.protocol.sha256")
local Crypto=require("src.protocol.original_crypto")
local Token={}
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local inverse={}
for i=1,#alphabet do inverse[alphabet:sub(i,i)]=i-1 end
local function b64(raw)
 local chunks={}
 for i=1,#raw,3 do
  local a,b,c=raw:byte(i,i+2)
  local v=a*65536+(b or 0)*256+(c or 0)
  chunks[#chunks+1]=alphabet:sub(math.floor(v/262144)+1,math.floor(v/262144)+1)
  chunks[#chunks+1]=alphabet:sub(math.floor(v/4096)%64+1,math.floor(v/4096)%64+1)
  if b then chunks[#chunks+1]=alphabet:sub(math.floor(v/64)%64+1,math.floor(v/64)%64+1) end
  if c then chunks[#chunks+1]=alphabet:sub(v%64+1,v%64+1) end
 end
 return table.concat(chunks)
end
local function unb64(str)
 if type(str)~="string" or #str%4==1 then return nil end
 local result={}
 local bits=0
 local value=0
 for i=1,#str do
  local n=inverse[str:sub(i,i)]
  if not n then return nil end
  value=value*64+n
  bits=bits+6
  if bits>=8 then
   bits=bits-8
   result[#result+1]=string.char(math.floor(value/2^bits)%256)
   value=value%2^bits
  end
 end
 return table.concat(result)
end
local function signature(secret,input)
 assert(type(secret)=="string" and #secret>=16,
  "original secret.key HMAC secret required")
 return Crypto.hmacSha256(secret,input,Sha.digest)
end
local function equal(a,b)
 if type(a)~="string" or type(b)~="string" or #a~=#b then return false end
 local diff=0
 for i=1,#a do diff=Crypto.bor(diff,Crypto.bxor(a:byte(i),b:byte(i))) end
 return diff==0
end
local HEADER=b64('{"alg":"HS256","typ":"JWT"}')
function Token.issue(store,account,opts)
 assert(type(account)=="table" and type(account.id)=="string",
  "authenticated account required")
 opts=opts or {}
 local ttl=opts.ttlSeconds or 60*60*24*30
 assert(type(ttl)=="number" and ttl%1==0 and ttl>=60 and ttl<=2592000,
  "Duracao do token invalida")
 local now=math.floor(store.nowMs()/1000)
 -- Preserve the original JSON.stringify property order for identical JWT bytes.
 local payload='{'
 if store.passwordMode then payload=payload..'"secureAuth":1,' end
 payload=payload..'"sub":'..Json.encode(account.id)..
  ',"iat":'..now..',"exp":'..(now+ttl)..
  ',"extra":{"verified":true'
 if account.email~=nil and account.email~=Json.null then
  payload=payload..',"identifier":'..Json.encode(account.email)
 end
 payload=payload..'}}'
 local signed=HEADER.."."..b64(payload)
 return signed.."."..b64(signature(store.secret,signed))
end
function Token.verify(store,token)
 if type(token)~="string" then return nil end
 local header,payload,sig=token:match("^([^.]+)%.([^.]+)%.([^.]+)$")
 if not header then return nil end
 local given=unb64(sig)
 if not given or not equal(given,signature(store.secret,header.."."..payload)) then
  return nil
 end
 local decoded=unb64(payload)
 if not decoded then return nil end
 local obj,_,err=Json.decode(decoded,1,Json.null)
 if err or type(obj)~="table" then return nil end
 local exp=obj.exp
 if type(exp)=="number" and exp~=0 and exp*1000<store.nowMs() then
  return nil
 end
 if store.passwordMode and obj.secureAuth~=1 then return nil end
 local id=obj.sub
 if id==nil or id==Json.null then return nil end
 id=tostring(id)
 local index=store.data and store.data.legacyIds or {}
 local resolved=index[id] or id
 return store.data.accounts[resolved]
end
Token.b64=b64
Token.unb64=unb64
return Token
