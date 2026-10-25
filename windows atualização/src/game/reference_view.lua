-- Lua/LÖVE port of the reference Canvas drawing order and sprite rules.
-- Source: al007ex/moomoo-clone/client/src/index.js and client/public/img.
-- No improvised animal, weapon or tree illustrations.
local C=require("src.game.config")
local Catalog=require("src.game.catalog")
local Animals=require("src.game.animals")
local Shapes=require("src.game.reference_primitives")
local Objects=require("src.game.reference_objects")
local Assets=require("src.game.reference_assets")
local Mob=require("src.game.mob_animations")
local CombatText=require("src.game.reference_combat_text")
local BossEffects=require("src.game.reference_boss_effects")
local SecretMap=require("src.game.reference_secret_map")
local View={}
local Materials=require("src.game.map_materials")
-- client/src/index.js updateGame waterMult / waterPlus (Canvas only).
local waterMult=1
local waterPlus=1
function View.advanceWater(dt)
  if type(dt)~="number" or dt<=0 then return waterMult end
  waterMult=waterMult+waterPlus*C.waveSpeed*dt*1000
  if waterMult>=C.waveMax then
    waterMult=C.waveMax
    waterPlus=-1
  elseif waterMult<=1 then
    waterMult=1
    waterPlus=1
  end
  return waterMult
end
local pi=math.pi
local cos,sin=math.cos,math.sin

local skinColors={
  "#bf8f54","#cbb091","#896c4b","#fadadc","#ececec",
  "#c37373","#4c4c4c","#ecaff7","#738cc3","#8bc373"
}
local variants={[0]="",[1]="_g",[2]="_d",[3]="_r",[4]="_e"}
local hatById,tailById={},{}
for _,v in ipairs(Catalog.hats) do hatById[v.id]=v end
for _,v in ipairs(Catalog.accessories) do tailById[v.id]=v end
local function see(e,camera,w,h,scale)
  if type(e.x)~="number" or type(e.y)~="number" then return false end
  local x,y=camera:worldToScreen(e.visualX or e.x,e.visualY or e.y)
  local s=(scale or e.scale or 120)*camera.zoom
  return x+s>=0 and x-s<=w and y+s>=0 and y-s<=h
end
function View.riverGeometry(camera)
  -- World Y, not player Y or mouse dragging. This is the exact map centre
  -- used by client/src/index.js::renderWaterBodies.
  local _,y=camera:worldToScreen(0,C.mapScale/2)
  local bank=(C.riverWidth+C.riverPadding)*camera.zoom
  local water=(C.riverWidth+(waterMult-1)*250)*camera.zoom
  return y,bank,water
end
local function river(camera,w)
  local y,bank,water=View.riverGeometry(camera)
  Shapes.color("#dbc666")
  love.graphics.rectangle("fill",0,y-bank/2,w,bank)
  Shapes.color("#91b2db")
  love.graphics.rectangle("fill",0,y-water/2,w,water)
end
local function ground(camera,w,h)
  Shapes.color("#b6db66")
  love.graphics.rectangle("fill",0,0,w,h)
  local _,snow=camera:worldToScreen(0,C.snowBiomeTop)
  if snow>0 then
    Shapes.color("#ffffff")
    love.graphics.rectangle("fill",0,0,w,math.min(h,snow))
  end
  local _,desert=camera:worldToScreen(0,C.mapScale-C.snowBiomeTop)
  if desert<h then
    Shapes.color("#dbc666")
    love.graphics.rectangle("fill",0,math.max(0,desert),w,
      h-math.max(0,desert))
  end
  river(camera,w)
  -- The running Node server adds a valid west-of-map secret region absent
  -- from the archived browser renderer. Draw the Node-configured geography
  -- without altering original river, snow or desert east of x=0.
  SecretMap.draw(camera,w,h,waterMult)
end
local function grid(camera,w,h)
  -- Same transparent grid and spacing used by the reference Canvas client.
  love.graphics.setColor(0,0,0,0.06)
  love.graphics.setLineWidth(4)
  -- JS grid is maxScreenHeight/18 (60 world units), then transformed by
  -- resize()'s cover scale. Keep it aligned to the same camera world origin.
  local step=60*camera.zoom
  local originX,originY=camera:worldToScreen(0,0)
  local x=originX%step
  while x<w do
    love.graphics.line(x,0,x,h)
    x=x+step
  end
  local y=originY%step
  while y<h do
    love.graphics.line(0,y,w,y)
    y=y+step
  end
end
local function boundaries(camera,w,h)
  local x0,y0=camera:worldToScreen(0,0)
  local x1,y1=camera:worldToScreen(C.mapScale,C.mapScale)
  love.graphics.setColor(0,0,0,0.09)
  if x0>0 then
    -- Preserve the 9% reference edge shade everywhere EXCEPT inside the
    -- Node-authoritative west gorge / basins / waterfall.
    SecretMap.shadeOutside(camera,w,h)
  end
  if x1<w then love.graphics.rectangle("fill",math.max(0,x1),0,w-math.max(0,x1),h) end
  if y0>0 then love.graphics.rectangle("fill",0,0,w,math.min(h,y0)) end
  if y1<h then love.graphics.rectangle("fill",0,math.max(0,y1),w,h-math.max(0,y1)) end
end

local function drawObjectLayer(orderedObjects,camera,w,h,layer)
  -- JS prepareObjectRenderLists fills buckets in objectManager ARRAY order.
  -- No pairs(): that reorders overlapping sprites unpredictably in Lua.
  for _,o in ipairs(orderedObjects) do
    if Objects.layer(o)==layer and see(o,camera,w,h,tonumber(o.scale) or 100) then
      local x,y=camera:worldToScreen(o.x,o.y)
      Objects.draw(o,x+(o.wiggleX or 0)*camera.zoom,
        y+(o.wiggleY or 0)*camera.zoom,camera.zoom)
    end
  end
end
-- Packet X includes the projectile TYPE, not an image name or diameter.
-- Resolve the actual source and dimensions from the original items list.
-- Four types use original sprites; two are original Canvas circles.
function View.projectileStyle(projectile)
  if type(projectile)~="table" or type(projectile.indx)~="number"
    or projectile.indx%1~=0 then return nil end
  local spec=Catalog.projectiles[projectile.indx+1]
  if not spec or type(spec.scale)~="number" then return nil end
  return {
    layer=projectile.layer or spec.layer or 0,
    radius=spec.scale,
    src=spec.src,
    circle=not spec.src and spec.indx==1
  }
end
local function drawProjectiles(world,camera,w,h,layer)
  for _,p in pairs(world.projectiles) do
    local spec=View.projectileStyle(p)
    if spec and spec.layer==layer and
      see(p,camera,w,h,spec.radius) then
      local x,y=camera:worldToScreen(p.visualX or p.x,p.visualY or p.y)
      love.graphics.push("all")
      love.graphics.translate(x,y)
      love.graphics.rotate(p.dir or 0)
      if spec.src then
        -- The original drawImage uses (scale,scale) image dimensions;
        -- no zoom is applied twice when rotating the actual source PNG.
        Assets.draw("weapons",spec.src..".png",0,0,
          spec.radius*camera.zoom,spec.radius*camera.zoom)
      elseif spec.circle then
        Shapes.circle(0,0,spec.radius*camera.zoom,
          "#939393",Shapes.outline)
      end
      love.graphics.pop()
    end
  end
end
-- Crab King's surface/dive states originate from the Node I packet.
-- No alternative artwork is fabricated for underwater states.
function View.animalOpacity(animal,kind)
  if not kind or not kind.boss then return 1 end
  if animal.state==2 then return 0.2 end
  if animal.state==1 then return 0.55 end
  if animal.state==3 then return 0.7 end
  return 1
end
local function renderAnimal(a,camera,world,animatedOnly)
  local kind=world and world:animalKind(a.index) or Animals.byId(a.index)
  if not kind or not kind.src then return end
  local x,y=camera:worldToScreen(a.visualX or a.x,a.visualY or a.y)
  -- renderAI: tmpScale = scale * 1.2 * spriteMlt
  local radius=kind.scale*1.2*(kind.spriteMlt or 1)*camera.zoom
  local angle=(a.dir or 0)+(a.dirPlus or 0)-pi/2
  local alpha=View.animalOpacity(a,kind)
  -- Only real supplied PNGs: an absent enemy sprite must not make
  -- a server-authoritative enemy completely invisible.
  -- Map JSON may supply optional frames. No animation data or asset?
  -- Use the SAME original PNG; no change to classic/V2 visuals.
  local frames=Mob.definition(world and world.animationCatalog,a)
  local rendered=Mob.draw(a,frames,x,y,radius*2,angle,alpha)
  if not rendered and animatedOnly then return false end
  if not rendered then
    rendered=Assets.draw("animals",kind.src..".png",
      x,y,radius*2,radius*2,angle,alpha)
  end
  if not rendered and type(a.index)=="number" and a.index>=15
    and not animatedOnly then
    -- An optional community sprite may be missing. Keep the new species
    -- visible as a native wolf until its own PNG is installed locally.
    rendered=Assets.draw("animals","wolf_1.png",
      x,y,radius*2,radius*2,angle,alpha)
  end
  if not rendered then
    local candidate=Animals.fallbackArt and Animals.fallbackArt[kind.src]
    if candidate then
      Assets.draw("animals",candidate..".png",
        x,y,radius*2,radius*2,angle,alpha)
    end
  end
  return rendered
end
local function drawWeapon(weapon,variant,scale)
  local filename,fallback=Assets.weaponFilename(
    weapon.src,variants[variant or 0] or "")
  if not filename then return end
  -- The upstream has no bow_1_d.png. Use only the EXISTING original bow
  -- image in this exceptional case, never a newly invented sprite.
  local x,y=scale+(weapon.xOff or 0),(weapon.yOff or 0)
  local ok=Assets.draw("weapons",filename,x,y,weapon.length,weapon.width)
  if not ok and not fallback and variant and variant~=0 then
    Assets.draw("weapons",weapon.src..".png",x,y,
      weapon.length,weapon.width)
  end
  local proj=type(weapon.projectile)=="number"
    and Catalog.projectiles[weapon.projectile+1] or nil
  if proj and not weapon.hideProjectile and proj.src then
    Assets.draw("weapons",proj.src..".png",scale,0,proj.scale,proj.scale)
  end
end
local function drawTail(player)
  local tailId=player.tail
  local tail=type(tailId)=="number" and tailById[tailId] or nil
  if not tail then return end
  local x=-20-(tail.xOff or 0)
  Assets.draw("accessories","access_"..tailId..".png",x,0,
    tail.scale,tail.scale,tail.spin and (player.skinRot or 0) or 0)
end
local function drawHat(player)
  local hatId=player.skin
  local hat=type(hatId)=="number" and hatById[hatId] or nil
  if not hat then return end
  love.graphics.push()
  love.graphics.rotate(pi/2)
  Assets.draw("hats","hat_"..hatId..".png",0,0,hat.scale,hat.scale)
  if hat.topSprite then
    Assets.draw("hats","hat_"..hatId.."_top.png",0,0,
      hat.scale,hat.scale,player.skinRot or 0)
  end
  love.graphics.pop()
end
local function drawHeldItem(index,scale)
  local item=Catalog.itemById(index)
  if not item then return end
  local image=Objects.sprite({id=index,scale=item.scale})
  if image then
    local center=scale-(item.holdOffset or 0)+image:getWidth()/2
    love.graphics.setColor(1,1,1)
    love.graphics.draw(image,center,0,0,1,1,
      image:getWidth()/2,image:getHeight()/2)
  end
end
local function playerBody(p,dt)
  local scale=p.scale or C.playerScale
  local weapon=Catalog.weaponById(p.weaponIndex or 0)
  local build=type(p.buildIndex)=="number" and p.buildIndex or -1
  local armAngle=(pi/4)*((weapon and weapon.armS) or 1)
  local handAngle=build<0 and ((weapon and weapon.hndS) or 1) or 1
  local handDist=build<0 and ((weapon and weapon.hndD) or 1) or 1
  local col=skinColors[(tonumber(p.skinColor) or 0)+1] or skinColors[1]
  drawTail(p)
  if weapon and build<0 and not weapon.aboveHand then
    drawWeapon(weapon,p.variant,scale)
  end
  Shapes.circle(scale*cos(armAngle),scale*sin(armAngle),14,col,Shapes.outline)
  Shapes.circle(scale*handDist*cos(-armAngle*handAngle),
    scale*handDist*sin(-armAngle*handAngle),14,col,Shapes.outline)
  if weapon and build<0 and weapon.aboveHand then
    drawWeapon(weapon,p.variant,scale)
  end
  if build>=0 then drawHeldItem(build,scale) end
  Shapes.circle(0,0,scale,col,Shapes.outline)
  drawHat(p)
end
-- The browser uses getAttackDir() for the LOCAL player and the server's
-- direction for everyone else. Neither choice changes combat authority.
-- Both gameplay aim updates and local rendering use this same rule.
-- The server's K(0) locks direction; drawing must not keep tracking
-- the mouse after it has stopped receiving new direction packets.
function View.localAim(locked,cursor,lastSent)
  if locked then
    return type(lastSent)=="number" and lastSent or 0
  end
  return type(cursor)=="number" and cursor or 0
end
function View.playerDrawAngle(player,localAim)
  local direction=type(localAim)=="number" and localAim or (player.dir or 0)
  return direction+(player.dirPlus or 0)
end
-- Node setDive sends m(sid,state,duration) for player sprites, just as I
-- carries states for the Crab King. Fade the EXACT body/weapon/hat PNGs and
-- primitives in place; no replacement, fake sprite, or predicted movement.
function View.playerOpacity(player)
  if not player then return 1 end
  if player.dive==1 then return 0.55 end
  if player.dive==2 then return 0.2 end
  if player.dive==3 then return 0.7 end
  return 1
end
local diveShader=nil
local function playerDiveShader()
  if diveShader then return diveShader end
  -- Shape primitives use their own setColor calls; a shader multiplies
  -- their final alpha AND the original reference image alpha uniformly.
  diveShader=love.graphics.newShader([[
    uniform float diveOpacity;
    vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
      vec4 originalPixel = Texel(texture, textureCoords) * color;
      return vec4(originalPixel.rgb, originalPixel.a * diveOpacity);
    }
  ]])
  return diveShader
end
local function drawPlayer(p,camera,dt,localAim)
  local x,y=camera:worldToScreen(p.visualX or p.x,p.visualY or p.y)
  p.skinRot=(p.skinRot or 0)+dt*1000*0.002
  love.graphics.push("all")
  local opacity=View.playerOpacity(p)
  if opacity<1 then
    local shader=playerDiveShader()
    shader:send("diveOpacity",opacity)
    love.graphics.setShader(shader)
  end
  love.graphics.translate(x,y)
  love.graphics.rotate(View.playerDrawAngle(p,localAim))
  love.graphics.scale(camera.zoom)
  playerBody(p,dt)
  love.graphics.pop()
end
local chatFont=nil
local function drawChatBubble(p,x,y,scale)
  if not p.chatMessage or (p.chatCountdown or 0)<=0 then return end
  if not chatFont then chatFont=love.graphics.newFont(32) end
  local previous=love.graphics.getFont()
  love.graphics.setFont(chatFont)
  local content=p.chatMessage
  local tw=chatFont:getWidth(content)
  local bubbleW=tw+17
  local bubbleH=47
  local cx=x
  local cy=y-scale-90
  love.graphics.setColor(0,0,0,0.2)
  love.graphics.rectangle("fill",cx-bubbleW/2,cy-bubbleH/2,bubbleW,bubbleH,6,6)
  love.graphics.setColor(1,1,1)
  love.graphics.print(content,cx-tw/2,cy-chatFont:getHeight()/2)
  love.graphics.setFont(previous)
end
-- Render labels at original Canvas world coordinates; CSS HUD is separate.
function View.isTeammate(world,p)
  local me=world:localPlayer()
  return p.sid==world.sid or (me and type(me.team)=="string"
    and #me.team>0 and p.team==me.team) or false
end
function View.playerNameVisible(world,p)
  -- JS hides the name and health bar of enemy skin 10 (Assassin).
  return p.skin~=10 or View.isTeammate(world,p)
end
function View.animalName(a,world)
  local kind=world and world:animalKind(a.index) or Animals.byId(a.index)
  if not kind then return nil end
  if type(kind.name)=="string" then return kind.name end
  if type(a.nameIndex)=="number" and a.nameIndex%1==0 then
    return C.cowNames[a.nameIndex+1]
  end
  return nil
end
local labelFonts={}
local function font(size)
  size=math.max(10,math.floor(size))
  if not labelFonts[size] then labelFonts[size]=love.graphics.newFont(size) end
  return labelFonts[size]
end
local function labelText(content,sz)
  if type(content)~="string" or content=="" then return 0 end
  local f=font(sz)
  love.graphics.setFont(f)
  local w=f:getWidth(content)
  local top=-C.nameY
  -- JS uses strokeText with darkOutlineColor and rounded 8/11px stroke.
  Shapes.color(Shapes.darkOutline)
  local radius=(sz==30) and 4 or 5.5
  for i=0,7 do
    local angle=i*pi/4
    love.graphics.print(content,-w/2+cos(angle)*radius,
      top-f:getHeight()/2+sin(angle)*radius)
  end
  love.graphics.setColor(1,1,1)
  love.graphics.print(content,-w/2,top-f:getHeight()/2)
  return w
end
function View.healthBarOffset(entityScale)
  return 2*(entityScale or C.playerScale)+C.nameY
end
local function labelHealth(health,maxHealth,friendly,entityScale)
  if type(health)~="number" or health<=0
    or type(maxHealth)~="number" or maxHealth<=0 then return end
  local bar=C.healthBarWidth
  local pad=C.healthBarPad
  local ratio=math.max(0,math.min(1,health/maxHealth))
  local offset=View.healthBarOffset(entityScale)
  Shapes.color(Shapes.darkOutline)
  love.graphics.rectangle("fill",-bar-pad,offset,bar*2+pad*2,17,8,8)
  Shapes.color(friendly and "#8ecc51" or "#cc5151")
  love.graphics.rectangle("fill",-bar,offset+pad,bar*2*ratio,
    17-pad*2,7,7)
end
local function labels(world,camera,w,h)
  local previous=love.graphics.getFont()
  -- Original Canvas lists all players before animals, in creation order.
  for _,p in ipairs(world:orderedPlayers()) do
    -- The reference draws all server-visible bodies and labels, even when
    -- the centre is outside the viewport; broad cosmetics can cross an edge.
    if p.x and p.y and p.invisible~=1 then
      if View.playerNameVisible(world,p) then
        local x,y=camera:worldToScreen(p.visualX or p.x,p.visualY or p.y)
        local s=p.scale or C.playerScale
        love.graphics.push()
        love.graphics.translate(x,y-s*camera.zoom)
        love.graphics.scale(camera.zoom)
        local name=(type(p.team)=="string" and
          "["..p.team.."] " or "")..tostring(p.name or "")
        local textWidth=labelText(name,30)
        if p.isLeader==1 or p.isLeader==true then
          Assets.draw("icons","crown.png",
            -textWidth/2-C.crownPad,-C.nameY-5,
            C.crownIconScale,C.crownIconScale)
        end
        if p.icon==1 then
          Assets.draw("icons","skull.png",
            textWidth/2+C.crownPad,-C.nameY-5,
            C.crownIconScale,C.crownIconScale)
        end
        labelHealth(p.health,p.maxHealth,View.isTeammate(world,p),s)
        love.graphics.pop()
      end
    end
  end
  for _,a in ipairs(world:orderedAnimals()) do
    if a.x and a.y then
      local kind=world and world:animalKind(a.index) or Animals.byId(a.index)
      if kind then
        local x,y=camera:worldToScreen(a.visualX or a.x,a.visualY or a.y)
        love.graphics.push()
        love.graphics.translate(x,y-(kind.scale or 75)*camera.zoom)
        love.graphics.scale(camera.zoom)
        labelText(View.animalName(a,world),kind.nameScale or 30)
        labelHealth(a.health,kind.health,false,kind.scale)
        love.graphics.pop()
      end
    end
  end
  love.graphics.setFont(previous)
  -- Original updateGame calls textManager.update after all labels and
  -- before chat speech bubbles. The lifetime advances in World:update.
  CombatText.draw(world.combatText,camera)
  -- In client/src/index.js speech bubbles come after all world name/HP labels.
  for _,p in ipairs(world:orderedPlayers()) do
    if p.x and p.y and p.invisible~=1 then
      local x,y=camera:worldToScreen(p.visualX or p.x,p.visualY or p.y)
      drawChatBubble(p,x,y,(p.scale or C.playerScale)*camera.zoom)
    end
  end
end
-- All interactable art is projected from the same coordinates and
-- authoritative state as the physical custom-map geometry.
function View.nearestInteraction(world)
 local area=world and world.space
 local player=world and world:localPlayer()
 if not area or not player or type(player.x)~="number" then return nil end
 local best,dist
 for _,obj in ipairs(area.interactables or {}) do
  if (obj.kind=="cache" or obj.kind=="lever"
    or obj.kind=="node" or obj.kind=="switch") and not obj.used then
   local dx,dy=obj.x-player.x,obj.y-player.y
   local d=dx*dx+dy*dy
   if d<=150*150 and (not dist or d<dist) then
    best,dist=obj,d
   end
  end
 end
 return best
end
local function drawMapInteractables(world,camera)
 local area=world.space
 if not area then return end
 local u=camera.zoom
 for _,obj in ipairs(area.interactables or {}) do
  if obj.kind~="gate" or obj.closed then
   local x,y=camera:worldToScreen(obj.x,obj.y)
   if obj.kind=="cache" then
    love.graphics.setColor(obj.used and 0.26 or 0.50,
      obj.used and 0.24 or 0.34,0.17,1)
    love.graphics.rectangle("fill",x-35*u,y-26*u,70*u,52*u,4*u)
    love.graphics.setColor(obj.used and 0.4 or 0.85,0.65,0.29,1)
    love.graphics.rectangle("line",x-35*u,y-26*u,70*u,52*u,4*u)
    love.graphics.rectangle("fill",x-3*u,y-19*u,6*u,38*u)
   elseif obj.kind=="lever" or obj.kind=="switch" then
    love.graphics.setColor(0.27,0.31,0.31,1)
    love.graphics.circle("fill",x,y,29*u)
    love.graphics.setColor(obj.used and 0.35 or 0.94,
      obj.used and 0.80 or 0.58,0.18,1)
    love.graphics.setLineWidth(math.max(1,6*u))
    local angle=(obj.kind=="switch" and (obj.version or 0)%2==1
      or obj.used) and 0.8 or -0.8
    love.graphics.line(x,y,x+math.sin(angle)*43*u,y-math.cos(angle)*43*u)
    love.graphics.setLineWidth(1)
   elseif obj.kind=="node" then
    local n=obj.remaining or obj.charges or 0
    love.graphics.setColor(n>0 and 0.28 or 0.18,
      n>0 and 0.55 or 0.24,n>0 and 0.64 or 0.25,1)
    love.graphics.polygon("fill",x,y-38*u,x+34*u,y-7*u,
      x+22*u,y+27*u,x-25*u,y+30*u,x-37*u,y-5*u)
    love.graphics.setColor(0.87,0.92,0.85,1)
    love.graphics.print(tostring(n),x-5*u,y-9*u)
   elseif obj.kind=="gate" then
    -- The gate is already a real obstacle in zone.obstacles.
    love.graphics.setColor(0.95,0.75,0.31,1)
    love.graphics.circle("fill",x,y,6*u)
   end
  end
 end
end

-- Original game uses a flat surface. Custom LC map packs add their own
-- visually separate zones; all collision/teleport authority stays server-side.
local function drawMapHelp(world)
 if not world.map then return end
 local w,h=love.graphics.getDimensions()
 local near=world.spaceId=="surface"
 local mapName=world.map.name or world.map.id or "Personalizado"
 love.graphics.setColor(0.07,0.10,0.07,0.86)
 love.graphics.rectangle("fill",16,69,math.min(500,w-32),54,5,5)
 love.graphics.setColor(0.96,0.93,0.79,1)
 love.graphics.print("MAPA: "..mapName:upper(),25,76)
 love.graphics.setColor(0.66,0.88,0.53,1)
 love.graphics.print(near and "SUPERFICIE" or ("REGIAO: "..world.spaceId:upper()),25,99)
 local settings=world.roomSettings
 if settings and type(settings.difficulty)=="string" then
  local mods=type(settings.mods)=="table" and #settings.mods or 0
  love.graphics.setColor(0.08,0.11,0.07,0.85)
  love.graphics.rectangle("fill",16,167,math.min(500,w-32),32,5,5)
  love.graphics.setColor(0.88,0.91,0.72,1)
  local mobTotal=(tonumber(settings.surfaceAnimals) or 0)
    +(tonumber(settings.interiorAnimals) or 0)
  local modName=""
  if mods>0 and type(settings.mods[1])=="string" then
   modName=" ("..settings.mods[1]:sub(1,18)
     ..(mods>1 and " +"..(mods-1) or "")..")"
  end
  love.graphics.print("MODO: "..settings.difficulty:upper()..
    "  |  MODS: "..mods..modName.."  |  ANIMAIS: "..mobTotal,25,176)
 end
 if near then
  local player=world:localPlayer()
  if player and player.x and player.y and world.spaceId=="surface" then
   local nearest,dist
   for _,portal in ipairs(world.map.portals or {}) do
    if type(portal.x)=="number" and type(portal.y)=="number" then
     local dx,dy=portal.x-player.x,portal.y-player.y
     local d=math.floor(math.sqrt(dx*dx+dy*dy))
     if not dist or d<dist then nearest=portal;dist=d end
    end
   end
   if nearest then
    local label=nearest.label or nearest.to or "PASSAGEM"
    love.graphics.setColor(0.07,0.10,0.07,0.88)
    love.graphics.rectangle("fill",16,129,math.min(500,w-32),33,5,5)
    love.graphics.setColor(0.96,0.88,0.55,1)
    love.graphics.print("PASSAGEM "..label:upper():sub(1,22)..
      ": "..dist.."  -  ENTRE CAMINHANDO",25,138)
   end
  end
 end
 if near then
  love.graphics.setColor(0.09,0.11,0.09,0.83)
  love.graphics.rectangle("fill",16,h-52,345,36,5,5)
  love.graphics.setColor(0.96,0.95,0.87,1)
  love.graphics.print("B: CASA (70 MADEIRA, 35 PEDRA)",24,h-43)
 end
 if world.spaceId and world.spaceId:match("^casa%-%d+$") then
  love.graphics.setColor(0.09,0.11,0.09,0.83)
  love.graphics.rectangle("fill",16,h-52,390,36,5,5)
  love.graphics.setColor(0.96,0.95,0.87,1)
  love.graphics.print("H: EDITOR DE PAREDES  |  15 MADEIRA + 5 PEDRA",24,h-43)
 end
 local obj=View.nearestInteraction(world)
 if obj then
  love.graphics.setColor(0.10,0.11,0.10,0.88)
  love.graphics.rectangle("fill",w/2-205,h-170,410,37,6,6)
  love.graphics.setColor(0.97,0.89,0.65,1)
  local label=obj.label or (obj.kind=="cache" and "Bau de recursos"
    or obj.kind=="node" and "Ponto de coleta"
    or obj.kind=="switch" and "Interruptor" or "Alavanca")
  if obj.kind=="node" then
   label=label.." ("..tostring(obj.remaining or obj.charges)..")"
  end
  love.graphics.printf("F: "..label:sub(1,48),w/2-196,h-161,392,"center")
 end
 if world.mapMessage and (world.mapMessageTimer or 0)>0 then
  love.graphics.setColor(0.07,0.10,0.07,0.91)
  love.graphics.rectangle("fill",w/2-290,h-102,580,43,5,5)
  love.graphics.setColor(0.96,0.90,0.72,1)
  love.graphics.printf(world.mapMessage,w/2-276,h-91,552,"center")
 end
end
-- Doorways open visually as the avatar walks into them. The server
-- alone changes floors once it validates the crossing.
function View.doorOpenRatio(distance)
 if type(distance)~="number" or distance~=distance then return 0 end
 return math.max(0,math.min(1,(185-distance)/110))
end
local function doorProgress(world,portal)
 local player=world:localPlayer()
 if not player or type(player.x)~="number"
  or type(player.y)~="number" then return 0 end
 local dx,dy=player.x-portal.x,player.y-portal.y
 return View.doorOpenRatio(math.sqrt(dx*dx+dy*dy))
end

local function mapPortalMarkers(world,camera,indoor)
 if not indoor then return end
 local area=world.space
 if not area then return end
 for _,p in ipairs(area.portals or {}) do
  if type(p.x)=="number" and type(p.y)=="number" then
   local x,y=camera:worldToScreen(p.x,p.y)
   local u=camera.zoom
   local style=Materials.portalStyle(area,p)
   local theme=Materials.themes[Materials.visual(area).wall]
   local open=doorProgress(world,p)
   local w,h=176*u,144*u
   love.graphics.setColor(0.07,0.08,0.08,1)
   love.graphics.rectangle("fill",x-w/2,y-h/2,w,h,5*u,5*u)
   love.graphics.setColor(theme.trim)
   love.graphics.setLineWidth(math.max(1,4*u))
   love.graphics.rectangle("line",x-w/2,y-h/2,w,h,5*u,5*u)
   love.graphics.setLineWidth(1)
   if style=="stairs" or style=="tunnel" or style=="hatch" then
    for k=0,4 do
     local sy=y-49*u+k*25*u
     love.graphics.setColor(0.29-k*0.035,0.32-k*0.035,0.29-k*0.035,1)
     love.graphics.rectangle("fill",x-62*u,sy,124*u,17*u)
     love.graphics.setColor(theme.trim)
     love.graphics.line(x-62*u,sy,x+62*u,sy)
    end
   end
   if style=="hatch" or style=="door" then
    love.graphics.setColor(theme.wall)
    love.graphics.rectangle("fill",x-68*u-open*105*u,y-51*u,
      136*u*(1-open),102*u,3*u,3*u)
    love.graphics.setColor(theme.trim)
    love.graphics.rectangle("line",x-68*u-open*105*u,y-51*u,
      136*u*(1-open),102*u,3*u,3*u)
   elseif style=="tunnel" or style=="arch" then
    love.graphics.setColor(theme.wall)
    for _,rock in ipairs({{-83,-42,21},{81,49,25},
       {79,-44,18},{-80,54,19}}) do
     love.graphics.circle("fill",x+rock[1]*u,y+rock[2]*u,rock[3]*u)
    end
   end
  end
 end
end

local function drawHouses(world,camera)
 if not world.map or not world.space then return end
 for _,portal in ipairs(world.map.portals or {}) do
  if type(portal.x)=="number" and type(portal.y)=="number" then
   local x,y=camera:worldToScreen(portal.x,portal.y)
   local u=camera.zoom
   local style=Materials.portalStyle(nil,portal)
   if style=="tunnel" or style=="arch" then
     -- Rock ring and dark mouth; no house roof for caves.
     love.graphics.setColor(0.28,0.30,0.27)
     love.graphics.circle("fill",x,y,160*u)
     love.graphics.setColor(0.40,0.41,0.36)
     love.graphics.circle("line",x,y,150*u)
     love.graphics.setColor(0.085,0.095,0.085)
     love.graphics.circle("fill",x,y,96*u)
   elseif style=="hatch" or style=="stairs" then
     -- Steel hatch over reinforced concrete in the same top-down idiom.
     love.graphics.setColor(0.24,0.27,0.28)
     love.graphics.rectangle("fill",x-165*u,y-150*u,330*u,300*u)
     love.graphics.setColor(0.48,0.53,0.53)
     love.graphics.rectangle("fill",x-140*u,y-125*u,280*u,250*u)
     love.graphics.setColor(0.14,0.19,0.19)
     love.graphics.rectangle("fill",x-74*u,y-55*u,148*u,110*u)
     love.graphics.push("all")
     love.graphics.translate(x-74*u,y-55*u)
     love.graphics.rotate(-doorProgress(world,portal)*math.pi*0.48)
     love.graphics.setColor(0.34,0.42,0.44)
     love.graphics.rectangle("fill",0,0,146*u,108*u,4*u,4*u)
     love.graphics.setColor(0.63,0.69,0.69)
     love.graphics.rectangle("line",4*u,4*u,138*u,100*u)
     love.graphics.setColor(0.93,0.76,0.36)
     love.graphics.circle("fill",120*u,54*u,8*u)
     love.graphics.pop()
   else
   -- The roof is opaque outdoors. It is absent when the player enters,
   -- revealing the separately rendered interior on the next server packet.
   love.graphics.setColor(0.30,0.21,0.14)
   love.graphics.rectangle("fill",x-220*u,y-230*u,440*u,405*u)
   love.graphics.setColor(0.58,0.37,0.21)
   love.graphics.rectangle("fill",x-197*u,y-211*u,394*u,363*u)
   love.graphics.setColor(0.73,0.49,0.28)
   love.graphics.rectangle("fill",x-184*u,y-195*u,368*u,335*u)
   love.graphics.setColor(0.24,0.18,0.12)
   love.graphics.rectangle("fill",x-64*u,y+120*u,128*u,65*u)
   love.graphics.setColor(0.90,0.75,0.37)
   love.graphics.circle("fill",x,y+167*u,24*u)
   end -- house roof
   if portal.style then
    local label=(portal.label or portal.to or "PASSAGEM"):upper():sub(1,25)
    love.graphics.setColor(0.08,0.10,0.08,0.85)
    love.graphics.rectangle("fill",x-94*u,y-191*u,188*u,31*u,5*u,5*u)
    love.graphics.setColor(0.97,0.87,0.55,1)
    love.graphics.printf(label,x-90*u,y-187*u,180*u,"center")
   end
  end
 end
end

-- In-game floor plan derived solely from authoritative zone rectangles,
-- not an independent PNG map. Exits and player location share world coords.
function View.dungeonMapGeometry(zone,player,size)
 if type(zone)~="table" or type(zone.width)~="number"
   or type(zone.height)~="number" or zone.width<=0 or zone.height<=0
   or type(player)~="table" then return nil end
 size=size or 174
 local factor=size/math.max(zone.width,zone.height)
 local left=(size-zone.width*factor)*0.5
 local top=(size-zone.height*factor)*0.5
 return {scale=factor,left=left,top=top,
  x=left+(player.x or 0)*factor,
  y=top+(player.y or 0)*factor}
end
local function drawDungeonMap(world)
 local zone=world.space
 local player=world:localPlayer()
 if not zone or not player or type(player.x)~="number" then return end
 local size=174
 local g=View.dungeonMapGeometry(zone,player,size)
 if not g then return end
 local left,top=22,230
 love.graphics.push("all")
 love.graphics.setColor(0.06,0.08,0.09,0.90)
 love.graphics.rectangle("fill",left-7,top-29,size+14,size+37,6,6)
 love.graphics.setColor(0.91,0.92,0.83,1)
 love.graphics.print("PLANTA DO ANDAR  [M]",left,top-22)
 love.graphics.setColor(0.15,0.19,0.19,1)
 love.graphics.rectangle("fill",left,top,size,size)
 local ox,oy=left+g.left,top+g.top
 local zoneWidth,zoneHeight=zone.width*g.scale,zone.height*g.scale
 love.graphics.setColor(0.37,0.43,0.43,1)
 love.graphics.rectangle("line",ox,oy,zoneWidth,zoneHeight)
 love.graphics.setScissor(left,top,size,size)
 for _,r in ipairs(zone.obstacles or {}) do
  love.graphics.setColor(r.material=="wood" and 0.58 or 0.57,
    r.material=="wood" and 0.38 or 0.62,
    r.material=="wood" and 0.23 or 0.57,1)
  love.graphics.rectangle("fill",ox+r.x*g.scale,oy+r.y*g.scale,
    math.max(1,r.width*g.scale),math.max(1,r.height*g.scale))
 end
 for _,portal in ipairs(zone.portals or {}) do
  local x,y=ox+portal.x*g.scale,oy+portal.y*g.scale
  love.graphics.setColor(0.98,0.80,0.32,1)
  love.graphics.circle("fill",x,y,4)
  love.graphics.setColor(0.12,0.12,0.12,1)
  love.graphics.circle("line",x,y,4)
 end
 for _,other in ipairs(world:orderedPlayers()) do
  if other.sid~=world.sid and other.x and other.y and
   player.team and player.team~=false and other.team==player.team then
   love.graphics.setColor(0.39,0.84,0.96,1)
   love.graphics.circle("fill",ox+other.x*g.scale,
     oy+other.y*g.scale,3)
  end
 end
 love.graphics.setColor(0.26,0.98,0.37,1)
 love.graphics.circle("fill",left+g.x,top+g.y,5)
 love.graphics.setColor(0.07,0.18,0.09,1)
 love.graphics.circle("line",left+g.x,top+g.y,5)
 love.graphics.setScissor()
 love.graphics.pop()
end

local function drawIndoor(world,camera,dt,options)
 local area=assert(world.space,"active local area required")
 local w,h=love.graphics.getDimensions()
 local mine=area.type=="underground"
 love.graphics.setColor(mine and 0.25 or 0.68,
  mine and 0.26 or 0.59,mine and 0.27 or 0.43,1)
 love.graphics.rectangle("fill",0,0,w,h)
 local x0,y0=camera:worldToScreen(0,0)
 local x1,y1=camera:worldToScreen(area.width,area.height)
 love.graphics.setColor(mine and 0.39 or 0.78,
  mine and 0.37 or 0.67,mine and 0.33 or 0.53,1)
 love.graphics.rectangle("fill",x0,y0,x1-x0,y1-y0)
 -- All geometry is described by map JSON; zone IDs do not select
 -- materials. Community maps can mix wood, metal, rock, sand, ice and more.
 local visual=Materials.visual(area)
 local material=Materials.themes[visual.floor]
 local wallMaterial=Materials.themes[visual.wall]
 local tile=visual.tileSize
 local xmin=math.max(0,math.floor(camera:screenToWorld(0,0)/tile)-1)
 local xmax=math.min(math.ceil(area.width/tile),
   math.ceil(camera:screenToWorld(w,0)/tile)+1)
 local _,wy0=camera:screenToWorld(0,0)
 local _,wy1=camera:screenToWorld(0,h)
 local ymin=math.max(0,math.floor(wy0/tile)-1)
 local ymax=math.min(math.ceil(area.height/tile),math.ceil(wy1/tile)+1)
 love.graphics.setColor(material.floor)
 love.graphics.rectangle("fill",x0,y0,x1-x0,y1-y0)
 for iy=ymin,ymax do
  for ix=xmin,xmax do
   local px,py=camera:worldToScreen(ix*tile,iy*tile)
   local size=tile*camera.zoom
   local hash=(ix*137+iy*97+ix*iy*17)%13
   local variation=(hash-6)*0.003
   local color=material.floor
   love.graphics.setColor(math.min(1,color[1]+variation),
     math.min(1,color[2]+variation),math.min(1,color[3]+variation),1)
   love.graphics.rectangle("fill",px+1,py+1,size-2,size-2)
   love.graphics.setColor(material.trim[1],material.trim[2],
     material.trim[3],0.36)
   love.graphics.rectangle("line",px+3,py+3,size-6,size-6)
   if visual.floor=="rock" or visual.floor=="stone"
     or visual.floor=="earth" or visual.floor=="sand" then
    love.graphics.line(px+size*0.15,py+size*0.28,
      px+size*0.47,py+size*0.41,
      px+size*0.65,py+size*0.66)
   elseif visual.floor=="metal" then
    for _,corner in ipairs({{11,11},{tile-11,11},{11,tile-11},
      {tile-11,tile-11}}) do
     love.graphics.circle("fill",px+corner[1]*camera.zoom,
       py+corner[2]*camera.zoom,2.5*camera.zoom)
    end
   elseif visual.floor=="wood" then
    love.graphics.line(px,py+size*0.5,px+size,py+size*0.5)
   end
  end
 end
 for _,obstacle in ipairs(area.obstacles or {}) do
  local x,y=camera:worldToScreen(obstacle.x,obstacle.y)
  local a,b=obstacle.width*camera.zoom,obstacle.height*camera.zoom
  love.graphics.setColor(0.08,0.09,0.08,0.5)
  love.graphics.rectangle("fill",x+4*camera.zoom,y+5*camera.zoom,a,b)
  local wallTheme=Materials.themes[obstacle.material] or wallMaterial
  love.graphics.setColor(wallTheme.wall)
  love.graphics.rectangle("fill",x,y,a,b)
  love.graphics.setColor(wallTheme.trim[1],wallTheme.trim[2],
    wallTheme.trim[3],0.56)
  love.graphics.rectangle("line",x+3*camera.zoom,y+3*camera.zoom,
    math.max(2,a-6*camera.zoom),math.max(2,b-6*camera.zoom))
  if obstacle.material=="wood" then
    love.graphics.setColor(0.22,0.15,0.09,0.52)
    local along=(obstacle.width>obstacle.height)
    local tiles=math.floor((along and obstacle.width or obstacle.height)/40)
    for i=1,tiles do
      if along then
        love.graphics.line(x+i*40*camera.zoom,y,
          x+i*40*camera.zoom,y+b)
      else
        love.graphics.line(x,y+i*40*camera.zoom,
          x+a,y+i*40*camera.zoom)
      end
    end
  end
  love.graphics.setColor(1,1,1,0.1)
  love.graphics.rectangle("fill",x+3*camera.zoom,y+3*camera.zoom,a-6*camera.zoom,5*camera.zoom)
 end
 mapPortalMarkers(world,camera,true)
 drawMapInteractables(world,camera)
 -- Mob AI and original projectile packets must be drawn inside caves,
 -- not only on the outdoor surface.
 drawProjectiles(world,camera,w,h,0)
 for _,a in ipairs(world:orderedAnimals()) do
  local kind=world and world:animalKind(a.index) or Animals.byId(a.index)
  if a.x and a.y and kind then renderAnimal(a,camera,world) end
 end
 for _,ghost in ipairs(world.mobDeathEffects or {}) do
  renderAnimal(ghost,camera,world,true)
 end
 drawProjectiles(world,camera,w,h,1)
 for _,p in ipairs(world:orderedPlayers()) do
  if p.x and p.y and p.invisible~=1 then
   local aim=(p.sid==world.sid and options) and options.localAim or nil
   drawPlayer(p,camera,dt or 0,aim)
  end
 end
 labels(world,camera,w,h)
 drawMapHelp(world)
 if options and options.showDungeonMap~=false then
  drawDungeonMap(world)
 end
 love.graphics.setColor(0.06,0.07,0.06,0.85)
 love.graphics.rectangle("fill",15,14,250,39,5,5)
 love.graphics.setColor(1,1,1,1)
 love.graphics.print(
   visual.name or (area.type=="underground" and "SUBSOLO" or "INTERIOR"),
   27,24)
end

function View.draw(world,camera,dt,options)
  if world.map and world.spaceId and world.spaceId~="surface" then
    return drawIndoor(world,camera,dt,options)
  end
  local w,h=love.graphics.getDimensions()
  -- Aiming is local presentation only. The actual attack and target
  -- direction are still transmitted via the original D/F Node packets.
  local function aimFor(player)
    if player.sid==world.sid and options then return options.localAim end
    return nil
  end
  View.advanceWater(dt or 0)
  ground(camera,w,h)
  if not options or options.showGrid~=false then
    grid(camera,w,h)
  end
  -- Show server-defined attack areas on the ground, below animals/players.
  -- This makes the imminent boss hit visible without changing collisions.
  BossEffects.draw(world.bossEffects,camera)
  local objects=world:orderedObjects()
  -- The JS engine iterates the same players[] and ais[] arrays for each
  -- rendering pass, preserving overlap and zIndex across frames.
  local players=world:orderedPlayers()
  local animals=world:orderedAnimals()
  drawObjectLayer(objects,camera,w,h,-1)
  drawProjectiles(world,camera,w,h,0)
  for _,p in ipairs(players) do
    if (p.zIndex or 0)==0 and p.x and p.y and p.invisible~=1
      then drawPlayer(p,camera,dt or 0,aimFor(p)) end
  end
  for _,a in ipairs(animals) do
    local kind=world and world:animalKind(a.index) or Animals.byId(a.index)
    if kind and a.x and a.y then renderAnimal(a,camera,world) end
  end
  for _,ghost in ipairs(world.mobDeathEffects or {}) do
    renderAnimal(ghost,camera,world,true)
  end
  drawObjectLayer(objects,camera,w,h,0)
  drawProjectiles(world,camera,w,h,1)
  drawObjectLayer(objects,camera,w,h,1)
  for _,p in ipairs(players) do
    if (p.zIndex or 0)==1 and p.x and p.y and p.invisible~=1
      then drawPlayer(p,camera,dt or 0,aimFor(p)) end
  end
  drawObjectLayer(objects,camera,w,h,2)
  drawObjectLayer(objects,camera,w,h,3)
  if world.map then
    drawHouses(world,camera)
    drawMapInteractables(world,camera)
  end
  boundaries(camera,w,h)
  -- The JS reference composites this violet-blue tint after game objects
  -- and before world labels, not over the HTML/CSS HUD.
  love.graphics.setColor(0,0,70/255,0.35)
  love.graphics.rectangle("fill",0,0,w,h)
  love.graphics.setColor(1,1,1,1)
  labels(world,camera,w,h)
  if world.map then
    mapPortalMarkers(world,camera,false)
    drawMapHelp(world)
  end
end
return View
