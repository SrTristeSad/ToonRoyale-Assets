-- Local-only world-space extension. Never reorder original packet names/IDs.
-- Protocol IDs are chosen from currently UNUSED table slots after shuffle.
local Wire={}
function Wire.install(tables)
 for _,direction in ipairs({"c2s","s2c"}) do
  local map=assert(tables[direction],"packet table required")
  if map.enc.j then return false end
  local n=127
  while map.dec[n] and n>=64 do n=n-1 end
  assert(n>=64,"no free protocol extension slot")
  map.enc.j=n
  map.dec[n]="j"
 end
 return true
end
return Wire
