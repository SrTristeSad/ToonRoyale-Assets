-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact practical bridge for JS Number.toFixed(d) -> parseFloat.
-- printf decimal rounding is correctly based on the source float (unlike
-- floor(x*10^d+.5)); however, C uses ties-to-even while JS toFixed uses
-- ties-away-from-zero. Detect an EXACT halfway binary float by its 2-adic
-- exponent, without first multiplying and thus misclassifying values such
-- as 101.675 (whose binary value is actually *below* the halfway mark).
local Fixed={}
local function isExactHalfway(value,d)
  if value==0 then return false end
  local repr=string.format("%a",math.abs(value))
  local before,after,power=repr:match("^0x([%da-f]+)%.([%da-f]+)p([+-]?%d+)$")
  if not before then
    before,power=repr:match("^0x([%da-f]+)p([+-]?%d+)$")
    after=""
  end
  assert(before and power,"hex-float conversion not supported")
  local significant=assert(tonumber(before..after,16),"invalid binary significand")
  local exponent=tonumber(power)-#after*4+d
  while significant%2==0 do
    significant=significant//2
    exponent=exponent+1
  end
  -- 10^d = 2^d * 5^d and 5^d is odd, so a denominator of exactly 2
  -- marks a decimal-grid halfway, even when decimal multiplication rounds.
  return exponent==-1
end
function Fixed.toFloat(value,d)
  assert(type(value)=="number" and value==value
     and value~=math.huge and value~=-math.huge,"finite coordinate required")
  assert(type(d)=="number" and d>=0 and d<=6 and d%1==0,
     "supported original network decimal precision required")
  if isExactHalfway(value,d) then
    local mul=10^d
    local rounded=math.floor(math.abs(value)*mul+0.5)/mul
    return value<0 and -rounded or rounded
  end
  return assert(tonumber(string.format("%."..d.."f",value)),
    "decimal serialization unavailable")
end
return Fixed
