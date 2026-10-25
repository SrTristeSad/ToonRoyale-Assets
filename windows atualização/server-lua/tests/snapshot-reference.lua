-- Connected but not yet spawned viewers have undefined x/y in Node.
-- JS comparisons with NaN reject visibility instead of crashing.
local PreSpawnSync=require("server-lua.world.snapshot")
assert(PreSpawnSync.canSee({alive=false},{x=10,y=20,scale=35})==false,
  "unspawned viewer must not crash snapshot visibility")
assert(PreSpawnSync.canSee({x=10,y=20},{scale=35})==false,
  "other without position must not crash snapshot visibility")
-- SPDX-License-Identifier: AGPL-3.0-only
-- Same state transitions as snapshot-reference.mjs; compares actual S2C packet payloads.
local Config=require("src.game.config")
local Sync=require("server-lua.world.snapshot")
local MP=require("src.protocol.msgpack")
local function repr(v)
  if v==nil or v==MP.null then return "~" end
  if type(v)=="boolean" then return v and "true" or "false" end
  if type(v)=="number" and v==math.floor(v) then return string.format("%.0f",v) end
  return tostring(v)
end
local function printPacket(name,...)
  local args={...}
  local fields={}
  for i=1,select("#",...) do
    local v=select(i,...)
    if type(v)=="table" and v~=MP.null then
      local elements={}
      for j=1,#v do elements[j]=repr(v[j]) end
      fields[i]=table.concat(elements,",")
    else
      fields[i]=repr(v)
    end
  end
  print("PACK|"..name.."|"..table.concat(fields,"|"))
end
local function makePlayer(id,sid,x,y,settings)
  local p={
    id=id,sid=sid,name="Player"..sid,x=x,y=y,dir=0.21,
    health=100,maxHealth=100,scale=35,skinColor=0,
    morph=0,dive=0,powers={speed=1},
    anon=false,isLeader=false,skinIndex=0,tailIndex=0,iconIndex=0,zIndex=0,
    buildIndex=-1,weaponIndex=0,shameTimer=0,noMovTimer=0,
    alive=true,isPlayer=true,visiblePlayers={},attrCache={},
    sentTo={},disguised=false
  }
  for k,v in pairs(settings or {}) do p[k]=v end
  p.variant=function(self)return {id=self.weaponIndex==1 and 1 or 0}end
  p.send=function(self,name,...)printPacket(name,...)end
  return p
end
local me=makePlayer("me",0,100,100,{team="RED",clanTag="Red"})
local ally=makePlayer("ally",1,180,120,{anon=true,team="RED",clanTag="Red",name="Ally"})
local far=makePlayer("far",2,5000,5000,{team="BLUE",clanTag="Blue"})
local stealth=makePlayer("stealth",3,210,110,{skin={invisTimer=10},noMovTimer=30})
local tree={sid=0,x=110.25,y=150.5,dir=0,scale=150,type=0,active=true}
local friendly={sid=1,x=140,y=180,dir=0,scale=50,type=2,active=true,hideFromEnemy=true,id=4,owner=me}
local hostile={sid=2,x=180,y=190,dir=0,scale=35,type=2,active=true,hideFromEnemy=true,id=3,owner=far}
local remote={sid=3,x=5000,y=5000,dir=0,scale=55,type=2,active=true}
local game={players={me,ally,far,stealth},game_objects={tree,friendly,hostile,remote}}
print("TICK|1")
Sync.syncPlayers(game,me,Config)
Sync.syncObjects(game,me,Config)
ally.x=310
ally.weaponIndex=1
ally.shameTimer=40
ally.team=nil
far.x=400;far.y=200
remote.x=350;remote.y=250
print("TICK|2")
Sync.syncPlayers(game,me,Config)
Sync.syncObjects(game,me,Config)
ally.alive=false
far.x=5000;far.y=5000
stealth.noMovTimer=0
me.dir=0.7
print("TICK|3")
Sync.syncPlayers(game,me,Config)
Sync.syncObjects(game,me,Config)
