// SPDX-License-Identifier: AGPL-3.0-only
// Execute unchanged first-party ClanManager from Node, packet-by-packet output.
import {ClanManager} from "../../server/src/moomoo/modules/clanManager.js";
const events=[];
function val(x){
 if(x===null||x===undefined)return "~";
 if(Array.isArray(x))return x.map(val).join(",");
 if(typeof x==="object")return [x.sid,x.owner,x.clan?1:0].map(val).join(",");
 return String(x);
}
const players=[0,1,2,3].map(sid=>({
 id:"p"+sid,sid,name:"Player"+sid,team:null,isOwner:false,
 clanTag:null,alive:true,joinRequests:new Set(),
 send(name,...args){events.push(this.id+":"+name+":"+args.map(val).join(":"))}
}));
const server={broadcast(name,...args){events.push("ALL:"+name+":"+args.map(val).join(":"))}};
const mgr=new ClanManager(players,server);
const cases=[
 ["create Alpha",()=>mgr.create("Alpha",players[0])],
 ["create duplicate",()=>mgr.create("Alpha",players[2])],
 ["request member",()=>mgr.requestJoin(players[1],"Alpha")],
 ["request duplicate",()=>mgr.requestJoin(players[1],"Alpha")],
 ["accept member",()=>mgr.answerRequest(players[0],1,true)],
 ["request other",()=>mgr.requestJoin(players[2],"Alpha")],
 ["decline other",()=>mgr.answerRequest(players[0],2,false)],
 ["kick member",()=>mgr.kick(players[0],1)],
 ["request again",()=>mgr.requestJoin(players[1],"Alpha")],
 ["accept again",()=>mgr.answerRequest(players[0],1,true)],
 ["leave member",()=>mgr.leaveTribe(players[1])],
 ["rejoin request",()=>mgr.requestJoin(players[1],"Alpha")],
 ["forget request",()=>mgr.forget(players[1])],
 ["ignored answer",()=>mgr.answerRequest(players[0],1,true)],
 ["create Beta",()=>mgr.create("Beta",players[2])],
 ["owner leaves",()=>mgr.leaveTribe(players[0])],
 ["remove beta",()=>mgr.remove("Beta")],
 ["clan create",()=>{players[3].clanTag="Clan";mgr.create("clan",players[3])}],
 ["clan forbidden",()=>mgr.requestJoin(players[1],"Clan")],
 ["clan allowed",()=>{players[1].clanTag="Clan";mgr.requestJoin(players[1],"Clan")}],
 ["clan accept",()=>mgr.answerRequest(players[3],1,true)],
 ["clan kick",()=>mgr.kick(players[3],1)],
 ["clan remove",()=>mgr.remove("Clan")],
 ["recreate order A",()=>mgr.create("Alpha",players[0])],
 ["recreate order B",()=>mgr.create("Beta",players[2])],
 ["recreate order A",()=>{mgr.remove("Alpha");mgr.create("Alpha",players[0])}]
];
for(const [label,fn] of cases){
 events.length=0;
 fn();
 const list=mgr.list().map(x=>[x.sid,x.owner,x.clan?1:0].join(",")).join(";");
 const states=players.map(x=>[x.sid,x.team??"~",x.isOwner?1:0].join(",")).join(";");
 const waiting=[...players[0].joinRequests].sort((a,b)=>a-b).join(",")+
    "/"+[...players[3].joinRequests].sort((a,b)=>a-b).join(",");
 console.log(["TRIBE",label,list,states,waiting,events.join(";")].join("|"));
}
