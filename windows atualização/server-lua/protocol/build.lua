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
return M
