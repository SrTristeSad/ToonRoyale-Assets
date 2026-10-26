-- Game controller compatibility layer. Uses SDL gamepad mapping whenever
-- available; generic DirectInput USB joysticks use physical axes/buttons.
-- No gamepad driver DLLs or network calls are required.
local Pad={}
local rawButtons={a=1,b=2,x=3,y=4,
 leftshoulder=5,rightshoulder=6,
 lefttrigger=7,righttrigger=8,
 back=9,start=10,leftstick=11,rightstick=12}
local rawAxes={leftx=1,lefty=2,rightx=3,righty=4,triggerright=6}
local function try(call)
 local ok,value=pcall(call)
 if ok then return value end
 return nil
end
function Pad.isMapped(joy)
 return joy and try(function()return joy:isGamepad()end)==true
end
function Pad.active(devices)
 local fallback
 for _,joy in ipairs(devices or {}) do
  local connected=try(function()return joy:isConnected()end)
  if connected~=false then
   if Pad.isMapped(joy) then return joy end
   local axes=try(function()return joy:getAxisCount()end)
   if not fallback and type(axes)=="number" and axes>=2 then fallback=joy end
  end
 end
 return fallback
end
function Pad.axis(joy,name)
 if not joy then return 0 end
 if Pad.isMapped(joy) then
  local v=try(function()return joy:getGamepadAxis(name)end)
  if type(v)=="number" then return v end
  return 0
 end
 local index=rawAxes[name]
 local count=try(function()return joy:getAxisCount()end) or 0
 if not index or index>count then return 0 end
 local v=try(function()return joy:getAxis(index)end)
 return type(v)=="number" and v or 0
end
function Pad.button(joy,name)
 if not joy then return false end
 if Pad.isMapped(joy) then
  return try(function()return joy:isGamepadDown(name)end)==true
 end
 local index=rawButtons[name]
 if not index then return false end
 local count=try(function()return joy:getButtonCount()end) or 0
 return index<=count and try(function()return joy:isDown(index)end)==true
end
function Pad.triggerRight(joy)
 if not joy then return false end
 if Pad.isMapped(joy) then return Pad.axis(joy,"triggerright")>=0.55 end
 -- Many USB/DirectInput controllers expose R2 as button 8. Some expose
 -- it as raw axis 6. Support either form, but never interpret stick axes.
 return Pad.button(joy,"righttrigger") or Pad.axis(joy,"triggerright")>=0.55
end
function Pad.buttonName(joy,index)
 if Pad.isMapped(joy) then return nil end
 for name,number in pairs(rawButtons) do
  if number==index then return name end
 end
 return nil
end
return Pad
