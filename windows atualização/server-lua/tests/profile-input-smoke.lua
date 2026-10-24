-- Regression: Node packets.js V (profile watch and stats).
local Input=require("server-lua.world.input")
local events={}
local player={alive=true,watchStats=-1,anticheat={
 invalid=function(_,name,reason) events[#events+1]="invalid:"..name..":"..reason end
}}
local game={
 sendProfile=function(_,viewer,sid)
   assert(viewer==player)
   events[#events+1]="profile:"..sid
 end,
 sendStats=function(_,viewer,sid)
   assert(viewer==player)
   events[#events+1]="stats:"..sid
 end
}
local ctx={items={weapons={},list={}},game=game}
local function run(sid,expected)
 events={}
 Input.handle(ctx,player,"V",{sid})
 assert(table.concat(events,",")==expected,table.concat(events,",").." ~= "..expected)
end
run(7,"profile:7,stats:7")
assert(player.watchStats==7)
run(-1,"")
assert(player.watchStats==-1)
run(0,"profile:0,stats:0")
run("7","invalid:V:stats")
run(1.5,"invalid:V:stats")
-- Positive selections must fail closed if the profile service is not available.
local failing={items=ctx.items,game={sendStats=game.sendStats}}
assert(not pcall(function() Input.handle(failing,player,"V",{2}) end))
print("PASS 6 testes de consulta V, incluindo servico obrigatorio")
