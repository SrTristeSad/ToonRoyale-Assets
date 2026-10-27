-- Original Moo IO pause/options UI. It is an overlay, not a replacement
-- scene. The authoritative world keeps rendering and receiving packets.
local UI=require("src.game.pc_menu_style")
local Pause={}
Pause.__index=Pause
local W,H=1280,720
local F={}
local function font(n)
  if not F[n] then F[n]=love.graphics.newFont(n) end
  return F[n]
end
local rects={
  resume={410,239,460,53},
  settings={410,301,460,53},
  leave={410,425,460,53},
  rootInvite={410,363,460,53},
  grid={410,246,460,58},
  fullscreen={410,316,460,58},
  back={410,454,460,52},
  info={410,386,460,58},
  controls={410,453,460,53},
  settingsBack={410,521,460,44},
  hudSizeLess={407,221,88,41},hudSizeMore={785,221,88,41},
  hudOpacityLess={407,272,88,41},hudOpacityMore={785,272,88,41},
  hudMoveLess={407,323,88,41},hudMoveMore={785,323,88,41},
  hudFireLess={407,374,88,41},hudFireMore={785,374,88,41},
  hudDeadLess={407,425,88,41},hudDeadMore={785,425,88,41},
  hudReset={400,493,222,45},hudBack={652,493,222,45},
  hudEditor={410,545,460,47},
  copyInvite={410,359,460,58},
  inviteBack={410,431,460,52},
  confirm={410,404,216,56},
  cancel={644,404,226,56}
}
local function coords(x,y)
  local w,h=love.graphics.getDimensions()
  local z=math.min(w/W,h/H)
  return (x-(w-W*z)/2)/z,(y-(h-H*z)/2)/z
end
local function hit(x,y,r)
  return x>=r[1] and x<r[1]+r[3] and y>=r[2] and y<r[2]+r[4]
end
local function label(text,x,y,w,h,size,color)
  love.graphics.setFont(font(size))
  if color then
    love.graphics.setColor(color[1],color[2],color[3],color[4] or 1)
  else
    love.graphics.setColor(1,1,1,1)
  end
  love.graphics.printf(text,x,y+(h-size)/2-3,w,"center")
end
local function button(text,kind,selected)
  local r=rects[kind]
  local mx,my=coords(love.mouse.getPosition())
  UI.button(r[1],r[2],r[3],r[4],text,selected,false,hit(mx,my,r))
end
function Pause.new()
  return setmetatable({page=nil,owner=false,confirmQuit=false},Pause)
end
function Pause:isOpen()return self.page~=nil end
function Pause:open(owner)
  self.owner=owner==true
  self.page="root"
  self.confirmQuit=false
end
function Pause:close()
  self.page=nil
  self.confirmQuit=false
end
function Pause:confirm(owner,quit)
  self.owner=owner==true
  self.confirmQuit=quit==true
  self.page="confirm"
end
function Pause:keypressed(key)
  if not self.page then return nil end
  if key=="escape" then
    if self.page=="invite" then
      self.page="root"
      return "back"
    elseif self.page=="hud" then
      self.page="settings"
    elseif self.page=="editor" then
      self.page="hud"
      return "editor_cancel"
    elseif self.page=="confirm" or self.page=="settings" or self.page=="info" then
      self.page="root"
      self.confirmQuit=false
    else
      self:close()
      return "resume"
    end
    return "back"
  end
  return nil
end
function Pause:click(screenX,screenY)
  if not self.page then return nil end
  local x,y=coords(screenX,screenY)
  local function which(key)return hit(x,y,rects[key])end
  if self.page=="root" then
    if which("resume") then self:close();return "resume" end
    if which("settings") then self.page="settings";return "settings" end
    if which("rootInvite") and self.owner then
      self.page="invite"
      return "show_invite"
    end
    if which("leave") then
      if self.owner then self.page="confirm";return "confirm" end
      self:close();return "leave_guest"
    end
  elseif self.page=="settings" then
    if which("grid") then return "toggle_grid" end
    if which("fullscreen") then return "toggle_fullscreen" end
    if which("info") then self.page="info";return "info" end
    if which("controls") then return "edit_controls" end
    if which("settingsBack") then self.page="root";return "back" end
  elseif self.page=="hud" then
    if which("hudEditor") then return "editor_open" end
    local actions={
      hudSizeLess="hud_smaller",hudSizeMore="hud_bigger",
      hudOpacityLess="opacity_less",hudOpacityMore="opacity_more",
      hudMoveLess="move_less",hudMoveMore="move_more",
      hudFireLess="fire_less",hudFireMore="fire_more",
      hudDeadLess="dead_less",hudDeadMore="dead_more",
      hudReset="hud_reset"
    }
    for key,action in pairs(actions) do if which(key) then return action end end
    if which("hudBack") then self.page="settings";return "back" end
  elseif self.page=="info" then
    if which("back") then self.page="settings";return "back" end
  elseif self.page=="invite" then
    if which("copyInvite") then return "copy_invite" end
    if which("inviteBack") then self.page="root";return "back" end
  elseif self.page=="confirm" then
    if which("confirm") then
      local quit=self.confirmQuit
      self:close()
      return quit and "quit_owner" or "leave_owner"
    end
    if which("cancel") then self.page="root";self.confirmQuit=false;return "cancel" end
  end
  return nil
end
function Pause:draw(grid,fullscreen,inviteText,world,mobileHud)
  if not self.page then return end
  local w,h=love.graphics.getDimensions()
  love.graphics.push("all")
  love.graphics.origin()
  -- Retain the ACTUAL rendered game world visible behind the modal.
  love.graphics.setColor(0.015,0.021,0.019,0.70)
  love.graphics.rectangle("fill",0,0,w,h)
  local z=math.min(w/W,h/H)
  love.graphics.translate((w-W*z)/2,(h-H*z)/2)
  love.graphics.scale(z)
  UI.panel(360,self.page=="hud" and 105 or 114,560,
    self.page=="hud" and 550 or 465,{0.19,0.21,0.20})
  love.graphics.setColor(0.77,0.82,0.77,0.27)
  love.graphics.rectangle("fill",366,120,548,3)
  if self.page=="root" then
    label("JOGO PAUSADO",395,146,490,58,32)
    label(self.owner and "Sua sala privada continua online."
      or "O servidor continua em funcionamento.",405,205,470,31,15,
      {0.77,0.82,0.75})
    button("VOLTAR AO JOGO","resume",true)
    button("CONFIGURACOES","settings")
    if self.owner and inviteText and inviteText~="" then
      button("CONVIDAR AMIGOS","rootInvite")
    else
      button("CONVIDAR AMIGOS - SO ANFITRIAO","rootInvite")
    end
    button(self.owner and "SAIR E ENCERRAR SALA" or "SAIR DA PARTIDA","leave")
  elseif self.page=="settings" then
    label("CONFIGURACOES",395,146,490,58,31)
    label("Alteracoes aplicadas na partida.",405,205,470,31,15,
      {0.77,0.82,0.75})
    button("GRADE DO MAPA: "..(grid and "LIGADA" or "DESLIGADA"),"grid")
    button("TELA CHEIA: "..(fullscreen and "LIGADA" or "DESLIGADA"),"fullscreen")
    button("INFORMACOES DO MAPA","info")
    button(mobileHud and "CONTROLES TOUCH" or "EDITAR TECLADO E JOYSTICK","controls")
    button("VOLTAR","settingsBack")
  elseif self.page=="hud" then
    label("CONTROLES TOUCH",395,145,490,58,29)
    local rows={
      {"hudSizeLess","hudSizeMore","BOTOES",mobileHud and mobileHud.hudScale or 1.2,221},
      {"hudOpacityLess","hudOpacityMore","OPACIDADE",mobileHud and mobileHud.hudOpacity or .9,272},
      {"hudMoveLess","hudMoveMore","MOVIMENTO",mobileHud and mobileHud.moveScale or 1,323},
      {"hudFireLess","hudFireMore","MIRA + ATAQUE",mobileHud and mobileHud.fireScale or 1,374},
      {"hudDeadLess","hudDeadMore","ZONA MORTA",mobileHud and mobileHud.deadzone or .15,425}
    }
    for _,r in ipairs(rows) do
      button("-",r[1]);button("+",r[2])
      label(r[3].."   "..string.format("%.0f%%",r[4]*100),502,r[5],275,42,18)
    end
    button("RESTAURAR","hudReset");button("VOLTAR","hudBack")
    button("EDITAR POSICOES NA TELA","hudEditor")
  elseif self.page=="info" then
    label("INFORMACOES DA PARTIDA",395,146,490,58,28)
    local map=world and world.map
    local settings=world and world.roomSettings
    label("MAPA: "..(map and (map.name or map.id) or "Sem mapa personalizado"),400,231,480,40,17)
    label("REGIAO: "..tostring(world and world.spaceId or "surface"),400,278,480,40,17)
    label("DIFICULDADE: "..tostring(settings and settings.difficulty or "normal"),400,325,480,40,17)
    label("MODS ATIVOS: "..tostring(settings and settings.mods and #settings.mods or 0),400,370,480,40,17)
    button("VOLTAR","back")
  elseif self.page=="invite" then
    label("CONVIDAR AMIGOS",395,146,490,58,31)
    label("Envie este convite para seus amigos.",405,217,470,31,16,
      {0.82,0.88,0.79})
    local code=tostring(inviteText or "")
    love.graphics.setColor(0.12,0.16,0.14,0.97)
    love.graphics.rectangle("fill",389,284,502,57)
    label(code~="" and code or "Convite indisponivel",399,292,482,38,
      code:len()>40 and 14 or 17)
    button("COPIAR CONVITE","copyInvite",true)
    button("VOLTAR","inviteBack")
  else
    label("ENCERRAR SUA SALA?",393,146,494,58,30)
    label("Isso desconecta todos os jogadores do mapa.",395,240,490,32,17,
      {1,0.82,0.73})
    label("Voce tem certeza?",395,290,490,36,22)
    button("SIM, ENCERRAR","confirm")
    button("CANCELAR","cancel",true)
  end
  if self.page~="hud" then
    label("ESC: voltar  |  Multiplayer: o mundo nao e pausado",
      376,508,528,35,14,{0.79,0.85,0.77})
  end
  if mobileHud then
    label("ANDROID LUA 0.5.8 - HUD MOVEL",392,
      self.page=="hud" and 615 or 550,500,20,13,{0.82,0.89,0.83})
  end
  love.graphics.pop()
end
return Pause
