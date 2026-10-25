local Config=require("src.game.config")
local Env=require("server-lua.world.environment")
local fmt=function(n) return string.format("%.6f",n) end
local positions={
  {10,10,50,50},{14399,14399,14300,14300},{-300,7200,-320,7190},
  {-300,9000,35,9000},{-2500,7200,-2550,7200},{-3800,7250,-3790,7260},
  {-1600,5200,-1550,7000},{-400,6050,-400,7200},{50,7500,50,7490},
  {14430,7000,14400,7000},{10,14400,10,14370}
}
for _,p in ipairs(positions) do
  local x,y,px,py=p[1],p[2],p[3],p[4]
  local player={x=x,y=y,xVel=0.65,yVel=-0.13,scale=35}
  Env.keepInWorld(player,px,py,Config)
  print(table.concat({"BOUND",x,y,px,py,fmt(player.x),fmt(player.y),
    fmt(player.xVel),fmt(player.yVel)},"|"))
end
local samples={{-100,7200},{-1500,6500},{-3500,6800},{-4700,7250},
  {-400,9000},{100,7200},{-2200,7800}}
for _,p in ipairs(samples) do
  print(table.concat({"SECRET",p[1],p[2],fmt(Env.secretDistance(Config,p[1],p[2])),
    Env.inSecretPool(Config,p[1],p[2]) and 1 or 0},"|"))
end
for _,p in ipairs({{nil,nil},{ {coldM=true},nil },{nil,{id=6}},{nil,{id=12}}}) do
  local player={skin=p[1],tail=p[2]}
  print(table.concat({"SNOW",player.skin and 1 or 0,
    player.tail and player.tail.id or 0,fmt(Env.snowFactor(player,Config))},"|"))
end
