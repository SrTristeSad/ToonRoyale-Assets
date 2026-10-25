-- SPDX-License-Identifier: AGPL-3.0-only
-- Math.atan2 from the original Node server, including LuaJIT/LÖVE.
local M={}
function M.atan2(y,x)
 if math.atan2 then return math.atan2(y,x) end
 if x>0 then return math.atan(y/x) end
 if x<0 then return math.atan(y/x)+(y>=0 and math.pi or -math.pi) end
 if y>0 then return math.pi/2 end
 if y<0 then return -math.pi/2 end
 return 0
end
return M
