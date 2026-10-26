package.path="./?.lua;./?/init.lua;"..package.path
-- Regression: the Windows widgets must never be rendered or clickable in
-- Android game mode, even when callers accidentally omit the mobile flag.
local drawn={}
local function record(text) drawn[#drawn+1]=tostring(text) end
love={
 system={getOS=function()return "Android" end},
 mouse={getPosition=function()return 0,0 end},
 graphics={
  getDimensions=function()return 1280,720 end,
  newFont=function(n)return {getHeight=function()return n end}end,
  setFont=function()end, setColor=function()end,
  rectangle=function()end, setLineWidth=function()end,
  print=function(text)record(text)end,
  printf=function(text)record(text)end
 }
}
local Runtime=require("src.mobile.runtime")
assert(Runtime.active(),"Actual Android OS must be recognized")
local Panel=require("src.game.reference_panels")
local panel=Panel.new()
local world={tribeOwner=false,joinRequests={}}
local shopX,tribeX,top,size=panel:buttons(1280)
assert(shopX and tribeX and top and size)
panel:draw(world)        -- Missing flag must not silently show Windows Shop.
panel:draw(world,true)   -- Even a mistaken true must not bypass OS gate.
assert(#drawn==0,"Desktop Shop/Tribe buttons leaked into Android HUD")
assert(panel:click(world,shopX+10,top+10,1280,720)==nil,
  "Invisible Windows Shop hitbox captured Android touches")
assert(panel:click(world,tribeX+10,top+10,1280,720)==nil,
  "Invisible Windows Tribe hitbox captured Android touches")
assert(not panel:isOpen(),"No desktop store/tribe window should open")
-- The only legacy drawing allowed in mobile is the server-authoritative
-- upgrade selector; the old Age bar, minimap and inventory are forbidden.
local upgradeCalls=0
package.loaded["src.game.reference_upgrades"]={
 draw=function()upgradeCalls=upgradeCalls+1 end
}
local Hud=require("src.game.reference_hud")
Hud.draw(world,false,"",true)  -- Deliberately omits mobile flag.
assert(upgradeCalls==1,"Server upgrades must still be available")
assert(#drawn==0,"Desktop level, inventory or other HUD leaked on Android")
-- Permanent clans must never draw a second (desktop) button.
local Clan=require("src.game.account_clans")
local clan=Clan.new()
clan:draw(true) -- A mistaken desktop flag must not create a second button.
assert(#drawn==0,"Desktop Clan control leaked on Android")
-- Windows behaviour remains supported for mocked PC use.
love.system.getOS=function()return "Windows" end
assert(not Runtime.active())
panel:draw(world,true)
local foundShop,foundTribe=false,false
for _,label in ipairs(drawn) do
 if label=="Shop" then foundShop=true end
 if label=="Tribe" then foundTribe=true end
end
assert(foundShop and foundTribe,"Desktop Shop/Tribe should remain available on Windows")
print("ANDROID SINGLE HUD PASS: no desktop Shop/Tribe/Clan/AGE, no hidden touch hitboxes")
