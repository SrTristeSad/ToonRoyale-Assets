local Local=require("server-lua.local_server")
local dir="server-lua/tests/.boot-check"
assert(os.execute("mkdir -p "..dir))
local server=Local.new({bind="127.0.0.1",port=18967,
 roomCode="testing42",mode="lan",dataDir=dir,botCount=2,guiHost=true})
assert(server.rooms.LC.room.key=="LC")
assert(server.rooms.MB.room.key=="MB")
assert(#server.rooms.LC.room.bots.agents==2)
local ok,err=server:start()
assert(ok,err)
assert(server.host.controller and server.host.listener)
local peer={out="",state="http",tcp={getpeername=function()return "127.0.0.1"end}}
server.host:request(peer,{method="GET",target="/ping",headers={},body=""})
assert(peer.out:find("HTTP/1.1 200",1,true))
assert(peer.out:find('"key":"MB"',1,true))
assert(server:update()==true)
server:close()
os.execute("rmdir "..dir)
print("PASS LOCAL Lua boot: LC MB bot registry and controller")
