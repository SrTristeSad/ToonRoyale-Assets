-- SPDX-License-Identifier: AGPL-3.0-only
-- Headless UI smoke test; no connection to backend, no bots.
return function()
  local Home=require("src.game.mooio_home")
  love.window.setMode(1280,720,{resizable=false})
  local home=Home.new()
  assert(home.screen=="home")
  local Paths=require("src.net.mooio_paths")
  local realRoot,pathError=Paths.find(love.filesystem)
  assert(realRoot,pathError or "Diretorio do Moo IO nao encontrado")
  local source=love.filesystem.getSource()
  assert(realRoot==source or realRoot==love.filesystem.getSourceBaseDirectory() or
    realRoot==source.."/windows atualização" or
    realRoot==love.filesystem.getSourceBaseDirectory().."/windows atualização",
    "Scripts encontrados em pasta inesperada")
  assert(Paths.script(realRoot):find("scripts/start%-server%-lua%.ps1")~=nil)
  assert(home:click(640,310)=="play_tab","Jogar must open personal room")
  assert(home.screen=="play")
  assert(not home.starting and not home.hosting,"JOGAR only displays room options")
  assert(not home.botsEnabled,"Bots cannot turn on automatically")
  assert(home:click(210,446)=="configure")
  assert(home.screen=="create","room options must have their own screen")
  assert(home.mapId=="","new rooms must not auto-select a map requiring species mods")
  assert(#home.mapCatalog>=3,"built-in cave and cabin maps must be installed")
  assert(home:click(405,461)=="bots_toggle")
  assert(home.botsEnabled and home.botCount==2)
  assert(home:click(845,505)=="bots_count" and home.botCount==3)
  assert(home:click(402,505)=="bots_count" and home.botCount==2)
  assert(home.difficulty=="normal")
  assert(home:click(400,413)=="difficulty" and home.difficulty=="dificil")
  assert(home:click(400,373)=="difficulty" and home.difficulty=="pacifico")
  assert(home:click(745,373)=="difficulty" and home.difficulty=="normal")
  assert(home:click(745,413)=="difficulty" and home.difficulty=="extremo")
  assert(home:click(560,608)=="map_browse" and home.screen=="maps")
  -- Same as mods: selecting a map enables it; clicking again disables.
  local firstId=assert(home.mapCatalog[1]).id
  assert(home:click(690,256)=="map_toggle" and home.mapId==firstId,
    "one click must activate selected map")
  assert(home:click(690,256)=="map_toggle" and home.mapId=="",
    "second click must disable it without a special disable row")
  assert(home:click(820,656)=="maps_done" and home.screen=="create")
  home:refreshMaps()
  assert(home.mapId=="","F5 refresh silently re-enabled a disabled map")
  assert(home:mapName()=="Mapa desativado")
  assert(home:click(560,608)=="map_browse" and home.screen=="maps")
  -- A mod map is selectable without allowing an invalid host to crash:
  -- its exact required custom species are resolved from installed mods.
  local creatureMap
  for i,m in ipairs(home.mapCatalog) do
    if m.id=="reserva-criaturas" then
      creatureMap={page=math.floor((i-1)/6),row=(i-1)%6+1}
      break
    end
  end
  assert(creatureMap,"mod map must be discoverable alongside bundled maps")
  home.mapPage=creatureMap.page
  assert(home:click(690,249+(creatureMap.row-1)*64)=="map_toggle")
  assert(home.mapId=="reserva-criaturas" and home.modIds:find("novas-especies",1,true),
    "selecting creature map must enable its mandatory mod automatically")
  assert(home:checkMapMods(false)==true)
  home.screen="create"
  home.modIds=""
  assert(home:checkMapMods(false)==false,
    "disabling a required species mod must prevent creating an invalid room")
  assert(home:checkMapMods(true) and home.modIds=="novas-especies",
    "room creation should recover missing map dependencies")
  -- Return to the bundled caves without leaving the species mod forced on.
  home.modIds=""
  home.screen="maps";home.mapPage=0
  local sawCave=false
  for i,m in ipairs(home.mapCatalog) do
    if m.id=="bunker-e-cavernas" then
      home.mapPage=math.floor((i-1)/6)
      sawCave=home:click(690,256+64*((i-1)%6))=="map_toggle"
      break
    end
  end
  assert(sawCave and home:mapName()=="Bunker e Cavernas",
    "cave map must be a labeled selectable option")
  -- Both the active-green state and click-again deselection match mod UI.
  local currentRow
  for i,map in ipairs(home.mapCatalog) do
    if map.id=="bunker-e-cavernas" then
      currentRow=(i-1)%6+1
      break
    end
  end
  assert(home:click(690,250+(currentRow-1)*64)=="map_toggle"
    and home.mapId=="","selected cave must be deselectable in one click")
  assert(home:click(690,250+(currentRow-1)*64)=="map_toggle"
    and home.mapId=="bunker-e-cavernas","reselect must restore the same map")
  assert(home:click(820,656)=="maps_done" and home.screen=="create")
  assert(home:click(555,560)=="mod_browse")
  assert(home.screen=="mods" and #home.modCatalog>=4,
    "mod installer list should show bundled data-only mods")
  local toggle=home.modCatalog[1].id
  assert(home:click(180,260)=="mod_toggle",
    "installed mod must be selectable without entering its ID")
  assert(home.modIds:find(toggle,1,true)~=nil,
    "mod picker selection must be forwarded to room configuration")
  assert(home:click(862,656)=="mods_done" and home.screen=="create")
  assert(home:click(450,260)=="mode_lan")
  assert(home:click(755,260)=="mode_vpn")
  assert(home.serverMode=="vpn")
  assert(home:click(750,660)=="create","VPN room must be created explicitly")
  home.screen="play"
  home.hosting=true;home.hostAddress="192.168.1.7:8080";home.hostCode="abcd1234567890"
  assert(home:roomInvite()=="192.168.1.7:8080/abcd1234567890")
  assert(home:click(175,440)=="copy","host must have invitation sharing")
  assert(home:click(180,505)=="play_local","host must be able to play")
  assert(home:click(409,505)=="stop","host must be able to close the room")
  home.hosting=false
  assert(home:click(716,306)=="focus")
  home:textinput("100.80.12.34:8080")
  assert(home.invite=="100.80.12.34:8080")
  assert(home:click(715,385)=="focus")
  home:textinput("some-secret-code")
  assert(home:click(721,452)=="join","IP join button must work")
  assert(home:click(765,575)=="v2_login","V2 account login must be selectable")
  local full,err=Home.parseInvite(home.invite,home.joinCode)
  assert(full and full.host=="100.80.12.34" and full.port==8080 and full.code=="some-secret-code", "invite="..tostring(home.invite).." code="..tostring(home.joinCode).." result="..tostring(full and full.host).." reason="..tostring(err))
  local direct=assert(Home.parseInvite("192.168.0.12:8080/abcdefgh"))
  assert(direct.host=="192.168.0.12")
  assert(Home.parseInvite("8.8.8.8:8080/abcdefgh")==nil,"public IP not authorized")
  local secure=assert(Home.parseInvite("https://normal.play.example.org/abcdefgh12345678"))
  assert(secure.secure and secure.host=="normal.play.example.org" and secure.port==443,
    "V2 HTTPS invites must be accepted")
  home.roomOverlay=true
  assert(home:overlayClick(600,412)=="copy","Invite overlay must copy")
  assert(home:overlayClick(902,191)=="close_overlay","overlay must close")
  assert(home:click(1121,110)=="back")
  assert(home:click(640,386)=="server_tab")
  assert(home:click(210,286)=="focus",
    "server screen must offer a dedicated IP:port field")
  home:textinput("192.168.1.50:8080")
  assert(home.serverAddress=="192.168.1.50:8080")
  assert(home:click(860,281)=="server_browse",
    "server screen must expose a read-only room directory query")
  home.serverRooms={{id="arena",name="Arena",preset="custom",
    port=8090,players=2,capacity=40,online=true,publicAccess=false}}
  assert(home:click(180,356)=="server_select")
  assert(home.serverSelected==1)
  assert(home:click(850,535)=="focus")
  home:textinput("codigo-da-sala")
  assert(home.serverCode=="codigo-da-sala")
  assert(home:click(850,593)=="server_join",
    "client must select a listed V2 room before connecting")
  assert(home.provider==nil,"the local game cannot create a V2 server")
  assert(home:click(1121,110)=="back")
  assert(home:click(485,482)=="settings_tab")
  assert(home:click(453,300)=="grid")
  assert(home.showGrid==false)
  assert(home:click(445,390)=="fullscreen")
  assert(home:click(450,480)=="edit_controls",
    "Settings should open the keyboard and joystick editor")
  assert(home:keypressed("f2")==nil,
    "F2 is no longer a shortcut to copy invitation")
  -- Regression for the giant black stripe circled in the Windows screenshot.
  -- A flat, known world colour MUST stay uniform above/under the title;
  -- otherwise the menu has accidentally drawn another full-width panel.
  local panorama=love.graphics.newCanvas(1280,720)
  love.graphics.push("all")
  love.graphics.setCanvas(panorama)
  love.graphics.clear(0.48,0.60,0.70,1)
  home.screen="home"
  home:draw("idle","",true)
  love.graphics.setCanvas()
  local pixels=panorama:newImageData()
  local function colourDiff(ax,ay,bx,by)
    local ar,ag,ab=pixels:getPixel(ax,ay)
    local br,bg,bb=pixels:getPixel(bx,by)
    return math.abs(ar-br)+math.abs(ag-bg)+math.abs(ab-bb)
  end
  assert(colourDiff(22,245,22,267)<0.04,
    "Home still draws the opaque banner behind the logo")
  assert(colourDiff(22,22,22,62)<0.04,
    "Home still renders an extra top banner")
  assert(colourDiff(27,652,27,675)<0.04,
    "Home still paints a thick bottom banner")
  love.graphics.pop()
  panorama:release()
  -- Render each page to an offscreen canvas to catch graphical/layout crashes.
  local canvas=love.graphics.newCanvas(1280,720)
  love.graphics.setCanvas(canvas)
  for _,page in ipairs({"home","play","create","mods","server","settings"}) do
    home.screen=page
    home:draw("idle","")
    love.graphics.setCanvas()
    local frame=canvas:newImageData()
    local _,_,_,opacity=frame:getPixel(140,300)
    assert(opacity>0.95, "screen "..page.." did not render an opaque UI")
    if os.getenv("MOO_IO_CAPTURE_UI")=="1" then
      local file="ui-"..page..".png"
      frame:encode("png",file)
      print("UI CAPTURE "..file.." -> "..love.filesystem.getSaveDirectory())
    end
    love.graphics.setCanvas(canvas)
  end
  home.screen="play"
  home.roomOverlay=true
  home:draw("idle","")
  home:drawRoomOverlay()
  love.graphics.setCanvas()
  if os.getenv("MOO_IO_CAPTURE_UI")=="1" then
    canvas:newImageData():encode("png","ui-invite-overlay.png")
  end
  home.roomOverlay=false
  love.graphics.setCanvas()
  canvas:release()
  -- All title and submenus share keyboard/controller-friendly navigation.
  home.screen="home";home.navScreen=nil;home.navIndex=0
  assert(home:keypressed("tab")=="navigate" and home.navIndex==1)
  assert(home:keypressed("return")=="play_tab" and home.screen=="play")
  home.screen="server";home.focus="serverAddress"
  assert(home:keypressed("tab")=="navigate" and home.focus==nil,
    "Tab must release an active text field to navigate PC menus")
  print("MOO IO MENU PASS: salas locais, convite, LAN/VPN, opcoes e nenhuma entrada V2")
end
