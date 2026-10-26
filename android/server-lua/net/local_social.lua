-- SPDX-License-Identifier: AGPL-3.0-only
-- LOCAL server/src/api/social.js HTTP friendship routes (not V2).
local Json=require("server-lua.vendor.dkjson")
local Social={}
Social.__index=Social
local function array()return setmetatable({},{__jsontype="array"})end
local function message(code,value)return code,{message=value}end
local function safe(v)
 if v==nil or v==Json.null or v==false then return "" end
 return tostring(v)
end
function Social.new(opts)
 assert(opts and opts.store,"original AccountStore required")
 return setmetatable({store=opts.store,friendshipChanged=opts.friendshipChanged},Social)
end
local function requestJson(r)
 return {id=r.id,senderId=r.senderId,recipientId=r.recipientId,createdAt=r.createdAt}
end
function Social:handle(method,path,headers,body)
 local uid,suffix=path:match("^/api/social/friends/([%w]+)(.*)$")
 if not uid then return nil end
 local header=headers["authorization"] or ""
 local token=header:sub(1,7)=="Bearer " and header:sub(8) or nil
 local account=token and self.store:verifyToken(token) or nil
 if not account or account==Json.null then return message(401,"Unauthorized") end
 if self.store:accountById(uid)~=account then return message(403,"Forbidden") end
 local store=self.store
 if suffix=="" and method=="GET" then
  local result=array()
  for _,f in ipairs(store:friendsOf(account.id)) do
   result[#result+1]={id=f.id,createdAt=f.createdAt}
  end
  return 200,result
 end
 if suffix=="/requests" and method=="GET" then
  local result=array()
  for _,r in ipairs(store:requestsFor(account.id)) do
   result[#result+1]=requestJson(r)
  end
  return 200,result
 end
 if suffix=="/outgoing-requests" and method=="GET" then
  local result=array()
  for _,r in ipairs(store:requestsFrom(account.id)) do
   result[#result+1]=requestJson(r)
  end
  return 200,result
 end
 if suffix=="/requests" and method=="POST" then
  local id=safe(body.recipientId)
  local recipient=store:accountById(id)
  local result=store:createFriendRequest(account.id,recipient and recipient.id or id)
  if result.status==404 then return message(404,"User not found") end
  if result.status==409 then return message(409,"Request already exists") end
  if result.friends then
   if self.friendshipChanged then self.friendshipChanged(account.id,recipient.id)end
   return 200,{friends=true}
  end
  return 201,requestJson(result.request)
 end
 local requestId=suffix:match("^/requests/([%w]+)$")
 if requestId and method=="POST" then
  local accept=body.accept~=nil and body.accept~=false and body.accept~=0 and body.accept~="" and body.accept~=Json.null
  local request=store:answerFriendRequest(account.id,requestId,accept)
  if not request or request==Json.null then return message(404,"Request not found") end
  if accept and self.friendshipChanged then
   self.friendshipChanged(request.senderId,request.recipientId)
  end
  return 200,{accepted=accept}
 end
 requestId=suffix:match("^/outgoing%-requests/([%w]+)$")
 if requestId and method=="DELETE" then
  if not store:cancelFriendRequest(account.id,requestId) then
   return message(404,"Request not found")
  end
  return 204,nil
 end
 if suffix=="" and method=="DELETE" then
  if not store:removeFriend(account.id,safe(body.friendId)) then
   return message(404,"Friend not found")
  end
  return 204,nil
 end
 return message(404,"Not found")
end
return Social
