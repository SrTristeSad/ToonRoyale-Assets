-- SPDX-License-Identifier: AGPL-3.0-only
-- Moo IO: LAN/VPN rooms are hosted by the bundled Lua server.
-- Gameplay authority lives in the bundled LOCAL Lua room; no client-side fake world.
local Network=require("src.net.mooio_network")
local Mods=require("server-lua.world.room_mods")
local Maps=require("server-lua.world.map_profiles")
local Deps=require("server-lua.world.map_dependencies")
local UI=require("src.game.pc_menu_style")
local Home={}
Home.__index=Home

-- Stone, soil and grass: block-game-inspired original interface. No copied textures.
local C={
 bg={0.11,0.12,0.115},panel={0.21,0.23,0.22},
 raised={0.30,0.34,0.30},border={0.07,0.09,0.08},
 green={0.68,0.82,0.61},greenDark={0.10,0.19,0.12},
 white={0.97,0.97,0.96},muted={0.80,0.83,0.80},
 amber={1,0.84,0.38},red={0.98,0.54,0.45}
}
local function panel(x,y,w,h,color) UI.panel(x,y,w,h,color or C.panel) end
local function printText(t,x,y,size,color,w,align)
 UI.text(t,x,y,size,color or C.white,w,align)
end
local function inside(x,y,b)
  return x>=b[1] and y>=b[2] and x<b[1]+b[3] and y<b[2]+b[4]
end
local hostedBoxes={
  nickname={425,229,430,51},roomCopy={425,389,430,54},
  roomEnter={425,462,210,55},roomStop={645,462,210,55}
}
local boxes={
  back={1041,93,171,45},
  homePlay={360,278,560,64},homeServers={360,354,560,64},
  homeSettings={360,452,266,58},homeQuit={654,452,266,58},
  nickname={155,216,462,52},modeLan={155,312,223,46},
  modeVpn={393,312,224,46},vpnIP={155,368,462,46},
  createLan={155,623,462,53},createVpn={155,623,462,53},
  difficulty={155,524,302,47},mapBrowse={468,524,149,47},modIds={155,577,302,39},
  modBrowse={468,577,149,39},modsPrevious={160,638,240,39},
  modsNext={419,638,240,39},modsDone={730,638,365,39},
  botsToggle={155,423,462,39},botsMinus={155,475,110,42},
  botsPlus={508,475,109,42},
  roomCopy={155,419,462,55},roomEnter={155,485,226,55},
  roomStop={392,485,225,55},
  joinIP={704,267,421,51},joinCode={704,339,421,51},
  join={704,410,421,54},joinRetry={704,486,421,49},
  v2Login={704,537,421,38},
  serverAddress={150,260,600,50},serverRefresh={768,260,335,50},
  serverCode={773,513,326,49},serverEnter={773,573,326,51},
  serverPrev={150,633,260,42},serverNext={448,633,260,42},
  grid={355,280,570,57},fullscreen={355,364,570,57},
  controls={355,447,570,57},
  hudSizeLess={430,231,87,47},hudSizeMore={765,231,87,47},
  hudOpacityLess={430,298,87,47},hudOpacityMore={765,298,87,47},
  hudMoveLess={430,365,87,47},hudMoveMore={765,365,87,47},
  hudFireLess={430,432,87,47},hudFireMore={765,432,87,47},
  hudDeadLess={430,499,87,47},hudDeadMore={765,499,87,47},
  hudReset={430,574,422,49},
  overlayCopy={478,395,322,55},overlayClose={880,177,55,43},
  playConfigure={155,398,462,63},
  -- One compact, centred setup panel. No giant map preview.
  chooseLan={367,226,265,40},chooseVpn={645,226,265,40},
  createVpnIP={367,275,543,34},
  easyDiff={367,338,265,35},normalDiff={645,338,265,35},
  hardDiff={367,380,265,35},extremeDiff={645,380,265,35},
  createBots={367,424,543,36},createBotsMinus={367,469,107,37},
  createBotsPlus={803,469,107,37},
  createMods={367,519,543,43},
  chooseMapNext={367,569,543,43},
  createBack={367,624,191,34},createSubmit={569,624,341,34}
}
local function button(id,text,primary,hosted)
 local box=hosted and hostedBoxes[id] or boxes[id]
 local mx,my=love.mouse.getPosition()
 local w,h=love.graphics.getDimensions()
 local z=math.min(w/1280,h/720)
 mx=(mx-(w-1280*z)/2)/z
 my=(my-(h-720*z)/2)/z
 UI.button(box[1],box[2],box[3],box[4],text,false,primary,inside(mx,my,box))
end
local function field(id,value,placeholder,focused,hosted)
 local b=hosted and hostedBoxes[id] or boxes[id]
 UI.field(b[1],b[2],b[3],b[4],value,placeholder,focused)
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
    mapId="",mapCatalog=maps,
    mapPage=0,focus=nil,navIndex=0,
    serverAddress="",serverCode="",serverRooms={},serverDirectory=nil,
    serverPage=0,serverSelected=1,
    status="",statusScreen=nil,error=false,hosting=false,starting=false,
    hostAddress="",hostCode="",connectionState="idle",serverLog="",
    showGrid=true,fullscreen=false,sessionTitle="",
    roomOverlay=false,botsEnabled=false,botCount=2,
    hudScale=1.20,hudOpacity=.90,moveScale=1,fireScale=1,deadzone=.15
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
   math.max(0,math.ceil(#self.mapCatalog/6)-1))
 self.modPage=math.min(self.modPage,
   math.max(0,math.ceil(#self.modCatalog/6)-1))
 self:setStatus(#self.mapCatalog.." mapas e "..
   #self.modCatalog.." mods de regras encontrados.")
end
-- Resolve map-specific mob dependencies before any server process is started.
-- All lookups use validated metadata from the installed JSON manifests.
function Home:checkMapMods(auto)
 if self.mapId=="" or self.mapId=="classico" then return true end
 local map
 for _,entry in ipairs(self.mapCatalog) do
  if entry.id==self.mapId then map=entry;break end
 end
 if not map then return false,"Mapa nao instalado. Escolha outro na lista." end
 local ok,selected=pcall(Mods.ids,self.modIds)
 if not ok then return false,"Lista de mods invalida." end
 local nextIds,err,added=Deps.resolve(map,selected,self.modCatalog,8)
 if not nextIds then return false,err end
 if #added>0 then
  if not auto then
   return false,"O mapa exige mod: "..table.concat(added,", ")
  end
  self.modIds=table.concat(nextIds,",")
  self:setStatus("Mod necessario ativado: "..table.concat(added,", "))
 end
 return true
end
function Home:roomInvite()
  if self.hostAddress=="" or self.hostCode=="" then return "" end
  return self.hostAddress.."/"..self.hostCode
end
function Home:setStatus(t,err)
  self.status=tostring(t or "")
  self.statusScreen=self.screen
  self.error=err==true
end
function Home:click(sx,sy)
  local x,y=self:scale(sx,sy)
  if self.screen~="home" and inside(x,y,boxes.back) then
    self.screen=(self.screen=="hud" and "settings"
      or self.screen=="mods" and "create"
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
    if self.hosting then
      if inside(x,y,hostedBoxes.nickname) then
        self.focus="nickname";return "focus"
      end
      if inside(x,y,hostedBoxes.roomCopy) then
        self.focus=nil;return "copy"
      end
      if inside(x,y,hostedBoxes.roomEnter) then
        self.focus=nil;return "play_local"
      end
      if inside(x,y,hostedBoxes.roomStop) then
        self.focus=nil;return "stop"
      end
      self.focus=nil
      return nil
    end
    -- While the Lua server is starting, the visitor connection form is hidden
    -- and its old hitboxes must NOT remain clickable.
    if self.starting then self.focus=nil;return nil end
    if inside(x,y,boxes.nickname) then self.focus="nickname";return "focus" end
    if inside(x,y,boxes.joinIP) then self.focus="invite";return "focus" end
    if inside(x,y,boxes.joinCode) then self.focus="joinCode";return "focus" end
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
    if inside(x,y,boxes.chooseMapNext) then
      self.screen="maps";self.mapPage=0;self.focus=nil
      return "map_browse"
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
      local valid,reason=self:checkMapMods(true)
      if not valid then
        self:setStatus(reason,true)
        return "map_mod_required"
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
      self.mapPage=math.min(math.max(0,math.ceil(#self.mapCatalog/6)-1),
        self.mapPage+1);return "map_page"
    end
    for row=1,6 do
      local entry=self.mapCatalog[self.mapPage*6+row]
      if entry and inside(x,y,{151,242+(row-1)*64,976,57}) then
        -- Mod-like toggle: one active map, second click unchecks it.
        if self.mapId==entry.id then
          self.mapId=""
          self:setStatus("Mapa desativado. Mundo classico ativo.")
          return "map_toggle"
        end
        local previous=self.mapId
        self.mapId=entry.id
        local valid,reason=self:checkMapMods(true)
        if not valid then
          self.mapId=previous
          self:setStatus(reason,true)
          return "map_mod_required"
        end
        self:setStatus("Mapa ativado: "..entry.name)
        return "map_toggle"
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
  elseif self.screen=="hud" then
    local steps={
      {"hudSizeLess","hudScale",-.10,.85,1.55},{"hudSizeMore","hudScale",.10,.85,1.55},
      {"hudOpacityLess","hudOpacity",-.10,.50,1},{"hudOpacityMore","hudOpacity",.10,.50,1},
      {"hudMoveLess","moveScale",-.10,.75,1.50},{"hudMoveMore","moveScale",.10,.75,1.50},
      {"hudFireLess","fireScale",-.10,.75,1.50},{"hudFireMore","fireScale",.10,.75,1.50},
      {"hudDeadLess","deadzone",-.025,.05,.30},{"hudDeadMore","deadzone",.025,.05,.30}
    }
    for _,step in ipairs(steps) do
      if inside(x,y,boxes[step[1]]) then
        self[step[2]]=math.floor(math.max(step[4],math.min(step[5],self[step[2]]+step[3]))*1000+.5)/1000
        return "hud_changed"
      end
    end
    if inside(x,y,boxes.hudReset) then
      self.hudScale=1.20;self.hudOpacity=.90;self.moveScale=1
      self.fireScale=1;self.deadzone=.15
      return "hud_changed"
    end
  end
  return nil
end
local function removeLast(s)
  local i=#s
  while i>1 and s:byte(i)>=128 and s:byte(i)<192 do i=i-1 end
  return s:sub(1,i-1)
end
-- Tab/arrows and Enter use the same hitboxes as the mouse/gamepad.
-- Never create a second navigation or server-connection code path.
function Home:navTargets()
 local ids={}
 if self.screen=="home" then
  ids={"homePlay","homeServers","homeSettings","homeQuit"}
 elseif self.screen=="play" then
  ids=self.hosting and {"nickname","roomCopy","roomEnter","roomStop","back"}
    or self.starting and {"back"}
    or {"nickname","playConfigure","joinIP","joinCode","join","v2Login","back"}
 elseif self.screen=="create" then
  ids={"chooseLan","chooseVpn","easyDiff","normalDiff",
   "hardDiff","extremeDiff","createBots","createBotsMinus",
   "createBotsPlus","createMods","chooseMapNext","createSubmit",
   "createBack","back"}
  if self.serverMode=="vpn" then table.insert(ids,3,"createVpnIP") end
 elseif self.screen=="server" then
  ids={"serverAddress","serverRefresh"}
  for i=1,4 do
   local row=self.serverRooms[self.serverPage*4+i]
   if row then ids[#ids+1]={155,332+(i-1)*70,565,62} end
  end
  ids[#ids+1]="serverCode";ids[#ids+1]="serverEnter"
  ids[#ids+1]="serverPrev";ids[#ids+1]="serverNext";ids[#ids+1]="back"
 elseif self.screen=="maps" or self.screen=="mods" then
  local total=self.screen=="maps" and #self.mapCatalog or #self.modCatalog
  local page=self.screen=="maps" and self.mapPage or self.modPage
  for i=1,6 do
   if page*6+i<=total then
    ids[#ids+1]={151,242+(i-1)*64,976,57}
   end
  end
  ids[#ids+1]="modsPrevious";ids[#ids+1]="modsNext"
  ids[#ids+1]="modsDone";ids[#ids+1]="back"
 elseif self.screen=="settings" then
  ids={"grid","fullscreen","controls","back"}
 end
 local rects={}
 for _,id in ipairs(ids) do
  if type(id)=="table" then rects[#rects+1]=id
  elseif self.hosting and self.screen=="play" and hostedBoxes[id] then
    rects[#rects+1]=hostedBoxes[id]
  elseif boxes[id] then rects[#rects+1]=boxes[id] end
 end
 return rects
end
function Home:keyboardNavigate(key)
 if self.navScreen~=self.screen then
  self.navScreen=self.screen
  self.navIndex=0
 end
 local rects=self:navTargets()
 if #rects==0 then return nil end
 if key=="tab" or key=="down" or key=="up" then
  local direction=key=="up" and -1 or 1
  if not self.navIndex or self.navIndex==0 then
   self.navIndex=direction<0 and #rects or 1
  else
   self.navIndex=((self.navIndex-1+direction)%#rects)+1
  end
  local b=rects[self.navIndex]
  local w,h=love.graphics.getDimensions()
  local z=math.min(w/1280,h/720)
  local x=(w-1280*z)/2+(b[1]+b[3]/2)*z
  local y=(h-720*z)/2+(b[2]+b[4]/2)*z
  if love.mouse.setPosition then love.mouse.setPosition(x,y) end
  return "navigate"
 end
 if key=="return" or key=="kpenter" then
  if not self.navIndex or self.navIndex==0 then self.navIndex=1 end
  local b=rects[self.navIndex]
  if b then
   local w,h=love.graphics.getDimensions()
   local z=math.min(w/1280,h/720)
   return self:click((w-1280*z)/2+(b[1]+b[3]/2)*z,
      (h-720*z)/2+(b[2]+b[4]/2)*z)
  end
 end
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
    if key=="tab" then
      self.focus=nil
      return self:keyboardNavigate(key)
    end
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
  if key=="tab" or key=="up" or key=="down"
    or key=="return" or key=="kpenter" then
    local action=self:keyboardNavigate(key)
    if action then return action end
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
local function decorate(showWorld,isHome) UI.backdrop(showWorld,isHome) end
local titles={
 play={"JOGAR","Crie sua sala ou entre na partida de um amigo"},
 create={"CRIAR NOVA SALA","Conexao, dificuldade, jogadores e conteudo"},
 maps={"SELECIONAR MAPA","Escolha um mundo instalado"},
 mods={"PACOTES E MODS","Ative as modificacoes instaladas"},
 server={"MULTIPLAYER","Procure salas no servidor dedicado"},
 settings={"OPCOES","Personalize video e controles"}
}
function Home:draw(state,detail,showWorld)
  self.connectionState=state or self.connectionState
  love.graphics.push("all")
  local w,h=love.graphics.getDimensions()
  local z=math.min(w/1280,h/720)
  love.graphics.translate((w-1280*z)/2,(h-720*z)/2)
  love.graphics.scale(z)
  decorate(showWorld,self.screen=="home")
  if self.screen=="home" then
    -- The backdrop must be a continuous view of the world, not a huge
    -- opaque banner cutting across trees, river and other scenery.
    -- Text gets its OWN shadow, keeping contrast without a rectangular band.
    printText("MOO IO",364,94,90,{0.005,0.012,0.01,0.91},560,"center")
    printText("MOO IO",358,89,90,{0.005,0.012,0.01,0.66},560,"center")
    printText("MOO IO",360,89,90,C.white,560,"center")
    printText("SEU MUNDO, SEUS AMIGOS",362,223,19,{0.015,0.027,0.020,0.88},560,"center")
    printText("SEU MUNDO, SEUS AMIGOS",360,221,19,C.white,560,"center")
    button("homePlay","JOGAR",false)
    button("homeServers","MULTIPLAYER",false)
    button("homeSettings","OPCOES",false)
    button("homeQuit","SAIR DO JOGO",false)
    printText("Moo-IO  |  Windows Lua",22,683,16,{0,0,0,0.85},470)
    printText("Moo-IO  |  Windows Lua",20,681,16,C.white,470)
    printText("LAN  |  VPN  |  V2",829,683,16,{0,0,0,0.85},433,"right")
    printText("LAN  |  VPN  |  V2",827,681,16,C.white,433,"right")
    love.graphics.pop()
    return
  end
  local pageTitle=titles[self.screen] or titles.play
  if self.screen=="play" then
    if self.hosting then
      pageTitle={"MINHA SALA","Servidor ativo. Jogue ou compartilhe o convite."}
    elseif self.starting then
      pageTitle={"CRIANDO SALA","Inicializando o servidor Lua local."}
    end
  end
  UI.topbar(pageTitle[1],pageTitle[2])
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
      if self.hosting then
        -- Host view is distinct from Join view. No connection form appears
        -- after room creation, including when the host returns after death.
        panel(397,173,486,415,C.panel)
        printText("SUA SALA ESTA ATIVA",425,190,24,C.green,430,"center")
        field("nickname",self.nickname,"Seu apelido",
          self.focus=="nickname",true)
        printText(self.botsEnabled and self.botCount>0
            and (self.botCount.." bots ativos; convide seus amigos.")
            or "Sua sala continua aberta para seus amigos.",
            425,298,16,C.muted,430,"center")
        printText("CONVITE DA SALA",425,334,14,C.green,430,"center")
        printText(UI.oneLine(self:roomInvite(),418,16),
          425,360,16,C.white,430,"center")
        button("roomCopy","COPIAR CONVITE",false,true)
        button("roomEnter","JOGAR AGORA",true,true)
        button("roomStop","ENCERRAR SALA",false,true)
        printText("Se morrer, JOGAR AGORA renasce nesta mesma sala.",
          404,542,14,C.muted,473,"center")
      elseif self.starting then
        -- Do not render visitor fields while the room is booting. Only the
        -- creation status is shown, even if startup takes several seconds.
        panel(397,173,486,415,C.panel)
        printText("PREPARANDO SUA SALA",425,190,24,C.green,430,"center")
        printText("Inicializando o servidor Lua local...",425,266,18,C.white,430,"center")
        printText("Carregando mundo, bots, mapas e mods.",425,313,16,C.muted,430,"center")
        printText("Nao precisa conectar ao proprio servidor.",425,360,16,C.muted,430,"center")
        printText("O convite aparecera quando a sala estiver pronta.",
          425,415,15,C.muted,430,"center")
      else
      panel(130,174,505,493,C.panel,0)
      panel(672,174,477,402,C.panel,0)
      printText("01  CRIAR MINHA SALA",155,184,19,C.green)
      field("nickname",self.nickname,"Seu apelido",self.focus=="nickname")
      printText("Configure mapa, dificuldade e mods",158,310,17,C.muted,449)
        printText("MAPA SELECIONADO:",158,347,15,C.green)
        printText(self:mapName(),158,369,21,C.white,440)
        button("playConfigure","CONFIGURAR MINHA SALA",true)
        panel(155,484,462,118,C.raised,0)
        printText("DIFICULDADE  "..self.difficulty:upper(),172,500,17,C.white,412)
        printText("BOTS: "..(self.botsEnabled and self.botCount or 0)
          .."     |     MODS: "..(self.modIds=="" and "NENHUM" or "PERSONALIZADOS"),
          172,534,15,C.muted,425)
        printText("Clique em CONFIGURAR para criar a partida.",172,568,14,C.amber,422)
      printText("02  CONECTAR A OUTRA SALA",704,194,19,C.green)
      printText("IP, porta ou convite completo",704,236,15,C.muted)
      field("joinIP",self.invite,"192.168.1.5:8080",self.focus=="invite")
      printText("Codigo de acesso (separado ou no convite)",704,320,14,C.muted)
      field("joinCode",self.joinCode,"Codigo da sala",self.focus=="joinCode")
      button("join","ENTRAR NA SALA",true)
      if self.error then
        button("joinRetry","TENTAR NOVAMENTE",false)
      else
        printText("Convite LAN/VPN ou HTTPS V2 com certificado valido.",706,497,15,C.muted)
      end
      button("v2Login","ENTRAR COM CONTA V2 (NAVEGADOR)",false)
      end
    elseif self.screen=="create" then
      printText("F5: atualizar mapas e mods",367,160,13,C.amber,543,"center")
      panel(344,182,591,482,C.panel,0)
      printText("CONEXAO",367,195,15,C.green)
      button("chooseLan",self.serverMode=="lan" and "LAN ATIVA" or "LAN",self.serverMode=="lan")
      button("chooseVpn",self.serverMode=="vpn" and "VPN ATIVA" or "VPN",self.serverMode=="vpn")
      if self.serverMode=="vpn" then
        field("createVpnIP",self.vpnIP,"IP do computador na VPN",self.focus=="vpnIP")
      else
        printText("Amigos na mesma rede local.",367,280,15,C.muted,543,"center")
      end
      printText("DIFICULDADE",367,317,14,C.green)
      local opts={{"easyDiff","PACIFICO","pacifico"},
        {"normalDiff","NORMAL","normal"},{"hardDiff","DIFICIL","dificil"},
        {"extremeDiff","EXTREMO","extremo"}}
      for _,o in ipairs(opts) do button(o[1],o[2],o[3]==self.difficulty) end
      button("createBots",self.botsEnabled and "BOTS: ATIVADOS" or "BOTS: DESATIVADOS",self.botsEnabled)
      button("createBotsMinus","-")
      printText("QUANTIDADE "..(self.botsEnabled and self.botCount or 0).."/8",
        474,475,17,C.white,329,"center")
      button("createBotsPlus","+")
      button("createMods",self.modIds=="" and "MODS: NENHUM - ESCOLHER" or "MODS: PERSONALIZADOS - EDITAR",false)
      button("chooseMapNext",self.mapId=="" and "MAPA: DESATIVADO - ESCOLHER"
        or "MAPA: "..self:mapName().." - EDITAR",false)
      button("createBack","CANCELAR",false)
      button("createSubmit","CRIAR SALA",true)
    elseif self.screen=="maps" then
      printText("Clique para ativar; clique novamente para desmarcar o mapa.",145,213,15,C.muted)
      for row=1,6 do
        local i=self.mapPage*6+row
        local entry=self.mapCatalog[i]
        if entry then
          local y=242+(row-1)*64
          local active=entry.id==self.mapId
          UI.listRow(151,y,976,57,entry.name,entry.description,active,false)
        end
      end
      button("modsPrevious","ANTERIOR",false)
      button("modsNext","PROXIMOS",false)
      button("modsDone","CONCLUIR",true)
    elseif self.screen=="mods" then
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
          UI.listRow(151,y,976,57,mod.name,mod.description,on,false)
        end
      end
      button("modsPrevious","ANTERIOR",false)
      button("modsNext","PROXIMOS",false)
      button("modsDone","VOLTAR PARA SALA",true)
    elseif self.screen=="server" then
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
            local mode=room.preset=="traditional" and "Tradicional" or "Personalizada"
            local status=room.online and "Online" or "Offline"
            UI.listRow(155,y,565,62,room.name,
              mode.." | "..status.." | "..room.players.."/"..room.capacity..
              " jogadores",index==self.serverSelected,false)
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
      button("grid","GRADE DO MAPA     "..(self.showGrid and "LIGADA" or "DESLIGADA"),false)
      button("fullscreen","TELA CHEIA       "..(self.fullscreen and "LIGADA" or "DESLIGADA"),false)
      button("controls","EDITAR TECLADO E JOYSTICK",false)
      printText("Remapeie botoes e analogicos, altere a sensibilidade.",360,537,16,C.muted)
    end
  end
  panel(83,684,1111,34,{0.13,0.17,0.15},0)
  local currentStatus=self.status~="" and self.statusScreen==self.screen
  local help={
   play="Crie sua sala ou entre usando o convite de um amigo.",
   create="Escolha o mundo, a dificuldade e os mods; depois crie a sala.",
   maps="Mapas extras sao opcionais. Veja os requisitos antes de selecionar.",
   mods="Ative ou desative mods. Algumas especies dependem de um pacote.",
   server="Informe o endereco do servidor e selecione uma sala.",
   settings="Ajuste a imagem e personalize os controles do joystick."
  }
  local message=currentStatus and self.status or
    (state=="joining" and "Entrando na partida..." or
     state=="keyed_transport" and "Servidor conectado. Carregando mundo..." or
     state=="failed" and tostring(detail) or
     help[self.screen] or "Selecione uma opcao para comecar.")
  message=UI.oneLine(message,950,15)
  love.graphics.setColor(currentStatus and self.error and C.red or C.green)
  love.graphics.rectangle("fill",92,689,5,22)
  printText(currentStatus and self.error and "ATENCAO" or "STATUS",111,692,13,
    currentStatus and self.error and C.red or C.green)
  printText(message,212,691,15,currentStatus and self.error and {1,0.85,0.77} or C.white,950)
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
