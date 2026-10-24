-- SPDX-License-Identifier: AGPL-3.0-only
-- SHA-1 used ONLY by the RFC6455 WebSocket handshake (not gameplay authentication).
local B=require("src.protocol.original_crypto")
local add=function(...) local n=0;for i=1,select("#",...) do n=(n+select(i,...))%4294967296 end;return n end
local function rol(x,n) return B.bor(B.lshift(x,n),B.rshift(x,32-n)) end
local function be(n) return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256) end
local function u32(v,p) local a,b,c,d=v:byte(p,p+3);return a*16777216+b*65536+c*256+d end
local M={}
function M.digest(input)
  local length=#input*8
  local pad=(56-(#input+1)%64)%64
  local bytes=input.."\128"..string.rep("\0",pad)..be(math.floor(length/4294967296))..be(length%4294967296)
  local h0,h1,h2,h3,h4=0x67452301,0xefcdab89,0x98badcfe,0x10325476,0xc3d2e1f0
  for p=1,#bytes,64 do
    local w={}
    for i=1,16 do w[i]=u32(bytes,p+(i-1)*4) end
    for i=17,80 do w[i]=rol(B.bxor(B.bxor(w[i-3],w[i-8]),B.bxor(w[i-14],w[i-16])),1) end
    local a,b,c,d,e=h0,h1,h2,h3,h4
    for i=1,80 do
      local f,k
      if i<=20 then f=B.bor(B.band(b,c),B.band(B.bxor(b,0xffffffff),d));k=0x5a827999
      elseif i<=40 then f=B.bxor(B.bxor(b,c),d);k=0x6ed9eba1
      elseif i<=60 then f=B.bor(B.bor(B.band(b,c),B.band(b,d)),B.band(c,d));k=0x8f1bbcdc
      else f=B.bxor(B.bxor(b,c),d);k=0xca62c1d6 end
      local t=add(rol(a,5),f,e,k,w[i])
      e,d,c,b,a=d,c,rol(b,30),a,t
    end
    h0,h1,h2,h3,h4=add(h0,a),add(h1,b),add(h2,c),add(h3,d),add(h4,e)
  end
  return be(h0)..be(h1)..be(h2)..be(h3)..be(h4)
end
return M
