-- SPDX-License-Identifier: AGPL-3.0-only
-- Moo IO: personal play rooms are separate from dedicated server providers.
-- Gameplay authority is provided by the same Lua LOCAL server as Windows.
local Network=require("src.net.mooio_network")
local isAndroid=love.system and love.system.getOS and love.system.getOS()=="Android" or os.getenv("MOO_IO_FORCE_ANDROID_E2E")=="1"
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
  homePlay={95,278,400,68},homeServers={95,362,400,68},
  homeSettings={95,446,400,68},
  nickname={155,236,462,52},modeLan={155,312,223,46},
  modeVpn={393,312,224,46},vpnIP={155,368,462,46},
  createLan={155,530,462,53},createVpn={155,530,462,53},
  difficulty={155,303,462,39},mapChoice={155,349,462,38},
  modsChoice={155,391,462,29},
  botsToggle={155,423,462,39},botsMinus={155,475,110,42},
  botsPlus={508,475,109,42},
  roomCopy={155,419,462,55},roomEnter={155,485,226,55},
  roomStop={392,485,225,55},
  joinIP={704,287,421,51},joinCode={704,359,421,51},
  join={704,430,421,54},joinRetry={704,506,421,49},
  v2Login={704,557,421,38},
  serverAddress={155,239,668,51},serverCode={155,302,668,51},
  serverRefresh={846,239,283,51},serverEnter={846,302,283,51},
  serverPrev={155,566,209,43},serverNext={920,566,209,43},
  grid={355,280,570,57},fullscreen={355,364,570,57},
  overlayCopy={478,395,322,55},overlayClose={880,177,55,43}
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
  return setmetatable({
    screen="home",nickname="Jogador",invite="",joinCode="",vpnIP="",
    serverMode="lan",provider="lite",focus=nil,
    serverAddress="",serverCode="",serverRooms={},serverDirectory=nil,
    serverSelected=1,serverPage=0,
    status="",error=false,hosting=false,starting=false,
    hostAddress="",hostCode="",connectionState="idle",serverLog="",
    showGrid=true,fullscreen=false,sessionTitle="",
    roomOverlay=false,botsEnabled=false,botCount=2,
    difficulty="normal",mapId="classico",modIds=""
  },Home)
end
function Home:scale(x,y)
  local w,h=love.graphics.getDimensions()
  local z=math.min(w/1280,h/720)
  return (x-(w-1280*z)/2)/z,(y-(h-720*z)/2)/z
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
    self.screen="home";self.focus=nil;return "back"
  end
  if self.screen=="home" then
    if inside(x,y,boxes.homePlay) then
      self.screen="play";self.focus=nil;return "play_tab"
    elseif inside(x,y,boxes.homeServers) then
      self.screen="server";self.focus=nil;return "server_tab"
    elseif inside(x,y,boxes.homeSettings) then
      self.screen="settings";self.focus=nil;return "settings_tab"
    end
  elseif self.screen=="play" then
    if inside(x,y,boxes.nickname) then self.focus="nickname";return "focus" end
    if inside(x,y,boxes.joinIP) then self.focus="invite";return "focus" end
    if inside(x,y,boxes.joinCode) then self.focus="joinCode";return "focus" end
    if isAndroid and not self.hosting and not self.starting then
      if inside(x,y,boxes.difficulty) then
        local modes={"normal","pacifico","dificil","extremo"}
        for i,value in ipairs(modes) do
          if self.difficulty==value then
            self.difficulty=modes[i%#modes+1];break
          end
        end
        return "difficulty"
      end
      if inside(x,y,boxes.mapChoice) then
        local maps={"classico"}
        if love.filesystem and love.filesystem.getDirectoryItems then
          for _,dir in ipairs({"server-lua/maps","server-lua/mods/maps"}) do
            local ok,items=pcall(love.filesystem.getDirectoryItems,dir)
            if ok and type(items)=="table" then
              for _,file in ipairs(items) do
                local name=file:match("^([a-z][a-z0-9%-]*)%.json$")
                if name then maps[#maps+1]=name end
              end
            end
          end
        end
        table.sort(maps)
        for i,id in ipairs(maps) do
          if id==self.mapId then self.mapId=maps[i%#maps+1];break end
        end
        return "map"
      end
      if inside(x,y,boxes.modsChoice) then
        local mods={""}
        if love.filesystem and love.filesystem.getDirectoryItems then
          local ok,items=pcall(love.filesystem.getDirectoryItems,"server-lua/mods")
          if ok and type(items)=="table" then
            for _,file in ipairs(items) do
              local id=file:match("^([a-z][a-z0-9%-]*)%.json$")
              if id then mods[#mods+1]=id end
            end
          end
        end
        table.sort(mods)
        for i,id in ipairs(mods) do
          if self.modIds==id then self.modIds=mods[i%#mods+1];break end
        end
        return "mods"
      end
      if inside(x,y,boxes.botsToggle) then
        self.botsEnabled=not self.botsEnabled;return "bots_toggle"
      end
      if inside(x,y,boxes.botsMinus) then
        self.botCount=math.max(0,self.botCount-1)
        self.botsEnabled=self.botCount>0;return "bots_count"
      end
      if inside(x,y,boxes.botsPlus) then
        self.botCount=math.min(8,self.botCount+1)
        self.botsEnabled=true;return "bots_count"
      end
      if inside(x,y,boxes.createLan) then
        self.focus=nil;return "create"
      end
    elseif not isAndroid and not self.hosting and not self.starting then
      if inside(x,y,boxes.modeLan) then self.serverMode="lan";self.focus=nil;return "mode_lan" end
      if inside(x,y,boxes.modeVpn) then self.serverMode="vpn";self.focus=nil;return "mode_vpn" end
      if self.serverMode=="vpn" and inside(x,y,boxes.vpnIP) then
        self.focus="vpnIP";return "focus"
      end
      if inside(x,y,boxes.botsToggle) then
        self.botsEnabled=not self.botsEnabled
        self.focus=nil
        return "bots_toggle"
      end
      if inside(x,y,boxes.botsMinus) then
        self.botCount=math.max(0,self.botCount-1)
        self.botsEnabled=self.botCount>0
        self.focus=nil
        return "bots_count"
      end
      if inside(x,y,boxes.botsPlus) then
        self.botCount=math.min(8,self.botCount+1)
        self.botsEnabled=true
        self.focus=nil
        return "bots_count"
      end
      if inside(x,y,boxes[self.serverMode=="vpn" and "createVpn" or "createLan"]) then
        self.focus=nil;return "create"
      end
    elseif self.hosting then
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
      local index=self.serverPage*4+row
      local rect={155,375+(row-1)*44,974,40}
      if self.serverRooms[index] and inside(x,y,rect) then
        self.serverSelected=index;self.focus=nil;return "server_select"
      end
    end
  elseif self.screen=="settings" then
    if inside(x,y,boxes.grid) then self.showGrid=not self.showGrid;return "grid" end
    if inside(x,y,boxes.fullscreen) then self.fullscreen=not self.fullscreen;return "fullscreen" end
  end
  return nil
end
local function removeLast(s)
  local i=#s
  while i>1 and s:byte(i)>=128 and s:byte(i)<192 do i=i-1 end
  return s:sub(1,i-1)
end
function Home:keypressed(key)
  if key=="escape" then self.screen="home";self.focus=nil;return "back" end
  if self.focus then
    if key=="backspace" then self[self.focus]=removeLast(self[self.focus]) end
    if key=="v" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
      self:textinput(love.system.getClipboardText())
    end
    if key=="return" or key=="kpenter" then
      local from=self.focus
      self.focus=nil
      if from=="invite" then return "join" end
      if from=="serverAddress" then return "server_browse" end
      if from=="serverCode" then return "server_join" end
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
  elseif self.focus=="vpnIP" then
    chars=chars:gsub("[^%d%.]","")
    self.vpnIP=(self.vpnIP..chars):sub(1,15)
  elseif self.focus=="serverAddress" then
    chars=chars:gsub("[%c%s]","")
    self.serverAddress=(self.serverAddress..chars):sub(1,128)
  elseif self.focus=="serverCode" then
    chars=chars:gsub("[^%w%-]","")
    self.serverCode=(self.serverCode..chars):sub(1,64)
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
    printText(isAndroid and "Entre numa sala pelo IP." or "Crie sua sala somente se quiser.",612,325,20,C.green)
    printText(isAndroid and "Jogue com os amigos do Windows." or "Entre sozinho ou chame amigos.",612,363,18,C.muted)
    printText("Sem configurar um terminal.",612,406,17,C.muted)
  else
    button("back","< VOLTAR",false)
    if self.screen=="play" then
      printText("JOGAR",132,158,31,C.white)
      panel(130,194,505,402,C.panel,0)
      panel(672,194,477,402,C.panel,0)
      printText("01  CRIAR MINHA SALA",155,204,19,C.green)
      field("nickname",self.nickname,"Seu apelido",self.focus=="nickname")
      if isAndroid and not self.hosting and not self.starting then
        button("difficulty","DIFICULDADE: "..self.difficulty:upper(),false)
        button("mapChoice","MAPA: "..self.mapId:upper(),false)
        button("modsChoice","MOD: "..(self.modIds=="" and "DESLIGADO" or self.modIds:upper()),false)
        button("botsToggle",self.botsEnabled and "BOTS LIGADOS" or "BOTS DESLIGADOS",self.botsEnabled)
        button("botsMinus","-")
        printText("QUANTIDADE: "..(self.botsEnabled and self.botCount or 0).." / 8",
          274,485,17,C.white,225,"center")
        button("botsPlus","+")
        button("createLan","CRIAR SALA LUA",true)
      elseif self.hosting then
        printText(self.botsEnabled and self.botCount>0 and
          ("Sala criada - "..self.botCount.." bots ativos.")
          or "Sala criada - amigos podem entrar.",155,316,17,C.green)
        panel(155,351,462,51,C.raised,9)
        local invite=self:roomInvite()
        printText(invite,170,365,16,C.white,432,"center")
        button("roomCopy","COPIAR CONVITE",false)
        button("roomEnter","JOGAR AGORA",true)
        button("roomStop",isAndroid and "SAIR DA SALA" or "ENCERRAR",false)
      elseif self.starting then
        printText("Preparando sua sala...",155,331,18,C.green)
        printText("Voce escolheu criar esta sala.",155,383,16,C.muted)
        printText("Ninguem precisa abrir um terminal.",155,417,16,C.muted)
        printText(self.botsEnabled and
          ("Bots de IA: "..self.botCount) or "Bots desativados.",155,482,15,C.muted)
      else
        button("modeLan",self.serverMode=="lan" and "LAN ATIVA" or "LAN",self.serverMode=="lan")
        button("modeVpn",self.serverMode=="vpn" and "VPN ATIVA" or "VPN",self.serverMode=="vpn")
        if self.serverMode=="vpn" then
          field("vpnIP",self.vpnIP,"IP deste PC na VPN",self.focus=="vpnIP")
        end
        button("botsToggle",self.botsEnabled and "BOTS DE IA: LIGADOS" or
          "BOTS DE IA: DESLIGADOS",self.botsEnabled)
        button("botsMinus","-")
        printText("QUANTIDADE: "..(self.botsEnabled and self.botCount or 0).." / 8",
          274,485,17,C.white,225,"center")
        button("botsPlus","+")
        button(self.serverMode=="vpn" and "createVpn" or "createLan",
          "CRIAR MINHA SALA",true)
      end
      printText("02  ENTRAR EM OUTRA SALA",704,214,19,C.green)
      printText("Convite LAN/VPN ou HTTPS publico",704,256,15,C.muted)
      field("joinIP",self.invite,"IP:porta ou https://sala.dominio/CODIGO",self.focus=="invite")
      printText("Codigo de acesso (separado ou no convite)",704,340,14,C.muted)
      field("joinCode",self.joinCode,"Codigo da sala",self.focus=="joinCode")
      button("join","ENTRAR NA SALA",true)
      if not self.hosting and not self.starting then
        button("v2Login","ENTRAR NA CONTA V2 (NAVEGADOR)",false)
      end
      if self.error then
        button("joinRetry","TENTAR NOVAMENTE",false)
      else
        printText("HTTPS usa TLS validado; LAN/VPN mantem conexao original.",706,517,13,C.muted)
      end
    elseif self.screen=="server" then
      printText("SERVIDORES V2",140,157,31,C.white)
      printText("Consulte salas reais em LAN/VPN ou gateway HTTPS.",155,208,17,C.muted)
      field("serverAddress",self.serverAddress,
        "192.168.1.10:8080 ou https://v2.dominio.com",self.focus=="serverAddress")
      field("serverCode",self.serverCode,
        "Codigo da sala privada (se necessario)",self.focus=="serverCode")
      button("serverRefresh","BUSCAR SALAS",true)
      button("serverEnter","ENTRAR NA SALA",true)
      for row=1,4 do
        local index=self.serverPage*4+row
        local room=self.serverRooms[index]
        local yy=375+(row-1)*44
        panel(155,yy,974,40,room and index==self.serverSelected and C.raised or C.panel,0)
        if room then
          local capacity=tostring(room.players or 0).."/"..tostring(room.capacity or 0)
          local label=(room.online and "[ON] " or "[OFF] ")..
            tostring(room.name).."  |  "..capacity.."  |  "..tostring(room.preset)
          printText(label,170,yy+8,16,room.online and C.white or C.muted,940)
        elseif row==1 and #self.serverRooms==0 then
          printText("Informe o endereco e toque em BUSCAR SALAS.",174,yy+8,17,C.muted)
        end
      end
      button("serverPrev","ANTERIOR")
      button("serverNext","PROXIMO")
      printText("Pagina "..tostring(self.serverPage+1).."/"..
        tostring(math.max(1,math.ceil(#self.serverRooms/4))),481,573,17,C.muted,333,"center")
    else
      printText("CONFIGURACOES",336,190,31,C.white)
      button("grid","GRADE DO MAPA     "..(self.showGrid and "LIGADA" or "DESLIGADA"),false)
      button("fullscreen","TELA CHEIA       "..(self.fullscreen and "LIGADA" or "DESLIGADA"),false)
      printText("Convide amigos pela tela da sala ou pelo menu ESC.",360,477,16,C.muted)
      printText("ESC na partida: voltar e alterar as configuracoes.",360,505,16,C.muted)
    end
  end
  panel(83,614,1111,57,{0.13,0.17,0.15},0)
  local message=self.status~="" and self.status or
    (state=="joining" and "Entrando na partida..." or
     state=="keyed_transport" and "Servidor conectado. Carregando mundo..." or
     state=="failed" and tostring(detail) or
     "Jogar abre as opcoes. Criar sala e uma escolha.")
  if #message>135 then message=message:sub(1,132).."..." end
  love.graphics.setColor(self.error and C.red or C.green)
  love.graphics.rectangle("fill",92,625,5,35)
  printText(self.error and "ATENCAO" or "STATUS",111,627,13,
    self.error and C.red or C.green)
  printText(message,212,631,16,self.error and {1,0.85,0.77} or C.white,950)
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
