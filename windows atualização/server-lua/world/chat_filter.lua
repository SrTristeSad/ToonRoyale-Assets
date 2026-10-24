-- SPDX-License-Identifier: AGPL-3.0-only
-- Faithful translation of original libs/filterchat.js:
-- 1) JS .slice(0,30) UTF-16 code units, skipping code units >126;
-- 2) replace every literal occurrence for each Filter().list entry (gi)
--    with "M" + "o" repeated (word.length - 1), also mid-word.
-- The Filter 4.0.0 list = localList ++ badwords-list baseList only;
-- Moo-IO NAME_WORDS extras are for nicknames, not chat messages.
local Words=require("server-lua.world.name_words")
local Filter={}
local CHAT_WORDS_COUNT=896 -- pinned bad-words@4.0.0 + badwords-list@2.0.1-4
local function sanitize(message)
 local result={}
 local units=0
 for _,cp in utf8.codes(message) do
   local n=cp>65535 and 2 or 1
   if units+n>30 then break end
   units=units+n
   if cp<=126 then result[#result+1]=string.char(cp) end
 end
 return table.concat(result)
end
function Filter.clean(message)
 assert(type(message)=="string","original chat input must be a string")
 local result=sanitize(message)
 for index=1,CHAT_WORDS_COUNT do
   local word=Words[index]
   if word and #word>0 then
     local needle=string.lower(word)
     local replacement="M"..string.rep("o",#word-1)
     local pos=1
     while pos<=#result do
       local start,finish=string.find(string.lower(result),needle,pos,true)
       if not start then break end
       result=result:sub(1,start-1)..replacement..result:sub(finish+1)
       pos=start+#replacement
     end
   end
 end
 return result
end
return Filter
