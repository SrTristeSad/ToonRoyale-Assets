-- SPDX-License-Identifier: AGPL-3.0-only
-- Moo IO: LAN/VPN rooms are hosted by the bundled Lua server.
-- Gameplay authority lives in the bundled LOCAL Lua room; no client-side fake world.
local Network=require("src.net.mooio_network")
local Mods=require("server-lua.world.room_mods")
local Maps=require("server-lua.world.map_profiles")
local Home={}
Home.__index=Home

-- Stone, soil and grass: block-game-inspired original interface. No copied textures.
local C={
  bg={0.15,0.19,0.18}, panel={0.23,0.255,0.25},
  raised={0.32,0.345,0.33}, border={0.095,0.12,0.11},
  green={0.43,0.72,0.26}, greenDark={0.10,0.19,0.095},
  white={0.96,0.955,0.89}, muted={0.79,0.81,0.76},
  amber={1.0,0.80,0.39}, red={0.99,0.52,0.43}
}
local fonts={}
local function f(n)
  if not fonts[n] then fonts[n]=love.graphics.newFont(n) end
  love.graphics.setFont(fonts[n])
end
local function panel(x,y,w,h,color,r)
  -- Dark stepped border and top-left light edge give the UI a carved-block feel.
  color=color or C.panel
  love.graphics.setColor(0.055,0.068,0.062,0.9)
  love.graphics.rectangle("fill",x+5,y+6,w,h,0,0)
  love.graphics.setColor(C.border)
  love.graphics.rectangle("fill",x-2,y-2,w+4,h+4,0,0)
  love.graphics.setColor(color)
  love.graphics.rectangle("fill",x,y,w,h,0,0)
  love.graphics.setColor(1,1,1,0.11)
  love.graphics.rectangle("fill",x+2,y+2,w-4,3)
  love.graphics.rectangle("fill",x+2,y+2,3,h-4)
  love.graphics.setColor(0,0,0,0.25)
  love.graphics.rectangle("fill",x+2,y+h-5,w-4,4)
  love.graphics.rectangle("fill",x+w-5,y+2,4,h-4)
end
local function printText(t,x,y,size,color,w,align)
  f(size or 17); love.graphics.setColor(color or C.white)
  if w then love.graphics.printf(tostring(t),x,y,w,align or "left")
  else love.graphics.print(tostring(t),x,y) end
end
local function inside(x,y,b)
  return x>=b[1] and y>=b[2] and x<b[1]+b[3] and y<b[2]+b[4]
end
local boxes={
  back={1041,93,171,45},
  homePlay={360,278,560,64},homeServers={360,354,560,64},
  homeSettings={360,452,266,58},homeQuit={654,452,266,58},
  nickname={155,236,462,52},modeLan={155,312,223,46},
  modeVpn={393,312,224,46},vpnIP={155,368,462,46},
  createLan={155,623,462,53},createVpn={155,623,462,53},
  difficulty={155,524,302,47},mapBrowse={468,524,149,47},modIds={155,577,302,39},
  modBrowse={468,577,149,39},modsPrevious={160,638,240,39},
  modsNext={419,638,240,39},modsDone={730,638,365,39},
  botsToggle={155,423,462,39},botsMinus={155,475,110,42},
  botsPlus={508,475,109,42},
  roomCopy={155,419,462,55},roomEnter={155,485,226,55},
  roomStop={392,485,225,55},
  joinIP={704,287,421,51},joinCode={704,359,421,51},
  join={704,430,421,54},joinRetry={704,506,421,49},
  v2Login={704,557,421,38},
  serverAddress={150,260,600,50},serverRefresh={768,260,335,50},
  serverCode={773,513,326,49},serverEnter={773,573,326,51},
  serverPrev={150,633,260,42},serverNext={448,633,260,42},
  grid={355,280,570,57},fullscreen={355,364,570,57},
  controls={355,447,570,57},
  overlayCopy={478,395,322,55},overlayClose={880,177,55,43},
  playConfigure={155,418,462,63},
  chooseLan={122,242,212,43},chooseVpn={348,242,212,43},
  createVpnIP={122,292,438,34},
  easyDiff={122,349,210,40},normalDiff={348,349,212,40},
  hardDiff={122,398,210,40},extremeDiff={348,398,212,40},
  createBots={122,451,438,40},createBotsMinus={122,498,99,39},
  createBotsPlus={461,498,99,39},createMods={122,554,438,45},
  createSubmit={629,622,536,49},createBack={122,622,438,49},
  chooseMapPrev={631,569,232,37},chooseMapNext={880,569,282,37}
}
local function button(id,text,primary)
  local b=boxes[id]
  local mx,my=love.mouse.getPosition()
  local w,h=love.graphics.getDimensions()
  local z=math.min(w/1280,h/720)
  mx=(mx-(w-1280*z)/2)/z;my=(my-(h-720*z)/2)/z
  local hover=inside(mx,my,b)
  local bg=primary and (hover and {0.55,0.82,0.34} or C.green)
     or (hover and {0.39,0.43,0.40} or C.raised)
  panel(b[1],b[2],b[3],b[4],bg,0)
  if primary then
    love.graphics.setColor(0.71,0.92,0.50,0.38)
    love.graphics.rectangle("fill",b[1]+5,b[2]+4,b[3]-10,4)
  end
  printText(text,b[1]+10,b[2]+math.floor((b[4]-21)/2)-1,19,
    primary and C.greenDark or C.white,b[3]-20,"center")
end
local function field(id,value,placeholder,focused)
  local b=boxes[id]
  panel(b[1],b[2],b[3],b[4],{0.17,0.21,0.19},0)
  if focused then
    love.graphics.setColor(C.green)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line",b[1]+1,b[2]+1,b[3]-2,b[4]-2)
  end
  local show=value~="" and value or placeholder
  if #show>51 then show="..."..show:sub(-48) end
  printText(show..(focused and "|" or ""),b[1]+14,b[2]+15,17,
    value=="" and C.muted or C.white,b[3]-28)
end
function Home.parseInvite(value,code)
  if type(value)=="string" and type(code)=="string" and #code>0
    and value:match("^https://[a-z0-9%.%-]+/?$") then
    return Network.invite(value:gsub("/$","").."/"..code)
  end
  if type(value)=="string" and type(code)=="string" and #code>0
    and not value:find("/",1,true) then
    local host=value:match("^%s*(.-)%s*$")
    if host and not host:find(":",1,true) then host=host..":8080" end
    return Network.invite(host.."/"..code)
  end
  return Network.invite(value)
end
function Home.new()
  local installed=Mods.available(love.filesystem,"server-lua/mods")
  local maps=Maps.available(love.filesystem,"server-lua/maps")
  return setmetatable({
    screen="home",nickname="Jogador",invite="",joinCode="",vpnIP="",
    serverMode="lan",difficulty="normal",modIds="",modCatalog=installed,modPage=0,
    mapId=(maps[1] and maps[1].id or ""),mapCatalog=maps,
    mapPage=0,focus=nil,
    serverAddress="",serverCode="",serverRooms={},serverDirectory=nil,
    serverPage=0,serverSelected=1,
    status="",error=false,hosting=false,starting=false,
    hostAddress="",hostCode="",connectionState="idle",serverLog="",
    showGrid=true,fullscreen=false,sessionTitle="",
    roomOverlay=false,botsEnabled=false,botCount=2
  },Home)
end
function Home:scale(x,y)
  local w,h=love.graphics.getDimensions()
  local z=math.min(w/1280,h/720)
  return (x-(w-1280*z)/2)/z,(y-(h-720*z)/2)/z
end
function Home:mapName()
 if self.mapId=="" or self.mapId=="classico" then return "Mapa desativado" end
 for _,m in ipairs(self.mapCatalog) do
  if m.id==self.mapId then return m.name end
 end
 return "Mapa indisponivel: "..self.mapId
end
function Home:mapDescription()
 if self.mapId=="" or self.mapId=="classico" then
  return "Mundo tradicional do Moo-IO, sem regioes subterraneas."
 end
 for _,m in ipairs(self.mapCatalog) do
  if m.id==self.mapId then return m.description or "" end
 end
 return "Arquivo nao encontrado. Confira os mapas instalados."
end
function Home:refreshMaps()
 self.mapCatalog=Maps.available(love.filesystem,"server-lua/maps")
 -- Empty selection is explicit: never silently re-enable a map after F5.
 if self.mapId=="classico" then self.mapId="" end
 if self.mapId~="" and self.mapId~="classico" then
  local found=false
  for _,m in ipairs(self.mapCatalog) do
   if m.id==self.mapId then found=true;break end
  end
  if not found then
   self:setStatus("Mapa escolhido nao esta instalado neste pacote.",true)
  end
 end
end
function Home:refreshInstalled()
 self:refreshMaps()
 self.modCatalog=Mods.available(love.filesystem,"server-lua/mods")
 self.mapPage=math.min(self.mapPage,
   math.max(0,math.ceil((#self.mapCatalog)/4)-1))
 self.modPage=math.min(self.modPage,
   math.max(0,math.ceil(#self.modCatalog/4)-1))
 self:setStatus(#self.mapCatalog.." mapas e "..
   #self.modCatalog.." mods de regras encontrados.")
end
function Home:roomInvite()
  if self.hostAddress=="" or self.hostCode=="" then return "" end
  return self.hostAddress.."/"..self.hostCode
end
function Home:setStatus(t,err)
  self.status=tostring(t or "")
  self.error=err==true
end
function Home:click(sx,sy)
  local x,y=self:scale(sx,sy)
  if self.screen~="home" and inside(x,y,boxes.back) then
    self.screen=(self.screen=="mods" and "create"
      or self.screen=="maps" and "create"
      or self.screen=="create" and "play" or "home")
    self.focus=nil;return "back"
  end
  if self.screen=="home" then
    if inside(x,y,boxes.homePlay) then
      self.screen="play";self.focus=nil;return "play_tab"
    elseif inside(x,y,boxes.homeServers) then
      self.screen="server";self.focus=nil;return "server_tab"
    elseif inside(x,y,boxes.homeSettings) then
      self.screen="settings";self.focus=nil;return "settings_tab"
    elseif inside(x,y,boxes.homeQuit) then
      self.focus=nil;return "quit_game"
    end
  elseif self.screen=="play" then
    if not self.hosting and not self.starting
      and inside(x,y,boxes.playConfigure) then
      self.screen="create";self.focus=nil;self:refreshMaps()
      return "configure"
    end
    if inside(x,y,boxes.nickname) then self.focus="nickname";return "focus" end
    if inside(x,y,boxes.joinIP) then self.focus="invite";return "focus" end
    if inside(x,y,boxes.joinCode) then self.focus="joinCode";return "focus" end
    if self.hosting then
      if inside(x,y,boxes.roomCopy) then self.focus=nil;return "copy" end
      if inside(x,y,boxes.roomEnter) then self.focus=nil;return "play_local" end
      if inside(x,y,boxes.roomStop) then self.focus=nil;return "stop" end
    end
    if inside(x,y,boxes.join) then self.focus=nil;return "join" end
    if not self.hosting and not self.starting and inside(x,y,boxes.v2Login) then
      self.focus=nil;return "v2_login"
    end
    if self.error and inside(x,y,boxes.joinRetry) then self.focus=nil;return "retry" end
    self.focus=nil
  elseif self.screen=="create" then
    if inside(x,y,boxes.createBack) then self.screen="play";return "back" end
    if self.hosting or self.starting then
      self.screen="play";return nil
    end
    if inside(x,y,boxes.chooseLan) then self.serverMode="lan";return "mode_lan" end
    if inside(x,y,boxes.chooseVpn) then self.serverMode="vpn";return "mode_vpn" end
    if self.serverMode=="vpn" and inside(x,y,boxes.createVpnIP) then
      self.focus="vpnIP";return "focus"
    end
    local difficultyButtons={
      {"easyDiff","pacifico"},{"normalDiff","normal"},
      {"hardDiff","dificil"},{"extremeDiff","extremo"}
    }
    for _,item in ipairs(difficultyButtons) do
      if inside(x,y,boxes[item[1]]) then
        self.difficulty=item[2];self.focus=nil
        return "difficulty"
      end
    end
    if inside(x,y,boxes.createBots) then
      self.botsEnabled=not self.botsEnabled;return "bots_toggle"
    end
    if inside(x,y,boxes.createBotsMinus) then
      self.botCount=math.max(0,self.botCount-1)
      self.botsEnabled=self.botCount>0
      return "bots_count"
    end
    if inside(x,y,boxes.createBotsPlus) then
      self.botCount=math.min(8,self.botCount+1)
      self.botsEnabled=true
      return "bots_count"
    end
    if inside(x,y,boxes.createMods) then
      self.screen="mods";self.focus=nil;self.modPage=0
      self.modCatalog=Mods.available(love.filesystem,"server-lua/mods")
      return "mod_browse"
    end
    if inside(x,y,boxes.chooseMapPrev) or inside(x,y,boxes.chooseMapNext)
      or inside(x,y,{629,239,534,210}) then
      self.screen="maps";self.mapPage=0;return "map_browse"
    end
    if inside(x,y,boxes.createSubmit) then
      self.focus=nil
      local found=self.mapId==""
      for _,entry in ipairs(self.mapCatalog) do
        if entry.id==self.mapId then found=true;break end
      end
      if not found then
        self:setStatus("Mapa nao instalado. Selecione outro.",true)
        return "map_missing"
      end
      return "create"
    end
  elseif self.screen=="server" then
    if inside(x,y,boxes.serverAddress) then self.focus="serverAddress";return "focus" end
    if inside(x,y,boxes.serverCode) then self.focus="serverCode";return "focus" end
    if inside(x,y,boxes.serverRefresh) then self.focus=nil;return "server_browse" end
    if inside(x,y,boxes.serverEnter) then self.focus=nil;return "server_join" end
    if inside(x,y,boxes.serverPrev) then
      self.serverPage=math.max(0,self.serverPage-1);return "server_page"
    end
    if inside(x,y,boxes.serverNext) then
      self.serverPage=math.min(math.max(0,math.ceil(#self.serverRooms/4)-1),
        self.serverPage+1);return "server_page"
    end
    for row=1,4 do
      local box={155,332+(row-1)*70,565,62}
      local index=self.serverPage*4+row
      if inside(x,y,box) and self.serverRooms[index] then
        self.serverSelected=index;self.focus=nil;return "server_select"
      end
    end
  elseif self.screen=="maps" then
    if inside(x,y,boxes.modsDone) then self.screen="create";return "maps_done" end
    if inside(x,y,boxes.modsPrevious) then
      self.mapPage=math.max(0,self.mapPage-1);return "map_page"
    end
    if inside(x,y,boxes.modsNext) then
      self.mapPage=math.min(math.max(0,math.ceil((#self.mapCatalog+1)/6)-1),
        self.mapPage+1);return "map_page"
    end
    for row=1,6 do
      local n=self.mapPage*6+row
      if inside(x,y,{151,242+(row-1)*64,976,57}) then
        local entry=n==1 and {id="",name="DESATIVAR MAPA"} or self.mapCatalog[n-1]
        if entry then
          self.mapId=entry.id
          self:setStatus("Mapa selecionado: "..entry.name)
          return "map_select"
        end
      end
    end
  elseif self.screen=="mods" then
    if inside(x,y,boxes.modsDone) then
      self.screen="create";return "mods_done"
    end
    if inside(x,y,boxes.modsPrevious) then
      self.modPage=math.max(0,self.modPage-1);return "mod_page"
    end
    if inside(x,y,boxes.modsNext) then
      self.modPage=math.min(math.max(0,math.ceil(#self.modCatalog/6)-1),
        self.modPage+1);return "mod_page"
    end
    for row=1,6 do
      local index=self.modPage*6+row
      local item=self.modCatalog[index]
      if item and inside(x,y,{151,242+(row-1)*64,976,57}) then
        local valid,selected=pcall(Mods.ids,self.modIds)
        if not valid then
          self:setStatus("Confira os IDs digitados, separados por virgula.",true)
          return "mods_invalid"
        end
        local found
        for j,id in ipairs(selected) do if id==item.id then found=j;break end end
        if found then table.remove(selected,found)
        elseif #selected<8 then selected[#selected+1]=item.id
        else self:setStatus("Limite de oito mods por sala.",true);return "mods_limit" end
        self.modIds=table.concat(selected,",")
        self:setStatus(#selected.." mods selecionados.")
        return "mod_toggle"
      end
    end
  elseif self.screen=="settings" then
    if inside(x,y,boxes.grid) then self.showGrid=not self.showGrid;return "grid" end
    if inside(x,y,boxes.fullscreen) then self.fullscreen=not self.fullscreen;return "fullscreen" end
    if inside(x,y,boxes.controls) then return "edit_controls" end
  end
  return nil
end
local function removeLast(s)
  local i=#s
  while i>1 and s:byte(i)>=128 and s:byte(i)<192 do i=i-1 end
  return s:sub(1,i-1)
end
function Home:keypressed(key)
  if key=="f5" and (self.screen=="create"
     or self.screen=="mods" or self.screen=="maps") then
    self:refreshInstalled()
    return "refresh_installed"
  end
  if key=="escape" then
    self.screen=(self.screen=="mods" and "create"
      or self.screen=="maps" and "create"
      or self.screen=="create" and "play" or "home")
    self.focus=nil;return "back"
  end
  if self.focus then
    if key=="backspace" then self[self.focus]=removeLast(self[self.focus]) end
    if key=="v" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
      self:textinput(love.system.getClipboardText())
    end
    if key=="return" or key=="kpenter" then
      local from=self.focus
      self.focus=nil
      if from=="invite" then return "join" end
    end
    return nil
  end
  if self.screen=="home" then
    if key=="1" then self.screen="play";return "play_tab" end
    if key=="2" then self.screen="server";return "server_tab" end
    if key=="3" then self.screen="settings";return "settings_tab" end
  end
  return nil
end
function Home:textinput(chars)
  if not self.focus or type(chars)~="string" then return end
  if self.focus=="nickname" then
    chars=chars:gsub("[%c]","")
    self.nickname=(self.nickname..chars):sub(1,15)
  elseif self.focus=="invite" then
    chars=chars:gsub("[%c%s]","")
    self.invite=(self.invite..chars):sub(1,128)
  elseif self.focus=="joinCode" then
    chars=chars:gsub("[^%w%-]","")
    self.joinCode=(self.joinCode..chars):sub(1,64)
  elseif self.focus=="modIds" then
    chars=chars:lower():gsub("[^a-z0-9,%- ]","")
    self.modIds=(self.modIds..chars):sub(1,120)
  elseif self.focus=="serverAddress" then
    chars=chars:gsub("[%c%s]","")
    self.serverAddress=(self.serverAddress..chars):sub(1,190)
  elseif self.focus=="serverCode" then
    chars=chars:gsub("[^%w%-]","")
    self.serverCode=(self.serverCode..chars):sub(1,64)
  elseif self.focus=="vpnIP" then
    chars=chars:gsub("[^%d%.]","")
    self.vpnIP=(self.vpnIP..chars):sub(1,15)
  end
end
local function decorate(showWorld)
  if showWorld then
    -- Existing MooMoo top-down map preview is already drawn underneath.
    -- No counterfeit server players; keep the real world art visible.
    love.graphics.setColor(0.025,0.055,0.037,0.25)
    love.graphics.rectangle("fill",0,0,1280,720)
    love.graphics.setColor(0.06,0.11,0.075,0.20)
    love.graphics.rectangle("fill",30,34,1220,657,5,5)
    love.graphics.setColor(0.45,0.75,0.28,0.94)
    love.graphics.rectangle("fill",36,40,1208,6)
    love.graphics.setColor(1,1,1,0.08)
    love.graphics.rectangle("line",34,38,1212,650,5,5)
    return
  end
  -- Fallback decor only when no game background is provided.
  for iy=0,18 do
    for ix=0,32 do
      local x,y=ix*40,iy*40
      local v=(ix*13+iy*7)%6
      local g=0.18+v*0.008
      love.graphics.setColor(g,g+0.025,g+0.006,0.33)
      love.graphics.rectangle("fill",x+1,y+1,39,39)
      love.graphics.setColor(0.07,0.09,0.075,0.12)
      love.graphics.rectangle("fill",x+1,y+36,39,3)
    end
  end
  panel(30,34,1220,657,{0.21,0.24,0.22},0)
  love.graphics.setColor(0.31,0.48,0.23)
  love.graphics.rectangle("fill",36,40,1208,13)
  love.graphics.setColor(0.49,0.70,0.31)
  love.graphics.rectangle("fill",36,40,1208,5)
  -- Pixel foliage remains decorative, never a game sprite.
  local trees={{1130,120,1},{1220,191,0.65},{1060,455,0.7}}
  for _,t in ipairs(trees) do
    love.graphics.setColor(0.30,0.20,0.13,0.55)
    love.graphics.rectangle("fill",t[1]+15*t[3],t[2]+32*t[3],20*t[3],72*t[3])
    love.graphics.setColor(0.24,0.43,0.21,0.62)
    love.graphics.rectangle("fill",t[1],t[2],62*t[3],56*t[3])
    love.graphics.setColor(0.42,0.66,0.28,0.51)
    love.graphics.rectangle("fill",t[1]+10*t[3],t[2]+9*t[3],43*t[3],27*t[3])
  end
end
function Home:draw(state,detail,showWorld)
  self.connectionState=state or self.connectionState
  love.graphics.push("all")
  local w,h=love.graphics.getDimensions()
  local z=math.min(w/1280,h/720)
  love.graphics.translate((w-1280*z)/2,(h-720*z)/2)
  love.graphics.scale(z)
  if not showWorld then love.graphics.clear(C.bg) end
  if self.screen=="home" then
    -- Classic PC title layout: wide world backdrop, centered logo, stacked
    -- native beveled buttons. Graphics/text are original to Moo-IO.
    love.graphics.setColor(0.035,0.05,0.04,0.34)
    love.graphics.rectangle("fill",0,0,1280,720)
    love.graphics.setColor(0,0,0,0.53)
    printText("MOO IO",368,83,100,{0,0,0,0.7},550,"center")
    printText("MOO IO",360,75,100,C.white,560,"center")
    printText("SEU MUNDO, SEUS AMIGOS",425,205,19,C.muted,430,"center")
    love.graphics.push()
    love.graphics.translate(812,198)
    love.graphics.rotate(-0.18)
    printText("MAPAS! MODS! AVENTURAS!",-114,0,19,C.amber,315,"center")
    love.graphics.pop()
    button("homePlay","JOGAR / CRIAR SALA",true)
    button("homeServers","SERVIDORES",false)
    button("homeSettings","OPCOES",false)
    button("homeQuit","SAIR DO JOGO",false)
    printText("Moo-IO  |  Windows Lua",20,681,16,C.white,470)
    printText("Multiplayer LAN, VPN e V2",827,681,16,C.white,433,"right")
    love.graphics.pop()
    return
  end
  decorate(showWorld)
  -- Fixed header: the back button lives at the upper right, never over logo.
  love.graphics.setColor(0.09,0.12,0.095)
  love.graphics.rectangle("fill",58,72,325,83)
  love.graphics.setColor(0.20,0.29,0.19)
  love.graphics.rectangle("fill",63,77,315,73)
  printText("MOO",88,78,44,C.white)
  printText("IO",222,78,44,C.green)
  printText("MULTIPLAYER",91,127,13,C.muted)
  if self.screen=="home" then
    printText("ESCOLHA COMO JOGAR",96,213,29,C.white)
    button("homePlay","JOGAR",true)
    button("homeServers","SERVIDORES",false)
    button("homeSettings","CONFIGURACOES",false)
    panel(583,202,575,340,C.panel,0)
    printText("SEU MUNDO, SUAS REGRAS",608,255,25,C.white)
    printText("Crie sua sala somente se quiser.",612,325,20,C.green)
    printText("Entre sozinho ou chame amigos.",612,363,18,C.muted)
    printText("Sem configurar um terminal.",612,406,17,C.muted)
  else
    button("back","< VOLTAR",false)
    if self.screen=="play" then
      printText("JOGAR",132,158,31,C.white)
      panel(130,194,505,493,C.panel,0)
      panel(672,194,477,402,C.panel,0)
      printText("01  CRIAR MINHA SALA",155,204,19,C.green)
      field("nickname",self.nickname,"Seu apelido",self.focus=="nickname")
      if self.hosting then
        printText(self.botsEnabled and self.botCount>0 and
          ("Sala criada - "..self.botCount.." bots ativos.")
          or "Sala criada - amigos podem entrar.",155,316,17,C.green)
        panel(155,351,462,51,C.raised,9)
        local invite=self:roomInvite()
        printText(invite,170,365,16,C.white,432,"center")
        button("roomCopy","COPIAR CONVITE",false)
        button("roomEnter","JOGAR AGORA",true)
        button("roomStop","ENCERRAR",false)
      elseif self.starting then
        printText("Preparando sua sala...",155,331,18,C.green)
        printText("Voce escolheu criar esta sala.",155,383,16,C.muted)
        printText("Ninguem precisa abrir um terminal.",155,417,16,C.muted)
        printText(self.botsEnabled and
          ("Bots de IA: "..self.botCount) or "Bots desativados.",155,482,15,C.muted)
      else
        printText("Configure mapa, dificuldade e mods",158,330,17,C.muted,449)
        printText("MAPA SELECIONADO:",158,367,15,C.green)
        printText(self:mapName(),158,389,21,C.white,440)
        button("playConfigure","CONFIGURAR MINHA SALA",true)
        panel(155,504,462,118,C.raised,0)
        printText("DIFICULDADE  "..self.difficulty:upper(),172,520,17,C.white,412)
        printText("BOTS: "..(self.botsEnabled and self.botCount or 0)
          .."     |     MODS: "..(self.modIds=="" and "NENHUM" or "PERSONALIZADOS"),
          172,554,15,C.muted,425)
        printText("Clique em CONFIGURAR para criar a partida.",172,588,14,C.amber,422)
      end
      printText("02  ENTRAR EM OUTRA SALA",704,214,19,C.green)
      printText("IP, porta ou convite completo",704,256,15,C.muted)
      field("joinIP",self.invite,"192.168.1.5:8080",self.focus=="invite")
      printText("Codigo de acesso (separado ou no convite)",704,340,14,C.muted)
      field("joinCode",self.joinCode,"Codigo da sala",self.focus=="joinCode")
      button("join","ENTRAR NA SALA",true)
      if self.error then
        button("joinRetry","TENTAR NOVAMENTE",false)
      else
        printText("Convite LAN/VPN ou HTTPS V2 com certificado valido.",706,517,15,C.muted)
      end
      if not self.hosting and not self.starting then
        button("v2Login","ENTRAR COM CONTA V2 (NAVEGADOR)",false)
      end
    elseif self.screen=="create" then
      printText("CONFIGURAR NOVA SALA",121,155,29,C.white)
      printText("F5: atualizar mapas e mods instalados",635,172,13,C.amber,490)
      panel(100,195,482,477,C.panel,0)
      panel(613,195,564,477,C.panel,0)
      printText("CONEXAO",122,206,17,C.green)
      button("chooseLan",self.serverMode=="lan" and "LAN  ATIVA" or "LAN",self.serverMode=="lan")
      button("chooseVpn",self.serverMode=="vpn" and "VPN  ATIVA" or "VPN",self.serverMode=="vpn")
      if self.serverMode=="vpn" then
        field("createVpnIP",self.vpnIP,"IP do seu computador na VPN",self.focus=="vpnIP")
      else
        printText("Amigos na mesma rede local.",122,310,16,C.muted,440)
      end
      printText("DIFICULDADE",122,330,14,C.green)
      local opts={{"easyDiff","PACIFICO","pacifico"},
        {"normalDiff","NORMAL","normal"},{"hardDiff","DIFICIL","dificil"},
        {"extremeDiff","EXTREMO","extremo"}}
      for _,o in ipairs(opts) do button(o[1],o[2],o[3]==self.difficulty) end
      button("createBots",self.botsEnabled and "BOTS: ATIVADOS" or "BOTS: DESATIVADOS",self.botsEnabled)
      button("createBotsMinus","-")
      printText("QUANTIDADE  "..(self.botsEnabled and self.botCount or 0).."/8",
        229,504,17,C.white,223,"center")
      button("createBotsPlus","+")
      button("createMods",self.modIds=="" and "MODS: NENHUM  -  ESCOLHER" or "MODS: PERSONALIZADOS  -  EDITAR",false)
      printText("MAPA DA PARTIDA",635,207,18,C.green)
      panel(629,239,534,210,C.raised,0)
      printText(self:mapName(),650,282,23,C.white,480)
      printText("Escolha o mapa na lista ou desative mapas extras.",650,330,15,C.muted,490)
      button("chooseMapPrev","ESCOLHER MAPA",true)
      button("chooseMapNext","ABRIR LISTA",false)
      button("createBack","CANCELAR",false)
      button("createSubmit","CRIAR SALA NESTE MAPA",true)
      printText("SELECIONADO: "..self:mapName(),635,542,14,C.amber,510)
      if #self.mapCatalog==0 then
        printText("Aviso: nenhum mapa adicional encontrado no pacote.",
          636,543,14,C.red,511)
      end
    elseif self.screen=="maps" then
      printText("ESCOLHER MAPA",140,165,30,C.white)
      printText("Selecione um mapa instalado ou desative os mapas personalizados.",145,213,15,C.muted)
      for row=1,6 do
        local i=self.mapPage*6+row
        local entry=i==1 and {id="",name="DESATIVAR MAPA",description="Jogar sem mapa personalizado."} or self.mapCatalog[i-1]
        if entry then
          local y=242+(row-1)*64
          local active=entry.id==self.mapId
          panel(151,y,976,57,active and C.raised or C.panel,0)
          printText((active and "[ATIVO] " or "[ ] ")..entry.name,166,y+7,18,
            active and C.green or C.white,930)
          printText(entry.description,168,y+34,14,C.muted,920)
        end
      end
      button("modsPrevious","ANTERIOR",false)
      button("modsNext","PROXIMOS",false)
      button("modsDone","VOLTAR PARA SALA",true)
    elseif self.screen=="mods" then
      printText("MODS INSTALADOS",140,165,30,C.white)
      printText("Ative ou desative antes de criar a sala. Sem codigo Lua externo.",145,213,15,C.muted)
      if #self.modCatalog==0 then
        printText("Nenhum mod JSON valido encontrado em server-lua/mods.",169,316,20,C.muted)
      end
      local selected=","..self.modIds..","
      for row=1,6 do
        local mod=self.modCatalog[self.modPage*6+row]
        if mod then
          local y=242+(row-1)*64
          local on=selected:find(","..mod.id..",",1,true)~=nil
          panel(151,y,976,57,on and C.raised or C.panel,0)
          printText((on and "[ATIVO] " or "[ ] ")..mod.name,166,y+7,18,
            on and C.green or C.white,930)
          printText(mod.description,168,y+34,14,C.muted,920)
        end
      end
      button("modsPrevious","ANTERIOR",false)
      button("modsNext","PROXIMOS",false)
      button("modsDone","VOLTAR PARA SALA",true)
    elseif self.screen=="server" then
      printText("SERVIDORES",140,165,31,C.white)
      printText("Endereço do servidor dedicado: IP:porta (LAN/VPN) ou HTTPS V2.",145,220,16,C.muted)
      field("serverAddress",self.serverAddress,"192.168.1.10:8080",self.focus=="serverAddress")
      button("serverRefresh","BUSCAR SALAS",true)
      panel(147,325,582,310,C.panel,0)
      panel(765,325,349,310,C.panel,0)
      if #self.serverRooms==0 then
        printText("Nenhuma sala carregada.",177,370,21,C.white)
        printText("Informe o servidor e clique BUSCAR SALAS.",177,420,16,C.muted,520)
      else
        for row=1,4 do
          local index=self.serverPage*4+row
          local room=self.serverRooms[index]
          if room then
            local y=332+(row-1)*70
            panel(155,y,565,62,index==self.serverSelected and C.raised or C.bg,0)
            printText(room.name,169,y+7,19,room.online and C.white or C.muted,520)
            local mode=room.preset=="traditional" and "Tradicional" or "Personalizada"
            local state=room.online and "Online" or "Offline"
            printText(mode.."  •  "..state.."  •  "..room.players.."/"..room.capacity..
              " jogadores",169,y+35,14,C.muted,520)
          end
        end
      end
      local selected=self.serverRooms[self.serverSelected]
      printText("SALA SELECIONADA",781,344,18,C.green,315)
      if selected then
        printText(selected.name,781,386,20,C.white,315)
        printText(selected.publicAccess and "Publica: entrada pelo catalogo" or
          "Privada: convite necessario",781,427,15,C.muted,315)
        printText(selected.online and "Servidor disponivel" or "Sala offline",
          781,455,15,selected.online and C.green or C.amber,315)
      else
        printText("Selecione uma sala na lista.",781,394,16,C.muted,315)
      end
      field("serverCode",self.serverCode,"Codigo da sala privada",self.focus=="serverCode")
      button("serverEnter","ENTRAR NA SALA",true)
      button("serverPrev","ANTERIOR",false)
      button("serverNext","PROXIMAS",false)
    else
      printText("CONFIGURACOES",336,190,31,C.white)
      button("grid","GRADE DO MAPA     "..(self.showGrid and "LIGADA" or "DESLIGADA"),false)
      button("fullscreen","TELA CHEIA       "..(self.fullscreen and "LIGADA" or "DESLIGADA"),false)
      button("controls","EDITAR TECLADO E JOYSTICK",false)
      printText("Remapeie botoes e analogicos, altere a sensibilidade.",360,537,16,C.muted)
    end
  end
  panel(83,684,1111,34,{0.13,0.17,0.15},0)
  local message=self.status~="" and self.status or
    (state=="joining" and "Entrando na partida..." or
     state=="keyed_transport" and "Servidor conectado. Carregando mundo..." or
     state=="failed" and tostring(detail) or
     "Jogar abre as opcoes. Criar sala e uma escolha.")
  if #message>135 then message=message:sub(1,132).."..." end
  love.graphics.setColor(self.error and C.red or C.green)
  love.graphics.rectangle("fill",92,689,5,22)
  printText(self.error and "ATENCAO" or "STATUS",111,692,13,
    self.error and C.red or C.green)
  printText(message,212,691,15,self.error and {1,0.85,0.77} or C.white,950)
  love.graphics.pop()
end
function Home:drawRoomOverlay()
  if not self.roomOverlay then return end
  local w,h=love.graphics.getDimensions()
  love.graphics.push("all")
  love.graphics.setColor(0,0,0,0.72)
  love.graphics.rectangle("fill",0,0,w,h)
  local z=math.min(w/1280,h/720)
  love.graphics.translate((w-1280*z)/2,(h-720*z)/2)
  love.graphics.scale(z)
  panel(337,166,606,388,C.panel,0)
  printText("CONVIDAR AMIGOS",383,214,27,C.white)
  printText("Compartilhe o codigo desta sala privada.",386,275,17,C.muted)
  panel(388,318,503,54,C.raised,11)
  printText(self:roomInvite(),400,334,17,C.white,478,"center")
  panel(478,395,322,55,C.green,12)
  printText("COPIAR CONVITE",478,409,20,C.greenDark,322,"center")
  panel(880,177,55,43,C.raised,10)
  printText("X",897,185,21,C.white)
  printText("ESC para fechar",386,505,15,C.muted)
  love.graphics.pop()
end
function Home:overlayClick(sx,sy)
  if not self.roomOverlay then return nil end
  local x,y=self:scale(sx,sy)
  if inside(x,y,boxes.overlayCopy) then return "copy" end
  if inside(x,y,boxes.overlayClose) or not inside(x,y,{337,166,606,388}) then
    self.roomOverlay=false;return "close_overlay"
  end
  return "overlay"
end
return Home
