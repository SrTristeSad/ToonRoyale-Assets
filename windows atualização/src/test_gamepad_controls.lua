-- Real client callback regressions with a generic USB joystick simulation.
-- No server-authoritative inventory or aim packets are fabricated.
return function(setClient,setWorld,setPhase)
 local Pad=require("src.game.gamepad_controls")
 local World=require("src.game.world_state")
 local Hud=require("src.game.reference_hud")
 local joy={axes={[1]=0.9,[2]=0,[3]=0,[4]=0.9,[6]=0},
   buttons={},connected=true}
 function joy:isGamepad() return false end
 function joy:isConnected() return self.connected end
 function joy:getAxisCount() return 6 end
 function joy:getButtonCount() return 12 end
 function joy:getAxis(i) return self.axes[i] or 0 end
 function joy:isDown(i) return self.buttons[i]==true end
 assert(Pad.active({joy})==joy)
 assert(Pad.axis(joy,"leftx")==0.9)
 assert(Pad.axis(joy,"righty")==0.9)
 assert(not Pad.triggerRight(joy))
 assert(Pad.buttonName(joy,5)=="leftshoulder")
 local mapped={
   isGamepad=function()return true end,
   isConnected=function()return true end,
   getGamepadAxis=function(_,name) return name=="rightx" and -0.75 or 0 end,
   isGamepadDown=function(_,button) return button=="rightshoulder" end
 }
 assert(Pad.active({joy,mapped})==mapped,"mapped device should take priority")
 assert(Pad.axis(mapped,"rightx")==-0.75 and Pad.button(mapped,"rightshoulder"))
 local w=World.new()
 w.sid=7;w.spawned=true
 w.players[7]={sid=7,id=7,name="Tester",x=8000,y=8000,
   visualX=8000,visualY=8000,scale=35,buildIndex=-1,weaponIndex=0}
 w.inventory={weapons={0,1},items={0,3}}
 local first,weapon,slot=Hud.cycleSlot(w,1,nil)
 assert(first==1 and weapon and slot==2,
   "R2 must advance from starter weapon to next weapon")
 local nextId,nextWeapon,nextSlot=Hud.cycleSlot(w,1,slot)
 assert(nextId==0 and not nextWeapon and nextSlot==3,
   "R2 must advance from weapons into building items")
 local backId,backWeapon,backSlot=Hud.cycleSlot(w,-1,nextSlot)
 assert(backId==1 and backWeapon and backSlot==2,
   "L1 must navigate backward in same action bar")
 local client={name="Tester",sid=7,state="spawn_confirmed",
   sends={},events={}}
 function client:update() end
 function client:drain() local q=self.events;self.events={};return q end
 function client:send(name,args)
  self.sends[#self.sends+1]={name=name,args=args}
  return true
 end
 function client:close()end
 local old=love.joystick.getJoysticks
 love.joystick.getJoysticks=function()return {joy}end
 local function packets(name)
  local out={}
  for _,packet in ipairs(client.sends) do
   if packet.name==name then out[#out+1]=packet end
  end
  return out
 end
 local function frame() love.update(0.082) end
 setClient(client);setWorld(w);setPhase("playing")
 frame()
 assert(#packets("9")>=1,"left analog must send move packet 9")
 local aims=packets("D")
 assert(#aims>0 and math.abs(aims[#aims].args[1]-math.pi/2)<0.08,
   "right R3 analog must guide authoritative weapon D angle")
 -- R2 cycles exactly one hotbar item per physical pull.
 joy.axes[6]=0.85;frame()
 local z=packets("z")
 assert(#z==1 and z[1].args[1]==1 and z[1].args[2]==true,
   "R2 must choose next weapon via server z packet")
 frame()
 assert(#packets("z")==1,"held R2 must not skip multiple slots")
 joy.axes[6]=0;frame()
 joy.axes[6]=0.9;frame()
 z=packets("z")
 assert(#z==2 and z[2].args[1]==0 and z[2].args[2]==false,
   "next R2 pull must select first build item")
 -- L1 navigates backward even with a generic unmapped USB joystick.
 love.joystickpressed(joy,5)
 z=packets("z")
 assert(#z==3 and z[3].args[1]==1 and z[3].args[2]==true,
   "L1 must return to previous weapon")
 -- R1 attacks, leaving R2 independent for hotbar navigation.
 joy.buttons[6]=true;frame()
 local attacks=packets("F")
 assert(#attacks>0 and attacks[#attacks].args[1]==1,
   "R1 must start attack")
 joy.buttons[6]=false;frame()
 attacks=packets("F")
 assert(attacks[#attacks].args[1]==0,"releasing R1 must stop attack")
 -- Neutral right stick retains chosen angle instead of snapping to mouse.
 local n=#packets("D")
 joy.axes[3]=0;joy.axes[4]=0;frame()
 assert(#packets("D")==n,"centering R3 must preserve current aim")
 -- Rotating right stick must update direction even without attacking.
 joy.axes[3]=-1;joy.axes[4]=0;frame()
 aims=packets("D")
 assert(math.abs(math.abs(aims[#aims].args[1])-math.pi)<0.08,
   "rotating R3 must turn the visible weapon and server direction")
 setClient(nil);setPhase("menu")
 love.joystick.getJoysticks=old
 print("MOO IO GAMEPAD PASS: generic USB, R3 aim, L1/R2 hotbar, R1 attack")
end
