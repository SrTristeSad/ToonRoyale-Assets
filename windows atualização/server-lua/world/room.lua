-- SPDX-License-Identifier: AGPL-3.0-only
-- Composition root for the already-differential-tested Lua gameplay modules.
-- Critical missing Node subsystems remain REQUIRED services. Observer and
-- leaderboard packets are now real Lua ports; animal spawn / AI still absent.
local Config=require("src.game.config")
local Catalogue=require("server-lua.world.catalogue")
local Tribes=require("server-lua.world.tribes")
local World=require("server-lua.world.objects")
local Projectiles=require("server-lua.world.projectiles")
local Structures=require("server-lua.world.structures")
local Snapshot=require("server-lua.world.snapshot")
local Social=require("server-lua.world.social_sync")
local Profile=require("server-lua.world.profile")
local LifePersistence=require("server-lua.world.life_persistence")
local AccountUnlocks=require("server-lua.world.account_unlocks")
local Score=require("server-lua.world.score")
local PlayerUpdate=require("server-lua.world.player_update")
local Input=require("server-lua.world.input")
local Loop=require("server-lua.world.game_loop")
local Indoor=require("server-lua.world.indoor_movement")
local Room={}
Room.__index=Room

local serviceNames={"ensureAnimals"} -- required unless native animal manager supplied
local function round(v,dp)
  local m=10^dp
  if v<0 then return -math.floor(-v*m+0.5)/m end
  return math.floor(v*m+0.5)/m
end

function Room.new(opts)
  opts=opts or {}
  local callbacks=assert(opts.services,"missing original game services")
  if not opts.animalManager then
    for _,name in ipairs(serviceNames) do
      assert(type(callbacks[name])=="function",
        "original game subsystem callback required: "..name)
    end
  end
  local config=opts.config or Config
  local world=opts.world or World.new({config=config})
  local items=opts.items or Catalogue
  assert(items.weapons and items.projectiles,
    "item catalogue must contain original weapons and projectiles")
  local players=opts.players or {}
  local ais=opts.ais or {}
  local projectileManager=Projectiles.new({
    world=world,players=players,ais=ais,config=config,items=items
  })
  local animals=opts.animalManager
  if animals then
    assert(animals.ais==ais and animals.players==players
      and animals.world==world,"native animals must share Room actors and world")
    assert(type(animals.ensureAnimals)=="function"
      and type(animals.health)=="function"
      and type(animals.send)=="function",
      "native AI requires authoritative health and packet callbacks")
    local plan=config.server and config.server.animalSpawnPlan or {}
    for _,entry in ipairs(plan) do
      if entry.index==11 then
        assert(type(animals.boss)=="function"
          and type(animals.onCrabKingKilled)=="function"
          and type(animals.score)=="function"
          and type(animals.send)=="function",
          "Crab King requires original AI, victory rewards, scoring and packet callbacks")
        assert(opts.crabKillers and opts.crabKillers==animals.crabKillers,
          "Crab King winners must update the same Game.crabKillers table")
      end
    end
  end
  local now=assert(opts.nowMs,"starting authoritative clock required")
  local room=setmetatable({
    players=players,ais=ais,projectiles=projectileManager.projectiles,
    game_objects=world.objects,
    object_manager=world,projectile_manager=projectileManager,
    config=config,items=items,services=callbacks,key=opts.key or "LC",
    accounts=opts.accounts,crabKillers=opts.crabKillers or {},
    crownOf=opts.crownOf,animal_manager=animals,
    crowns=opts.crowns or {},crownsAt=opts.crownsAt or 0,
    lastTick=now,nowMs=now,
    bots=opts.bots,
    spawnTimer=0,leaderboardTimer=0,minimapTimer=0,statsTimer=0
  },Room)
  room.wallTimeMs=opts.wallTimeMs
  room.broadcast=opts.broadcast
  room.chat=opts.chat
  room.moderation=opts.moderation
  room.hooks=opts.hooks
  room.recordUnlocks=opts.recordUnlocks or function(self,player)
    return AccountUnlocks.record(self,player)
  end
  room.tribes=opts.tribes or (type(opts.broadcast)=="function" and
    Tribes.new(players,opts.broadcast) or nil)
  return room
end

function Room:recordLife(player,died)
  return LifePersistence.record(self,player,died)
end

-- Game.onPlayerDeath and Game.crownOf from the original Node server.js.
function Room:onPlayerDeath(player)
  self:recordLife(player,true)
  self.leaderboardTimer=0
end

function Room:crownOf(player)
  if not player.account or player.anon or not self.accounts then return 0 end
  local clock=assert(self.wallTimeMs,"real wall clock required for crowns")
  local now=clock()
  assert(type(now)=="number","wall clock must return milliseconds")
  if now-self.crownsAt>60000 then
    local crowns=assert(self.accounts.weeklyCrowns,
      "original AccountStore.weeklyCrowns required")
    self.crowns=crowns()
    assert(type(self.crowns)=="table","weeklyCrowns must return account ranks")
    self.crownsAt=now
  end
  return self.crowns[player.account.id] or 0
end

function Room:score(player,amount)
  return Score.add(player,amount,self.config)
end

-- Game.playerCount excludes the bot Player instances from the server list.
function Room:playerCount()
 local count=0
 for _,player in ipairs(self.players) do
  if not player.isBot then count=count+1 end
 end
 return count
end

function Room:sendId(id,name,...)
  for _,player in ipairs(self.players) do
    if player.id==id then return player:send(name,...) end
  end
end

function Room:updateStructures(delta)
  return Structures.update(self.object_manager,self.players,self.ais,
    self.items,delta,{
      addProjectile=function(...)
        return self.projectile_manager:addProjectile(...)
      end
    })
end
function Room:syncPlayers(viewer)
  return Snapshot.syncPlayers(self,viewer,self.config)
end
function Room:syncObjects(viewer)
  return Snapshot.syncObjects(self,viewer,self.config)
end
function Room:syncAnimals(viewer) return Social.syncAnimals(self,viewer) end
function Room:ensureAnimals()
  if self.animal_manager then return self.animal_manager:ensureAnimals() end
  return self.services.ensureAnimals(self)
end
function Room:updateLeaders() return Social.updateLeaders(self) end
function Room:sendLeaderboard() return Social.sendLeaderboard(self) end
function Room:sendMinimap(viewer) return Social.sendMinimap(self,viewer) end
function Room:sendStats(viewer,sid) return Social.sendStats(self,viewer,sid) end
function Room:sendProfile(viewer,sid)
  return Profile.send(self,viewer,sid)
end

function Room:hitObject(object,dir)
  -- Exact observer notifications from ObjectManager.hitObj.
  for _,viewer in ipairs(self.players) do
    if viewer.active then
      if object.sentTo and object.sentTo[viewer.id] then
        if not object.active then
          viewer:send("Q",object.sid)
        elseif viewer:canSee(object) then
          viewer:send("L",round(dir,1),object.sid)
        end
      end
      if not object.active and object.owner==viewer then
        assert(object.group and type(viewer.changeItemCount)=="function",
          "owner inventory callback required")
        viewer:changeItemCount(object.group.id,-1)
      end
    end
  end
end

function Room:bindPlayer(player)
  -- Bind a real Player with all its methods to the physics pipeline.
  -- The future Player constructor retains responsibility for authoritative
  -- economy, health, equipment, skin, variant, animation and auth state.
  assert(type(player.send)=="function" and type(player.variant)=="function"
    and type(player.canSee)=="function"
    and type(player.gather)=="function"
    and type(player.changeHealth)=="function"
    and type(player.addResource)=="function"
    and type(player.shootTurret)=="function",
    "complete Player methods required before integration")
  local found=false
  for _,p in ipairs(self.players) do if p==player then found=true;break end end
  if not found then self.players[#self.players+1]=player end
  player.update=function(actor,delta)
    if actor.spaceId and actor.spaceId~="surface" then
      local updated=Indoor.step(actor,delta,self)
      if actor.alive then self:checkPortalCrossing(actor) end
      return updated
    end
    local updated=PlayerUpdate.step(actor,delta,{
      items=self.items,config=self.config,
      players=self.players,ais=self.ais,world=self.object_manager,
      nowMs=self.nowMs,
      disable=function(obj) return self.object_manager:disableObject(obj) end,
      hit=function(obj,angle) return self:hitObject(obj,angle) end,
      addProjectile=function(...)
        return self.projectile_manager:addProjectile(...)
      end
    })
    if actor.alive then self:checkPortalCrossing(actor) end
    return updated
  end
  return player
end

-- Crossing the doorway with normal WASD movement changes map. Each
-- doorway triggers only on ENTER, not while idling inside its radius; the
-- destination doorway is disarmed until the player walks away. This makes
-- bunkers and caves behave like connected rooms, with no action key.
function Room:checkPortalCrossing(player)
 if self.key~="LC" or not self.customMap or not self.mapSpaces
   or not player.alive then return false end
 local zone=self.mapSpaces:get(player.spaceId or "surface")
 if not zone then return false end
 local nearest,distance
 for _,portal in ipairs(zone.portals or {}) do
  local dx,dy=player.x-portal.x,player.y-portal.y
  local d=dx*dx+dy*dy
  if d<=85*85 and (not distance or d<distance) then
   nearest,distance=portal,d
  end
 end
 if not nearest then
  player.portalInside=nil
  return false
 end
 -- Simply standing on a spawn pad must not change regions on its own.
 if type(player.moveDir)~="number"
   and math.abs(player.xVel or 0)<0.000001
   and math.abs(player.yVel or 0)<0.000001 then return false end
 -- No automatic ping-pong after arrival. The player has to leave the
 -- arrival circle before stepping into that passage again.
 if player.portalInside==nearest.id then return false end
 if self.nowMs<(player.nextPortalAt or 0) then return false end
 -- A blocked exit, or an occupied arrival pad, is NOT a successful
 -- crossing. Keep it armed so a player walking against that doorway can
 -- enter as soon as the obstruction clears, without walking away first.
 return self:usePortal(player,nearest.id)
end

-- Server-side portal routing: the client sends no coordinates and cannot
-- choose an arbitrary destination. Classic rooms have no such action.
function Room:usePortal(player,requestedPortal)
 if self.key~="LC" or not self.customMap or not self.mapSpaces
   or not player.alive then return false end
 local now=self.nowMs
 if now<(player.nextPortalAt or 0) then return false end
 local from=player.spaceId or "surface"
 local zone=self.mapSpaces:get(from)
 if not zone then return false end
 local nearest,dist
 for _,portal in ipairs(zone.portals or {}) do
  local dx,dy=player.x-portal.x,player.y-portal.y
  local d=dx*dx+dy*dy
  if d<=(requestedPortal and 85*85 or 150*150)
     and (not requestedPortal or requestedPortal==portal.id)
     and (not dist or d<dist) then
   nearest=portal;dist=d
  end
 end
 if not nearest then return false end
 local destination=self.mapSpaces:destination(from,nearest.id,player.scale)
 if not destination then return false end
 -- Do not stack two player bodies in a doorway or trap them in the
 -- collision system on arrival.
 for _,other in ipairs(self.players) do
  if other~=player and other.alive
    and (other.spaceId or "surface")==destination.spaceId then
   local dx,dy=destination.x-other.x,destination.y-other.y
   local clearance=player.scale+other.scale
   if dx*dx+dy*dy<clearance*clearance then return false end
  end
 end
 player.nextPortalAt=now+700
 local destZone=self.mapSpaces:get(destination.spaceId)
 local arrivalPortal
 for _,portal in ipairs(destZone.portals or {}) do
  local dx,dy=destination.x-portal.x,destination.y-portal.y
  if dx*dx+dy*dy<=120*120 then arrivalPortal=portal.id;break end
 end
 player.portalInside=arrivalPortal
 player.spaceId=destination.spaceId
 player.x=destination.x;player.y=destination.y
 player.xVel=0;player.yVel=0
 player.moveDir=nil;player.mouseState=0
 player.hits=0;player.gathering=0;player.autoGather=false
 player.buildIndex=-1;player.lockMove=false
 for _,obj in ipairs(self.object_manager.objects) do
  if obj.sentTo then obj.sentTo[player.id]=nil end
 end
 for _,other in ipairs(self.players) do
  if other.sentTo then other.sentTo[player.id]=nil end
  if player.sentTo then player.sentTo[other.id]=nil end
 end
 player.attrCache={};player.visiblePlayers={};player.visibleAis={}
 local newZone=self.mapSpaces:get(destination.spaceId)
 player:send("j",destination.spaceId,destination.x,destination.y,{
  id=newZone.id,type=newZone.type,width=newZone.width,height=newZone.height,
  portals=newZone.portals,obstacles=newZone.obstacles,
  visual=newZone.visual
 })
 return true
end

function Room:buildHouse(player)
 return require("server-lua.world.house_build").build(self,player)
end
function Room:buildWall(player,request)
 return require("server-lua.world.house_build").wall(self,player,request)
end
function Room:removeWall(player,index)
 return require("server-lua.world.house_build").removeWall(self,player,index)
end

function Room:handleInput(player,name,args)
  local present=false
  for _,p in ipairs(self.players) do
    if p==player then present=true;break end
  end
  assert(present,"cannot route client packets to a player outside this room")
  return Input.handle({
    items=self.items,tribes=self.tribes,accounts=self.accounts,
    broadcast=self.broadcast,chat=self.chat,moderation=self.moderation,game=self,
    wallTimeMs=self.wallTimeMs,gameKey=self.key,config=self.config,players=self.players,
    log=self.services.log
  },player,name,args)
end

-- Game.announceShutdown/closeAll from the original LOCAL Node server.
function Room:announceShutdown(seconds)
 local now=assert(self.wallTimeMs,"original wall clock required")
 self.restartAt=seconds>=0 and now()+seconds*1000 or 0
 assert(type(self.broadcast)=="function","original Game.server.broadcast required")
 self.broadcast("Z",seconds)
end
function Room:closeAll()
 for _,player in ipairs(self.players) do
  if player.kick then player.kick("Server is restarting - pick another") end
 end
end

function Room:tick(nowMs)
  -- GameLoop now calls bound Player.update, the real projectile update,
  -- object updates and snapshot functions, plus mandatory external services.
  self.nowMs=nowMs
  return Loop.tick(self,nowMs)
end
return Room
