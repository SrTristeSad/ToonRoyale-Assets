local Input={}
Input.__index=Input
function Input.new() return setmetatable({keys={},buttons={},dx=0,dy=0,gamepadX=0,gamepadY=0},Input) end
function Input:keypressed(k) self.keys[k]=true end
function Input:keyreleased(k) self.keys[k]=nil end
function Input:mousepressed(x,y,b) self.buttons[b]=true end
function Input:mousereleased(x,y,b) self.buttons[b]=nil end
function Input:update(dt)
  local k=self.keys
  self.dx=((k.d or k.right) and 1 or 0)-((k.a or k.left) and 1 or 0)
  self.dy=((k.s or k.down) and 1 or 0)-((k.w or k.up) and 1 or 0)
  if math.abs(self.gamepadX)>0 or math.abs(self.gamepadY)>0 then
    self.dx=self.gamepadX;self.dy=self.gamepadY
  end
end
function Input:gamepadMove(x,y)
 local function deadzone(v)
  if type(v)~="number" or math.abs(v)<0.22 then return 0 end
  return (math.abs(v)-0.22)/0.78*(v<0 and -1 or 1)
 end
 self.gamepadX=deadzone(x);self.gamepadY=deadzone(y)
end
function Input:describe()
  local keys={}
  for k,v in pairs(self.keys) do if v then keys[#keys+1]=k end end
  table.sort(keys)
  return #keys>0 and table.concat(keys,", ") or "nenhuma tecla"
end
return Input
