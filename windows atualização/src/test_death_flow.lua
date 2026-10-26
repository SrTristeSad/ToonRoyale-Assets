-- Headless LÖVE regression for death/respawn paths of a guest and owner.
-- No network, no fabricated game success: confirmations are server packets.
return function(death,home,hosted,setWorld,getWorld,setClient,getClient,
    setOwner,setPhase,getPhase,getCamera,connectRoom)
 local World=require("src.game.world_state")
 local function prepare(owner)
  local fake={name="Visitante",sid=7,state="spawn_confirmed",
    status="Conectado",sent={},queue={},spawns=0,closed=0}
  function fake:update() end
  function fake:drain()
   local q=self.queue
   self.queue={}
   return q
  end
  function fake:send(name,args)
   self.sent[#self.sent+1]={name=name,args=args}
   return true
  end
  function fake:spawn(profile)
   self.spawns=self.spawns+1
   self.profile=profile
   self.state="joining"
   return true
  end
  function fake:close() self.closed=self.closed+1 end
  local world=World.new()
  world.sid=7
  world.spawned=true
  world.players[7]={sid=7,x=1240,y=1780,visualX=1240,visualY=1780,
    scale=35,name="Visitante",alive=true}
  setWorld(world)
  setClient(fake)
  setOwner(owner)
  setPhase("playing")
  home.screen="play"
  death:reset()
  fake.queue={{kind="game_packet",data={name="P",args={}}}}
  love.update(0.016)
  assert(getPhase()=="death","death packet must trigger original animation")
  assert(world.lastDeath and world.lastDeath.x==1240
    and world.lastDeath.y==1780,"server death location was not preserved")
  local camera=getCamera()
  assert(camera.x==1240 and camera.y==1780,
    "death world backdrop did not freeze at last position")
  return fake,world
 end
 local guest,world=prepare(false)
 love.update(death.DURATION+0.1)
 assert(getPhase()=="death_choice","visitor must be offered a choice")
 assert(death:choiceAt(640,410,1280,720)=="back")
 assert(death:choiceAt(640,484,1280,720)=="exit")
 love.draw() -- Actual backdrop and modal should render.
 love.keypressed("return")
 assert(guest.spawns==1 and guest.profile.name=="Visitante",
  "return must request server-authoritative respawn without reconnecting")
 love.keypressed("return")
 assert(guest.spawns==1,"second return must not resend the spawn packet")
 assert(getPhase()=="death_choice","must wait for server confirmation")
 guest.state="spawn_confirmed"
 guest.queue={{kind="game_packet",data={name="C",args={7}}}}
 love.update(0.016)
 assert(getPhase()=="playing","only packet C permits gameplay")
 assert(getClient()==guest and guest.closed==0)
 local guestExit=prepare(false)
 love.update(death.DURATION+0.1)
 local hostState=hosted.state
 love.mousepressed(640,487,1)
 assert(getPhase()=="menu" and getClient()==nil
   and guestExit.closed==1,"guest exit must disconnect local client")
 assert(hosted.state==hostState,"guest exit must never terminate friend server")
 local owner=prepare(true)
 love.update(death.DURATION+0.1)
 assert(getPhase()=="menu","owner should retain existing post-death menu")
 assert(getClient()==owner and owner.closed==0,
  "owner death must not close its game connection")
 assert(getWorld().lastDeath.x==1240 and getCamera().x==1240)
 love.draw() -- Owner sees last death site behind familiar menu.
 -- The owner's Play Again MUST use the SAME Player/socket. Reconnecting
 -- discards shop purchases and triggers removal of placed server objects.
 local Marker=require("src.game.death_marker")
 local oldState,oldIP,oldPort,oldCode=
   hosted.state,hosted.hostIP,hosted.port,hosted.code
 hosted.state="ready"
 hosted.hostIP="127.0.0.1"
 hosted.port=19128
 hosted.code="owner-death-room"
 owner.host=hosted.hostIP
 owner.port=hosted.port
 owner.inviteCode=hosted.code
 owner.name="Jogador"
 -- Server player retains purchases and placed buildings when no socket is closed.
 world.store.hats[5]=true;world.store.hatIndex=5
 local oldMark=world.lastDeath
 home.hosting=true
 home.hostAddress=hosted.hostIP
 home.hostCode=hosted.code
 home.screen="play"
 -- Exercise the actual GUI's JOGAR AGORA button, not a direct fake spawn.
 love.mousepressed(530,506,1)
 assert(owner.spawns==1 and owner.closed==0,
   "owner must respawn without closing the purchased-items socket")
 assert(getWorld()==world and getWorld().lastDeath==oldMark,
   "owner's respawn must preserve world state and death X")
 assert(world.store.hats[5] and world.store.hatIndex==5,
   "shop purchases must not be reset on owner respawn")
 owner.queue={{kind="game_packet",data={name="C",args={7}}}}
 owner.state="spawn_confirmed"
 love.update(0.016)
 assert(getPhase()=="playing" and getClient()==owner,
   "owner should resume after server C confirmation on existing socket")
 assert(world.store.hats[5] and world.store.hatIndex==5)
 assert(Marker.minimapPoint(world,130,14400),
   "last death X must remain on the minimap after owner respawns")
 hosted.state,hosted.hostIP,hosted.port,hosted.code=
   oldState,oldIP,oldPort,oldCode
 home.hosting=false
 setClient(nil)
 setOwner(false)
 setPhase("menu")
 death:reset()
 print("MOO IO DEATH FLOW PASS: guest return/exit, owner same-session respawn with purchased items and minimap X")
end
