-- User-editable keyboard and gamepad controls; saved in LÖVE's save directory.
-- No executable configuration files; only validated key/button identifiers.
local Pad=require("src.game.gamepad_controls")
local UI=require("src.game.pc_menu_style")
local Settings={}
Settings.__index=Settings
local actions={
 {id="moveUp",label="Andar para cima",keyboard="w",button="(analogico)"},
 {id="moveDown",label="Andar para baixo",keyboard="s",button="(analogico)"},
 {id="moveLeft",label="Andar para esquerda",keyboard="a",button="(analogico)"},
 {id="moveRight",label="Andar para direita",keyboard="d",button="(analogico)"},
 {id="previous",label="Item anterior",keyboard="q",button="leftshoulder"},
 {id="next",label="Proximo item",keyboard="tab",button="righttrigger"},
 {id="attack",label="Atacar",keyboard="space",button="rightshoulder"},
 {id="interact",label="Interagir",keyboard="f",button="a"},
 {id="heal",label="Curar",keyboard="r",button="y"},
 {id="pause",label="Pausar / voltar",keyboard="escape",button="start"}
}
Settings.actions=actions
local default={}
for _,a in ipairs(actions) do default[a.id]={keyboard=a.keyboard,button=a.button} end
local validButtons={
 a=true,b=true,x=true,y=true,leftshoulder=true,rightshoulder=true,
 lefttrigger=true,righttrigger=true,start=true,back=true,
 dpup=true,dpdown=true,dpleft=true,dpright=true,
 leftstick=true,rightstick=true
}
local function validKey(v)
 return type(v)=="string" and v:match("^[a-z0-9]+$")~=nil
  or v=="space" or v=="tab" or v=="escape"
  or v=="up" or v=="down" or v=="left" or v=="right"
  or v=="lshift" or v=="rshift" or v=="return"
end
local function validButton(v)
 return validButtons[v]==true or type(v)=="number"
  and v>=1 and v<=32 and math.floor(v)==v
end
local function clamp(n,min,max)
 return math.min(max,math.max(min,n))
end
function Settings.new()
 local self=setmetatable({
  mapping={},rawMove=1,rawAim=3,mappedSwap=false,
  deadzone=0.24,sensitivity=1, waiting=nil,open=false
 },Settings)
 self:reset(false)
 self:load()
 return self
end
function Settings:reset(write)
 for _,a in ipairs(actions) do
  self.mapping[a.id]={keyboard=a.keyboard,button=a.button}
 end
 self.rawMove=1;self.rawAim=3
 self.mappedSwap=false;self.deadzone=0.24;self.sensitivity=1
 self.waiting=nil
 if write then self:save() end
end
local function file()
 return "mooio-controls-v1.txt"
end
function Settings:load()
 if not love or not love.filesystem or not love.filesystem.read then return end
 local ok,data=pcall(love.filesystem.read,file())
 if not ok or type(data)~="string" then return end
 for line in data:gmatch("[^\r\n]+") do
  local kind,id,value=line:match("^(%w+)%.([%w]+)=(.+)$")
  if kind=="key" and self.mapping[id] and validKey(value) then
   self.mapping[id].keyboard=value
  elseif kind=="pad" and self.mapping[id] then
   local v=value:match("^b(%d+)$")
   local b=v and tonumber(v) or value
   if validButton(b) then self.mapping[id].button=b end
  elseif kind=="axis" and id=="move" and tonumber(value) then
   self.rawMove=clamp(math.floor(tonumber(value)),1,5)
  elseif kind=="axis" and id=="aim" and tonumber(value) then
   self.rawAim=clamp(math.floor(tonumber(value)),1,5)
  elseif kind=="option" and id=="deadzone" and tonumber(value) then
   self.deadzone=clamp(tonumber(value),0.05,0.5)
  elseif kind=="option" and id=="sensitivity" and tonumber(value) then
   self.sensitivity=clamp(tonumber(value),0.5,2)
  elseif kind=="option" and id=="swap" then
   self.mappedSwap=value=="1"
  end
 end
end
function Settings:save()
 if not love or not love.filesystem or not love.filesystem.write then return false end
 local lines={}
 for _,a in ipairs(actions) do
  local m=self.mapping[a.id]
  lines[#lines+1]="key."..a.id.."="..m.keyboard
  if type(m.button)=="number" then
   lines[#lines+1]="pad."..a.id.."=b"..m.button
  elseif validButton(m.button) then
   lines[#lines+1]="pad."..a.id.."="..m.button
  end
 end
 lines[#lines+1]="axis.move="..self.rawMove
 lines[#lines+1]="axis.aim="..self.rawAim
 lines[#lines+1]="option.deadzone="..self.deadzone
 lines[#lines+1]="option.sensitivity="..self.sensitivity
 lines[#lines+1]="option.swap="..(self.mappedSwap and "1" or "0")
 return pcall(love.filesystem.write,file(),table.concat(lines,"\n").."\n")
end
function Settings:key(id)
 return self.mapping[id] and self.mapping[id].keyboard
end
function Settings:keyForAction(key)
 for _,a in ipairs(actions) do
  if self:key(a.id)==key then return a.id end
 end
end
function Settings:button(joy,id)
 local m=self.mapping[id]
 if not joy or not m then return false end
 local b=m.button
 if b=="righttrigger" then return Pad.triggerRight(joy) end
 if type(b)=="number" then
  local ok,v=pcall(function()return joy:isDown(b)end)
  return ok and v==true
 end
 return Pad.button(joy,b)
end
function Settings:matches(joy,physical,id)
 local m=self.mapping[id]
 if not m then return false end
 if type(physical)=="number" then
  if type(m.button)=="number" then return m.button==physical end
  return not Pad.isMapped(joy) and Pad.buttonName(joy,physical)==m.button
 end
 return m.button==physical
end
function Settings:axis(joy,name)
 if not joy then return 0 end
 local mapped=Pad.isMapped(joy)
 if mapped then
  local side=(name=="leftx" or name=="lefty") and "left" or "right"
  if self.mappedSwap then side=side=="left" and "right" or "left" end
  local axis=side..((name=="leftx" or name=="rightx") and "x" or "y")
  return Pad.axis(joy,axis)
 end
 local start=(name=="leftx" or name=="lefty") and self.rawMove or self.rawAim
 local index=start+((name=="lefty" or name=="righty") and 1 or 0)
 local ok,n=pcall(function()return joy:getAxis(index)end)
 return ok and type(n)=="number" and n or 0
end
function Settings:stick(x,y)
 local mag=math.sqrt(x*x+y*y)
 if mag<=self.deadzone then return 0,0 end
 local scaled=clamp((mag-self.deadzone)/(1-self.deadzone)*self.sensitivity,0,1)
 return x/mag*scaled,y/mag*scaled
end
function Settings:captureKeyboard(key)
 if not self.waiting or self.waiting.kind~="keyboard" then return false end
 if key=="escape" then self.waiting=nil;return true end
 if not validKey(key) then return true end
 local current=self.mapping[self.waiting.id]
 if current then current.keyboard=key;self:save() end
 self.waiting=nil
 return true
end
function Settings:captureButton(joy,physical)
 if not self.waiting or self.waiting.kind~="button" then return false end
 if not validButton(physical) then return true end
 local current=self.mapping[self.waiting.id]
 if current then current.button=physical;self:save() end
 self.waiting=nil
 return true
end
function Settings:isOpen()return self.open end
function Settings:show()self.open=true;self.waiting=nil end
function Settings:hide()self.open=false;self.waiting=nil end
local uiFonts={}
local function font(n)
 if not uiFonts[n] then uiFonts[n]=love.graphics.newFont(n) end
 return uiFonts[n]
end
local function inRect(x,y,r)
 return x>=r[1] and x<r[1]+r[3] and y>=r[2] and y<r[2]+r[4]
end
local function uiPoint(x,y)
 local w,h=love.graphics.getDimensions()
 local s=math.min(w/1280,h/720)
 return (x-(w-1280*s)/2)/s,(y-(h-720*s)/2)/s
end
function Settings:click(sx,sy)
 if not self.open then return false end
 local x,y=uiPoint(sx,sy)
 if inRect(x,y,{1092,93,90,44}) then self:hide();return "close" end
 for i,a in ipairs(actions) do
  local y0=154+(i-1)*38
  if inRect(x,y,{490,y0,245,34}) then
   self.waiting={kind="keyboard",id=a.id};return "capture"
  elseif i>4 and inRect(x,y,{750,y0,250,34}) then
   self.waiting={kind="button",id=a.id};return "capture"
  end
 end
 if inRect(x,y,{140,554,440,36}) then
  self.rawMove=self.rawMove%5+1;self:save();return "change"
 end
 if inRect(x,y,{600,554,440,36}) then
  self.rawAim=self.rawAim%5+1;self:save();return "change"
 end
 if inRect(x,y,{140,596,300,36}) then
  self.deadzone=self.deadzone>=0.5 and 0.05 or
   math.floor(self.deadzone*100+5.5)/100
  self.deadzone=clamp(self.deadzone,0.05,0.5);self:save();return "change"
 end
 if inRect(x,y,{458,596,300,36}) then
  self.sensitivity=self.sensitivity>=2 and 0.5 or
   math.floor(self.sensitivity*10+1.5)/10
  self:save();return "change"
 end
 if inRect(x,y,{776,596,270,36}) then
  self.mappedSwap=not self.mappedSwap;self:save();return "change"
 end
 if inRect(x,y,{140,642,400,35}) then
  self:reset(true);return "reset"
 end
 return nil
end
function Settings:draw(joy)
 if not self.open then return end
 love.graphics.push("all")
 love.graphics.origin()
 local w,h=love.graphics.getDimensions()
 love.graphics.setColor(0.02,0.035,0.02,0.91)
 love.graphics.rectangle("fill",0,0,w,h)
 local scale=math.min(w/1280,h/720)
 love.graphics.translate((w-1280*scale)/2,(h-720*scale)/2)
 love.graphics.scale(scale)
 UI.panel(100,72,1080,620,{0.19,0.21,0.20})
 love.graphics.setColor(0.75,0.80,0.74,0.3)
 love.graphics.rectangle("fill",104,77,1072,4)
 local f1,f2=font(27),font(15)
 love.graphics.setFont(f1);love.graphics.setColor(1,1,1)
 love.graphics.print("CONTROLES - TECLADO E JOYSTICK",140,97)
 love.graphics.setFont(f2)
 love.graphics.print("Acao",143,135)
 love.graphics.print("Teclado (clique para editar)",496,135)
 love.graphics.print("Joystick (clique para editar)",755,135)
 local function button(label,x,y,bw,bh,active)
  local mx,my=love.mouse.getPosition()
  local tx,ty=uiPoint(mx,my)
  UI.button(x,y,bw,bh,label,active,false,inRect(tx,ty,{x,y,bw,bh}))
 end
 for i,a in ipairs(actions) do
  local y=154+(i-1)*38
  love.graphics.setColor(i%2==0 and 0.21 or 0.18,0.22,0.20)
  love.graphics.rectangle("fill",138,y,910,34)
  love.graphics.setColor(1,1,1)
  love.graphics.print(a.label,145,y+9)
  local m=self.mapping[a.id]
  local kw=self.waiting and self.waiting.id==a.id and self.waiting.kind=="keyboard"
  local bw=self.waiting and self.waiting.id==a.id and self.waiting.kind=="button"
  button(kw and "PRESSIONE UMA TECLA" or m.keyboard:upper(),490,y,245,34,kw)
  if i<=4 then
   love.graphics.setColor(0.63,0.70,0.63)
   love.graphics.printf("Analogico",750,y+10,250,"center")
  else
   local desc=type(m.button)=="number" and ("Botao fisico "..m.button)
     or tostring(m.button):upper()
   button(bw and "PRESSIONE UM BOTAO" or desc,750,y,250,34,bw)
  end
 end
 button("Mover: eixos "..self.rawMove.."-"..(self.rawMove+1),140,554,440,36)
 button("Mirar: eixos "..self.rawAim.."-"..(self.rawAim+1),600,554,440,36)
 button("Zona morta: "..math.floor(self.deadzone*100).."%",140,596,300,36)
 button("Sensibilidade: "..string.format("%.1f",self.sensitivity),458,596,300,36)
 button("Trocar analogicos: "..(self.mappedSwap and "SIM" or "NAO"),776,596,270,36)
 button("RESTAURAR PADRAO",140,642,400,35)
 button("VOLTAR",1092,93,90,44)
 love.graphics.setColor(0.8,0.87,0.78)
 local dev=joy and (Pad.isMapped(joy) and "Gamepad SDL" or "Joystick USB generico") or "Nenhum joystick conectado"
 love.graphics.print(dev.." | Clique em um comando para remapear. ESC cancela a captura.",550,654)
 if joy then
  local lx,ly=self:axis(joy,"leftx"),self:axis(joy,"lefty")
  local rx,ry=self:axis(joy,"rightx"),self:axis(joy,"righty")
  love.graphics.setColor(0.68,0.88,0.58)
  love.graphics.print(string.format("Teste ao vivo  Mover: %.2f / %.2f  Mirar: %.2f / %.2f",lx,ly,rx,ry),555,678)
 end
 love.graphics.pop()
end
return Settings
