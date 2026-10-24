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
local Score=require("server-lua.world.score")
local PlayerUpdate=require("server-lua.world.player_update")
local Input=require("server-lua.world.input")
local Loop=require("server-lua.world.game_loop")
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
    lastTick=now,nowMs=now,
    bots=opts.bots,
    spawnTimer=0,leaderboardTimer=0,minimapTimer=0,statsTimer=0
  },Room)
  room.wallTimeMs=opts.wallTimeMs
  room.broadcast=opts.broadcast
  room.chat=opts.chat
  room.tribes=opts.tribes or (type(opts.broadcast)=="function" and
    Tribes.new(players,opts.broadcast) or nil)
  return room
end

function Room:score(player,amount)
  return Score.add(player,amount,self.config)
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
    return PlayerUpdate.step(actor,delta,{
      items=self.items,config=self.config,
      players=self.players,ais=self.ais,world=self.object_manager,
      nowMs=self.nowMs,
      disable=function(obj) return self.object_manager:disableObject(obj) end,
      hit=function(obj,angle) return self:hitObject(obj,angle) end,
      addProjectile=function(...)
        return self.projectile_manager:addProjectile(...)
      end
    })
  end
  return player
end

function Room:handleInput(player,name,args)
  local present=false
  for _,p in ipairs(self.players) do
    if p==player then present=true;break end
  end
  assert(present,"cannot route client packets to a player outside this room")
  return Input.handle({
    items=self.items,tribes=self.tribes,accounts=self.accounts,
    broadcast=self.broadcast,chat=self.chat,game=self,
    wallTimeMs=self.wallTimeMs,gameKey=self.key,config=self.config,players=self.players,
    unhandled=self.services.onUnportedPacket,
    log=self.services.log
  },player,name,args)
end

function Room:tick(nowMs)
  -- GameLoop now calls bound Player.update, the real projectile update,
  -- object updates and snapshot functions, plus mandatory external services.
  self.nowMs=nowMs
  return Loop.tick(self,nowMs)
end
return Room
