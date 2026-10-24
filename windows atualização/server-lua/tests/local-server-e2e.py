import http.client,json,base64,os,socket
HOST="127.0.0.1";PORT=int(os.getenv("PORT","18977"))
def request(method,path,payload=None,headers=None,port=PORT):
 c=http.client.HTTPConnection(HOST,port,timeout=8)
 body=json.dumps(payload).encode() if payload is not None else None
 c.request(method,path,body=body,headers=headers or {})
 r=c.getresponse();code=r.status;raw=r.read();c.close()
 return code,raw
code,raw=request("GET","/ping")
assert code==200,(code,raw)
ping=json.loads(raw);build=ping["build"]
servers={s["key"]:s for s in ping["servers"]}
assert set(servers)=={"LC","MB"}
assert servers["LC"]["playerCapacity"]==40
assert servers["MB"]["playerCapacity"]==80
code,raw=request("GET","/mooio/status")
assert code==200 and json.loads(raw)["bots"]==2
code,raw=request("POST","/api/join",{"host":f"http://{HOST}:{PORT}/s/LC","captcha":True},{"X-MooIO-Code":"testing42"})
assert code==200,(code,raw)
ticket=json.loads(raw)["ticket"]
nonce=base64.b64encode(os.urandom(16)).decode()
path=f"/s/LC?b={build}&token=tk:{ticket}"
wire=(f"GET {path} HTTP/1.1\r\nHost: {HOST}:{PORT}\r\n"
 f"Origin: http://{HOST}:{PORT}\r\nUpgrade: websocket\r\n"
 f"Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: {nonce}\r\n\r\n").encode()
sock=socket.create_connection((HOST,PORT),timeout=8);sock.sendall(wire)
data=b""
while b"\r\n\r\n" not in data:data+=sock.recv(4096)
assert b"101 Switching Protocols" in data,data
while b"io-init" not in data and len(data)<2048:data+=sock.recv(4096)
assert b"io-init" in data
sock.close()
code,raw=request("POST","/api/auth/code",{"email":"local@example.com"})
assert code==200,(code,raw)
flow=json.loads(raw)["flow"]
code,raw=request("POST","/api/auth/verify",{"code":"123456","flow":flow})
assert code==200,(code,raw)
jwt=json.loads(raw)["token"]
code,raw=request("POST","/api/join",{"host":"http://127.0.0.1:"+str(PORT)+"/s/MB","auth":jwt},{"X-MooIO-Code":"testing42"})
assert code==200,(code,raw)
member_ticket=json.loads(raw)["ticket"]
mb_wire=wire.replace(b"/s/LC?",b"/s/MB?").replace(ticket.encode(),member_ticket.encode())
mb=socket.create_connection((HOST,PORT),timeout=8)
mb.sendall(mb_wire);reply=b""
while b"101 Switching Protocols" not in reply:reply+=mb.recv(4096)
while b"io-init" not in reply and len(reply)<2048:reply+=mb.recv(4096)
assert b"io-init" in reply
mb.close()
replay=socket.create_connection((HOST,PORT),timeout=8)
replay.sendall(mb_wire)
assert b"403 Forbidden" in replay.recv(4096)
replay.close()
code,raw=request("POST","/shutdown",headers={"X-MooIO-Code":"testing42"},port=PORT+1)
assert code==200 and json.loads(raw)["ok"]
print("PASS Lua LOCAL LC and MB auth, one-use ticket, io-init and shutdown")
