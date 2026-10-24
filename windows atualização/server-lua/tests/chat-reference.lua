-- SPDX-License-Identifier: AGPL-3.0-only
-- Exact byte-visible mirror of chat-reference.mjs (Node originals).
local Filter=require("server-lua.world.chat_filter")
local Chat=require("server-lua.world.chat_input")
local Config=require("src.game.config")
local cases={
 {id="ascii",text="Hello world"},
 {id="censor-lower",text="Shit happens"},
 {id="censor-upper",text="SHIT HAPPENS"},
 {id="censor-inside",text="bullshit talk"},
 {id="censor-double",text="shit shit"},
 {id="censor-two",text="fUcK and shit"},
 {id="extended",text="Água é bom 2026!"},
 {id="emoji",text="🐸 Frogs 👑 jump"},
 {id="long-ascii",text="123456789012345678901234567890xxxxxxxx"},
 {id="utf16-boundary",text=string.rep("a",29).."😀Z"},
 {id="no-ascii",text="🔥🐷❤️"},
 {id="punctuation",text="{hello} ++ [wow]"},
 {id="newline",text="one\ntwo\rthree"},
 {id="empty",text=""},
 {id="nonascii-between",text="fuçk"},
 {id="control",text="abc\tdef\1!"}
}
local function hex(s)
 return (s:gsub(".",function(c)return string.format("%02x",string.byte(c))end))
end
for _,tc in ipairs(cases) do
 print("FILTER|"..tc.id.."|"..hex(Filter.clean(tc.text)))
end
local runs={}
for _,c in ipairs(cases)do runs[#runs+1]=c end
for _,c in ipairs({
 {id="cooldown",text="Hello",cooldown=100},
 {id="shadow",text="hello buddy",shadow=true},
 {id="dead",text="hello buddy",alive=false},
 {id="bad-input",text=12},
 {id="bad-null",text=false},
 {id="staff-absent",text="hello buddy",noChat=true},
 {id="shadow-staff-absent",text="hello buddy",noChat=true,shadow=true}
})do runs[#runs+1]=c end
for _,c in ipairs(runs)do
 local events={}
 local player={
   id="tester",sid=7,alive=c.alive~=false,
   chatCooldown=c.cooldown or 0,shadowed=c.shadow or false
 }
 player.anticheat={
   invalid=function(self,packet,why)
     events[#events+1]="INVALID:"..packet..":"..why
   end
 }
 player.send=function(self,packet,sid,text)
   events[#events+1]="SELF:"..packet..":"..sid..":"..hex(text)
 end
 local context={
   config=Config,gameKey="LC",
   broadcast=function(packet,sid,text)
     events[#events+1]="ALL:"..packet..":"..sid..":"..hex(text)
   end
 }
 if not c.noChat then
   context.chat={
     gameChat=function(self,p,text,room)
       events[#events+1]="LOG:"..p.sid..":"..hex(text)..":"..room
     end
   }
 end
 Chat.handle(context,player,{c.text})
 print(table.concat({"CHAT",c.id,player.chatCooldown,table.concat(events,";")},"|"))
end
