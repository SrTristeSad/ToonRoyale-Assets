-- SPDX-License-Identifier: AGPL-3.0-only
-- RFC6455 frames for an embedded LuaSocket server. Client packets are masked;
-- server packets are unmasked. Does NOT implement the gameplay dispatcher.
local Crypto=require("src.protocol.original_crypto")
local SHA1=require("server-lua.net.sha1")
local M={}
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(s)
  local out={}
  for p=1,#s,3 do
    local a,b,c=s:byte(p,p+2)
    local n=a*65536+(b or 0)*256+(c or 0)
    local i=math.floor(n/262144)%64+1
    local j=math.floor(n/4096)%64+1
    local k=math.floor(n/64)%64+1
    local l=n%64+1
    out[#out+1]=alphabet:sub(i,i)..alphabet:sub(j,j)..
      (b and alphabet:sub(k,k) or "=")..(c and alphabet:sub(l,l) or "=")
  end
  return table.concat(out)
end
local function keyValid(key)
  return type(key)=="string" and #key==24 and key:match("^[A-Za-z0-9+/]+==$")~=nil
end
function M.acceptKey(key)
  if not keyValid(key) then return nil,"invalid websocket key" end
  local msg=key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  local digest
  if love and love.data and love.data.hash then digest=love.data.hash("sha1",msg)
  else digest=SHA1.digest(msg) end
  return base64(digest)
end
function M.encode(payload,opcode)
  assert(type(payload)=="string" and #payload<=16384,"bad frame payload")
  opcode=opcode or 2
  assert(opcode==2 or opcode==8 or opcode==9 or opcode==10,"bad server opcode")
  local length=#payload
  if length<126 then return string.char(128+opcode,length)..payload end
  return string.char(128+opcode,126,math.floor(length/256),length%256)..payload
end
-- A parser can be called with a partial TCP receive buffer.
-- Returns a frame {opcode,payload}, leftover bytes; or nil, original buffer on
-- incomplete input; or nil, nil, error for protocol violations.
function M.decode(buf)
  if type(buf)~="string" then return nil,nil,"not a string" end
  if #buf<2 then return nil,buf end
  local h,len=buf:byte(1,2)
  if h<128 or h%16~=2 and h%16~=8 and h%16~=9 and h%16~=10 then
    return nil,nil,"fragmented or unsupported websocket frame"
  end
  if len<128 then return nil,nil,"unmasked client frame" end
  local size=len%128
  local offset=3
  if size==126 then
    if #buf<4 then return nil,buf end
    size=buf:byte(3)*256+buf:byte(4);offset=5
  elseif size==127 then
    return nil,nil,"websocket payload too large"
  end
  if size>16384 then return nil,nil,"websocket payload too large" end
  if #buf<offset+4+size-1 then return nil,buf end
  local mask=buf:sub(offset,offset+3)
  local payload=buf:sub(offset+4,offset+3+size)
  local unmasked={}
  for i=1,#payload do
    unmasked[i]=string.char(Crypto.bxor(payload:byte(i),mask:byte((i-1)%4+1)))
  end
  return {opcode=h%16,payload=table.concat(unmasked)},buf:sub(offset+4+size)
end
return M
