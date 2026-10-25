-- SPDX-License-Identifier: AGPL-3.0-only
-- Identical fixture to spawn-reference.mjs, including RNG and callbacks.
local Base=require("src.game.config")
local World=require("server-lua.world.objects")
local Spawn=require("server-lua.world.spawn")
local Crypto=require("src.protocol.original_crypto")
local cases={
  {name="normal",seed=1},
  {name="moofoll",seed=42,moofoll=true},
  {name="powers",seed=12345,powers={size=1.5,health=2}},
  {name="unlimited",seed=345,unlimited=true},
  {name="respawn",seed=987,spawnPoint=true},
  {name="obstructed",seed=72,blocked=true},
  {name="obstacles",seed=123,obstacles=true},
  {name="last-attempt",seed=555,rejectAll=true}
}
local function fmt(n) return string.format("%.6f",n) end
for _,tc in ipairs(cases) do
  local cfg=setmetatable({unlimitedResources=tc.unlimited or false},{__index=Base})
  local events={}
  local p={
    sid=7,id="user7",name="ExistingUser",points=333,
    alive=false,active=false,scale=8,health=12,maxHealth=40,
    pps=0.2,moveDir=2,spawned=false,skins={[123]=1},tails={[456]=1},
    skinIndex=1,tailIndex=2,
    powers={size=(tc.powers and tc.powers.size) or 1,
      health=(tc.powers and tc.powers.health) or 1,speed=1}
  }
  p.changeItemCount=function(self,group,amount)
    events[#events+1]="S:"..group..":"..amount
  end
  local calls=0
  local rng=Crypto.mulberry32(tc.seed)
  local world=World.new({config=cfg,random=function()calls=calls+1;return rng()end})
  if tc.obstacles then
    world:addObject(180,200,145,2)
    world:addObject(4000,4000,200,0)
  end
  local spawnObj=nil
  if tc.spawnPoint then
    spawnObj=world:addObject(511,633,80,4)
    spawnObj.sid=44
    spawnObj.id=9
    spawnObj.owner=p
    spawnObj.group={id=4}
    spawnObj.spawnPoint=true
  end
  if tc.rejectAll then world.canPlace=function() return false end end
  Spawn.spawn(p,tc.moofoll or false,world,{config=cfg,nowMs=543210,
    broadcast=function(name,sid)events[#events+1]=name..":"..sid end})
  local fields={"SPAWN",tc.name,calls,fmt(p.x),fmt(p.y),fmt(p.scale),
    fmt(p.speed),p.health,p.maxHealth,p.age,p.maxXP,p.XP,
    p.wood,p.food,p.stone,p.points,p.buildIndex,p.weaponIndex,
    table.concat(p.items,","),tostring(p.weapons[0] or "")..(p.weapons[1] and (","..p.weapons[1]) or ""),
    p.spawned and 1 or 0,p.alive and 1 or 0,
    p.moveDir==nil and 1 or 0,p.slowMult,p.lifeStats.score,
    spawnObj and (spawnObj.active and 1 or 0) or "-",table.concat(events,",")}
  print(table.concat(fields,"|"))
end
