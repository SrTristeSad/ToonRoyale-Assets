-- SPDX-License-Identifier: AGPL-3.0-only
-- Deterministic SHA-256 fallback for bare Lua tests and standalone Lua runtimes.
-- The Windows LÖVE host should provide love.data.hash("sha256",...) instead.
local C = require("src.protocol.original_crypto")
local bx, band, bor = C.bxor, C.band, C.bor
local rr, sh = C.rshift, C.lshift
local MOD = 4294967296
local function add(...) local s=0;for i=1,select("#",...) do s=(s+select(i,...))%MOD end;return s end
local function ror(x,n) return bor(rr(x,n),sh(x,32-n)) end
local function bnot(x) return bx(x,4294967295) end
local K={
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
}
local function be(n) return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256) end
local function u32(s,p) local a,b,c,d=s:byte(p,p+3);return a*16777216+b*65536+c*256+d end
local H0={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
local M={}
function M.digest(input)
  assert(type(input)=="string","SHA-256 needs string")
  local length=#input
  local bitLength=length*8
  local zeroes=(56-(length+1)%64)%64
  local high=math.floor(bitLength/MOD)
  local low=bitLength%MOD
  local data=input.."\128"..string.rep("\0",zeroes)..be(high)..be(low)
  local H={};for i=1,8 do H[i]=H0[i] end
  for pos=1,#data,64 do
    local w={}
    for i=1,16 do w[i]=u32(data,pos+(i-1)*4) end
    for i=17,64 do
      local a,b=w[i-15],w[i-2]
      local s0=bx(bx(ror(a,7),ror(a,18)),rr(a,3))
      local s1=bx(bx(ror(b,17),ror(b,19)),rr(b,10))
      w[i]=add(w[i-16],s0,w[i-7],s1)
    end
    local a,b,c,d,e,f,g,h=(table.unpack or unpack)(H)
    for i=1,64 do
      local S1=bx(bx(ror(e,6),ror(e,11)),ror(e,25))
      local ch=bx(band(e,f),band(bnot(e),g))
      local t1=add(h,S1,ch,K[i],w[i])
      local S0=bx(bx(ror(a,2),ror(a,13)),ror(a,22))
      local maj=bx(bx(band(a,b),band(a,c)),band(b,c))
      local t2=add(S0,maj)
      h,g,f,e,d,c,b,a=g,f,e,add(d,t1),c,b,a,add(t1,t2)
    end
    local v={a,b,c,d,e,f,g,h}
    for i=1,8 do H[i]=add(H[i],v[i]) end
  end
  local result={}
  for i=1,8 do result[i]=be(H[i]) end
  return table.concat(result)
end
return M
