-- Native navigation contract: create is a separate full-width setup flow.
-- Explicit selected map must reach the actual local host process.
return function(perform,home,hosted,getClient)
  assert(home.screen=="home" and hosted.state=="idle")
  local starts,lastCount=0,-1
  hosted.start=function(self,mode,ip,bots,difficulty,modIds,mapId)
    assert(difficulty=="dificil" and modIds=="" and
      mapId=="bunker-e-cavernas",
      "selected cave map and difficulty must reach server launcher")
    starts=starts+1
    lastCount=bots
    self.state="starting"
    return true
  end
  hosted.update=function() end
  assert(home:click(110,298)=="play_tab")
  perform("play_tab")
  assert(home.screen=="play" and starts==0 and not home.hosting)
  assert(home:click(200,440)=="configure")
  assert(home.screen=="create" and starts==0,
    "room cannot launch before explicit confirmation")
  assert(not home.botsEnabled,"bots must be disabled by default")
  assert(home:click(160,466)=="bots_toggle")
  assert(home.botsEnabled and home.botCount==2)
  assert(home:click(508,517)=="bots_count" and home.botCount==3)
  assert(home:click(170,517)=="bots_count" and home.botCount==2)
  assert(home:click(160,408)=="difficulty" and home.difficulty=="dificil")
  assert(home:click(730,587)=="map_browse" and home.screen=="maps")
  local selected
  for i,entry in ipairs(home.mapCatalog) do
    if entry.id=="bunker-e-cavernas" then
      local n=i+1
      home.mapPage=math.floor((n-1)/6)
      local row=(n-1)%6+1
      selected=home:click(705,249+(row-1)*64)
      break
    end
  end
  assert(selected=="map_select" and home.mapId=="bunker-e-cavernas",
    "cave map missing from native package map picker")
  assert(home:mapName()=="Bunker e Cavernas",
    "selection must show exact map name, not MAPA: OUTRO")
  assert(home:click(820,650)=="maps_done" and home.screen=="create")
  assert(home:click(720,647)=="create")
  perform("create")
  assert(starts==1 and lastCount==2 and home.starting,
    "only explicit Create button may launch room")
  assert(home.screen=="play" and getClient()==nil,
    "room preparation must return to play, without auto-join")
  hosted.state="ready"
  hosted.hostIP="192.168.1.20"
  hosted.address="192.168.1.20:8080"
  hosted.code="test-code"
  love.update(0.016)
  assert(home.hosting and not home.starting)
  assert(getClient()==nil,"ready room cannot auto-enter")
  home.screen="home"
  perform("play_tab")
  assert(starts==1 and getClient()==nil,"opening Play must not create new room")
  assert(home:click(180,505)=="play_local")
  print("MOO IO ROOM CHOICE PASS: visible cave map + difficulty -> real host")
end
