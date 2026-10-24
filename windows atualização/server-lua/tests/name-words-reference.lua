-- SPDX-License-Identifier: MIT
-- Exact word-order and Player.setUserData validation against Node source.
local words=require("server-lua.world.name_words")
local Identity=require("server-lua.world.player_identity")
local function hex(s)
 return (s:gsub(".",function(c)return string.format("%02x",string.byte(c))end))
end
for i,v in ipairs(words) do print("WORD|"..(i-1).."|"..hex(v)) end
local cases={
 {id="ordinary",name="Explorer"},{id="spaces",name="   Player  One   "},
 {id="short",name="Hi"},{id="long",name="LongPlayerCharacterName1234"},
 {id="whitespace",name="   "},{id="empty",name=""},
 {id="qweir",name="qweir"},{id="discord",name="discord"},
 {id="digits",name="d1sc0rd"},{id="decorated",name="-Long-Player-"},
 {id="unicode",name="Ação bonita"},{id="emoji",name="Rock🔥Star"},
 {id="punctuation",name="User@34#&+!"},{id="skin",name="Player",skin=2},
 {id="bad-skin",name="Player",skin=999},
 {id="anon-guest",name="Explorer",anon=true},
 {id="anon-account",name="Explorer",anon=true,account="Member"},
 {id="anon-account-disabled",name="Explorer",anon=false,account="Member"},
 {id="account-override",name="Explorer",account="Permanent"},
 {id="empty-account",name="Explorer",account=""},
 {id="lower",name="hello123"},
 {id="numeric",name=1234},{id="null",name=nil},
 {id="truth",name=true}
}
for _,tc in ipairs(cases) do
 local p=Identity.new("id",4,{hats={},accessories={}})
 p.name="old";p.skinColor=4;p.anon=true
 if tc.account~=nil then p.account={name=tc.account} end
 p:setUserData({name=tc.name,skin=tc.skin,anon=tc.anon})
 print(table.concat({"NAME",tc.id,hex(p.name),p.skinColor,
   p.anon and 1 or 0},"|"))
end
assert(#words==986,"source-versioned NAME_WORDS count changed")
