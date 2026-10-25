-- Controller and keyboard customization integration, including persistence.
return function()
 local Settings=require("src.game.control_settings")
 local cfg=Settings.new()
 cfg:reset(true)
 cfg:show()
 assert(cfg:click(550,160)=="capture")
 assert(cfg.waiting.id=="moveUp" and cfg.waiting.kind=="keyboard")
 assert(cfg:captureKeyboard("i"))
 assert(cfg:key("moveUp")=="i","keyboard remapping not applied")
 assert(cfg:click(800,320)=="capture")
 assert(cfg.waiting.kind=="button" and cfg.waiting.id=="previous")
 assert(cfg:captureButton(nil,10))
 assert(cfg.mapping.previous.button==10)
 assert(cfg:click(160,570)=="change" and cfg.rawMove==2)
 assert(cfg:click(700,570)=="change" and cfg.rawAim==4)
 local previous=cfg.deadzone
 assert(cfg:click(180,612)=="change" and cfg.deadzone>previous)
 local before=cfg.sensitivity
 assert(cfg:click(570,612)=="change" and cfg.sensitivity>before)
 local mapped={
  isGamepad=function()return true end,
  getGamepadAxis=function(_,axis)return axis=="leftx" and 0.9 or 0 end,
  isGamepadDown=function(_,name)return name=="a" end
 }
 local raw={
  isGamepad=function()return false end,
  getAxis=function(_,i)return i==2 and 0.8 or (i==4 and -0.9 or 0) end,
  isDown=function(_,i)return i==10 end
 }
 assert(cfg:axis(raw,"leftx")==0.8 and cfg:axis(raw,"rightx")==-0.9)
 assert(cfg:button(raw,"previous") and cfg:matches(raw,10,"previous"))
 assert(cfg:button(mapped,"interact"))
 local x,y=cfg:stick(0.85,0)
 assert(x>0 and x<=1 and y==0)
 cfg:save()
 local loaded=Settings.new()
 assert(loaded:key("moveUp")=="i")
 assert(loaded.mapping.previous.button==10)
 assert(loaded.rawMove==2 and loaded.rawAim==4)
 assert(loaded.deadzone==cfg.deadzone and loaded.sensitivity==cfg.sensitivity)
 assert(cfg:click(200,658)=="reset")
 assert(cfg:key("moveUp")=="w" and cfg.mapping.previous.button=="leftshoulder")
 assert(cfg:click(1122,114)=="close" and not cfg:isOpen())
 cfg:reset(true)
 print("PASS custom controls: keyboard, joystick buttons, analog axes, sensitivity, save/reload")
end
