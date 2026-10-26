-- Optional sprite-sheet animation layer for local custom-map animals.
-- Original combat, AI, networking and static sprites remain authoritative.
-- Missing configuration or PNG always falls back to reference animal art.
local Mob={}
local states={idle=true,walk=true,attack=true,hurt=true,death=true}
local sheets={}
local warned={}
local quads=setmetatable({},{__mode="k"})
local function isFinite(v)
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function safeSheet(name)
 return type(name)=="string" and #name<=64
  and name:match("^[a-zA-Z0-9][a-zA-Z0-9_%-]*%.png$")~=nil
end
function Mob.definition(map,animal)
 if not map or type(map.animations)~="table" or not animal
  or type(animal.index)~="number" then return nil end
 local entry=map.animations[tostring(animal.index)]
 return type(entry)=="table" and entry or nil
end
local function duration(set,state)
 local clip=type(set)=="table" and set[state]
 if type(clip)=="table" and isFinite(clip.fps)
   and clip.fps>0 and isFinite(clip.frames)
   and clip.frames>0 then
  return clip.frames/clip.fps
 end
 return state=="attack" and 0.6 or state=="hurt" and 0.30 or 0.7
end
function Mob.onPosition(entity,x,y)
 if type(entity)~="table" or not isFinite(x) or not isFinite(y) then return end
 local ox,oy=entity.x,entity.y
 if isFinite(ox) and isFinite(oy) then
  local dx,dy=x-ox,y-oy
  local d=dx*dx+dy*dy
  if d>9 and d<40000 then
   entity.mobWalkLeft=0.32
  elseif d>=40000 then
   entity.mobWalkLeft=0 -- teleports do not play walking cycles
  end
 end
end
function Mob.onAttack(entity,set)
 if type(entity)~="table" then return end
 entity.mobAction="attack"
 entity.mobActionLeft=duration(set,"attack")
end
function Mob.onHurt(entity,set)
 if type(entity)~="table" then return end
 entity.mobAction="hurt"
 entity.mobActionLeft=duration(set,"hurt")
end
function Mob.onDeath(entity,set)
 if type(entity)~="table" then return end
 entity.mobAction="death"
 entity.mobActionLeft=duration(set,"death")
end
function Mob.update(entity,set,dt)
 if not entity or not isFinite(dt) or dt<=0 then return end
 dt=math.min(dt,0.25)
 entity.mobWalkLeft=math.max(0,(entity.mobWalkLeft or 0)-dt)
 local action=entity.mobAction
 if action and action~="death" then
  entity.mobActionLeft=math.max(0,(entity.mobActionLeft or 0)-dt)
  if entity.mobActionLeft==0 then entity.mobAction=nil end
 end
 local state=entity.mobAction or
   ((entity.mobWalkLeft or 0)>0 and "walk" or "idle")
 -- Animation sets can specify any subset. A missing clip falls back to
 -- idle or static reference art rather than disabling the mob.
 local actual=type(set)=="table" and set[state] and state or nil
 if not actual and type(set)=="table" and set.idle then actual="idle" end
 if actual~=entity.mobClip then
  entity.mobClip=actual
  entity.mobClipTime=0
 elseif actual then
  entity.mobClipTime=(entity.mobClipTime or 0)+dt
 end
end
function Mob.frame(entity,set)
 if not entity or type(set)~="table" then return nil end
 local name=entity.mobClip
 local clip=states[name] and set[name]
 if type(clip)~="table" or not isFinite(clip.frames)
   or not isFinite(clip.fps) or clip.frames<1 or clip.fps<=0 then
  return nil end
 local t=entity.mobClipTime or 0
 local current=math.floor(math.max(0,t)*clip.fps)
 if clip.loop==false or (clip.loop==nil and
     (name=="attack" or name=="hurt" or name=="death")) then
  current=math.min(current,clip.frames-1)
 else
  current=current%clip.frames
 end
 return {name=name,row=clip.row,frame=current+1,
  width=set.frameWidth,height=set.frameHeight}
end
local function imageFor(sheet)
 if not safeSheet(sheet) then return nil end
 if sheets[sheet] then return sheets[sheet] end
 if not (love and love.filesystem and love.graphics) then return nil end
 local paths={
  "assets/custom/img/animals/animations/"..sheet,
  "server-lua/mods/animations/"..sheet
 }
 for _,path in ipairs(paths) do
  if love.filesystem.getInfo(path,"file") then
   local ok,image=pcall(love.graphics.newImage,path)
   if ok and image then
    image:setFilter("nearest","nearest")
    sheets[sheet]=image
    return image
   end
  end
 end
 -- Deliberately do NOT memoize missing files. A mod can be installed
 -- later without forcing an app restart or losing its static fallback.
 if not warned[sheet] then
  warned[sheet]=true
  print("[MOO IO ANIMACAO] spritesheet nao encontrado: "..sheet..
    " (usando PNG estatico do animal)")
 end
 return nil
end
function Mob.draw(entity,set,x,y,size,angle,alpha,imageLoader)
 if not entity or type(set)~="table" or not safeSheet(set.sheet) then
  return false end
 local frame=Mob.frame(entity,set)
 if not frame then return false end
 local image=imageLoader and imageLoader(set.sheet) or imageFor(set.sheet)
 if not image or not love or not love.graphics then return false end
 local w,h=frame.width,frame.height
 if not isFinite(w) or not isFinite(h) or w<1 or h<1
   or type(frame.row)~="number" or frame.row<0 then return false end
 local imageW,imageH=image:getWidth(),image:getHeight()
 if w*frame.frame>imageW or h*(frame.row+1)>imageH then return false end
 local cache=quads[image]
 if not cache then cache={};quads[image]=cache end
 local key=w..":"..h..":"..frame.row..":"..frame.frame
 local quad=cache[key]
 if not quad then
  quad=love.graphics.newQuad((frame.frame-1)*w,frame.row*h,
    w,h,imageW,imageH)
  cache[key]=quad
 end
 love.graphics.setColor(1,1,1,alpha or 1)
 love.graphics.draw(image,quad,x,y,angle or 0,
   size/w,size/h,w/2,h/2)
 return true
end
function Mob.clearCache()
 sheets={};warned={};quads=setmetatable({},{__mode="k"})
end
return Mob
