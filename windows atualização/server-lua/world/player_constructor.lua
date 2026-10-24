-- SPDX-License-Identifier: AGPL-3.0-only
-- Constructor-only port of Node modules/player.js: Player.constructor lines
-- 17-71; does not masquerade as completed Player methods. No spawn occurs.
local Player={}
local function freeOwnership(catalogue)
 local owned={}
 for _,entry in ipairs(catalogue) do
   if entry.price<=0 and not entry.dontSell then owned[entry.id]=1 end
 end
 return owned
end
function Player.new(id,sid,opts)
 opts=opts or {}
 assert(type(id)=="string" and #id>0,"original Player connection ID required")
 assert(type(sid)=="number" and sid>=0 and sid%1==0,"original Player SID required")
 local hats=assert(opts.hats,"original shared config/store hats required")
 local accessories=assert(opts.accessories,"original shared config/store accessories required")
 local p={
   id=id,sid=sid,tmpScore=0,team=nil,skinIndex=0,tailIndex=0,
   hitTime=0,tails=freeOwnership(accessories),skins=freeOwnership(hats),
   points=0,dt=0,hidden=false,itemCounts={},isPlayer=true,
   pps=0,moveDir=nil,skinRot=0,lastPing=0,iconIndex=0,skinColor=0,
   account=nil,role=nil,isMember=false,isOwner=false,isLeader=false,
   flagged=false,shadowed=false,name="unknown",alive=false,
   active=false,spawned=false,sentTo={},lifeStats=nil,watchStats=-1,
   joinRequests={},powers={
     god=0,aura=0,godlike=0,boss=0,invisible=0,size=1,power=1,
     speed=1,health=1
   },
   morph=-1,dive=0,disguised=false,anon=false,tribeCooldown=0,
   chatCooldown=0,pingCooldown=0
 }
 return p
end
return Player
