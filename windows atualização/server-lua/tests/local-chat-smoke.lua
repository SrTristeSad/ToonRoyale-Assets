local Chat=require("server-lua.world.local_chat")
local path="server-lua/tests/.chat-local-check.json"
local now=1792864800000
local clan={name="XYZ",members={{id="member1"}}}
local fake={data={clans={XYZ=clan}},
 accountById=function(_,id)return {id=id}end,
 prefsOf=function()return {clanChat=true}end}
local chat=Chat.new(path,{nowMs=function()return now end,
 store=fake,randomBytes=function(n)return string.rep("A",n)end})
chat:gameChat({name="Guest",shadowed=true},"hello","LC")
local member={account={id="member1"},name="Member",shadowed=false}
chat:gameChat(member,"hello member","MB")
chat:clanSystem("XYZ","Member joined the clan")
local reopened=Chat.new(path,{nowMs=function()return now end,store=fake})
assert(reopened.data.said.member1[1].text=="hello member")
assert(reopened.data.said.member1[1].server=="MB")
assert(reopened.data.clans.XYZ[1].system==true)
assert(reopened.data.clans.XYZ[1].text=="Member joined the clan")
local guest={name="Guest"}
for i=1,55 do chat:gameChat(guest,"line"..i,"LC")end
assert(#guest.saidLog==50 and guest.saidLog[1].text=="line6")
os.remove(path)
print("PASS chat LOCAL persistido Node: gameChat clanSystem 200/50 retention")
