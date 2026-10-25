// SPDX-License-Identifier: AGPL-3.0-only
// Every original field, position and item/group identity against native Lua.
import items from "../../shared/config/items.js";
import store from "../../shared/config/store.js";
function val(v){
 if(typeof v==="string")return "s:"+v;
 if(typeof v==="number")return "n:"+String(v);
 if(typeof v==="boolean")return "b:"+String(v);
 if(v==null)return "nil";
 if(typeof v==="function")return "function";
 throw Error("unsupported scalar "+typeof v);
}
function flatten(kind,index,value,path=""){
 if(Array.isArray(value)){
  value.forEach((v,i)=>flatten(kind,index,v,path+"["+i+"]"));
 }else if(value&&typeof value==="object"){
  // Item.group shares the same source object from items.groups.
  if(path===".group"){
    const group=items.groups.indexOf(value);
    if(group<0)throw Error("foreign source group");
    console.log(["CAT",kind,index,path,"ref:"+group].join("|"));
    return;
  }
  for(const key of Object.keys(value).sort()){
    flatten(kind,index,value[key],path+"."+key);
  }
 }else {
  console.log(["CAT",kind,index,path,val(value)].join("|"));
 }
}
for(const [kind,array] of Object.entries({
 groups:items.groups,projectiles:items.projectiles,
 weapons:items.weapons,list:items.list,
 hats:store.hats,accessories:store.accessories
})){
  console.log("COUNT|"+kind+"|"+array.length);
  array.forEach((entry,index)=>flatten(kind,index,entry));
}
const hpCases=[
 {name:"hurt",health:50},{name:"almost",health:90},
 {name:"full",health:100},{name:"over",health:120}
];
for(let foodId=0;foodId<3;foodId++){
 for(const tc of hpCases){
  const events=[];
  const p={
   health:tc.health,maxHealth:100,
   dmgOverTime:{dmg:0,time:0,doer:null},
   changeHealth(amount){
    events.push("HP:"+amount);
    if(this.health>=this.maxHealth)return false;
    this.health=Math.min(this.maxHealth,this.health+amount);
    return true;
   }
  };
  const result=items.list[foodId].consume(p);
  console.log(["FOOD",foodId,tc.name,result?1:0,p.health,
    p.dmgOverTime.dmg,p.dmgOverTime.time,
    p.dmgOverTime.doer===p?1:0,events.join(";")].join("|"));
 }
}
