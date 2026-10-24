# stdlib-only test of real LuaSocket listener / HTTP / ticket / WebSocket upgrade
import http.client
import json
import socket
import base64
import os
import struct

HOST="127.0.0.1"
PORT=18943

def request(method, path, body=None, headers=None):
    c=http.client.HTTPConnection(HOST,PORT,timeout=3)
    c.request(method,path,body=body,headers=headers or {})
    r=c.getresponse()
    status=r.status
    payload=r.read()
    c.close()
    return status,payload

status, body=request("GET","/ping")
assert status==200,(status,body)
data=json.loads(body)
assert data["build"]=="testbuild01"
assert data["servers"][0]["playerCapacity"]==40
status, body=request("GET","/mooio/protocol")
assert status==200
build=json.loads(body)
assert build["salt"]==0x12345678 and len(build["constants"])==8
payload=b'{"host":"http://127.0.0.1:18943/s/LC","captcha":true}'
status,body=request("POST","/api/join",body=payload,headers={
    "Content-Type":"application/json","Content-Length":str(len(payload)),"X-MooIO-Code":"wrongcode"
})
assert status==403,(status,body)
status,body=request("POST","/api/join",body=payload,headers={
    "Content-Type":"application/json","Content-Length":str(len(payload)),"X-MooIO-Code":"testing42"
})
assert status==200,(status,body)
ticket=json.loads(body)["ticket"]
assert len(ticket)==36
nonce=base64.b64encode(os.urandom(16)).decode()
path=f"/s/LC?b=testbuild01&token=tk:{ticket}"
headers=(f"GET {path} HTTP/1.1\r\n"
         f"Host: 127.0.0.1:18943\r\n"
         f"Origin: http://127.0.0.1:18943\r\n"
         f"Upgrade: websocket\r\nConnection: Upgrade\r\n"
         f"Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: {nonce}\r\n\r\n").encode()
s=socket.create_connection((HOST,PORT),timeout=3)
s.sendall(headers)
resp=b""
while b"\r\n\r\n" not in resp:
    resp+=s.recv(4096)
assert b"101 Switching Protocols" in resp,resp
assert b"Sec-WebSocket-Accept" in resp,resp
_,_,remaining=resp.partition(b"\r\n\r\n")
while len(remaining)<2: remaining+=s.recv(4096)
assert remaining[0]==0x82,remaining[:8]
second=remaining[1]
assert second<128, "server sent illegally masked frame"
payloadLen=second
offset=2
if second==126:
    while len(remaining)<4:remaining+=s.recv(4096)
    payloadLen=struct.unpack("!H",remaining[2:4])[0]
    offset=4
while len(remaining)<offset+payloadLen:remaining+=s.recv(4096)
handshake=remaining[offset:offset+payloadLen]
assert b"io-init" in handshake,handshake[:50]
s.close()
# Tickets are single use.
c=socket.create_connection((HOST,PORT),timeout=3)
c.sendall(headers)
assert b"403 Forbidden" in c.recv(4096)
c.close()
print("OK: Lua HTTP / guest invite / one-use ticket / WebSocket / io-init")
