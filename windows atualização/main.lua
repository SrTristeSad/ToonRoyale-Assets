-- Windows Moo IO client + dedicated LOCAL Lua server in one LÖVE package.
-- All gameplay is authoritative via genuine C/D/a/H/I server packets.
-- MOO_IO_LUA_SERVER=1 selects the bundled headless server process.
if os.getenv("MOO_IO_LUA_SERVER")=="1" then
  if not utf8 then utf8=require("utf8") end
  local instance
  function love.load()
    local Local=require("server-lua.local_server")
    local Socket=require("socket")
    local ip=assert(os.getenv("MOO_IO_BIND_IP"),"MOO_IO_BIND_IP required")
    local code=assert(os.getenv("MOO_IO_ROOM_CODE"),"MOO_IO_ROOM_CODE required")
    local created,server=pcall(Local.new,{
      bind=ip,port=tonumber(os.getenv("PORT")) or 8080,
      mode=os.getenv("MOO_IO_NETWORK_MODE")=="vpn" and "vpn" or "lan",
      roomCode=code,botCount=os.getenv("MOO_IO_BOT_COUNT") or "0",
      dataDir=os.getenv("MOO_IO_LUA_DATA_DIR") or "server-lua/data",
      difficulty=os.getenv("MOO_IO_DIFFICULTY") or "normal",
      modIds=os.getenv("MOO_IO_MODS") or "",
      mapId=os.getenv("MOO_IO_MAP_ID") or "",
      guiHost=true,nowMs=function()return math.floor(Socket.gettime()*1000)end,
      log=function(msg)print(msg)end
    })
    if not created then
      -- A missing mod or invalid map must never open the blue LÖVE crash
      -- window; the hosting client's watchdog displays this log instead.
      print("MOOIO_LUA_SERVER_ERROR: "..tostring(server):gsub("[\r\n]"," "))
      love.event.quit(1)
      return
    end
    instance=server
    local ok,why=instance:start()
    if not ok then
      print("MOOIO_LUA_SERVER_ERROR: "..tostring(why):gsub("[\r\n]"," "))
      love.event.quit(1)
      return
    end
    print("MOOIO_LUA_SERVER_READY")
  end
function love.update(dt)
    if instance and instance:update()==false then love.event.quit(0) end
  end
  function love.draw() end
  function love.quit()if instance then instance:close()end end
  return
end

local Original=require("src.net.original_client")
local World=require("src.game.world_state")
local View=require("src.game.reference_view")
local Menu=require("src.game.reference_menu")
local Home=require("src.game.mooio_home")
local Pause=require("src.game.mooio_pause")
local Host=require("src.net.mooio_host")
local Auth=require("src.net.local_auth")
local BrowserAuth=require("src.net.browser_auth")
local Directory=require("src.net.server_directory")
local TLS=require("src.net.tls_bridge")
local Config=require("src.game.config")
local Hud=require("src.game.reference_hud")
local Pad=require("src.game.gamepad_controls")
local Controls=require("src.game.control_settings")
local Panels=require("src.game.reference_panels")
local Clans=require("src.game.account_clans")
local Death=require("src.game.reference_death")
local Notices=require("src.game.reference_notices")
local Profile=require("src.game.reference_profile")
local Upgrades=require("src.game.reference_upgrades")
local Assets=require("src.game.reference_assets")
local Camera=require("src.camera")
local Input=require("src.input")
local Pack=require("src.protocol.msgpack")
local client=nil
local pendingBrowserLogin=nil
local integration=nil
local uiSmokeMode=os.getenv("MOO_IO_E2E") or os.getenv("MOOQUEST_UI_E2E")
local uiSmoke=uiSmokeMode~=nil and #uiSmokeMode>0
local uiAuthStarted=false
local uiSmokeTime=0
local uiSmokeClicked=false
local uiSmokeDrawn=false
local world=World.new()
local camera=nil
local menuCamera=nil
local menuPreview=nil
local previewW,previewH=0,0
local previewAge=2
local menu=Menu.new()
local home=Home.new()
local hosted=Host.new()
local pause=Pause.new()
local sessionIsHost=false
local allowQuit=false
local joinRequested=false
local connectRoom
local homeAction
local panels=Panels.new()
local profile=Profile.new()
local clans=Clans.new()
local death=Death.new()
local phase="menu"
local diagnostic=nil
local reconnectSeconds=0
local latestEvent="Nenhum io-init recebido."
local startupError=nil
local input=Input.new()
local controls=Controls.new()
input.bindings=controls
local movementClock=0
local lastMove=false
local lastAim=nil
local playerX,playerY=nil,nil
local serverPackets=0
local died=false
local deathBackdrop=false
local deathReturnPending=false
local deathChoiceStatus=""
local heartbeatClock=0
local frameDelta=0
local chatOpen=false
local chatDraft=""
local mouseAttack=false
local spaceAttack=false
local showDungeonMap=true
local lockDir=false
local angle
local gamepadAim=nil
local gamepadAttack=false
local gamepadR2Held=false
local gamepadSlotCursor=nil
local currentAttackDir
local function activeGamepad()
 if not love.joystick or not love.joystick.getJoysticks then return nil end
 return Pad.active(love.joystick.getJoysticks())
end
local function cycleGamepadSlot(step)
 if phase~="playing" or died or not client
   or client.state~="spawn_confirmed" then return false end
 local id,isWeapon,cursor=Hud.cycleSlot(world,step,gamepadSlotCursor)
 if id==nil then return false end
 local ok=client:send("z",{id,isWeapon})
 if ok then gamepadSlotCursor=cursor end
 return ok
end
local function updateGamepad()
 local joy=activeGamepad()
 if not joy then
  input:gamepadMove(0,0)
  gamepadAim=nil
  gamepadR2Held=false
  if gamepadAttack then
   gamepadAttack=false
   if client and client.state=="spawn_confirmed"
     and not mouseAttack and not spaceAttack then
    client:send("F",{0,Pack.null})
   end
  end
  return
 end
 local lx,ly=controls:stick(controls:axis(joy,"leftx"),controls:axis(joy,"lefty"))
 input:gamepadMove(lx,ly)
 local rx,ry=controls:stick(controls:axis(joy,"rightx"),controls:axis(joy,"righty"))
 -- The R3 analog guides both the server D direction and the visible weapon.
 -- Holding the last angle at stick center avoids snapping back to the mouse.
 if rx*rx+ry*ry>=0.12 then
  gamepadAim=angle(ry,rx)
  if lockDir then
   if client:send("K",{0}) then lockDir=false end
  end
 end
 local r2=controls:button(joy,"next")
 if r2 and not gamepadR2Held then cycleGamepadSlot(1) end
 gamepadR2Held=r2
 -- R1 attacks. R2 is reserved for moving forward through the hotbar.
 local attacking=controls:button(joy,"attack")
 if phase=="playing" and client and client.state=="spawn_confirmed"
   and not died and not pause:isOpen() and not chatOpen
   and not panels:isOpen() and not clans:isOpen() and not profile:isOpen() then
  if attacking and not gamepadAttack then
   gamepadAttack=true
   if not mouseAttack and not spaceAttack then
    client:send("F",{1,gamepadAim or currentAttackDir()})
   end
  elseif not attacking and gamepadAttack then
   gamepadAttack=false
   if not mouseAttack and not spaceAttack then
    client:send("F",{0,Pack.null})
   end
  end
 elseif gamepadAttack then
  gamepadAttack=false
  if client and client.state=="spawn_confirmed"
    and not mouseAttack and not spaceAttack then
   client:send("F",{0,Pack.null})
  end
 end
end
currentAttackDir=function()
  local w,h=love.graphics.getDimensions()
  local mx,my=love.mouse.getPosition()
  return angle(my-h/2,mx-w/2)
end
local function shortenChat(text)
  -- JavaScript chatBox.value.slice(0,30): keep up to 30 UTF-8 characters.
  local count=0
  for i=1,#text do
    local b=text:byte(i)
    if b<128 or b>=192 then
      count=count+1
      if count>30 then return text:sub(1,i-1) end
    end
  end
  return text
end
local function backspaceUtf8(text)
  local pos=#text
  while pos>1 do
    local b=text:byte(pos)
    if b<128 or b>=192 then break end
    pos=pos-1
  end
  return text:sub(1,pos-1)
end

function love.load()
  love.graphics.setDefaultFilter("linear","linear")
  camera=Camera.new()
  menuCamera=Camera.new()
  menuCamera:follow(Config.mapScale/2,Config.mapScale/2)
  local integrationMode=os.getenv("MOOQUEST_INTEGRATION")
  if integrationMode and #integrationMode>0 then
    integration=require("src.test_integration").new(integrationMode)
    return
  end
  if os.getenv("MOOQUEST_TESTS")=="1" then
    diagnostic=require("src.test_runner").run()
    -- Automated Windows batch tests must fail with an OS error code, not
    -- only print failing assertions inside an otherwise successful LÖVE run.
    if os.getenv("MOOQUEST_TESTS_EXIT")=="1" then
      love.event.quit(diagnostic.failed>0 and 1 or 0)
    end
    return
  end
  if os.getenv("MOO_IO_ROOM_CHOICE_TEST")=="1" then
    local ok,err=pcall(function()
      require("src.test_room_choice")(homeAction,home,hosted,
        function() return client end)
    end)
    if not ok then print("MOO IO ROOM CHOICE FAIL: "..tostring(err)) end
    allowQuit=true -- mocked owner must not block an automated test exit
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_V2_CLIENT_TEST")=="1" then
    local ok,err=pcall(function()
      require("src.test_tls_bridge")()
      require("src.test_browser_auth")()
      require("src.test_server_directory")()
      local invite=require("src.game.mooio_home").parseInvite(
        "https://normal.play.example.org/abcdefgh12345678","")
      assert(invite and invite.secure and invite.port==443,
        "cliente nao reconhece convite publico V2")
    end)
    if not ok then print("MOO IO V2 JOIN FAIL: "..tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_MENU_TEST")=="1" then
    local ok,err=pcall(function() require("src.test_mooio_menu")() end)
    if not ok then print("MOO IO MENU FAIL: "..tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_PAUSE_TEST")=="1" then
    local ok,err=pcall(function()
      require("src.test_pause_flow")(pause,hosted,home,
        function() phase="playing" end,
        function() return phase end,
        function() return client end,
        function(value) client=value end,
        function(value) sessionIsHost=value end,
        function() return sessionIsHost end,
        homeAction)
    end)
    if not ok then print("MOO IO PAUSE FAIL: "..tostring(err)) end
    allowQuit=true -- test already verified the window-close confirmation
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_DEATH_MARKER_TEST")=="1" then
    local ok,err=pcall(function()
      require("src.test_death_marker")()
    end)
    if not ok then print("MOO IO DEATH MARKER FAIL: "..tostring(err)) end
    allowQuit=true
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_DEATH_FLOW_TEST")=="1" then
    local ok,err=pcall(function()
      require("src.test_death_flow")(death,home,hosted,
        function(value) world=value end,function() return world end,
        function(value) client=value end,function() return client end,
        function(value) sessionIsHost=value end,
        function(value) phase=value end,function() return phase end,
        function() return camera end)
    end)
    if not ok then print("MOO IO DEATH FLOW FAIL: "..tostring(err)) end
    allowQuit=true
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_CONTROL_SETTINGS_TEST")=="1" then
    local ok,err=pcall(function()
      require("src.test_control_settings")()
    end)
    if not ok then print("MOO IO CONTROL SETTINGS FAIL: "..tostring(err)) end
    allowQuit=true
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_GAMEPAD_TEST")=="1" then
    local ok,err=pcall(function()
      require("src.test_gamepad_controls")(
        function(v) client=v end,
        function(v) world=v end,
        function(v) phase=v end)
    end)
    if not ok then print("MOO IO GAMEPAD FAIL: "..tostring(err)) end
    allowQuit=true
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_HUD_TEST")=="1" then
    local ok,err=pcall(function() require("src.test_missing_asset_ui")() end)
    if not ok then print("MOO IO HUD FAIL: "..tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_MAP_VIEW_TEST")=="1" then
    local ok,err=pcall(function() require("src.test_map_view")() end)
    if not ok then print("MOO IO MAP VIEW FAIL: "..tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_MOB_ANIMATION_TEST")=="1" then
    local ok,err=pcall(function() require("src.test_mob_animations")() end)
    if not ok then print("MOO IO MOB ANIMATION FAIL: "..tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_SPRITE_TEST")=="1" then
    local ok,err=pcall(function() require("src.test_sprite_render")() end)
    if not ok then print("MOO IO SPRITES FAIL: "..tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  if os.getenv("MOO_IO_WEAPON_VISUAL_TEST")=="1" then
    local ok,err=pcall(function() require("src.test_weapon_visual")() end)
    if not ok then print("MOO IO WEAPON VISUAL FAIL: "..tostring(err)) end
    love.event.quit(ok and 0 or 1)
    return
  end
  -- Normal opening: stay on Moo IO home; no network or terminal is opened.
  -- CI may inject an invitation to prove that the native Play flow reaches C.
  if os.getenv("MOO_IO_E2E")=="1" then
    local remoteHost=os.getenv("MOO_IO_HOST") or "127.0.0.1"
    local remotePort=tonumber(os.getenv("MOO_IO_PORT")) or 8080
    local inviteCode=os.getenv("MOO_IO_ROOM_CODE")
    local ok,result=pcall(Original.new,{host=remoteHost,port=remotePort,
      server="LC",autoSpawn=false,inviteCode=inviteCode})
    if not ok then error("Moo IO test init: "..tostring(result)) end
    client=result
    joinRequested=true
    home.screen="play"
    local connected,err=client:connect()
    if not connected then error("Moo IO test connect: "..tostring(err)) end
  end
end

angle=function(y,x)
  if math.atan2 then return math.atan2(y,x) end
  if x>0 then return math.atan(y/x) end
  if x<0 then return math.atan(y/x)+(y>=0 and math.pi or -math.pi) end
  if y>0 then return math.pi/2 end
  if y<0 then return -math.pi/2 end
  return 0
end

  -- Continuous cursor travel for controller navigation; axis callbacks only fire
-- on changes, so relying on them makes menus nearly impossible to navigate.
local function updateGamepadMenu(dt)
 if not controls:isOpen() and phase~="menu" and phase~="death_choice" and not pause:isOpen() then return end
 local joy=activeGamepad()
 if not joy then return end
 local xaxis,yaxis=controls:axis(joy,"leftx"),controls:axis(joy,"lefty")
 if math.abs(xaxis)<0.24 then xaxis=0 end
 if math.abs(yaxis)<0.24 then yaxis=0 end
 if xaxis==0 and yaxis==0 then return end
 local x,y=love.mouse.getPosition()
 local w,h=love.graphics.getDimensions()
 local distance=460*math.min(dt,0.08)
 local nextX=math.max(0,math.min(w-1,math.floor(x+xaxis*distance+0.5)))
 local nextY=math.max(0,math.min(h-1,math.floor(y+yaxis*distance+0.5)))
 love.mouse.setPosition(nextX,nextY)
end

function love.update(dt)
  frameDelta=dt
  if integration then integration:update(dt);return end
  if diagnostic then return end
  updateGamepadMenu(dt)
  -- The menu backdrop reuses the original top-down world preview even
  -- before connecting to a Node server.
  if phase=="menu" then
    menu.world:update(dt)
    previewAge=previewAge+dt
  end
  hosted:update(dt)
  if home.starting or hosted.state=="failed" then home.serverLog=hosted.lastLog end
  if home.starting and hosted.state=="starting"
    and hosted.progress~="" and home.status~=hosted.progress then
    home:setStatus(hosted.progress)
  end
  if home.starting and hosted.state=="ready" then
    home.starting=false;home.hosting=true
    home.hostAddress=hosted.address;home.hostCode=hosted.code
    home:setStatus("Sala criada. Convide amigos pelo menu ESC.")
  elseif home.starting and hosted.state=="failed" then
    home.starting=false;home.hosting=false
    home:setStatus(hosted.error or "Nao foi possivel iniciar o servidor.",true)
  end
  -- Server V2 browser PKCE flow. Never accept a password in the game.
  if pendingBrowserLogin then
    if home.screen~="play" then pendingBrowserLogin=nil
    else
      pendingBrowserLogin.elapsed=pendingBrowserLogin.elapsed+dt
      if pendingBrowserLogin.elapsed>=2.5 then
        pendingBrowserLogin.elapsed=0
        local result,why=BrowserAuth.poll(pendingBrowserLogin)
        if result then
          local target=pendingBrowserLogin.target
          pendingBrowserLogin=nil
          home:setStatus("Conta autorizada. Entrando na sala V2...")
          connectRoom(target.host,target.port,target.code,result.token,target.secure)
        elseif why~="pending" then
          pendingBrowserLogin=nil
          home:setStatus(why or "Autorizacao V2 recusada.",true)
        end
      end
    end
  end
  if not client then return end
  if joinRequested and client.state=="keyed_transport" then
    joinRequested=false
    local ok,err=client:spawn({name=home.nickname,skin=menu.skin})
    if ok then
      uiSmokeClicked=true
      home:setStatus("Entrando no mundo; aguardando o servidor...")
    else home:setStatus("Falha ao entrar: "..tostring(err),true) end
  end
  if (client.state=="failed" or client.state=="blocked" or client.state=="closed")
    and not home.error then
    joinRequested=false
    home:setStatus(client.error or client.status or "Conexao encerrada.",true)
  end
  if uiSmoke then
    uiSmokeTime=uiSmokeTime+dt
    if uiSmokeTime>22 then
      print("UI E2E FAIL: timeout; phase="..tostring(phase)..
        " state="..tostring(client.state).." status="..tostring(client.status))
      love.event.quit(1)
      uiSmoke=false
      return
    end
  end
  client:update()
  for _,evt in ipairs(client:drain()) do
    if evt.kind=="io-init" then
      local h=evt.data
      latestEvent=string.format("io-init REAL: keyed=%d, pinned=%s, sealMode=%d",
        h.mode,tostring(h.pinned),h.sealMode)
    elseif evt.kind=="game_packet" then
      local packet=evt.data
      world:apply(packet.name,packet.args)
      serverPackets=serverPackets+1
      if packet.name=="j" and world.justChangedSpace then
        world.justChangedSpace=false
        if camera then camera.hasTarget=false end
        movementClock=0;lastMove=false;lastAim=nil
        -- Preserve held WASD during a seamless door transition.
        -- The server clears velocity for safety; the next movement tick
        -- sends the current input again after the camera changes rooms.
        mouseAttack=false;spaceAttack=false
        client:send("9",{Pack.null})
        client:send("F",{0,Pack.null})
        latestEvent="Area: "..tostring(world.spaceId)
        home:setStatus("Explorando "..tostring(world.spaceId))
      end
      if packet.name=="C" then
        profile:close()
        panels:reset()
        clans:close()
        death:reset()
        deathBackdrop=false
        deathReturnPending=false
        deathChoiceStatus=""
        phase="playing"
        home:setStatus("Partida iniciada.")
        menu.status=""
        latestEvent="SPAWN CONFIRMADO pelo Node original. SID "..tostring(client.sid)
        movementClock=0
        lastMove=false
        lastAim=nil
        -- The reference client's addPlayer(isYou) snaps the camera on spawn.
        -- Reset smoothing when respawning or entering a new match.
        if camera then camera.hasTarget=false end
        lockDir=false
        mouseAttack=false
        spaceAttack=false
        gamepadR2Held=false;gamepadSlotCursor=nil
        died=false
      elseif packet.name=="a" and client.sid then
        -- The original server transmits [sid,x,y,dir*100] per visible player.
        local positions=packet.args[1]
        if type(positions)=="table" then
          for i=1,#positions-3,4 do
            if positions[i]==client.sid then
              playerX,playerY=positions[i+1],positions[i+2]
              break
            end
          end
        end
      elseif packet.name=="P" then
        -- Freeze the background at the actual server-confirmed death site.
        if camera and world.lastDeath then
          camera:follow(world.lastDeath.x,world.lastDeath.y)
        end
        -- No stale profile selection after death; stop the real Node's
        -- watchStats stream instead of just concealing the local overlay.
        if profile:isOpen() then
          profile:close()
          client:send("V",{-1})
        end
        -- Match killPlayer() in the browser: hide the HUD, show "YOU DIED"
        -- over the live world, then reveal the usual Play screen after 3s.
        panels:reset()
        clans:close()
        chatOpen=false;chatDraft=""
        input.keys={};input:gamepadMove(0,0);lastMove=false
        gamepadAttack=false;gamepadAim=nil
        gamepadR2Held=false;gamepadSlotCursor=nil
        mouseAttack=false;spaceAttack=false;lockDir=false
        deathBackdrop=sessionIsHost and world.lastDeath~=nil
        deathReturnPending=false;deathChoiceStatus=""
        died=true
        phase="death"
        death:start()
        menu.status=""
        latestEvent="YOU DIED: morte confirmada pelo Node."
      elseif packet.name=="B" then
        latestEvent="Servidor recusou partida: "..tostring(packet.args[1])
      end
    end
  end
  world:update(dt)
  if phase=="death" and death:update(dt) then
    -- Preserve the owner\u0027s familiar menu while keeping the death position.
    -- Guests stay connected and explicitly decide to respawn or disconnect.
    phase=sessionIsHost and "menu" or "death_choice"
    menu.status=""
  end
  -- Use the actual menu click handler, not Original:spawn(), so CI verifies
  -- the user's Play button and the real Node connection together.
  -- The Moo IO E2E uses the same automatic spawn path as normal players.
  -- No simulated menu click or fake C packet is allowed.
  local localPlayer=world:localPlayer()
  if localPlayer and localPlayer.x and localPlayer.y and camera then
    camera:followReference(localPlayer.visualX or localPlayer.x,
      localPlayer.visualY or localPlayer.y,dt)
  end
  -- The multiplayer server must still receive keepalive packets while
  -- ESC options are open. Only player movement and attacks are suspended.
  if client.state=="spawn_confirmed" and not died then
    heartbeatClock=heartbeatClock+dt
    if heartbeatClock>=15 then
      heartbeatClock=0
      client:send("0",{})
    end
  end
  if client.state=="spawn_confirmed" and not died and not pause:isOpen() then
    local blocked=panels:isOpen() or clans:isOpen() or profile:isOpen()
      or chatOpen or home.roomOverlay
    if blocked then
      input.keys={}
      input:gamepadMove(0,0)
      gamepadAim=nil
      if gamepadAttack then
        gamepadAttack=false
        client:send("F",{0,Pack.null})
      end
    else
      updateGamepad()
    end
    input:update(dt)
    movementClock=movementClock+dt
    if movementClock>=0.07 then
      movementClock=0
      local dx,dy=input.dx,input.dy
      local move=(dx~=0 or dy~=0) and angle(dy,dx) or false
      if move~=lastMove then
        client:send("9",{move==false and Pack.null or move})
        lastMove=move
      end
      local aim=View.localAim(lockDir,gamepadAim or currentAttackDir(),lastAim)
      if not lastAim or math.abs(aim-lastAim)>0.02 then
        client:send("D",{aim})
        lastAim=aim
      end
    end
  end
  if client.state=="failed" or client.state=="closed" then
    phase="menu"
    reconnectSeconds=reconnectSeconds+dt
    -- Retry only on explicit R to avoid connection-throttling.
  end
end

local function line(y,text,color)
  if color then love.graphics.setColor(color) else love.graphics.setColor(0.88,0.93,0.89) end
  love.graphics.print(text,36,y)
end

function love.draw()
  love.graphics.clear(0.075,0.11,0.10)
  if integration then
    love.graphics.print("Real Node integration: "..integration.mode,30,30)
    love.graphics.print("State: "..tostring(integration.client.state),30,60)
    integration:draw()
    return
  end
  if diagnostic then
    line(28,"MOO IO | TESTES DO CLIENTE LUA")
    line(66,string.format("Aprovados: %d   Falhas: %d",diagnostic.passed,diagnostic.failed))
    for i,r in ipairs(diagnostic.rows) do
      line(92+i*27,(r.pass and "OK   " or "ERRO ")..r.path,
        r.pass and {0.45,0.86,0.56} or {1,0.55,0.5})
      if not r.pass then
        love.graphics.setColor(1,0.75,0.64)
        love.graphics.printf(tostring(r.error):gsub("%s+"," "):sub(1,125),
          395,92+i*27,850)
      end
    end
    line(585,"Relatorio: "..tostring(diagnostic.reportPath or diagnostic.reportError or "nao gravado"))
    line(626,"ESC: sair")
    return
  end
  local w,h=love.graphics.getDimensions()
  local p=world:localPlayer()
  if phase=="death" then
    -- The original browser keeps the world underneath #diedText
    -- instead of instantly replacing it with the game entry card.
    View.draw(world,camera,frameDelta,{showGrid=menu.grid})
    death:draw(w,h)
    Hud.drawDeathMap(world)
    Notices.draw(world,w,h)
    return
  end
  if phase=="death_choice" then
    View.draw(world,camera,frameDelta,{showGrid=menu.grid})
    death:drawChoices(w,h,deathReturnPending,deathChoiceStatus)
    Hud.drawDeathMap(world)
    return
  end
  if phase=="menu" then
    -- The background is the original MooMoo world scene, not a static
    -- fake screenshot or a generated entity pretending to be online.
    -- Reuse a cached view of the familiar top-down game world on the title
    -- screen. Rendering all procedural foliage every frame slowed the menu,
    -- particularly on software-rendered or lower-end Windows machines.
    -- Rebuild once per second or immediately on resize/grid changes.
    if not deathBackdrop and (not menuPreview or previewW~=w or previewH~=h or previewAge>=1) then
      if menuPreview and (previewW~=w or previewH~=h) then
        menuPreview:release()
        menuPreview=nil
      end
      if not menuPreview then
        menuPreview=love.graphics.newCanvas(w,h)
        previewW,previewH=w,h
      end
      love.graphics.push("all")
      love.graphics.setCanvas(menuPreview)
      love.graphics.clear(0,0,0,0)
      View.draw(menu.world,menuCamera,frameDelta,{showGrid=menu.grid})
      love.graphics.pop()
      previewAge=0
    end
    if deathBackdrop and world.lastDeath and camera then
      View.draw(world,camera,frameDelta,{showGrid=menu.grid})
    elseif menuPreview then
      love.graphics.setColor(1,1,1,1)
      love.graphics.draw(menuPreview,0,0)
    end
    local state=client and client.state or "idle"
    home:draw(state,client and (client.error or client.status) or "",true)
    if home.roomOverlay then home:drawRoomOverlay() end
    if pause:isOpen() then pause:draw(home.showGrid,home.fullscreen,home:roomInvite(),world) end
    controls:draw(activeGamepad())
    return
  end
  if client and client.state=="spawn_confirmed" and not died
    and p and p.x and p.y then
    -- Match browser renderPlayers(): the local avatar aims at the cursor
    -- immediately, while the Node remains authoritative for D/F combat.
    View.draw(world,camera,frameDelta,
      {showGrid=menu.grid,showDungeonMap=showDungeonMap,
       localAim=View.localAim(lockDir,gamepadAim or currentAttackDir(),lastAim)})
    Hud.draw(world,chatOpen,chatDraft,
      chatOpen or panels:isOpen() or clans:isOpen() or profile:isOpen())
    panels:draw(world)
    -- Keep permanent clans internal; no separate Clan button in gameplay HUD.
    clans:draw(false)
    Notices.draw(world,w,h)
    profile:draw(world)
    -- Invite controls are in ESC > CONFIGURACOES, not on the HUD.
    if uiSmoke and uiSmokeClicked and not uiSmokeDrawn then
      uiSmokeDrawn=true
      print("MOO IO E2E PASS: convite -> handshake -> C/D -> mundo e HUD renderizados")
      love.event.quit(0)
    end
    if pause:isOpen() then
      pause:draw(home.showGrid,home.fullscreen,home:roomInvite(),world)
      controls:draw(activeGamepad())
      return
    end
    -- Only show missing PNG diagnostics on explicit developer opt-in.
    if os.getenv("MOO_IO_DEBUG_ASSETS")=="1" then
      local absent,total=Assets.missingSummary(3)
      if total>0 then
        love.graphics.push("all")
        love.graphics.setColor(0,0,0,0.88)
        love.graphics.rectangle("fill",16,58,590,34+19*#absent,5,5)
        love.graphics.setColor(1,0.83,0.63)
        love.graphics.print("PNG ausentes: "..total,24,64)
        for i,file in ipairs(absent) do
          love.graphics.print(file,24,64+i*19)
        end
        love.graphics.pop()
      end
    end
    return
  end
  -- Awaiting first authoritative world state (no fake player/entities).
  love.graphics.setColor(0.06,0.11,0.12)
  love.graphics.rectangle("fill",0,0,w,h)
  love.graphics.setColor(0.90,0.95,0.91)
  love.graphics.printf("MOO IO",0,h/2-72,w,"center")
  love.graphics.setColor(0.56,0.78,0.62)
  love.graphics.printf("Carregando mundo e jogadores...",0,h/2-20,w,"center")
  love.graphics.setColor(0.68,0.75,0.73)
  love.graphics.printf(client and client.status or "Aguardando servidor...",40,h/2+26,w-80,"center")
  if pause:isOpen() then pause:draw(home.showGrid,home.fullscreen,home:roomInvite(),world) end
  controls:draw(activeGamepad())
end

local menuAction
local function requestPlay()
  if not client then
    menu.status=startupError or "Cliente de rede indisponivel."
    return false
  end
  if phase=="death" or
    (client.state~="keyed_transport" and
    not (died and client.state=="spawn_confirmed")) then
    menu.status=client.state=="joining"
      and "Play enviado; aguardando confirmacao C do servidor..."
      or "Aguardando conexao com Node. Estado: "..tostring(client.state)
    return false
  end
  local ok,why=client:spawn({name=menu.name,skin=menu.skin})
  if not ok then
    menu.status="Falha ao entrar: "..tostring(why)
    return false
  end
  died=false
  menu.status="Entrando na partida; aguardando confirmacao do Node..."
  return true
end
local function accountAction(action)
  if action=="auth_request" then
    local flow,err=Auth.requestCode(menu.authEmail)
    if not flow then
      menu.authMessage=err;return
    end
    menu.authFlow=flow.flow
    menu.authStep="code"
    menu.authCode=""
    menu.authFocus="code"
    menu.authMessage="Este servidor local aceita QUALQUER codigo de 6 digitos. Nao ha envio de email."
    return
  elseif action=="auth_verify" then
    local account,err=Auth.verifyCode(menu.authFlow,menu.authCode)
    if not account then menu.authMessage=err;return end
    if not client then menu.authMessage="Cliente Node indisponivel";return end
    client.authToken=account.token
    clans:reset()
    menu.accountEmail=menu.authEmail
    menu.authMode=nil
    menu.authFlow=nil
    menu.authCode=""
    menu.authMessage=""
    menu.status="Conta local conectada. Reabrindo sessao de jogo..."
    -- The original API issues account-bound join tickets. The old guest
    -- WebSocket cannot be retroactively converted to a registered session.
    world=World.new()
    local ok,why=client:connect()
    if not ok then menu.status="Falha ao conectar conta: "..tostring(why) end
    return
  elseif action=="auth_logout" then
    if not client then return end
    client.authToken=nil
    clans:reset()
    menu.accountEmail=nil
    menu.status="Conta local desconectada. Reabrindo como convidado..."
    world=World.new()
    local ok,why=client:connect()
    if not ok then menu.status="Falha na conexao guest: "..tostring(why) end
  end
end
menuAction=function(action)
  if action=="play" then return requestPlay() end
  if action=="play_unavailable" then
    menu.status="Jogo indisponivel; confira o status do servidor e os Detalhes."
    return false
  end
  if action=="auth_request" or action=="auth_verify" or
    action=="auth_logout" then
    accountAction(action)
    return true
  end
  if action=="clan_open" then
    clans:toggle(client and client.authToken)
    return true
  end
  if action=="auth_open" or action=="auth_back" then
    menu.status=""
  end
  return false
end

-- Native menu actions. Only one authoritative Node session exists at a time.
connectRoom=function(ip,port,inviteCode,authToken,secure)
  if client then client:close();client=nil end
  world=World.new()
  deathBackdrop=false;deathReturnPending=false;deathChoiceStatus=""
  death:reset()
  local ok,connection=pcall(Original.new,{
    host=ip,port=port,server="LC",inviteCode=inviteCode,autoSpawn=false,
    authToken=authToken,secure=secure==true
  })
  if not ok then
    home:setStatus("Cliente de rede: "..tostring(connection),true)
    return false
  end
  client=connection
  sessionIsHost=hosted.state=="ready"
    and ip==hosted.hostIP and inviteCode==hosted.code
  menu.name=home.nickname
  joinRequested=true
  home.screen="play"
  home:setStatus("Conectando a "..ip..":"..port.."...")
  local connected,err=client:connect()
  if not connected then
    joinRequested=false
    home:setStatus("Falha de conexao: "..tostring(err),true)
  end
  return connected
end

homeAction=function(action)
  if action=="edit_controls" then
    controls:show()
    return
  elseif action=="quit_game" then
    if hosted.state=="ready" or hosted.state=="starting" then
      -- Never destroy a live friend's room from the title screen silently.
      pause:confirm(true,true)
    else
      allowQuit=true
      love.event.quit()
    end
    return
  elseif action=="play_tab" then
    -- Navigating to JOGAR cannot launch a server or join a room.
    -- Both operations require their own explicit button.
    home.screen="play"
    if hosted.state=="ready" then
      home:setStatus("Sala pronta. Clique JOGAR AGORA se quiser entrar.")
    elseif hosted.state=="starting" then
      home:setStatus("Preparando a sala que voce escolheu criar...")
    else
      home:setStatus("Escolha CRIAR MINHA SALA ou ENTRAR EM OUTRA SALA.")
    end
  elseif action=="server_browse" then
    local directory,why=Directory.fetch(home.serverAddress)
    if not directory then
      home.serverRooms={};home.serverDirectory=nil;home.serverSelected=1;home.serverPage=0
      home:setStatus(why or "Nao foi possivel consultar as salas.",true)
    else
      home.serverDirectory=directory
      home.serverRooms=directory.rooms
      home.serverSelected=1;home.serverPage=0
      home.serverCode=""
      home:setStatus(#directory.rooms.." salas encontradas. Escolha uma para entrar.")
    end
  elseif action=="server_join" then
    local selected=home.serverRooms[home.serverSelected]
    if not selected then home:setStatus("Escolha uma sala na lista.",true);return end
    if not selected.online then home:setStatus("A sala escolhida esta offline.",true);return end
    local target,why=Directory.target(home.serverDirectory,selected,home.serverCode)
    if not target then home:setStatus(why,true);return end
    -- V2 is a remote server; never spawn a V2 worker in this client.
    -- Reuse the existing browser-based authorization and genuine game session.
    home.invite=target.invite;home.joinCode=""
    home.screen="play"
    homeAction("v2_login")
  elseif action=="server_select" or action=="server_page" then
    home:setStatus("Selecione a sala e clique ENTRAR NA SALA.")
  elseif action=="server_to_play" then
    home.screen="play"
    home:setStatus("Use IP LAN/VPN ou convite seguro https://sala.dominio/CODIGO.")
  elseif action=="back" then
    home:setStatus("")
  elseif action=="create" then
    -- The only path that can create a private server is an explicit click.
    if home.screen~="create" or home.starting or home.hosting then return end
    if client then client:close();client=nil end
    home:setStatus("Iniciando servidor local sem terminal...")
    local ok,err=hosted:start(home.serverMode,home.vpnIP,
      home.botsEnabled and home.botCount or 0,home.difficulty,home.modIds,home.mapId)
    if ok then
      home.starting=true;home.hosting=false
      home.screen="play"
      home.hostCode="";home.hostAddress=""
    else
      home.starting=false
      home:setStatus(tostring(err),true)
    end
  elseif action=="mode_lan" or action=="mode_vpn" then
    home:setStatus(home.serverMode=="vpn"
      and "Abra sua VPN com os amigos e informe o IP virtual deste computador."
      or "Modo LAN: amigos conectados ao mesmo roteador.")
  elseif action=="v2_login" then
    if pendingBrowserLogin then
      home:setStatus("Login V2 pendente. Autorize no navegador.");return
    end
    local target,why=Home.parseInvite(home.invite,home.joinCode)
    if not target then home:setStatus(why,true);return end
    local request,err=BrowserAuth.begin(target.host,target.port,target.code,
      {secure=target.secure})
    if not request then home:setStatus(err,true);return end
    local opened,allowed=pcall(love.system.openURL,request.verificationUri)
    if not opened or allowed==false then
      home:setStatus("Nao foi possivel abrir o navegador seguro.",true);return
    end
    request.target=target
    pendingBrowserLogin=request
    home:setStatus("Autentique-se no navegador. O jogo conectara automaticamente.")
  elseif action=="join" then
    local target,why=Home.parseInvite(home.invite,home.joinCode)
    if not target then home:setStatus(why,true);return end
    connectRoom(target.host,target.port,target.code,nil,target.secure)
  elseif action=="play_local" then
    if hosted.state=="ready" then
      connectRoom(hosted.hostIP,hosted.port,hosted.code)
    else home:setStatus("A sala ainda nao esta pronta.",true) end
  elseif action=="stop" then
    -- Even from the main menu, the owner must confirm disconnecting
    -- everybody before the host process can be stopped.
    if hosted.state=="ready" or hosted.state=="starting" then
      pause:confirm(true,false)
    end
  elseif action=="retry" then
    if hosted.state=="ready" and (home.invite=="" or home.invite==home:roomInvite()) then
      connectRoom(hosted.hostIP,hosted.port,hosted.code)
    else
      local target,why=Home.parseInvite(home.invite,home.joinCode)
      if target then connectRoom(target.host,target.port,target.code,nil,target.secure)
      else home:setStatus(why,true) end
    end
  elseif action=="copy" then
    local link=home:roomInvite()
    if link~="" then
      love.system.setClipboardText(link)
      home:setStatus("Convite copiado para a area de transferencia.")
    end
  elseif action=="grid" then
    menu.grid=home.showGrid
    previewAge=2
    home:setStatus(home.showGrid and "Grade ativada." or "Grade desativada.")
  elseif action=="fullscreen" then
    local ok,err=love.window.setFullscreen(home.fullscreen)
    if not ok then home:setStatus(tostring(err),true) end
  end
end

-- The profile is read-only: both opening and closing use Node V packets.
-- A local modal NEVER gives the client authority to create account stats.
local function closeProfile()
  if not profile:isOpen() then return end
  profile:close()
  if client and client.state=="spawn_confirmed" then
    client:send("V",{-1})
  end
end
local function openProfile(sid)
  if type(sid)~="number" or sid<0 or sid%1~=0
    or not client or client.state~="spawn_confirmed" then return false end
  local ok,err=client:send("V",{sid})
  if not ok then
    latestEvent="Perfil indisponivel: "..tostring(err)
    return false
  end
  profile:open(sid)
  panels:close()
  clans:close()
  chatOpen=false;chatDraft=""
  input.keys={};lastMove=false
  mouseAttack=false;spaceAttack=false
  client:send("e",{})
  client:send("F",{0,Pack.null})
  return true
end

-- One gate for leaving a live match or terminating an owned room.
-- Choosing cancel/ESC from the confirmation never touches host:stop().
local function stopGameplay(owned)
  pause:close()
  if client then client:close();client=nil end
  joinRequested=false
  sessionIsHost=false
  home.roomOverlay=false
  if owned then
    hosted:stop()
    home.hosting=false;home.starting=false
    home.hostAddress="";home.hostCode=""
  end
  input.keys={};input:gamepadMove(0,0);lastMove=false
  gamepadAttack=false;gamepadR2Held=false;gamepadSlotCursor=nil
  gamepadAim=nil
  mouseAttack=false;spaceAttack=false
  chatOpen=false;chatDraft=""
  panels:reset();clans:close();profile:close()
  phase="menu";died=false
  deathBackdrop=false;deathReturnPending=false;deathChoiceStatus=""
  death:reset()
  home.screen="play"
  home:setStatus(owned and "Sala encerrada. Os participantes foram desconectados."
    or "Voce saiu da partida. A sala do anfitriao continua online.")
end
-- Respawn via the same authenticated connection; only the server's C
-- packet may return the guest to active play.
local function returnAfterDeath()
  if phase~="death_choice" or sessionIsHost or deathReturnPending then return false end
  if not client then deathChoiceStatus="Conexao indisponivel.";return false end
  local name=type(client.name)=="string" and client.name or home.nickname
  local ok,err=client:spawn({name=name,skin=0})
  if ok then
    deathReturnPending=true
    deathChoiceStatus=""
  else
    deathChoiceStatus="Nao foi possivel voltar: "..tostring(err):sub(1,75)
  end
  return ok
end
local function stopPlayerControls()
  input.keys={}
  input:gamepadMove(0,0)
  gamepadAim=nil
  gamepadAttack=false
  gamepadR2Held=false;gamepadSlotCursor=nil
  lastMove=false
  mouseAttack=false;spaceAttack=false
  chatOpen=false;chatDraft=""
  if client and client.state=="spawn_confirmed" then
    -- Stop server-authoritative movement as well as gathering/attacking.
    -- Otherwise the last key direction may keep moving the avatar on ESC.
    client:send("9",{Pack.null})
    client:send("e",{})
    client:send("F",{0,Pack.null})
  end
end
local function pauseAction(action)
  if action=="edit_controls" then
    controls:show()
    stopPlayerControls()
  elseif action=="toggle_grid" then
    home.showGrid=not home.showGrid
    menu.grid=home.showGrid
    previewAge=2
  elseif action=="toggle_fullscreen" then
    home.fullscreen=not home.fullscreen
    local ok,err=love.window.setFullscreen(home.fullscreen)
    if not ok then home.fullscreen=not home.fullscreen;home:setStatus(tostring(err),true) end
  elseif action=="copy_invite" then
    local invite=home:roomInvite()
    if pause.owner and hosted.state=="ready" and invite~="" then
      love.system.setClipboardText(invite)
      home:setStatus("Convite copiado para enviar aos amigos.")
    end
  elseif action=="leave_guest" then
    stopGameplay(false)
  elseif action=="leave_owner" or action=="quit_owner" then
    stopGameplay(true)
    if action=="quit_owner" then
      allowQuit=true
      love.event.quit()
    end
  end
end
local function gamepadAction(joystick,physical)
 if joystick~=activeGamepad() then return end
 if controls:isOpen() then
  if controls.waiting then controls:captureButton(joystick,physical)
  elseif physical=="a" or physical==1 then
   local x,y=love.mouse.getPosition()
   controls:click(x,y)
  elseif physical=="b" then controls:hide() end
  return
 end
 local match=function(id)return controls:matches(joystick,physical,id)end
 if match("pause") then love.keypressed("escape");return end
 if phase=="death_choice" then
  if match("interact") then love.keypressed("return")
  elseif physical=="b" or match("pause") then love.keypressed("escape") end
  return
 end
 if phase=="menu" or pause:isOpen() then
  if match("interact") then
   local x,y=love.mouse.getPosition()
   love.mousepressed(x,y,1)
  elseif physical=="b" then love.keypressed("escape") end
  return
 end
 if phase~="playing" or chatOpen or died or profile:isOpen()
   or panels:isOpen() or clans:isOpen() then return end
 if match("previous") then cycleGamepadSlot(-1)
 elseif match("interact") then love.keypressed("f")
 elseif match("heal") then love.keypressed("r")
 elseif physical=="b" then love.keypressed("escape")
 elseif physical=="dpup" then love.keypressed("1")
 elseif physical=="dpright" then love.keypressed("2")
 elseif physical=="dpdown" then love.keypressed("3")
 elseif physical=="dpleft" then love.keypressed("4")
 end
end
function love.gamepadaxis(joystick,axis,value)
 if controls:isOpen() and joystick==activeGamepad()
  and controls.waiting and controls.waiting.kind=="button"
  and axis=="triggerright" and value>=0.75 then
  controls:captureButton(joystick,"righttrigger")
 end
end
function love.joystickaxis(joystick,index,value)
 if controls:isOpen() and joystick==activeGamepad()
  and controls.waiting and controls.waiting.kind=="button"
  and index==6 and value>=0.75 and not Pad.isMapped(joystick) then
  controls:captureButton(joystick,"righttrigger")
 end
end
function love.gamepadpressed(joystick,button)
 gamepadAction(joystick,button)
end
function love.gamepadreleased(joystick,button)
 if joystick~=activeGamepad() then return end
 if button=="x" and spaceAttack then love.keyreleased("space") end
end
function love.joystickpressed(joystick,index)
 if joystick~=activeGamepad() or Pad.isMapped(joystick) then return end
 gamepadAction(joystick,index)
end
function love.joystickreleased(joystick,index)
 if joystick~=activeGamepad() or Pad.isMapped(joystick) then return end
end
function love.keypressed(key)
  if controls:isOpen() then
    if controls:captureKeyboard(key) then return end
    if key=="escape" then controls:hide() end
    return
  end
  if phase=="playing" and not chatOpen then
    local mapped=controls:keyForAction(key)
    if mapped=="previous" then cycleGamepadSlot(-1);return end
    if mapped=="next" then cycleGamepadSlot(1);return end
    local virtual={attack="space",interact="f",heal="r",pause="escape"}
    key=virtual[mapped] or key
  end
  if pause:isOpen() then
    pauseAction(pause:keypressed(key))
    return
  end
  if home.roomOverlay then
    if key=="escape" then home.roomOverlay=false end
    return
  end

  if phase=="playing" and key=="escape" then
    stopPlayerControls()
    panels:close();clans:close()
    if profile:isOpen() then closeProfile() end
    home.roomOverlay=false
    pause:open(sessionIsHost)
    return
  end
  if phase=="death" then return end
  if phase=="death_choice" then
    if key=="return" or key=="kpenter" or key=="r" then
      returnAfterDeath()
    elseif key=="escape" or key=="backspace" then
      stopGameplay(false)
    end
    return
  end
  if profile:isOpen() then
    if key=="escape" or key=="p" then closeProfile() end
    return
  end
  if clans:isOpen() then
    clans:keypressed(key)
    return
  end
  if key=="escape" and phase=="playing" and panels:isOpen() then
    panels:keypressed(key,world)
    return
  end
  if diagnostic then return end
  if phase=="menu" then
    homeAction(home:keypressed(key))
    return
  end
  if key=="escape" and chatOpen then
    chatOpen=false;chatDraft=""
    return
  end
  if chatOpen then
    if key=="return" or key=="kpenter" then
      local value=shortenChat(chatDraft)
      if #value>0 and client then client:send("6",{value}) end
      chatDraft="";chatOpen=false
    elseif key=="backspace" then
      chatDraft=backspaceUtf8(chatDraft)
    end
    return
  end
  -- The original browser closes or traps focus in the Store/Tribe
  -- overlay. Enter must NEVER create a chat box behind an open modal.
  if panels:isOpen() then
    panels:keypressed(key,world)
    return
  end
  if (key=="return" or key=="kpenter") and client
    and client.state=="spawn_confirmed" and not died then
    chatOpen=true;chatDraft=""
    input.keys={}
    lastMove=false
    -- A player can open chat while holding mouse/Space. Stop the ongoing
    -- attack on the real Node server before giving keyboard focus to chat,
    -- exactly as store/tribe and window focus loss already do.
    mouseAttack=false;spaceAttack=false
    client:send("e",{})
    client:send("F",{0,Pack.null})
    return
  end
  if key=="f" and phase=="playing" and client
     and client.state=="spawn_confirmed" and world.map
     and not panels:isOpen() and not chatOpen then
    local obj=View.nearestInteraction(world)
    if obj then client:send("j",{"interact",obj.id}) end
    return
  end
  if key=="m" and phase=="playing" and client
     and client.state=="spawn_confirmed" and world.map
     and world.spaceId~="surface" and not panels:isOpen()
     and not chatOpen then
    showDungeonMap=not showDungeonMap
    return
  end
  input:keypressed(key)
  -- Mirror the reference client's default gameplay bindings.
  if client and client.state=="spawn_confirmed" and not died then
    if key=="p" and world.sid then
      openProfile(world.sid)
      return
    end
    if key=="e" then client:send("K",{1});return end
    if key=="x" then
      local ok=client:send("K",{0})
      if ok then lockDir=not lockDir end
      return
    end
    if key=="r" then client:send("S",{1});return end
    if key=="c" then
      local p=world:localPlayer()
      if p and p.x and p.y then world.mapMarker={x=p.x,y=p.y} end
      return
    end
    if key=="q" and world.inventory.items[1]~=nil then
      gamepadSlotCursor=nil
      client:send("z",{world.inventory.items[1],false});return
    end
    if key:match("^[1-9]$") then
      gamepadSlotCursor=nil
      local index,isWeapon=Hud.slotForKey(world,key)
      if index~=nil then client:send("z",{index,isWeapon}) end
      return
    end
    if key=="space" and not spaceAttack then
      spaceAttack=true
      if not mouseAttack and not gamepadAttack then
        client:send("F",{1,gamepadAim or currentAttackDir()})
      end
      return
    end
  end
  if key=="r" and client then
    if died and client.state=="spawn_confirmed" then
      local ok,reason=client:send("M",{
        Pack.map({name=client.name,moofoll=false,skin=0,anon=false})
      })
      if ok then latestEvent="Renascimento solicitado ao servidor Node original..."
      else latestEvent="Falha no renascimento: "..tostring(reason) end
      return
    end
    if client.state=="spawn_confirmed" then return end
    if client.state~="closed" and client.state~="failed" then return end
    reconnectSeconds=0
    startupError=nil
    playerX,playerY=nil,nil
    serverPackets=0
    lastMove=false
    lastAim=nil
    lockDir=false
    mouseAttack=false
    spaceAttack=false
    died=false
    heartbeatClock=0
    world=World.new()
    if camera then camera.hasTarget=false end
    local ok,err=client:connect()
    if not ok then startupError=err end
  end
end
function love.textinput(text)
  if phase=="death" then return end
  if clans:isOpen() then clans:textinput(text);return end
  if phase=="menu" then home:textinput(text);return end
  if panels:isOpen() then panels:textinput(text);return end
  if chatOpen and type(text)=="string" then
    chatDraft=shortenChat(chatDraft..text)
  end
end
function love.keyreleased(key)
  if phase=="death" then return end
  if controls:keyForAction(key)=="attack" then key="space" end
  if not diagnostic then input:keyreleased(key) end
  if key=="space" and spaceAttack then
    spaceAttack=false
    if not mouseAttack and not gamepadAttack
      and client and client.state=="spawn_confirmed" then
      client:send("F",{0,Pack.null})
    end
  end
end
function love.focus(focused)
  if not focused and client and client.state=="spawn_confirmed" then
    client:send("e",{})
    client:send("F",{0,Pack.null})
    mouseAttack=false;spaceAttack=false
    input.keys={}
    lastMove=false
  end
end
function love.mousepressed(x,y,button)
  if controls:isOpen() then controls:click(x,y);return end
  if pause:isOpen() then
    if button==1 then pauseAction(pause:click(x,y)) end
    return
  end
  if home.roomOverlay then
    if button==1 and home:overlayClick(x,y)=="copy" then
      local link=home:roomInvite()
      if link~="" then love.system.setClipboardText(link) end
      home:setStatus("Convite copiado para enviar aos amigos.")
    end
    return
  end
  if diagnostic or phase=="death" then return end
  if phase=="death_choice" then
    if button==1 then
      local w,h=love.graphics.getDimensions()
      local action=death:choiceAt(x,y,w,h)
      if action=="back" then returnAfterDeath()
      elseif action=="exit" then stopGameplay(false) end
    end
    return
  end
  if phase=="menu" then
    if button==1 then homeAction(home:click(x,y)) end
    return
  end
  if not client or client.state~="spawn_confirmed" or died then return end
  if button==1 then
    local w,h=love.graphics.getDimensions()
    if profile:isOpen() then
      local consumed,closed=profile:click(x,y,w,h)
      if closed then client:send("V",{-1}) end
      if consumed then return end
    end
    if clans:click(x,y,w,h,false,client and client.authToken) then
      if clans:isOpen() and panels:isOpen() then panels:close() end
      -- Keep the permanent Clan window exclusive with Shop and Tribe,
      -- matching how the original client hides competing overlays.
      -- The account overlay must not cause attacks or movement while typing.
      input.keys={};lastMove=false
      chatOpen=false;chatDraft=""
      mouseAttack=false;spaceAttack=false
      client:send("e",{})
      client:send("F",{0,Pack.null})
      return
    end
    local action=panels:click(world,x,y,w,h)
    if action then
      if action.packet then
        local ok,err=client:send(action.packet,action.args or {})
        if not ok then
          panels.message=tostring(err)
        elseif action.consumeRequest then
          -- This consumes only the displayed notification after a
          -- successful send, never a server-owned team or membership.
          table.remove(world.joinRequests,1)
        end
      else
        -- Reference toggleStoreMenu/toggleAllianceMenu close chat and
        -- stop gathering while the menu takes keyboard/mouse focus.
        chatOpen=false;chatDraft=""
        if panels:isOpen() then
          input.keys={}
          lastMove=false
          mouseAttack=false;spaceAttack=false
          client:send("e",{})
          client:send("F",{0,Pack.null})
        end
      end
      return
    end
    if panels:isOpen() then return end
    if chatOpen then return end
    local profileSid=Hud.leaderboardHitTest(world,w,x,y)
    if profileSid~=nil then
      openProfile(profileSid)
      return
    end
    if Hud.mapHitTest(w,h,x,y) then
      client:send("S",{1})
      return
    end
    local upgradeIndex=Upgrades.hitTest(world,w,x,y)
    if upgradeIndex~=nil then
      client:send("H",{upgradeIndex})
      return
    end
    local itemIndex,isWeapon=Hud.hitTest(world,w,h,x,y)
    if itemIndex~=nil then
      gamepadSlotCursor=nil
      client:send("z",{itemIndex,isWeapon})
      return
    end
    if not mouseAttack then
      mouseAttack=true
      if not spaceAttack and not gamepadAttack then
        client:send("F",{1,gamepadAim or currentAttackDir()})
      end
    end
  end
end
-- Browser storeDisplay uses mouseover/mouseout for live item details.
-- Only presentation changes; no purchase, equip or Node packet on hover.
function love.mousemoved(x,y)
  if pause:isOpen() then return end
  -- Physical mouse movement takes over aiming from the right stick.
  if phase=="playing" then gamepadAim=nil end
  if phase=="playing" and panels:isOpen() and love.graphics then
    local w,h=love.graphics.getDimensions()
    panels:hover(x,y,w,h)
  end
end
function love.wheelmoved(dx,dy)
  if pause:isOpen() then return end
  if clans:isOpen() then clans:wheelmoved(dx,dy);return end
  if phase=="playing" then panels:wheelmoved(dx,dy,world) end
end
function love.mousereleased(_,_,button)
  if diagnostic or not client or client.state~="spawn_confirmed" then return end
  if button==1 and mouseAttack then
    mouseAttack=false
    if not spaceAttack and not gamepadAttack then
      client:send("F",{0,Pack.null})
    end
  end
end
function love.quit()
  if not allowQuit and (hosted.state=="ready" or hosted.state=="starting") then
    -- The window close button must not silently terminate an owner's map.
    stopPlayerControls()
    home.roomOverlay=false
    pause:confirm(true,true)
    return true -- cancel OS close; show confirmation in existing window
  end
  if client then client:close() end
  if hosted then hosted:stop() end
  TLS.stop()
end

function love.resize(w,h)
  previewAge=2
  if camera then camera:resize(w,h) end
  if menuCamera then menuCamera:resize(w,h) end
end
