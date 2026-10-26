package.path="./?.lua;./?/init.lua;"..package.path
local Host=require("src.net.mooio_host")
local channels={}
local threads={}
local function channel(name)
  if not channels[name] then
    local ch={messages={}}
    function ch:clear() self.messages={} end
    function ch:push(msg) self.messages[#self.messages+1]=msg end
    function ch:pop()
      if #self.messages==0 then return nil end
      return table.remove(self.messages,1)
    end
    channels[name]=ch
  end
  return channels[name]
end
local folderCount=0
local platform={
  createDirectory=function(path)
    assert(path=="lua-server")
    folderCount=folderCount+1
    return true
  end,
  saveDirectory=function()return "/mock-private-files" end,
  newChannel=channel,
  newThread=function(path)
    assert(path=="src/mobile/lua_host_thread.lua")
    local thread={running=false,args=nil}
    function thread:start(...)
      self.running=true
      self.args={...}
      return true
    end
    function thread:isRunning()return self.running end
    function thread:getError()return self.error end
    threads[#threads+1]=thread
    return thread
  end
}
local h=Host.new({
  platform=platform,
  chooseIP=function(mode)
    assert(mode=="lan")
    return "192.168.1.40"
  end,
  generateCode=function()return "secure-private-room-1234" end
})
assert(h.state=="idle" and #threads==0)
assert(h:start("lan",nil,3,"dificil","lobos-em-matilha","bunker-e-cavernas"))
assert(h.state=="starting" and #threads==1 and folderCount==1)
local opts=threads[1].args
assert(opts[3]=="192.168.1.40" and opts[4]=="lan")
assert(opts[5]=="secure-private-room-1234" and opts[6]==3)
assert(opts[7]=="dificil" and opts[8]=="lobos-em-matilha")
assert(opts[9]=="bunker-e-cavernas" and
  opts[10]=="/mock-private-files/lua-server")
assert(h.address=="192.168.1.40:8080")
for i=1,10 do h:update(.1) end
assert(h.state=="starting","must never report ready before Lua opens sockets")
channel(opts[2]):push("ready")
h:update(.01)
assert(h.state=="ready")
assert(not h:start("lan"),"must not launch two authoritative servers")
h:stop()
assert(h.state=="idle" and channel(opts[1]):pop()=="stop")
assert(not h:start("lan"),"must not restart before previous thread stops")
threads[1].running=false
assert(h:start("lan",nil,0,"pacifico","","classico"))
local second=threads[2].args
channel(second[2]):push("failed:socket already in use")
threads[2].running=false
h:update(0.1)
assert(h.state=="failed" and h.error:find("socket already in use",1,true))
h:stop()
for _,bad in ipairs({-1,9,1.5}) do
  assert(not h:start("lan",nil,bad))
end
assert(not h:start("lan",nil,2,"unknown"))
assert(not h:start("lan",nil,2,"normal","../hack"))
assert(not h:start("lan",nil,2,"normal","","../../hack"))
local localOnly=Host.new({
  platform=platform,generateCode=function()return "another-private-code" end,
  chooseIP=function()return "127.0.0.1" end
})
assert(localOnly:start("lan",nil,0,"extremo"))
assert(localOnly.hostIP=="127.0.0.1")
local internal=Host.new({
  platform=platform,generateCode=function()return "another-private-code" end,
  chooseIP=function()return "8.8.8.8" end
})
assert(not internal:start("lan"),"public IP must be rejected")
print("ANDROID LUA HOST PASS: real thread lifecycle, ready gate, server options, private IP and restart")
