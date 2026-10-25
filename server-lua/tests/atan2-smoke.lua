local Angles=require("server-lua.world.atan2")
local pairs={
 {0,1,0},{1,0,math.pi/2},{0,-1,math.pi},
 {-1,0,-math.pi/2},{1,1,math.pi/4},
 {1,-1,3*math.pi/4},{-1,-1,-3*math.pi/4},
 {-1,1,-math.pi/4}
}
for _,p in ipairs(pairs) do
 assert(math.abs(Angles.atan2(p[1],p[2])-p[3])<1e-10,
  "Math.atan2 quadrant mismatch")
end
print("PASS Math.atan2 do Node nos quatro quadrantes LuaJIT/Lua")
