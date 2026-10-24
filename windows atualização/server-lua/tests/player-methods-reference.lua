local Player=require("server-lua.world.player_constructor")
local Config=require("src.game.config")
local scenes={
 {id="ordinary"},{id="anonymous",anon=true},{id="role",role="mod",invisible=true},
 {id="invisible",invisible=true},{id="invis-hat",invisHat=true},
 {id="far",far=true},{id="large",size=1.6,healthMult=1.8},
 {id="small",size=0.7,healthMult=0.5},{id="shame",shameTimer=1000},
 {id="dead",dead=true}
}
for _,t in ipairs(scenes) do
 local p=Player.new("client",14,{hats={},accessories={},config=Config})
 p.name="Hero";p.anon=t.anon or false;p.role=t.role
 p.alive=not t.dead;p.skinIndex=28;p.shameTimer=t.shameTimer or 0
 p.moveDir=1.2;p.maxHealth=100;p.health=70
 p.scale=Config.playerScale;p.powers.size=t.size or 1
 p.powers.health=t.healthMult or 1
 p.x=100;p.y=100
 local other={
  isPlayer=true,x=t.far and 30000 or 100,y=100,scale=35,
  noMovTimer=t.invisHat and 1000 or 0,
  skin=t.invisHat and {invisTimer=500} or nil,
  powers={invisible=t.invisible and 1 or 0}
 }
 local own=p:shownName(p)
 local stranger=p:shownName(nil)
 local seen=p:canSee(other)
 local missing=p:canSee(nil)
 local skin=p:displaySkin()
 p:applyPowers();p:resetMoveDir()
 local function num(v)
   if v==math.floor(v) then return string.format("%.0f",v) end
   return tostring(v)
 end
 print(table.concat({"PMETHOD",t.id,own,stranger,seen and 1 or 0,
   missing and 1 or 0,skin,num(p.scale),num(p.maxHealth),num(p.health),
   p.moveDir==nil and 1 or 0},"|"))
end
