-- SPDX-License-Identifier: AGPL-3.0-only
-- Original shared/config/items.js: 23 items -> existing group object IDs.
-- Lightweight catalogue for constructor/inventory differential tests.
-- Runtime should supply the FULL authoritative items catalogue to Player.new.
local groups={}
for id=0,13 do groups[id]={id=id} end
local groupById={[0]=0,[1]=0,[2]=0,[3]=1,[4]=1,[5]=1,[6]=2,[7]=2,[8]=2,[9]=2,[10]=3,[11]=3,[12]=3,[13]=4,[14]=11,[15]=5,[16]=6,[17]=7,[18]=8,[19]=9,[20]=10,[21]=12,[22]=13}
local list={}
for id,groupId in pairs(groupById) do
  list[id]={id=id,group=groups[groupId]}
end
return {groups=groups,list=list}
