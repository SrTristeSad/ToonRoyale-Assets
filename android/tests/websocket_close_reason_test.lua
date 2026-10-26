-- Distinguish a TCP EOF from a genuine two-byte RFC6455 status.
-- 29551 is ASCII "so", the first two bytes of "socket closed"; never a
-- server close code. Protects actual Android menu diagnostics.
package.path="./?.lua;./?/init.lua;"..package.path
local Client=require("src.net.websocket_client")
local Original=require("src.net.original_client")
local transport=Client.new({
  secureRandom=function(n)return string.rep("x",n)end,
  sha1=function()return string.rep("y",20)end,
  socket={}
})
transport:emit("close","socket closed",false)
local eof=transport:drain()[1]
assert(eof.kind=="close" and eof.protocolClose==false)
local first=Original.new({http={}})
first.websocket={update=function()end,
  drain=function()return {eof}end,
  state="closed"}
first.state="connecting"
first:update()
assert(first.state=="closed")
assert(first.error:find("TCP",1,true) and
  first.error:find("EOF",1,true),first.error)
assert(not first.error:find("29551",1,true))
transport:emit("close",string.char(15,161),true)
local realClose=transport:drain()[1]
local second=Original.new({http={}})
second.websocket={update=function()end,
  drain=function()return {realClose}end,
  state="closed"}
second.state="connecting"
second:update()
assert(second.error:find("4001",1,true),second.error)
assert(not second.error:find("29551",1,true))
local blocked=Original.new({http={}})
blocked.state="blocked"
blocked.websocket={state="closed",update=function()end,
  drain=function()return {}end}
blocked:update()
assert(blocked.state=="blocked",
  "A closed socket must not conceal an authenticated protocol rejection")
print("ANDROID WEBSOCKET CLOSE REASON PASS: raw EOF vs true 4001 frame")
