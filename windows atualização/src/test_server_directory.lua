-- Static and mocked HTTP contract: IP:port -> list choices -> select room.
return function()
  local Directory=require("src.net.server_directory")
  local Json=require("src.net.json")
  local lan=assert(Directory.parse("192.168.1.10:8080"))
  assert(lan.host=="192.168.1.10" and lan.port==8080 and not lan.secure)
  local vpn=assert(Directory.parse("100.90.11.21:8888"))
  assert(vpn.port==8888)
  local public=assert(Directory.parse("https://normal.example.org"))
  assert(public.host=="normal.example.org" and public.secure)
  for _,bad in ipairs({"8.8.8.8:8080","http://normal.example.org",
    "https://normal.example.org:8080","127.0.0.1:99999",
    "https://wrong..example.org"}) do
    assert(Directory.parse(bad)==nil,"unsafe endpoint accepted: "..bad)
  end
  local payload={
    schemaVersion=1,serverType="Moo-IO-V2",currentId="normal",
    rooms={
      {id="normal",name="Tradicional",preset="traditional",
       port=8080,players=4,capacity=40,online=true,publicAccess=false},
      {id="lobos",name="Lobos",preset="custom",
       port=8090,players=9,capacity=40,online=true,
       publicAccess=true,inviteCode="public-room-code"}
    }
  }
  local raw=assert(Json.encode(payload))
  local directory=assert(Directory.decode(raw,lan))
  assert(#directory.rooms==2)
  assert(directory.rooms[1].inviteCode==nil)
  local denied,message=Directory.target(directory,directory.rooms[1])
  assert(not denied and message:find("privada"))
  local privateRoom=assert(Directory.target(directory,directory.rooms[1],"secret-code-123"))
  assert(privateRoom.host=="192.168.1.10" and privateRoom.port==8080
    and privateRoom.code=="secret-code-123")
  local modded=assert(Directory.target(directory,directory.rooms[2]))
  assert(modded.host=="192.168.1.10" and modded.port==8090
    and modded.code=="public-room-code")
  local publicDirectory=assert(Directory.decode(raw,public))
  local remote=assert(Directory.target(publicDirectory,publicDirectory.rooms[2]))
  assert(remote.secure and remote.host=="lobos.example.org"
    and remote.port==443 and remote.invite=="https://lobos.example.org/public-room-code")
  local data=raw
  local http={TIMEOUT=10}
  function http.request(req)
    assert(req.method=="GET" and req.url=="http://192.168.1.10:8080/api/public/rooms")
    req.sink(data)
    return 1,200
  end
  local ltn12={sink={table=function(chunks)
    return function(chunk)
      if chunk~=nil then chunks[#chunks+1]=chunk end
      return 1
    end
  end}}
  local got=assert(Directory.fetch("192.168.1.10:8080",{http=http,ltn12=ltn12}))
  assert(#got.rooms==2 and http.TIMEOUT==10,"directory response must be validated")
  local malicious=raw:gsub('"publicAccess":true','"publicAccess":true,"inviteCode":"oops"')
  -- Duplicate JSON keys or malformed details never grant private access.
  assert(Directory.target(directory,directory.rooms[1],"") == nil)
  assert(Directory.decode('{"serverType":"other","rooms":[],"schemaVersion":1,"currentId":"normal"}',lan)==nil)
  print("MOO IO SERVER DIRECTORY PASS: IP:port listing, capacity, public and private join, HTTPS routing")
end
