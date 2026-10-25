-- Regression: genuine Node-style packets drive the Lua client's visible weapon.
-- This renders only a deterministic fixture; it never creates fake live players.
return function()
  local World=require("src.game.world_state")
  local View=require("src.game.reference_view")
  local Hud=require("src.game.reference_hud")
  local Camera=require("src.camera")
  local Catalog=require("src.game.catalog")
  local Assets=require("src.game.reference_assets")
  local world=World.new()
  assert(world:apply("C",{0}),"server spawn C required")
  assert(world:apply("D",{{"visual-test",0,"Jogador",8000,8000,0,
    100,100,35,0}}),"server snapshot D required")
  local camera=Camera.new()
  camera:follow(8000,8000)
  local canvas=love.graphics.newCanvas(1280,720)
  local function capture(weaponId,weaponInventory,label)
    assert(world:apply("a",{{0,8000,8000,0},
      {0,-1,weaponId,0,false,0,0,0,0,0},{}}),"server attributes a required")
    if weaponInventory then
      assert(world:apply("V",{weaponInventory,1}),"server inventory V required")
      assert(Hud.slotForKey(world,"1")==weaponId,
        "client action bar lost its evolved primary weapon: "..weaponId)
    end
    local def=Catalog.weaponById(weaponId)
    if def then
      assert(Assets.get("weapons",def.src..".png"),
        "missing original weapon sprite "..def.src)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0,0,0,0)
    View.draw(world,camera,0,{showGrid=true})
    Hud.draw(world,false,"",true)
    love.graphics.pop()
    local pixels=canvas:newImageData()
    if os.getenv("MOO_IO_CAPTURE_UI")=="1" then
      local filename="ui-weapon-"..label..".png"
      pixels:encode("png",filename)
      print("UI CAPTURE "..filename.." -> "..love.filesystem.getSaveDirectory())
    end
    return pixels
  end
  local empty=capture(999,nil,"none")
  local hammer=capture(0,{0},"hammer")
  local sword=capture(3,{3},"sword")
  local katana=capture(4,{4},"katana")
  local function visibleWeapon(image,name)
    local total=0
    for y=225,450,4 do
      for x=480,805,4 do
        local r,g,b=image:getPixel(x,y)
        local r0,g0,b0=empty:getPixel(x,y)
        total=total+math.abs(r-r0)+math.abs(g-g0)+math.abs(b-b0)
      end
    end
    assert(total>8,name.." vanished from the rendered player body")
    print(("MOO IO WEAPON %s: render difference %.2f"):format(name,total))
  end
  visibleWeapon(hammer,"hammer")
  visibleWeapon(sword,"sword")
  visibleWeapon(katana,"katana")
  canvas:release()
  print("MOO IO WEAPON VISUAL PASS: hammer, sword and katana after authentic a/V packets")
end
