-- Dimensions available to Android touch controls. LÖVE's graphics dimensions
-- may include the navigation/gesture bar; that strip is not interactive.
-- getSafeArea exists in the LÖVE 11.5 runtime, with logical pixel units.
local S={}
local function finite(x)
 return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
function S.bounds(w,h)
 local result={left=0,top=0,right=w,bottom=h,width=w,height=h}
 if not (love and love.window and type(love.window.getSafeArea)=="function")
 then return result end
 local ok,x,y,sw,sh=pcall(love.window.getSafeArea)
 if not ok or not (finite(x) and finite(y) and finite(sw) and finite(sh))
    or sw<=0 or sh<=0 then return result end
 local left=clamp(x,0,w-1)
 local top=clamp(y,0,h-1)
 local right=clamp(x+sw,left+1,w)
 local bottom=clamp(y+sh,top+1,h)
 result.left=left;result.top=top
 result.right=right;result.bottom=bottom
 result.width=right-left;result.height=bottom-top
 return result
end
return S
