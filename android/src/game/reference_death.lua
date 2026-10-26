-- Exact original MooMoo.io death transition:
-- client/src/index.js killPlayer() -> #diedText, grow at 0.1 px per ms
-- (up to 120px), then show the familiar opening menu after 3000ms.
-- client/public/css/main.css: background rgba(0,0,0,0.25),
-- centered vertically and horizontally, with white "YOU DIED".
-- The 3-second browser animation is preserved. Guest rooms subsequently
-- show a local choice: respawn in the existing session or leave the host.
local Config=require("src.game.config")
local Death={}
Death.__index=Death
Death.DURATION=(Config.deathFadeout or 3000)/1000
function Death.new()
  return setmetatable({elapsed=0,active=false},Death)
end
function Death:start()
  self.elapsed=0
  self.active=true
end
function Death:reset()
  self.elapsed=0
  self.active=false
end
function Death:fontSize()
  -- The reference updateGame adds 0.1 * deltaMillis until 120px,
  -- then rounds to whole pixels (0 is invisible at packet P).
  return math.min(120,math.floor(self.elapsed*100+0.5))
end
function Death:update(dt)
  if not self.active then return false end
  if type(dt)~="number" or dt<=0 then return false end
  self.elapsed=math.min(Death.DURATION,self.elapsed+dt)
  return self.elapsed>=Death.DURATION
end
local fonts={}
function Death:draw(width,height)
  if not self.active then return end
  local gfx=love.graphics
  width=width or gfx.getWidth()
  height=height or gfx.getHeight()
  gfx.push("all")
  gfx.setColor(0,0,0,0.25)
  gfx.rectangle("fill",0,0,width,height)
  local size=self:fontSize()
  if size>0 then
    local font=fonts[size]
    if not font then
      font=gfx.newFont(size)
      fonts[size]=font
    end
    gfx.setFont(font)
    gfx.setColor(1,1,1,1)
    gfx.printf("YOU DIED",0,math.floor((height-font:getHeight())/2),
      width,"center")
  end
  gfx.pop()
end

-- Coordinates are in a fixed 1280x720 interface space and adapt to the
-- current LÖVE window without affecting the game-world camera.
local VW,VH=1280,720
local options={
  back={390,380,500,60},
  exit={390,462,500,60}
}
local function scaleToWindow(x,y,w,h)
 local z=math.min(w/VW,h/VH)
 return (x-(w-VW*z)/2)/z,(y-(h-VH*z)/2)/z
end
function Death:choiceAt(x,y,width,height)
 if not self.active or self.elapsed<Death.DURATION then return nil end
 width=width or love.graphics.getWidth()
 height=height or love.graphics.getHeight()
 x,y=scaleToWindow(x,y,width,height)
 for name,r in pairs(options) do
  if x>=r[1] and y>=r[2] and x<r[1]+r[3]
     and y<r[2]+r[4] then return name end
 end
 return nil
end
function Death:drawChoices(width,height,waiting,message)
 if not self.active or self.elapsed<Death.DURATION then return end
 local gfx=love.graphics
 width=width or gfx.getWidth()
 height=height or gfx.getHeight()
 gfx.push("all")
 gfx.origin()
 gfx.setColor(0.025,0.035,0.025,0.68)
 gfx.rectangle("fill",0,0,width,height)
 local z=math.min(width/VW,height/VH)
 gfx.translate((width-VW*z)/2,(height-VH*z)/2)
 gfx.scale(z)
 gfx.setColor(0.08,0.10,0.09,0.96)
 gfx.rectangle("fill",335,145,610,420)
 gfx.setColor(0.57,0.72,0.41)
 gfx.rectangle("fill",335,145,610,6)
 gfx.setColor(0.96,0.96,0.92)
 local heading=gfx.newFont(38)
 gfx.setFont(heading)
 gfx.printf("VOCE MORREU",355,206,570,"center")
 local small=gfx.newFont(18)
 gfx.setFont(small)
 gfx.setColor(0.79,0.84,0.77)
 gfx.printf(waiting and "Aguardando o servidor liberar seu retorno..."
   or "Voce ainda esta conectado a sala do seu amigo.",362,300,556,"center")
 if message and message~="" then
  gfx.setColor(1,0.78,0.55)
  gfx.printf(message,365,339,550,"center")
 end
 local px,py=love.mouse.getPosition()
 local mx,my=scaleToWindow(px,py,width,height)
 for _,entry in ipairs({
  {id="back",label=waiting and "RETORNO SOLICITADO" or "VOLTAR A PARTIDA"},
  {id="exit",label="SAIR DA SALA"}
 }) do
  local r=options[entry.id]
  local active=not (entry.id=="back" and waiting)
  local hover=active and mx>=r[1] and mx<r[1]+r[3]
    and my>=r[2] and my<r[2]+r[4]
  gfx.setColor(0.02,0.035,0.02)
  gfx.rectangle("fill",r[1]+4,r[2]+5,r[3],r[4])
  gfx.setColor(hover and 0.44 or 0.29,hover and 0.60 or 0.35,
    hover and 0.35 or 0.29)
  gfx.rectangle("fill",r[1],r[2],r[3],r[4])
  gfx.setColor(1,1,1,0.20)
  gfx.rectangle("fill",r[1]+2,r[2]+2,r[3]-4,3)
  gfx.setColor(active and 1 or 0.67,active and 1 or 0.71,active and 1 or 0.68)
  gfx.printf(entry.label,r[1],r[2]+17,r[3],"center")
 end
 gfx.pop()
end
return Death
